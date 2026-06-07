//=============================================================================
// M09: Attention Unit
// TinyStories NPU - Multi-Head Attention Computation Module
//-----------------------------------------------------------------------------
// Features:
//   - Multi-Head Attention (8 heads, head_size=8)
//   - MQA (Multi-Query Attention): 4 KV heads, 8 Query heads
//   - Causal Masking for autoregressive inference
//   - KV Cache management with overflow protection (REQ-M09-010)
//   - RoPE integration (interface to M11)
//   - SoftMax integration (interface to M12)
//-----------------------------------------------------------------------------
// Clock Domain:  CLK_SYS (250-500 MHz, DVFS)
// Power Domain:  PD_MAIN (0.7-0.9V, Power Gate)
// Base Address:  0x800A_0000
//=============================================================================

module M09_AttentionUnit #(
    // Attention Parameters (TinyStories 15M)
    parameter int N_HEADS      = 8,      // Query heads
    parameter int N_KV_HEADS   = 4,      // KV heads (MQA)
    parameter int HEAD_SIZE    = 8,      // Dimension per head
    parameter int SEQ_LEN      = 512,    // Maximum sequence length
    parameter int KV_DIM       = 32,     // KV vector dimension (4 * 8)
    parameter int KV_MUL       = 2,      // Query/KV sharing ratio

    // Address Parameters
    parameter int KV_KEY_BASE  = 32'h8004_0000,  // Key Cache base address
    parameter int KV_VAL_BASE  = 32'h8006_0000,  // Value Cache base address

    // Precision Parameters (ATTN_PRECISION register)
    parameter int PRECISION_FP32 = 0,
    parameter int PRECISION_FP16 = 1,
    parameter int PRECISION_FP8  = 2,
    parameter int PRECISION_INT8 = 3
)(
    // Clock & Reset
    input  logic        clk_sys_i,        // Main system clock
    input  logic        rst_sys_n_i,      // System reset (active low)
    input  logic        pg_main_en_i,     // Power Gate enable (from M05)

    // Activation Input Interface (from M02 SRAM)
    input  logic        act_valid_i,
    input  logic [511:0] act_data_i,      // Activation data (64-dim * 8 heads)
    input  logic [15:0] act_pos_i,        // Current token position (0-511)
    input  logic [7:0]  act_layer_i,      // Current layer index (0-4)
    output logic        act_ready_o,

    // Q/K/V Vector Interface
    input  logic        q_valid_i,
    input  logic [63:0] q_data_i,         // Query vector (8 heads * 8-dim)
    input  logic        k_valid_i,
    input  logic [31:0] k_data_i,         // Key vector (4 KV heads * 8-dim)
    input  logic        v_valid_i,
    input  logic [31:0] v_data_i,         // Value vector (4 KV heads * 8-dim)
    output logic        qkv_ready_o,

    // KV Cache Interface (to M02 SRAM)
    output logic [19:0] kv_addr_o,
    output logic [63:0] kv_wdata_o,
    output logic        kv_wen_o,
    input  logic [63:0] kv_rdata_i,
    output logic        kv_valid_o,
    input  logic        kv_ready_i,

    // Systolic Array Interface (to M00)
    output logic        sa_cmd_valid_o,
    input  logic        sa_cmd_ready_i,
    output logic [1:0]  sa_op_o,          // 0=QK, 1=AV
    output logic [7:0]  sa_head_o,
    output logic [15:0] sa_pos_o,
    input  logic        sa_result_valid_i,
    input  logic [255:0] sa_result_data_i,
    output logic        sa_result_ready_o,

    // SoftMax Interface (to M12)
    output logic        sm_valid_o,
    output logic [511:0] sm_data_o,       // Score vector
    output logic [7:0]  sm_head_o,
    input  logic        sm_ready_i,
    input  logic        sm_result_valid_i,
    input  logic [511:0] sm_result_data_i, // Attention weights

    // Output Interface (to M02 SRAM)
    output logic        out_valid_o,
    output logic [63:0] out_data_o,       // Attention output
    output logic [7:0]  out_layer_o,
    input  logic        out_ready_i,

    // Control Interface (from M08 Scheduler)
    input  logic        attn_start_i,
    input  logic [1:0]  attn_phase_i,     // 0=Score, 1=SoftMax, 2=Output
    input  logic [7:0]  attn_head_sel_i,
    output logic        attn_done_o,
    output logic        attn_busy_o,

    // RoPE Interface (to M11)
    input  logic        rope_en_i,
    input  logic [63:0] rope_q_rotated_i,
    input  logic [31:0] rope_k_rotated_i,
    input  logic        rope_valid_i,

    // Error/Status Outputs
    output logic        kv_overflow_o,    // REQ-M09-010: KV Cache overflow flag
    output logic        error_o           // General error flag
);

    //=========================================================================
    // FSM State Definitions
    //=========================================================================
    typedef enum logic [3:0] {
        IDLE        = 4'b0000,  // Waiting for attn_start
        QKV_LOAD    = 4'b0001,  // Loading Q/K/V vectors from SRAM
        ROPE_WAIT   = 4'b0010,  // Waiting for RoPE rotation (optional)
        SCORE_INIT  = 4'b0011,  // Initialize Score computation
        SCORE_COMPUTE = 4'b0100, // Computing Q*K^T via M00
        CAUSAL_MASK = 4'b0101,  // Applying causal mask
        SOFTMAX_WAIT = 4'b0110, // Waiting for SoftMax from M12
        AV_COMPUTE  = 4'b0111,  // Computing Attention*V via M00
        KV_UPDATE   = 4'b1000,  // Updating KV Cache
        OUTPUT_STORE = 4'b1001, // Storing output to SRAM
        DONE        = 4'b1010   // Completion state
    } state_t;

    logic [3:0] current_state, next_state;

    //=========================================================================
    // Internal Registers
    //=========================================================================

    // Position and Layer tracking
    logic [15:0] current_pos_r;
    logic [7:0]  current_layer_r;
    logic [7:0]  current_head_r;
    logic [2:0]  current_kv_head_r;  // 0-3 for MQA

    // Score computation counters
    logic [15:0] score_cnt_r;        // Score position counter
    logic [7:0]  head_cnt_r;         // Head index counter (0-7)
    logic [3:0]  retry_cnt_r;        // Timeout retry counter

    // Q/K/V buffers
    logic [63:0] q_buffer_r;         // Query buffer (8 heads * 8-dim)
    logic [31:0] k_buffer_r;         // Key buffer (4 KV heads * 8-dim)
    logic [31:0] v_buffer_r;         // Value buffer (4 KV heads * 8-dim)

    // Score accumulator (FP32 for precision)
    logic [511:0] score_buffer_r;    // Score vector (8 heads * 64 positions)
    logic [511:0] masked_score_r;    // Masked score vector

    // Attention weights buffer
    logic [511:0] weights_buffer_r;  // From SoftMax

    // Output buffer
    logic [63:0] output_buffer_r;    // Attention output

    // Control flags
    logic rope_bypass_r;             // RoPE skip flag
    logic mask_done_r;               // Causal mask completion
    logic kv_overflow_flag_r;        // REQ-M09-010: Overflow detection

    // Configuration registers (from control interface)
    logic causal_mask_en_r;          // Causal masking enable
    logic kv_update_en_r;            // KV Cache update enable
    logic [1:0] data_precision_r;    // Data precision mode
    logic [31:0] scale_factor_r;     // Attention scale = 1/sqrt(head_size)

    //=========================================================================
    // MQA Head Mapping Logic
    //=========================================================================
    // Query heads share KV heads:
    //   Head 0,1 -> KV Head 0
    //   Head 2,3 -> KV Head 1
    //   Head 4,5 -> KV Head 2
    //   Head 6,7 -> KV Head 3

    function automatic logic [2:0] get_kv_head(input logic [7:0] q_head);
        get_kv_head = q_head[2:1];
    endfunction

    //=========================================================================
    // KV Cache Address Generator
    //=========================================================================
    // Key Cache: addr = KV_KEY_BASE + layer*seq_len*kv_dim*2 + pos*kv_dim*2 + kv_head*head_size*2
    // Value Cache: addr = KV_VAL_BASE + layer*seq_len*kv_dim*2 + pos*kv_dim*2 + kv_head*head_size*2

    function automatic logic [19:0] calc_kv_addr(
        input logic [7:0]  layer,
        input logic [15:0] pos,
        input logic [2:0]  kv_head,
        input logic        is_value  // 0=Key, 1=Value
    );
        logic [31:0] base_addr;
        logic [31:0] offset;

        base_addr = is_value ? KV_VAL_BASE : KV_KEY_BASE;
        offset = (layer * SEQ_LEN * KV_DIM * 2) +
                 (pos * KV_DIM * 2) +
                 (kv_head * HEAD_SIZE * 2);

        calc_kv_addr = base_addr[19:0] + offset[19:0];
    endfunction

    //=========================================================================
    // Causal Mask Logic
    //=========================================================================
    // Apply mask: score[i] = -inf for i > current_pos

    function automatic logic [511:0] apply_causal_mask(
        input logic [511:0] scores,
        input logic [15:0] pos,
        input logic [1:0]  precision
    );
        logic [511:0] masked_scores;
        logic [15:0] i;

        // Mask value based on precision
        logic [63:0] mask_val;
        case (precision)
            PRECISION_FP32: mask_val = 64'hFFFFFFFF_E0000000;  // -1e20 approx
            PRECISION_FP16: mask_val = 64'hFFFF_FFFF_FFFF;     // -65504 per element
            default:        mask_val = 64'hFFFF_FFFF_FFFF;     // FP8: -240
        endcase

        masked_scores = scores;

        // Apply mask for positions > current_pos
        for (i = 0; i < 64; i++) begin
            if (i > pos) begin
                masked_scores[i*8 +: 8] = mask_val[7:0];
            end
        end

        apply_causal_mask = masked_scores;
    endfunction

    //=========================================================================
    // REQ-M09-010: KV Cache Overflow Protection
    //=========================================================================

    always_comb begin
        kv_overflow_flag_r = (current_pos_r >= SEQ_LEN);
    end

    //=========================================================================
    // FSM State Transition Logic
    //=========================================================================

    always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
        if (!rst_sys_n_i) begin
            current_state <= IDLE;
        end else if (!pg_main_en_i) begin
            current_state <= IDLE;  // Power gate: return to idle
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (attn_start_i) begin
                    next_state = QKV_LOAD;
                end
            end

            QKV_LOAD: begin
                if (q_valid_i && k_valid_i && v_valid_i) begin
                    if (rope_en_i) begin
                        next_state = ROPE_WAIT;
                    end else begin
                        next_state = SCORE_INIT;
                    end
                end else if (retry_cnt_r >= 15) begin
                    next_state = IDLE;  // Timeout
                end
            end

            ROPE_WAIT: begin
                if (rope_valid_i) begin
                    next_state = SCORE_INIT;
                end
            end

            SCORE_INIT: begin
                if (sa_cmd_ready_i) begin
                    next_state = SCORE_COMPUTE;
                end
            end

            SCORE_COMPUTE: begin
                if (score_cnt_r >= current_pos_r) begin
                    next_state = CAUSAL_MASK;
                end
            end

            CAUSAL_MASK: begin
                if (mask_done_r) begin
                    next_state = SOFTMAX_WAIT;
                end
            end

            SOFTMAX_WAIT: begin
                if (sm_result_valid_i) begin
                    next_state = AV_COMPUTE;
                end
            end

            AV_COMPUTE: begin
                if (sa_result_valid_i) begin
                    if (kv_update_en_r && !kv_overflow_flag_r) begin
                        next_state = KV_UPDATE;
                    end else begin
                        next_state = OUTPUT_STORE;
                    end
                end
            end

            KV_UPDATE: begin
                if (kv_ready_i) begin
                    next_state = OUTPUT_STORE;
                end
            end

            OUTPUT_STORE: begin
                if (out_ready_i) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;  // Always return to IDLE
            end

            default: next_state = IDLE;
        endcase
    end

    //=========================================================================
    // FSM Output Logic
    //=========================================================================

    always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
        if (!rst_sys_n_i) begin
            // Reset all outputs and registers
            act_ready_o       <= 1'b0;
            qkv_ready_o       <= 1'b0;
            kv_valid_o        <= 1'b0;
            kv_wen_o          <= 1'b0;
            kv_addr_o         <= 20'b0;
            kv_wdata_o        <= 64'b0;
            sa_cmd_valid_o    <= 1'b0;
            sa_op_o           <= 2'b0;
            sa_head_o         <= 8'b0;
            sa_pos_o          <= 16'b0;
            sa_result_ready_o <= 1'b0;
            sm_valid_o        <= 1'b0;
            sm_data_o         <= 512'b0;
            sm_head_o         <= 8'b0;
            out_valid_o       <= 1'b0;
            out_data_o        <= 64'b0;
            out_layer_o       <= 8'b0;
            attn_done_o       <= 1'b0;
            attn_busy_o       <= 1'b0;
            kv_overflow_o     <= 1'b0;
            error_o           <= 1'b0;

            current_pos_r     <= 16'b0;
            current_layer_r   <= 8'b0;
            current_head_r    <= 8'b0;
            current_kv_head_r <= 3'b0;
            score_cnt_r       <= 16'b0;
            head_cnt_r        <= 8'b0;
            retry_cnt_r       <= 4'b0;

            q_buffer_r        <= 64'b0;
            k_buffer_r        <= 32'b0;
            v_buffer_r        <= 32'b0;
            score_buffer_r    <= 512'b0;
            masked_score_r    <= 512'b0;
            weights_buffer_r  <= 512'b0;
            output_buffer_r   <= 64'b0;

            mask_done_r       <= 1'b0;
            causal_mask_en_r  <= 1'b1;  // Default enabled
            kv_update_en_r    <= 1'b1;
            data_precision_r  <= PRECISION_FP16;
            scale_factor_r    <= 32'h3B4E_3B4E;  // ~0.35355 (1/sqrt(8))

        end else if (!pg_main_en_i) begin
            // Power gate: reset outputs
            attn_busy_o <= 1'b0;
            act_ready_o <= 1'b0;

        end else begin
            // Default: clear handshake signals
            act_ready_o       <= 1'b0;
            qkv_ready_o       <= 1'b0;
            kv_valid_o        <= 1'b0;
            kv_wen_o          <= 1'b0;
            sa_cmd_valid_o    <= 1'b0;
            sa_result_ready_o <= 1'b0;
            sm_valid_o        <= 1'b0;
            out_valid_o       <= 1'b0;
            attn_done_o       <= 1'b0;

            case (current_state)
                IDLE: begin
                    attn_busy_o <= 1'b0;
                    if (attn_start_i) begin
                        // Store position and layer info
                        current_pos_r   <= act_pos_i;
                        current_layer_r <= act_layer_i;
                        attn_busy_o     <= 1'b1;
                        retry_cnt_r     <= 4'b0;
                        error_o         <= 1'b0;
                    end
                end

                QKV_LOAD: begin
                    act_ready_o <= 1'b1;

                    if (q_valid_i) begin
                        q_buffer_r <= q_data_i;
                        current_head_r <= attn_head_sel_i;
                    end

                    if (k_valid_i) begin
                        k_buffer_r <= k_data_i;
                        current_kv_head_r <= get_kv_head(current_head_r);
                    end

                    if (v_valid_i) begin
                        v_buffer_r <= v_data_i;
                    end

                    if (q_valid_i && k_valid_i && v_valid_i) begin
                        qkv_ready_o <= 1'b1;
                        retry_cnt_r <= 4'b0;
                    end else begin
                        retry_cnt_r <= retry_cnt_r + 1;
                        if (retry_cnt_r >= 15) begin
                            error_o <= 1'b1;  // Timeout error
                        end
                    end
                end

                ROPE_WAIT: begin
                    if (rope_valid_i) begin
                        q_buffer_r <= rope_q_rotated_i;
                        k_buffer_r <= rope_k_rotated_i;
                    end
                end

                SCORE_INIT: begin
                    sa_cmd_valid_o <= 1'b1;
                    sa_op_o        <= 2'b00;  // QK operation
                    sa_head_o      <= current_head_r;
                    sa_pos_o       <= score_cnt_r;  // Position = current score count
                    score_cnt_r    <= 16'b0;
                end

                SCORE_COMPUTE: begin
                    sa_result_ready_o <= 1'b1;

                    // Issue next SA command for next position
                    if (sa_cmd_ready_i) begin
                        sa_cmd_valid_o <= 1'b1;
                        sa_op_o        <= 2'b00;
                        sa_head_o      <= current_head_r;
                        sa_pos_o       <= score_cnt_r + 1;
                    end

                    if (sa_result_valid_i) begin
                        // Accumulate score
                        score_buffer_r <= sa_result_data_i[511:0];
                        score_cnt_r    <= score_cnt_r + 1;
                    end
                end

                CAUSAL_MASK: begin
                    // Apply causal mask in one cycle
                    if (causal_mask_en_r) begin
                        masked_score_r <= apply_causal_mask(
                            score_buffer_r,
                            current_pos_r,
                            data_precision_r
                        );
                    end else begin
                        masked_score_r <= score_buffer_r;
                    end
                    mask_done_r <= 1'b1;
                end

                SOFTMAX_WAIT: begin
                    sm_valid_o <= 1'b1;
                    sm_data_o  <= masked_score_r;
                    sm_head_o  <= current_head_r;

                    if (sm_result_valid_i) begin
                        weights_buffer_r <= sm_result_data_i;
                    end
                end

                AV_COMPUTE: begin
                    sa_cmd_valid_o    <= 1'b1;
                    sa_op_o           <= 2'b01;  // AV operation
                    sa_head_o         <= current_head_r;
                    sa_pos_o          <= current_pos_r;
                    sa_result_ready_o <= 1'b1;

                    if (sa_result_valid_i) begin
                        output_buffer_r <= sa_result_data_i[63:0];
                    end
                end

                KV_UPDATE: begin
                    // REQ-M09-010: Check overflow before writing
                    if (!kv_overflow_flag_r) begin
                        kv_valid_o <= 1'b1;
                        kv_wen_o   <= 1'b1;

                        // Write Key first
                        kv_addr_o  <= calc_kv_addr(
                            current_layer_r,
                            current_pos_r,
                            current_kv_head_r,
                            1'b0  // is_value = 0 for Key
                        );
                        kv_wdata_o <= {k_buffer_r, 32'b0};

                        // Then write Value (2-cycle operation)
                        if (kv_ready_i) begin
                            kv_addr_o  <= calc_kv_addr(
                                current_layer_r,
                                current_pos_r,
                                current_kv_head_r,
                                1'b1  // is_value = 1 for Value
                            );
                            kv_wdata_o <= {v_buffer_r, 32'b0};
                        end
                    end else begin
                        // Overflow: skip write, set flag
                        kv_overflow_o <= 1'b1;
                    end
                end

                OUTPUT_STORE: begin
                    out_valid_o  <= 1'b1;
                    out_data_o   <= output_buffer_r;
                    out_layer_o  <= current_layer_r;
                end

                DONE: begin
                    attn_done_o <= 1'b1;
                    attn_busy_o <= 1'b0;

                    // Clear overflow flag if no overflow occurred
                    if (!kv_overflow_flag_r) begin
                        kv_overflow_o <= 1'b0;
                    end
                end

                default: begin
                    // Should not happen
                    error_o <= 1'b1;
                end
            endcase
        end
    end

    //=========================================================================
    // Assertions for Verification
    //=========================================================================

`ifdef VERIFICATION
    // REQ-M09-010: Overflow detection should trigger flag
    assert property (@(posedge clk_sys_i)
        (current_pos_r >= SEQ_LEN) |-> kv_overflow_flag_r)
        else $error("REQ-M09-010: KV overflow flag not set");

    // FSM should always return to IDLE after DONE
    assert property (@(posedge clk_sys_i)
        (current_state == DONE) |=> (current_state == IDLE))
        else $error("FSM: Did not return to IDLE after DONE");
`endif

    // Handshake protocol: valid and ready should not both be high at same cycle
    // for outputs that require response

    //=========================================================================
    // Debug Signals (Optional)
    //=========================================================================

    // State debug output (can be connected to testbench or debug interface)
    logic [3:0] debug_state;
    assign debug_state = current_state;

    // Score counter debug
    logic [15:0] debug_score_cnt;
    assign debug_score_cnt = score_cnt_r;

endmodule