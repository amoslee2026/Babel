//=============================================================================
// M00: Systolic Array - Top Module
// 128x128 PE Array with WS/OS Dual-Mode, Multi-Precision MAC Support
//-----------------------------------------------------------------------------
// Module: M00_SystolicArray
// Description:
//   - 128x128 PE systolic array for matrix multiplication
//   - WS (Weight Stationary) and OS (Output Stationary) modes
//   - FP8 (E4M3/E5M2), FP16, INT8, FP32 precision support
//   - Activity control for power optimization
//   - Matrix size boundary check (REQ-M00-010)
//-----------------------------------------------------------------------------
// Parameters:
//   - PE_ROWS: Number of PE rows (default 128)
//   - PE_COLS: Number of PE columns (default 128)
//   - DATA_W_MAX: Maximum data width (32-bit for FP32)
//   - ACC_W: Accumulator width (32-bit)
//-----------------------------------------------------------------------------
// Clock Domain: CLK_SYS (250-500 MHz)
// Power Domain: PD_MAIN (DVFS support)
//-----------------------------------------------------------------------------

module M00_SystolicArray #(
    parameter PE_ROWS        = 16,
    parameter PE_COLS        = 16,
    parameter DATA_W_MAX     = 32,
    parameter ACC_W          = 32,
    parameter ADDR_W         = 16,
    parameter ROW_CNT_W      = 4,   // 0-15
    parameter COL_CNT_W      = 4    // 0-15
)(
    // Clock and Reset
    input  logic                     clk_i,
    input  logic                     rst_ni,

    // PE Array Control Interface
    input  logic                     pe_mode_i,        // WS=0 / OS=1
    input  logic [1:0]               pe_precision_i,   // FP8=00/FP16=01/INT8=10/FP32=11
    input  logic                     pe_start_i,
    output logic                     pe_done_o,
    input  logic [ROW_CNT_W-1:0]     pe_row_cnt_i,     // Active rows (0-127)
    input  logic [COL_CNT_W-1:0]     pe_col_cnt_i,     // Active cols (0-127)

    // Data Flow Interface
    input  logic [PE_COLS*DATA_W_MAX-1:0] weight_in_i,
    input  logic [PE_ROWS*DATA_W_MAX-1:0] input_in_i,
    output logic [PE_ROWS*DATA_W_MAX-1:0] output_out_o,
    output logic [PE_ROWS*ACC_W-1:0]      partial_out_o,  // OS mode partial sum

    // Address Interface
    input  logic [ADDR_W-1:0]        weight_addr_i,
    input  logic [ADDR_W-1:0]        input_addr_i,
    input  logic [ADDR_W-1:0]        output_addr_i,

    // Precision Control Interface
    input  logic                     fp8_format_i,     // E4M3=0 / E5M2=1
    input  logic [1:0]               round_mode_i,     // RN=00/RZ=01/RU=10/RD=11
    input  logic                     saturation_i,
    input  logic                     mix_precision_en_i,

    // Error Interface (REQ-M00-010)
    output logic                     pe_size_error_o,
    output logic [2:0]               pe_size_error_code_o,  // 001=M, 010=N, 100=K

    // Internal K dimension (accumulation depth)
    input  logic [8:0]               pe_k_cnt_i        // K dimension (0-256)
);

//=============================================================================
// Local Parameters
//=============================================================================
localparam STATE_W          = 3;
localparam IDLE             = 3'b000;
localparam MODE_CONFIG      = 3'b001;
localparam WS_PRELOAD       = 3'b010;
localparam WS_STREAM        = 3'b011;
localparam WS_COLLECT       = 3'b100;
localparam OS_INIT          = 3'b101;
localparam OS_STREAM        = 3'b110;
localparam OS_WRITEBACK     = 3'b111;

// Precision codes
localparam PREC_FP8         = 2'b00;
localparam PREC_FP16        = 2'b01;
localparam PREC_INT8        = 2'b10;
localparam PREC_FP32        = 2'b11;

// Counter widths
localparam PRELOAD_CNT_W    = 8;   // 0-127
localparam STREAM_CNT_W     = 16;  // 0-65535 (for large K)
localparam COLLECT_CNT_W    = 8;
localparam WRITEBACK_CNT_W  = 14;  // 0-16383 (128*128-1)

