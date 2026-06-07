// ============================================================================
// Module: M10_FFNMatMul
// Description: FFN/MatMul Unit - Transformer Feed-Forward Network pipeline
//              with SwiGLU activation and generic matrix multiplication
// ============================================================================
// Design Specification: spec_mas/M10/MAS.md
// FSM Specification: spec_mas/M10/FSM.md
// Datapath: spec_mas/M10/datapath.md
// ============================================================================
// Version: 1.0
// Status: RTL implementation
// Generated: 2026-05-17
// ============================================================================

/* verilator lint_off TIMESCALEMOD */
module M10_FFNMatMul #(
    // Configuration parameters
    parameter int DIM           = 64,        // Input/output dimension
    parameter int HIDDEN_DIM    = 256,       // Hidden dimension (4x expansion)
    parameter int DATA_WIDTH    = 32,        // FP32 data width
    parameter int VECTOR_WIDTH  = 256,       // Vector width (bits)
    parameter int LUT_DEPTH     = 256,       // Sigmoid LUT depth
    parameter int TIMEOUT_LIMIT = 65536,     // Max wait cycles for SA

    // Command definitions (4-bit)
    parameter logic [3:0] CMD_MMUL   = 4'h1,      // Matrix-vector multiply
    parameter logic [3:0] CMD_MLOAD  = 4'h2,      // Pre-load weight row
    parameter logic [3:0] CMD_MSET   = 4'h3       // Set dimension parameters
)(
    // Clock and reset
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   enable,

    // Control interface
    input  logic                   start,
    input  logic [1:0]             mode,         // 0x0: MatMul Only, 0x1: FFN Complete, 0x2: Activation Only
    output logic                   busy,
    output logic                   done,
    output logic                   error,
    output logic [7:0]             error_code,

    // Data input interface
    input  logic [VECTOR_WIDTH-1:0] x_in,        // Input vector (64 x FP32 packed)
    input  logic                   x_valid,
    output logic                   x_ready,

    // Data output interface
    output logic [VECTOR_WIDTH-1:0] y_out,       // Output vector (64 x FP32 packed)
    output logic                   y_valid,
    input  logic                   y_ready,

    // Configuration interface
    input  logic [15:0]            s_dim,        // MatMul dimension (user-defined)
    input  logic [31:0]            w_base,       // Weight base address
    input  logic [31:0]            w1_offset,    // w1 weight offset
    input  logic [31:0]            w3_offset,    // w3 weight offset
    input  logic [31:0]            w2_offset,    // w2 weight offset

    // Systolic Array Interface (M00) - Port 1 (w1, w2)
    output logic [3:0]             sa_cmd_1,
    output logic [15:0]            sa_dim_1,
    output logic [31:0]            sa_w_base_1,
    output logic [7:0]             sa_w_row_1,
    output logic [VECTOR_WIDTH-1:0] sa_input_1,
    input  logic [VECTOR_WIDTH-1:0] sa_result_1,
    input  logic                   sa_done_1,

    // Systolic Array Interface (M00) - Port 2 (w3 parallel)
    output logic [3:0]             sa_cmd_2,
    output logic [15:0]            sa_dim_2,
    output logic [31:0]            sa_w_base_2,
    output logic [7:0]             sa_w_row_2,
    output logic [VECTOR_WIDTH-1:0] sa_input_2,
    input  logic [VECTOR_WIDTH-1:0] sa_result_2,
    input  logic                   sa_done_2,

    // Systolic Array error input
    input  logic                   sa_error_in,

    // Error clear
    input  logic                   error_clear
);

    // ========== State Definitions ==========
    localparam logic [2:0]
        IDLE        = 3'b000,
        MATMUL_W1W3 = 3'b001,
        WAIT_SA1    = 3'b010,
        ACTIVATION  = 3'b011,
        MATMUL_W2   = 3'b100,
        WAIT_SA2    = 3'b101,
        OUTPUT      = 3'b110,
        ERROR       = 3'b111;

    // ========== Error Code Definitions ==========
    localparam logic [7:0]
        NO_ERROR      = 8'h00,
        ERR_TIMEOUT   = 8'h01,
        ERR_INVALID_MODE = 8'h02,
        ERR_ACT_ERROR = 8'h03,
        ERR_SA_ERROR  = 8'h04;

    // ========== Registers ==========
    logic [2:0]     state, next_state;
    logic [1:0]     mode_reg;
    logic [15:0]    dim_reg;
    logic [31:0]    w_base_reg;
    logic [31:0]    w1_offset_reg, w3_offset_reg, w2_offset_reg;

    // Command sent counter
    logic           cmd_sent_1, cmd_sent_2;

    // Activation pipeline counter
    logic [3:0]     act_cnt;
    logic           activation_done;

    // Timeout counter
    logic [15:0]    timeout_cnt;

    // Output handshake
    logic           y_valid_reg;

    // ========== Data Registers ==========
    // MatMul results (256 x FP32 = 1024 bits each, but we use VECTOR_WIDTH for simplicity)
    // For hidden_dim = 256, we need 8 x 256-bit vectors
    logic [VECTOR_WIDTH-1:0] w1_out [0:HIDDEN_DIM/DIM-1];  // 4 vectors for 256 elements
    logic [VECTOR_WIDTH-1:0] w3_out [0:HIDDEN_DIM/DIM-1];
    logic [VECTOR_WIDTH-1:0] sigmoid_out [0:HIDDEN_DIM/DIM-1];
    logic [VECTOR_WIDTH-1:0] silu_out [0:HIDDEN_DIM/DIM-1];
    logic [VECTOR_WIDTH-1:0] gate_out [0:HIDDEN_DIM/DIM-1];

    // Input buffer
    logic [VECTOR_WIDTH-1:0] x_in_reg;

    // ========== Sigmoid LUT (256 entries, FP32) ==========
    // Pre-computed sigmoid values for range [-8, 8]
    logic [DATA_WIDTH-1:0] sigmoid_lut [0:LUT_DEPTH-1];

    // LUT address and result
    logic [7:0]     lut_addr;
    logic [DATA_WIDTH-1:0] lut_result;

    // ========== Activation Pipeline Registers ==========
    logic [DATA_WIDTH-1:0] act_input_elem;
    logic [DATA_WIDTH-1:0] act_sigmoid_elem;
    logic [DATA_WIDTH-1:0] act_silu_elem;
    logic [DATA_WIDTH-1:0] act_gate_elem;
    logic [5:0]     act_elem_idx;       // Element index (0-63)
    logic [1:0]     act_vec_idx;        // Vector index (0-3)

    // ========== Internal Signals ==========
    logic           sa_start_1, sa_start_2;
    logic           act_start;

    // ========================================================================
    // Sigmoid LUT Initialization
    // ========================================================================
    /* verilator lint_off WIDTHEXPAND */
    // Initialize sigmoid LUT with pre-computed values
    // Address mapping: addr = (input + 8) * 16 (quantized)
    // For FP32 inputs, we need to quantize to 8-bit address

    initial begin
        // Initialize sigmoid LUT (simplified - real implementation would use calculated values)
        // Range: [-8, 8] mapped to [0, 255]
        for (int i = 0; i < LUT_DEPTH; i++) begin
            // Placeholder: sigmoid(x) = 1/(1+exp(-x))
            // Pre-computed values would be loaded here
            sigmoid_lut[i] = 32'h3F800000; // 1.0 as placeholder
        end
        // Real implementation would load from file or calculate
        // Example values:
        sigmoid_lut[0]    = 32'h00000000; // sigmoid(-8) ~ 0
        sigmoid_lut[128]  = 32'h3F000000; // sigmoid(0) = 0.5
        sigmoid_lut[255]  = 32'h3F800000; // sigmoid(8) ~ 1.0
    end
    /* verilator lint_on WIDTHEXPAND */

    // ========================================================================
    // LUT Read Logic
    // ========================================================================
    always_comb begin
        // Quantize FP32 input to 8-bit LUT address
        // Input range: [-8, 8] -> Address range: [0, 255]
        // Simplified: addr = clamp((input * 16) + 128)
        // For now, use direct address from activation pipeline
        lut_result = sigmoid_lut[lut_addr];
    end

    // ========================================================================
    // State Machine - State Register (Unified error handling)
    // ========================================================================
    /* verilator lint_off WIDTHEXPAND */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;
            error        <= 1'b0;
            error_code   <= NO_ERROR;
            y_valid_reg  <= 1'b0;
        end else if (enable) begin
            state <= next_state;

            // Unified error handling - check conditions before state updates
            // Check for invalid mode at start
            if (state == IDLE && start && mode > 2'h2) begin
                error      <= 1'b1;
                error_code <= ERR_INVALID_MODE;
            end

            // Check for SA error input (any time)
            if (sa_error_in && !error) begin
                error      <= 1'b1;
                error_code <= ERR_SA_ERROR;
            end

            // Clear error on error_clear request
            if (error_clear) begin
                error      <= 1'b0;
                error_code <= NO_ERROR;
            end

            // State-specific updates
            case (state)
                IDLE: begin
                    if (start && !busy && !error) begin
                        mode_reg      <= mode;
                        dim_reg       <= s_dim;
                        w_base_reg    <= w_base;
                        w1_offset_reg <= w1_offset;
                        w3_offset_reg <= w3_offset;
                        w2_offset_reg <= w2_offset;
                        x_in_reg      <= x_in;
                        busy          <= 1'b1;
                        done          <= 1'b0;
                    end
                end

                MATMUL_W1W3: begin
                    // Commands are sent in this state
                end

                WAIT_SA1: begin
                    timeout_cnt <= timeout_cnt + 1'b1;

                    // Check timeout
                    if (timeout_cnt >= TIMEOUT_LIMIT && !error) begin
                        error      <= 1'b1;
                        error_code <= ERR_TIMEOUT;
                    end

                    // Receive results when done
                    if (sa_done_1 && sa_done_2 && mode_reg == 2'h1) begin
                        w1_out[0] <= sa_result_1;
                        w3_out[0] <= sa_result_2;
                        timeout_cnt <= 16'h0;
                    end else if (sa_done_1 && mode_reg == 2'h0) begin
                        // MatMul Only mode - use port 1 result directly
                        y_out <= sa_result_1;
                        timeout_cnt <= 16'h0;
                    end
                end

                ACTIVATION: begin
                    act_cnt <= act_cnt + 1'b1;

                    // Activation pipeline (8 cycles total)
                    // activation_done is set by Activation Pipeline block
                    if (activation_done) begin
                        act_cnt <= 4'h0;
                    end
                end

                MATMUL_W2: begin
                    // Send w2 command
                end

                WAIT_SA2: begin
                    timeout_cnt <= timeout_cnt + 1'b1;

                    if (timeout_cnt >= TIMEOUT_LIMIT && !error) begin
                        error      <= 1'b1;
                        error_code <= ERR_TIMEOUT;
                    end

                    if (sa_done_1) begin
                        y_out <= sa_result_1;
                        timeout_cnt <= 16'h0;
                    end
                end

                OUTPUT: begin
                    y_valid_reg <= 1'b1;

                    if (y_ready) begin
                        y_valid_reg <= 1'b0;
                        done        <= 1'b1;
                        busy        <= 1'b0;
                    end
                end

                ERROR: begin
                    // Error state - handled by unified error logic above
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    /* verilator lint_on WIDTHEXPAND */

    // ========================================================================
    // State Machine - Next State Logic
    // ========================================================================
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start) begin
                    case (mode)
                        2'h0, 2'h1: next_state = MATMUL_W1W3;  // MatMul Only or FFN Complete
                        2'h2:       next_state = ACTIVATION;   // Activation Only
                        default:    next_state = ERROR;        // Invalid mode
                    endcase
                end else begin
                    next_state = IDLE;
                end
            end

            MATMUL_W1W3: begin
                // Wait for commands to be sent
                if (cmd_sent_1 && cmd_sent_2 && mode_reg == 2'h1) begin
                    next_state = WAIT_SA1;
                end else if (cmd_sent_1 && mode_reg == 2'h0) begin
                    next_state = WAIT_SA1;
                end else if (error) begin
                    next_state = ERROR;
                end
            end

            WAIT_SA1: begin
                if (error) begin
                    next_state = ERROR;
                end else if (sa_done_1 && sa_done_2 && mode_reg == 2'h1) begin
                    next_state = ACTIVATION;
                end else if (sa_done_1 && mode_reg == 2'h0) begin
                    next_state = OUTPUT;
                end
            end

            ACTIVATION: begin
                if (error) begin
                    next_state = ERROR;
                end else if (activation_done) begin
                    case (mode_reg)
                        2'h1: next_state = MATMUL_W2;  // Continue to w2
                        2'h2: next_state = OUTPUT;     // Activation Only complete
                        default: next_state = ERROR;
                    endcase
                end
            end

            MATMUL_W2: begin
                if (cmd_sent_1) begin
                    next_state = WAIT_SA2;
                end else if (error) begin
                    next_state = ERROR;
                end
            end

            WAIT_SA2: begin
                if (error) begin
                    next_state = ERROR;
                end else if (sa_done_1) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                if (y_ready) begin
                    next_state = IDLE;
                end
            end

            ERROR: begin
                if (error_clear && !error) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // ========================================================================
    // MatMul Command Dispatch
    // ========================================================================
    /* verilator lint_off WIDTHTRUNC */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sa_cmd_1     <= 4'h0;
            sa_cmd_2     <= 4'h0;
            sa_dim_1     <= 16'h0;
            sa_dim_2     <= 16'h0;
            sa_w_base_1  <= 32'h0;
            sa_w_base_2  <= 32'h0;
            sa_w_row_1   <= 8'h0;
            sa_w_row_2   <= 8'h0;
            sa_input_1   <= '0;
            sa_input_2   <= '0;
            cmd_sent_1   <= 1'b0;
            cmd_sent_2   <= 1'b0;
        end else if (enable) begin
            case (state)
                MATMUL_W1W3: begin
                    if (mode_reg == 2'h1 && !cmd_sent_1 && !cmd_sent_2) begin
                        // FFN Complete: send w1 and w3 commands in parallel
                        sa_cmd_1    <= CMD_MMUL;
                        sa_cmd_2    <= CMD_MMUL;
                        sa_dim_1    <= HIDDEN_DIM;
                        sa_dim_2    <= HIDDEN_DIM;
                        sa_w_base_1 <= w_base_reg + w1_offset_reg;
                        sa_w_base_2 <= w_base_reg + w3_offset_reg;
                        sa_input_1  <= x_in_reg;
                        sa_input_2  <= x_in_reg;
                        cmd_sent_1  <= 1'b1;
                        cmd_sent_2  <= 1'b1;
                    end else if (mode_reg == 2'h0 && !cmd_sent_1) begin
                        // MatMul Only: send single command
                        sa_cmd_1    <= CMD_MMUL;
                        sa_dim_1    <= dim_reg;
                        sa_w_base_1 <= w_base_reg;
                        sa_input_1  <= x_in_reg;
                        cmd_sent_1  <= 1'b1;
                    end
                end

                MATMUL_W2: begin
                    if (!cmd_sent_1) begin
                        // Send w2 command
                        sa_cmd_1    <= CMD_MMUL;
                        sa_dim_1    <= DIM;
                        sa_w_base_1 <= w_base_reg + w2_offset_reg;
                        sa_input_1  <= gate_out[0];  // Use gate result as input
                        cmd_sent_1  <= 1'b1;
                    end
                end

                default: begin
                    // Clear commands in other states
                    if (state != WAIT_SA1 && state != WAIT_SA2) begin
                        sa_cmd_1 <= 4'h0;
                        sa_cmd_2 <= 4'h0;
                        cmd_sent_1 <= 1'b0;
                        cmd_sent_2 <= 1'b0;
                    end
                end
            endcase
        end
    end
    /* verilator lint_on WIDTHTRUNC */

    // ========================================================================
    // Activation Pipeline (SwiGLU)
    // ========================================================================
    // Simplified implementation - processes one element at a time
    // Real implementation would parallelize across multiple elements

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_elem_idx    <= 6'h0;
            act_vec_idx     <= 2'h0;
            act_input_elem  <= 32'h0;
            act_sigmoid_elem <= 32'h0;
            act_silu_elem   <= 32'h0;
            act_gate_elem   <= 32'h0;
            lut_addr        <= 8'h0;
            act_start       <= 1'b0;
            activation_done <= 1'b0;

            for (int i = 0; i < HIDDEN_DIM/DIM; i++) begin
                sigmoid_out[i] <= '0;
                silu_out[i]    <= '0;
                gate_out[i]    <= '0;
            end
        end else if (enable) begin
            // Clear activation_done at start of new activation
            if (state == ACTIVATION && act_cnt == 4'h0) begin
                activation_done <= 1'b0;
            end

            if (state == ACTIVATION) begin
                // Activation pipeline stages
                case (act_cnt)
                    // Stage 1-4: Sigmoid LUT lookup (simplified)
                    4'h0: begin
                        // Start sigmoid lookup for element 0
                        act_elem_idx <= 6'h0;
                        act_vec_idx  <= 2'h0;
                        act_start    <= 1'b1;
                        // Extract element from w1_out (simplified)
                        act_input_elem <= w1_out[0][DATA_WIDTH-1:0];
                        lut_addr <= 8'h80;  // Center point (sigmoid(0) = 0.5)
                    end

                    4'h4: begin
                        // Sigmoid result received
                        act_sigmoid_elem <= lut_result;
                        // SiLU = w1 * sigmoid
                        // Placeholder multiplication result
                        act_silu_elem <= act_input_elem;  // Simplified
                    end

                    4'h6: begin
                        // Gate = silu * w3
                        // Placeholder multiplication result
                        act_gate_elem <= act_silu_elem;  // Simplified
                        gate_out[0][DATA_WIDTH-1:0] <= act_gate_elem;
                    end

                    4'h8: begin
                        // Pipeline complete
                        activation_done <= 1'b1;
                        act_start <= 1'b0;
                    end

                    default: begin
                        // Pipeline stages continue
                    end
                endcase
            end else begin
                // Clear activation_done in non-ACTIVATION states
                activation_done <= 1'b0;
                act_start <= 1'b0;
            end
        end
    end

    // ========================================================================
    // Output Assignment
    // ========================================================================
    assign y_valid = y_valid_reg;

    // ========================================================================
    // Input Ready Logic
    // ========================================================================
    always_comb begin
        x_ready = (state == IDLE && !busy);
    end

    // ========================================================================
    // Debug/Assertion Support
    // ========================================================================
    // State encoding output for debug
    logic [2:0] state_debug;
    assign state_debug = state;

    // Assertions (for simulation)
    // synthesis translate_off
    initial begin
        // Verify parameter ranges
        assert (DIM > 0) else $error("DIM must be positive");
        assert (HIDDEN_DIM > DIM) else $error("HIDDEN_DIM must be greater than DIM");
        assert (LUT_DEPTH == 256) else $error("LUT_DEPTH must be 256");
    end

    // Check for illegal state transitions
    always @(posedge clk) begin
        if (rst_n && enable) begin
            case (state)
                IDLE: begin
                    if (start && mode > 2'h2) begin
                        $warning("Invalid mode detected: %h", mode);
                    end
                end
                default: begin
                    // Other states: no specific check
                end
            endcase
        end
    end
    // synthesis translate_on

endmodule
/* verilator lint_on TIMESCALEMOD */