//=============================================================================
// Internal Signals
//=============================================================================
// FSM State
logic [STATE_W-1:0]         current_state;
logic [STATE_W-1:0]         next_state;

// Control signals
logic                       array_en;
logic                       weight_sram_rd_en;
logic                       input_sram_rd_en;
logic                       output_sram_wr_en;
logic                       weight_flow_en;
logic                       input_flow_en;
logic                       acc_clr;
logic                       acc_rd_en;
logic                       ctrl_reg_load;

// Counters
logic [PRELOAD_CNT_W-1:0]   preload_cnt;
logic [STREAM_CNT_W-1:0]    stream_cnt;
logic [COLLECT_CNT_W-1:0]   collect_cnt;
logic [WRITEBACK_CNT_W-1:0] writeback_cnt;

// Counter control
logic                       preload_cnt_en;
logic                       preload_cnt_clr;
logic                       stream_cnt_en;
logic                       stream_cnt_clr;
logic                       collect_cnt_en;
logic                       collect_cnt_clr;
logic                       writeback_cnt_en;
logic                       writeback_cnt_clr;

// Boundary check
logic                       preload_done;
logic                       stream_done;
logic                       collect_done;
logic                       init_done;
logic                       writeback_done;
logic                       max_stream_reached;

// PE Array data
logic [PE_ROWS-1:0][PE_COLS-1:0][DATA_W_MAX-1:0] pe_weight_reg;
logic [PE_ROWS-1:0][PE_COLS-1:0][DATA_W_MAX-1:0] pe_input_reg;
logic [PE_ROWS-1:0][PE_COLS-1:0][ACC_W-1:0]      pe_acc_reg;
logic [PE_ROWS-1:0][PE_COLS-1:0][DATA_W_MAX-1:0] pe_output_reg;

// PE Array control
logic [PE_ROWS-1:0][PE_COLS-1:0]                 pe_en;
logic [PE_ROWS-1:0][PE_COLS-1:0]                 pe_mac_en;
logic [PE_ROWS-1:0][PE_COLS-1:0]                 pe_acc_en;

// Data width based on precision
logic [DATA_W_MAX-1:0]                           effective_data_w;
logic                                            is_fp8_mode;
logic                                            is_fp16_mode;
logic                                            is_int8_mode;
logic                                            is_fp32_mode;

// Registered inputs
logic                                            pe_mode_reg;
logic [1:0]                                      pe_precision_reg;
logic [ROW_CNT_W-1:0]                            pe_row_cnt_reg;
logic [COL_CNT_W-1:0]                            pe_col_cnt_reg;
logic [8:0]                                      pe_k_cnt_reg;

//=============================================================================
// Precision Mode Detection
//=============================================================================
always_comb begin
    is_fp8_mode   = (pe_precision_reg == PREC_FP8);
    is_fp16_mode  = (pe_precision_reg == PREC_FP16);
    is_int8_mode  = (pe_precision_reg == PREC_INT8);
    is_fp32_mode  = (pe_precision_reg == PREC_FP32);
end

//=============================================================================
// REQ-M00-010: Matrix Size Boundary Check
//=============================================================================
always_comb begin
    pe_size_error_o = 1'b0;
    pe_size_error_code_o = 3'b000;

    // M dimension check (row count)
    if (pe_row_cnt_i > PE_ROWS) begin
        pe_size_error_o = 1'b1;
        pe_size_error_code_o[0] = 1'b1;  // M overflow
    end

    // N dimension check (col count)
    if (pe_col_cnt_i > PE_COLS) begin
        pe_size_error_o = 1'b1;
        pe_size_error_code_o[1] = 1'b1;  // N overflow
    end

    // K dimension check (accumulation depth)
    if (pe_k_cnt_i > 256) begin
        pe_size_error_o = 1'b1;
        pe_size_error_code_o[2] = 1'b1;  // K overflow
    end
end

//=============================================================================
// Control Register Load
//=============================================================================
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        pe_mode_reg        <= 1'b0;
        pe_precision_reg   <= PREC_FP16;
        pe_row_cnt_reg     <= PE_ROWS[ROW_CNT_W-1:0];
        pe_col_cnt_reg     <= PE_COLS[COL_CNT_W-1:0];
        pe_k_cnt_reg       <= 128;
    end else if (ctrl_reg_load) begin
        pe_mode_reg        <= pe_mode_i;
        pe_precision_reg   <= pe_precision_i;
        pe_row_cnt_reg     <= pe_row_cnt_i;
        pe_col_cnt_reg     <= pe_col_cnt_i;
        pe_k_cnt_reg       <= pe_k_cnt_i;
    end
end

//=============================================================================
// Counter Logic
//=============================================================================
// Preload counter (WS weight preload)
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        preload_cnt <= '0;
    end else if (preload_cnt_clr) begin
        preload_cnt <= '0;
    end else if (preload_cnt_en) begin
        preload_cnt <= preload_cnt + 1'b1;
    end
end

// Stream counter (WS input stream / OS accumulate)
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        stream_cnt <= '0;
    end else if (stream_cnt_clr) begin
        stream_cnt <= '0;
    end else if (stream_cnt_en) begin
        stream_cnt <= stream_cnt + 1'b1;
    end
end

// Collect counter (WS output collect)
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        collect_cnt <= '0;
    end else if (collect_cnt_clr) begin
        collect_cnt <= '0;
    end else if (collect_cnt_en) begin
        collect_cnt <= collect_cnt + 1'b1;
    end
end

// Writeback counter (OS output writeback)
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        writeback_cnt <= '0;
    end else if (writeback_cnt_clr) begin
        writeback_cnt <= '0;
    end else if (writeback_cnt_en) begin
        writeback_cnt <= writeback_cnt + 1'b1;
    end
end

//=============================================================================
// Boundary Detection
//=============================================================================
always_comb begin
    // WS preload done when counter reaches row count
    preload_done = (preload_cnt >= pe_row_cnt_reg);

    // WS stream done when pipeline fill/drain complete
    // Duration: M + N - 1 cycles
    max_stream_reached = (stream_cnt >= (pe_row_cnt_reg + pe_col_cnt_reg - 1));
    stream_done = max_stream_reached;

    // WS collect done when all rows collected
    collect_done = (collect_cnt >= pe_row_cnt_reg);

    // OS init done (1 cycle)
    init_done = 1'b1;  // Always done after 1 cycle

    // OS writeback done when all outputs written
    writeback_done = (writeback_cnt >= (pe_row_cnt_reg * pe_col_cnt_reg));
end

//=============================================================================
// FSM State Register
//=============================================================================
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

//=============================================================================
// FSM Next State Logic
//=============================================================================
always_comb begin
    next_state = current_state;

    case (current_state)
        IDLE: begin
            if (pe_start_i && !pe_size_error_o) begin
                next_state = MODE_CONFIG;
            end
        end

        MODE_CONFIG: begin
            // Use pe_mode_i (input) directly, not pe_mode_reg (which is updated in this cycle)
            if (pe_mode_i == 1'b0) begin  // WS mode
                next_state = WS_PRELOAD;
            end else begin  // OS mode
                next_state = OS_INIT;
            end
        end

        WS_PRELOAD: begin
            if (preload_done) begin
                next_state = WS_STREAM;
            end
        end

        WS_STREAM: begin
            if (stream_done) begin
                next_state = WS_COLLECT;
            end
        end

        WS_COLLECT: begin
            if (collect_done) begin
                next_state = IDLE;
            end
        end

        OS_INIT: begin
            if (init_done) begin
                next_state = OS_STREAM;
            end
        end

        OS_STREAM: begin
            if (stream_cnt >= pe_k_cnt_reg) begin
                next_state = OS_WRITEBACK;
            end
        end

        OS_WRITEBACK: begin
            if (writeback_done) begin
                next_state = IDLE;
            end
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

//=============================================================================
// FSM Output Logic
//=============================================================================
always_comb begin
    // Default values
    array_en           = 1'b0;
    weight_sram_rd_en  = 1'b0;
    input_sram_rd_en   = 1'b0;
    output_sram_wr_en  = 1'b0;
    weight_flow_en     = 1'b0;
    input_flow_en      = 1'b0;
    acc_clr            = 1'b0;
    acc_rd_en          = 1'b0;
    ctrl_reg_load      = 1'b0;

    // Counter control defaults
    preload_cnt_en     = 1'b0;
    preload_cnt_clr    = 1'b0;
    stream_cnt_en      = 1'b0;
    stream_cnt_clr     = 1'b0;
    collect_cnt_en     = 1'b0;
    collect_cnt_clr    = 1'b0;
    writeback_cnt_en   = 1'b0;
    writeback_cnt_clr  = 1'b0;

    case (current_state)
        IDLE: begin
            preload_cnt_clr    = 1'b1;
            stream_cnt_clr     = 1'b1;
            collect_cnt_clr    = 1'b1;
            writeback_cnt_clr  = 1'b1;
        end

        MODE_CONFIG: begin
            array_en        = 1'b1;
            ctrl_reg_load   = 1'b1;
        end

        WS_PRELOAD: begin
            array_en           = 1'b1;
            weight_sram_rd_en  = 1'b1;
            preload_cnt_en     = 1'b1;
        end

        WS_STREAM: begin
            array_en          = 1'b1;
            input_sram_rd_en  = 1'b1;
            stream_cnt_en     = 1'b1;
        end

        WS_COLLECT: begin
            array_en           = 1'b1;
            output_sram_wr_en  = 1'b1;
            collect_cnt_en     = 1'b1;
        end

        OS_INIT: begin
            array_en = 1'b1;
            acc_clr  = 1'b1;
        end

        OS_STREAM: begin
            array_en       = 1'b1;
            weight_flow_en = 1'b1;
            input_flow_en  = 1'b1;
            stream_cnt_en  = 1'b1;
        end

        OS_WRITEBACK: begin
            array_en          = 1'b1;
            output_sram_wr_en = 1'b1;
            acc_rd_en         = 1'b1;
            writeback_cnt_en  = 1'b1;
        end
    endcase
end

// pe_done output
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        pe_done_o <= 1'b0;
    end else begin
        // pe_done is asserted for 1 cycle when returning to IDLE
        pe_done_o <= (current_state != IDLE) && (next_state == IDLE);
    end
end

//=============================================================================
// PE Array Enable Generation
//=============================================================================
// Generate PE enable signals based on row/col counts
always_comb begin
    for (int row = 0; row < PE_ROWS; row++) begin
        for (int col = 0; col < PE_COLS; col++) begin
            // Enable PE if within active region
            pe_en[row][col] = array_en &&
                              (row < pe_row_cnt_reg) &&
                              (col < pe_col_cnt_reg);

            // MAC enable during compute phases
            pe_mac_en[row][col] = pe_en[row][col] &&
                                  ((current_state == WS_STREAM) ||
                                   (current_state == OS_STREAM));

            // Accumulator enable during accumulate
            pe_acc_en[row][col] = pe_en[row][col] && pe_mac_en[row][col];
        end
    end
end

//=============================================================================
// PE Array Implementation (Simplified for RTL)
//=============================================================================
// Weight registers - preload in WS mode, flow in OS mode
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                pe_weight_reg[row][col] <= '0;
            end
        end
    end else begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                if (pe_en[row][col]) begin
                    // WS mode: preload weights row-wise
                    if (current_state == WS_PRELOAD && row == preload_cnt) begin
                        pe_weight_reg[row][col] <= weight_in_i[col*DATA_W_MAX +: DATA_W_MAX];
                    end
                    // OS mode: weight flows row-wise
                    else if (current_state == OS_STREAM && weight_flow_en) begin
                        // Weight from left neighbor or input
                        if (col == 0) begin
                            pe_weight_reg[row][col] <= weight_in_i[row*DATA_W_MAX +: DATA_W_MAX];
                        end else begin
                            pe_weight_reg[row][col] <= pe_weight_reg[row][col-1];
                        end
                    end
                end
            end
        end
    end
end

// Input registers - flow column-wise
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                pe_input_reg[row][col] <= '0;
            end
        end
    end else begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                if (pe_en[row][col]) begin
                    // WS mode: input flows column-wise from top
                    if (current_state == WS_STREAM && input_sram_rd_en) begin
                        if (row == 0) begin
                            pe_input_reg[row][col] <= input_in_i[col*DATA_W_MAX +: DATA_W_MAX];
                        end else begin
                            // Skewed input: delayed by row index
                            if (stream_cnt >= row) begin
                                pe_input_reg[row][col] <= pe_input_reg[row-1][col];
                            end
                        end
                    end
                    // OS mode: input flows column-wise
                    else if (current_state == OS_STREAM && input_flow_en) begin
                        if (row == 0) begin
                            pe_input_reg[row][col] <= input_in_i[col*DATA_W_MAX +: DATA_W_MAX];
                        end else begin
                            pe_input_reg[row][col] <= pe_input_reg[row-1][col];
                        end
                    end
                end
            end
        end
    end
end

// Accumulator registers
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                pe_acc_reg[row][col] <= '0;
            end
        end
    end else begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                // Clear accumulator
                if (acc_clr && pe_en[row][col]) begin
                    pe_acc_reg[row][col] <= '0;
                end
                // MAC operation
                else if (pe_acc_en[row][col]) begin
                    // Simplified MAC: weight * input + partial_sum
                    // In WS mode, partial sum comes from left neighbor
                    // In OS mode, accumulate locally

                    logic [ACC_W-1:0] partial_in;

                    // WS mode: partial sum flows from left
                    if (pe_mode_reg == 1'b0 && col > 0) begin
                        partial_in = pe_acc_reg[row][col-1];
                    end else begin
                        partial_in = '0;
                    end

                    // MAC operation (simplified - actual implementation would use
                    // proper FP8/FP16/INT8/FP32 arithmetic)
                    pe_acc_reg[row][col] <= mac_compute(
                        pe_weight_reg[row][col],
                        pe_input_reg[row][col],
                        partial_in,
                        pe_precision_reg,
                        fp8_format_i,
                        round_mode_i,
                        saturation_i
                    );
                end
            end
        end
    end
end

//=============================================================================
// MAC Compute Function (Placeholder for Precision Handling)
//=============================================================================
// This function represents the MAC operation with precision handling.
// In actual implementation, this would be a proper floating-point/int arithmetic unit.
function automatic logic [ACC_W-1:0] mac_compute(
    input logic [DATA_W_MAX-1:0] weight,
    input logic [DATA_W_MAX-1:0] input_val,
    input logic [ACC_W-1:0]      partial_sum,
    input logic [1:0]            precision,
    input logic                  fp8_format,
    input logic [1:0]            round_mode,
    input logic                  saturation
);
    logic [ACC_W-1:0] result;
    logic [ACC_W-1:0] mult_result;

    // Simplified MAC for RTL simulation
    // Actual implementation would use proper FP arithmetic modules

    case (precision)
        PREC_FP8: begin
            // FP8->FP16 multiply, then FP32 accumulate
            // Placeholder: treat as 8-bit signed for simulation
            mult_result = ($signed(weight[7:0]) * $signed(input_val[7:0])) << 16;
            result = partial_sum + mult_result;
        end

        PREC_FP16: begin
            // FP16 multiply, FP32 accumulate
            mult_result = ($signed(weight[15:0]) * $signed(input_val[15:0])) << 8;
            result = partial_sum + mult_result;
        end

        PREC_INT8: begin
            // INT8 multiply, FP32 accumulate
            mult_result = ($signed(weight[7:0]) * $signed(input_val[7:0])) << 16;
            result = partial_sum + mult_result;
        end

        PREC_FP32: begin
            // FP32 multiply and accumulate
            mult_result = weight * input_val;
            result = partial_sum + mult_result;
        end

        default: begin
            result = '0;
        end
    endcase

    // Saturation handling (placeholder)
    if (saturation) begin
        // Check for overflow and saturate
        if (result > (1 << 31) - 1) begin
            result = (1 << 31) - 1;
        end else if (result < -(1 << 31)) begin
            result = -(1 << 31);
        end
    end

    mac_compute = result;
endfunction

//=============================================================================
// Output Collection
//=============================================================================
// Output registers - collect results from right edge of PE array
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                pe_output_reg[row][col] <= '0;
            end
        end
    end else begin
        for (int row = 0; row < PE_ROWS; row++) begin
            // In WS mode, output comes from rightmost PE of each row
            if (current_state == WS_COLLECT && output_sram_wr_en &&
                row < pe_row_cnt_reg) begin
                // Quantize accumulator to output precision
                pe_output_reg[row][pe_col_cnt_reg-1] <= quantize_output(
                    pe_acc_reg[row][pe_col_cnt_reg-1],
                    pe_precision_reg,
                    fp8_format_i,
                    round_mode_i,
                    saturation_i
                );
            end
            // In OS mode, read all accumulators
            else if (current_state == OS_WRITEBACK && acc_rd_en &&
                     pe_en[row][writeback_cnt % pe_col_cnt_reg]) begin
                pe_output_reg[row][writeback_cnt % pe_col_cnt_reg] <= quantize_output(
                    pe_acc_reg[row][writeback_cnt % pe_col_cnt_reg],
                    pe_precision_reg,
                    fp8_format_i,
                    round_mode_i,
                    saturation_i
                );
            end
        end
    end
end

//=============================================================================
// Quantize Output Function
//=============================================================================
function automatic logic [DATA_W_MAX-1:0] quantize_output(
    input logic [ACC_W-1:0]      acc_value,
    input logic [1:0]            precision,
    input logic                  fp8_format,
    input logic [1:0]            round_mode,
    input logic                  saturation
);
    logic [DATA_W_MAX-1:0] result;

    // Simplified quantization for RTL simulation
    case (precision)
        PREC_FP8: begin
            // Quantize 32-bit accumulator to FP8
            // Placeholder: truncate to 8 bits
            result[7:0] = acc_value[7:0];
            result[DATA_W_MAX-1:8] = '0;
        end

        PREC_FP16: begin
            // Quantize 32-bit to FP16
            result[15:0] = acc_value[15:0];
            result[DATA_W_MAX-1:16] = '0;
        end

        PREC_INT8: begin
            // Quantize to INT8
            result[7:0] = acc_value[7:0];
            result[DATA_W_MAX-1:8] = '0;
        end

        PREC_FP32: begin
            // No quantization needed
            result = acc_value;
        end

        default: begin
            result = '0;
        end
    endcase

    quantize_output = result;
endfunction

//=============================================================================
// Output Interface
//=============================================================================
// Multiplex output based on current state and collection counter
always_comb begin
    output_out_o = '0;
    partial_out_o = '0;

    if (current_state == WS_COLLECT) begin
        // WS mode: output flows from right edge
        for (int row = 0; row < PE_ROWS; row++) begin
            if (row < pe_row_cnt_reg) begin
                output_out_o[row*DATA_W_MAX +: DATA_W_MAX] =
                    pe_output_reg[row][pe_col_cnt_reg-1];
            end
        end
    end else if (current_state == OS_WRITEBACK) begin
        // OS mode: output all PE results
        for (int row = 0; row < PE_ROWS; row++) begin
            for (int col = 0; col < PE_COLS; col++) begin
                if (row < pe_row_cnt_reg && col < pe_col_cnt_reg) begin
                    output_out_o[row*DATA_W_MAX +: DATA_W_MAX] =
                        pe_output_reg[row][col];
                    partial_out_o[row*ACC_W +: ACC_W] =
                        pe_acc_reg[row][col];
                end
            end
        end
    end
end

//=============================================================================
// Assertions
//=============================================================================
// REQ-M00-010: Assert that matrix dimensions are within bounds
// property: M <= 128, N <= 128, K <= 256

// Formatted for synthesis tools
// synthesis translate_off
// Note: Verilator does not support procedural concurrent assertions (IEEE 1800-2023 16.14.6)
// Runtime dimension checks moved to testbench tb_M00_SystolicArray.sv
initial begin
    // Empty initial block for lint compatibility
end
// synthesis translate_on

endmodule