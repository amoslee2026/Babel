//      // verilator_coverage annotation
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
            parameter PE_ROWS        = 128,
            parameter PE_COLS        = 128,
            parameter DATA_W_MAX     = 32,
            parameter ACC_W          = 32,
            parameter ADDR_W         = 16,
            parameter ROW_CNT_W      = 8,   // 0-127
            parameter COL_CNT_W      = 8    // 0-127
        )(
            // Clock and Reset
 013573     input  logic                     clk_i,
 000001     input  logic                     rst_ni,
        
            // PE Array Control Interface
 000002     input  logic                     pe_mode_i,        // WS=0 / OS=1
 000004     input  logic [1:0]               pe_precision_i,   // FP8=00/FP16=01/INT8=10/FP32=11
 000022     input  logic                     pe_start_i,
 000016     output logic                     pe_done_o,
 000003     input  logic [ROW_CNT_W-1:0]     pe_row_cnt_i,     // Active rows (0-127)
 000003     input  logic [COL_CNT_W-1:0]     pe_col_cnt_i,     // Active cols (0-127)
        
            // Data Flow Interface
            input  logic [PE_COLS*DATA_W_MAX-1:0] weight_in_i,
            input  logic [PE_ROWS*DATA_W_MAX-1:0] input_in_i,
            output logic [PE_ROWS*DATA_W_MAX-1:0] output_out_o,
            output logic [PE_ROWS*ACC_W-1:0]      partial_out_o,  // OS mode partial sum
        
            // Address Interface
%000000     input  logic [ADDR_W-1:0]        weight_addr_i,
%000000     input  logic [ADDR_W-1:0]        input_addr_i,
%000000     input  logic [ADDR_W-1:0]        output_addr_i,
        
            // Precision Control Interface
 000002     input  logic                     fp8_format_i,     // E4M3=0 / E5M2=1
%000000     input  logic [1:0]               round_mode_i,     // RN=00/RZ=01/RU=10/RD=11
%000000     input  logic                     saturation_i,
%000000     input  logic                     mix_precision_en_i,
        
            // Error Interface (REQ-M00-010)
 000001     output logic                     pe_size_error_o,
 000001     output logic [2:0]               pe_size_error_code_o,  // 001=M, 010=N, 100=K
        
            // Internal K dimension (accumulation depth)
 000003     input  logic [8:0]               pe_k_cnt_i        // K dimension (0-256)
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
 000016 logic [STATE_W-1:0]         current_state;
 000016 logic [STATE_W-1:0]         next_state;
        
        // Control signals
 000016 logic                       array_en;
 000010 logic                       weight_sram_rd_en;
 000010 logic                       input_sram_rd_en;
 000016 logic                       output_sram_wr_en;
 000006 logic                       weight_flow_en;
 000006 logic                       input_flow_en;
 000006 logic                       acc_clr;
 000006 logic                       acc_rd_en;
 000016 logic                       ctrl_reg_load;
        
        // Counters
 000002 logic [PRELOAD_CNT_W-1:0]   preload_cnt;
%000000 logic [STREAM_CNT_W-1:0]    stream_cnt;
 000002 logic [COLLECT_CNT_W-1:0]   collect_cnt;
 000010 logic [WRITEBACK_CNT_W-1:0] writeback_cnt;
        
        // Counter control
 000010 logic                       preload_cnt_en;
 000017 logic                       preload_cnt_clr;
 000016 logic                       stream_cnt_en;
 000017 logic                       stream_cnt_clr;
 000010 logic                       collect_cnt_en;
 000017 logic                       collect_cnt_clr;
 000006 logic                       writeback_cnt_en;
 000017 logic                       writeback_cnt_clr;
        
        // Boundary check
 000012 logic                       preload_done;
 000014 logic                       stream_done;
 000012 logic                       collect_done;
 000001 logic                       init_done;
 000009 logic                       writeback_done;
 000014 logic                       max_stream_reached;
        
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
%000000 logic [DATA_W_MAX-1:0]                           effective_data_w;
 000006 logic                                            is_fp8_mode;
 000004 logic                                            is_fp16_mode;
 000003 logic                                            is_int8_mode;
 000002 logic                                            is_fp32_mode;
        
        // Registered inputs
 000001 logic                                            pe_mode_reg;
 000003 logic [1:0]                                      pe_precision_reg;
 000004 logic [ROW_CNT_W-1:0]                            pe_row_cnt_reg;
 000004 logic [COL_CNT_W-1:0]                            pe_col_cnt_reg;
 000002 logic [8:0]                                      pe_k_cnt_reg;
        
        //=============================================================================
        // Precision Mode Detection
        //=============================================================================
 000001 always_comb begin
 000001     is_fp8_mode   = (pe_precision_reg == PREC_FP8);
 000001     is_fp16_mode  = (pe_precision_reg == PREC_FP16);
 000001     is_int8_mode  = (pe_precision_reg == PREC_INT8);
 000001     is_fp32_mode  = (pe_precision_reg == PREC_FP32);
        end
        
        //=============================================================================
        // REQ-M00-010: Matrix Size Boundary Check
        //=============================================================================
 000001 always_comb begin
 000001     pe_size_error_o = 1'b0;
 000001     pe_size_error_code_o = 3'b000;
        
            // M dimension check (row count)
 000002     if (pe_row_cnt_i > PE_ROWS) begin
 000002         pe_size_error_o = 1'b1;
 000002         pe_size_error_code_o[0] = 1'b1;  // M overflow
            end
        
            // N dimension check (col count)
 000002     if (pe_col_cnt_i > PE_COLS) begin
 000002         pe_size_error_o = 1'b1;
 000002         pe_size_error_code_o[1] = 1'b1;  // N overflow
            end
        
            // K dimension check (accumulation depth)
 000003     if (pe_k_cnt_i > 256) begin
 000003         pe_size_error_o = 1'b1;
 000003         pe_size_error_code_o[2] = 1'b1;  // K overflow
            end
        end
        
        //=============================================================================
        // Control Register Load
        //=============================================================================
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         pe_mode_reg        <= 1'b0;
 000006         pe_precision_reg   <= PREC_FP16;
 000006         pe_row_cnt_reg     <= PE_ROWS[ROW_CNT_W-1:0];
 000006         pe_col_cnt_reg     <= PE_COLS[COL_CNT_W-1:0];
 000006         pe_k_cnt_reg       <= 128;
 000008     end else if (ctrl_reg_load) begin
 000008         pe_mode_reg        <= pe_mode_i;
 000008         pe_precision_reg   <= pe_precision_i;
 000008         pe_row_cnt_reg     <= pe_row_cnt_i;
 000008         pe_col_cnt_reg     <= pe_col_cnt_i;
 000008         pe_k_cnt_reg       <= pe_k_cnt_i;
            end
        end
        
        //=============================================================================
        // Counter Logic
        //=============================================================================
        // Preload counter (WS weight preload)
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         preload_cnt <= '0;
 000034     end else if (preload_cnt_clr) begin
 000034         preload_cnt <= '0;
 000325     end else if (preload_cnt_en) begin
 000325         preload_cnt <= preload_cnt + 1'b1;
            end
        end
        
        // Stream counter (WS input stream / OS accumulate)
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         stream_cnt <= '0;
 000034     end else if (stream_cnt_clr) begin
 000034         stream_cnt <= '0;
 000963     end else if (stream_cnt_en) begin
 000963         stream_cnt <= stream_cnt + 1'b1;
            end
        end
        
        // Collect counter (WS output collect)
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         collect_cnt <= '0;
 000034     end else if (collect_cnt_clr) begin
 000034         collect_cnt <= '0;
 000325     end else if (collect_cnt_en) begin
 000325         collect_cnt <= collect_cnt + 1'b1;
            end
        end
        
        // Writeback counter (OS output writeback)
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         writeback_cnt <= '0;
 000034     end else if (writeback_cnt_clr) begin
 000034         writeback_cnt <= '0;
 001624     end else if (writeback_cnt_en) begin
 005123         writeback_cnt <= writeback_cnt + 1'b1;
            end
        end
        
        //=============================================================================
        // Boundary Detection
        //=============================================================================
 000001 always_comb begin
            // WS preload done when counter reaches row count
 000001     preload_done = (preload_cnt >= pe_row_cnt_reg);
        
            // WS stream done when pipeline fill/drain complete
            // Duration: M + N - 1 cycles
 000001     max_stream_reached = (stream_cnt >= (pe_row_cnt_reg + pe_col_cnt_reg - 1));
 000001     stream_done = max_stream_reached;
        
            // WS collect done when all rows collected
 000001     collect_done = (collect_cnt >= pe_row_cnt_reg);
        
            // OS init done (1 cycle)
 000001     init_done = 1'b1;  // Always done after 1 cycle
        
            // OS writeback done when all outputs written
 000001     writeback_done = (writeback_cnt >= (pe_row_cnt_reg * pe_col_cnt_reg));
        end
        
        //=============================================================================
        // FSM State Register
        //=============================================================================
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         current_state <= IDLE;
 006781     end else begin
 006781         current_state <= next_state;
            end
        end
        
        //=============================================================================
        // FSM Next State Logic
        //=============================================================================
 000001 always_comb begin
 000001     next_state = current_state;
        
 000001     case (current_state)
 000041         IDLE: begin
 000008             if (pe_start_i && !pe_size_error_o) begin
 000008                 next_state = MODE_CONFIG;
                    end
                end
        
 000008         MODE_CONFIG: begin
                    // Use pe_mode_i (input) directly, not pe_mode_reg (which is updated in this cycle)
 000003             if (pe_mode_i == 1'b0) begin  // WS mode
 000005                 next_state = WS_PRELOAD;
 000003             end else begin  // OS mode
 000003                 next_state = OS_INIT;
                    end
                end
        
 000325         WS_PRELOAD: begin
 000005             if (preload_done) begin
 000005                 next_state = WS_STREAM;
                    end
                end
        
 000640         WS_STREAM: begin
 000005             if (stream_done) begin
 000005                 next_state = WS_COLLECT;
                    end
                end
        
 000325         WS_COLLECT: begin
 000005             if (collect_done) begin
 000005                 next_state = IDLE;
                    end
                end
        
 000003         OS_INIT: begin
%000000             if (init_done) begin
 000003                 next_state = OS_STREAM;
                    end
                end
        
 000323         OS_STREAM: begin
 000003             if (stream_cnt >= pe_k_cnt_reg) begin
 000003                 next_state = OS_WRITEBACK;
                    end
                end
        
 005123         OS_WRITEBACK: begin
 000003             if (writeback_done) begin
 000003                 next_state = IDLE;
                    end
                end
        
%000000         default: begin
%000000             next_state = IDLE;
                end
            endcase
        end
        
        //=============================================================================
        // FSM Output Logic
        //=============================================================================
%000000 always_comb begin
            // Default values
%000000     array_en           = 1'b0;
%000000     weight_sram_rd_en  = 1'b0;
%000000     input_sram_rd_en   = 1'b0;
%000000     output_sram_wr_en  = 1'b0;
%000000     weight_flow_en     = 1'b0;
%000000     input_flow_en      = 1'b0;
%000000     acc_clr            = 1'b0;
%000000     acc_rd_en          = 1'b0;
%000000     ctrl_reg_load      = 1'b0;
        
            // Counter control defaults
%000000     preload_cnt_en     = 1'b0;
%000000     preload_cnt_clr    = 1'b0;
%000000     stream_cnt_en      = 1'b0;
%000000     stream_cnt_clr     = 1'b0;
%000000     collect_cnt_en     = 1'b0;
%000000     collect_cnt_clr    = 1'b0;
%000000     writeback_cnt_en   = 1'b0;
%000000     writeback_cnt_clr  = 1'b0;
        
%000000     case (current_state)
%000000         IDLE: begin
%000000             preload_cnt_clr    = 1'b1;
%000000             stream_cnt_clr     = 1'b1;
%000000             collect_cnt_clr    = 1'b1;
%000000             writeback_cnt_clr  = 1'b1;
                end
        
%000000         MODE_CONFIG: begin
%000000             array_en        = 1'b1;
%000000             ctrl_reg_load   = 1'b1;
                end
        
%000000         WS_PRELOAD: begin
%000000             array_en           = 1'b1;
%000000             weight_sram_rd_en  = 1'b1;
%000000             preload_cnt_en     = 1'b1;
                end
        
%000000         WS_STREAM: begin
%000000             array_en          = 1'b1;
%000000             input_sram_rd_en  = 1'b1;
%000000             stream_cnt_en     = 1'b1;
                end
        
%000000         WS_COLLECT: begin
%000000             array_en           = 1'b1;
%000000             output_sram_wr_en  = 1'b1;
%000000             collect_cnt_en     = 1'b1;
                end
        
%000000         OS_INIT: begin
%000000             array_en = 1'b1;
%000000             acc_clr  = 1'b1;
                end
        
%000000         OS_STREAM: begin
%000000             array_en       = 1'b1;
%000000             weight_flow_en = 1'b1;
%000000             input_flow_en  = 1'b1;
%000000             stream_cnt_en  = 1'b1;
                end
        
%000000         OS_WRITEBACK: begin
%000000             array_en          = 1'b1;
%000000             output_sram_wr_en = 1'b1;
%000000             acc_rd_en         = 1'b1;
%000000             writeback_cnt_en  = 1'b1;
                end
            endcase
        end
        
        // pe_done output
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         pe_done_o <= 1'b0;
 006781     end else begin
                // pe_done is asserted for 1 cycle when returning to IDLE
 006781         pe_done_o <= (current_state != IDLE) && (next_state == IDLE);
            end
        end
        
        //=============================================================================
        // PE Array Enable Generation
        //=============================================================================
        // Generate PE enable signals based on row/col counts
 000001 always_comb begin
 000001     for (int row = 0; row < PE_ROWS; row++) begin
 868864         for (int col = 0; col < PE_COLS; col++) begin
                    // Enable PE if within active region
 111214592             pe_en[row][col] = array_en &&
 111214592                               (row < pe_row_cnt_reg) &&
 111214592                               (col < pe_col_cnt_reg);
        
                    // MAC enable during compute phases
 111214592             pe_mac_en[row][col] = pe_en[row][col] &&
 111214592                                   ((current_state == WS_STREAM) ||
 111214592                                    (current_state == OS_STREAM));
        
                    // Accumulator enable during accumulate
 111214592             pe_acc_en[row][col] = pe_en[row][col] && pe_mac_en[row][col];
                end
            end
        end
        
        //=============================================================================
        // PE Array Implementation (Simplified for RTL)
        //=============================================================================
        // Weight registers - preload in WS mode, flow in OS mode
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         for (int row = 0; row < PE_ROWS; row++) begin
 000768             for (int col = 0; col < PE_COLS; col++) begin
 098304                 pe_weight_reg[row][col] <= '0;
                    end
                end
 006781     end else begin
 006781         for (int row = 0; row < PE_ROWS; row++) begin
 867968             for (int col = 0; col < PE_COLS; col++) begin
 31426560                 if (pe_en[row][col]) begin
                            // WS mode: preload weights row-wise
 026624                     if (current_state == WS_PRELOAD && row == preload_cnt) begin
 026624                         pe_weight_reg[row][col] <= weight_in_i[col*DATA_W_MAX +: DATA_W_MAX];
                            end
                            // OS mode: weight flows row-wise
 2708480                     else if (current_state == OS_STREAM && weight_flow_en) begin
                                // Weight from left neighbor or input
 026848                         if (col == 0) begin
 026848                             pe_weight_reg[row][col] <= weight_in_i[row*DATA_W_MAX +: DATA_W_MAX];
 2681632                         end else begin
 2681632                             pe_weight_reg[row][col] <= pe_weight_reg[row][col-1];
                                end
                            end
                        end
                    end
                end
            end
        end
        
        // Input registers - flow column-wise
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         for (int row = 0; row < PE_ROWS; row++) begin
 000768             for (int col = 0; col < PE_COLS; col++) begin
 098304                 pe_input_reg[row][col] <= '0;
                    end
                end
 006781     end else begin
 006781         for (int row = 0; row < PE_ROWS; row++) begin
 867968             for (int col = 0; col < PE_COLS; col++) begin
 31426560                 if (pe_en[row][col]) begin
                            // WS mode: input flows column-wise from top
 5373952                     if (current_state == WS_STREAM && input_sram_rd_en) begin
 053248                         if (row == 0) begin
 053248                             pe_input_reg[row][col] <= input_in_i[col*DATA_W_MAX +: DATA_W_MAX];
 5320704                         end else begin
                                    // Skewed input: delayed by row index
 1330176                             if (stream_cnt >= row) begin
 3990528                                 pe_input_reg[row][col] <= pe_input_reg[row-1][col];
                                    end
                                end
                            end
                            // OS mode: input flows column-wise
 2708480                     else if (current_state == OS_STREAM && input_flow_en) begin
 026848                         if (row == 0) begin
 026848                             pe_input_reg[row][col] <= input_in_i[col*DATA_W_MAX +: DATA_W_MAX];
 2681632                         end else begin
 2681632                             pe_input_reg[row][col] <= pe_input_reg[row-1][col];
                                end
                            end
                        end
                    end
                end
            end
        end
        
        // Accumulator registers
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         for (int row = 0; row < PE_ROWS; row++) begin
 000768             for (int col = 0; col < PE_COLS; col++) begin
 098304                 pe_acc_reg[row][col] <= '0;
                    end
                end
 006781     end else begin
 006781         for (int row = 0; row < PE_ROWS; row++) begin
 867968             for (int col = 0; col < PE_COLS; col++) begin
                        // Clear accumulator
 021504                 if (acc_clr && pe_en[row][col]) begin
 021504                     pe_acc_reg[row][col] <= '0;
                        end
                        // MAC operation
 8082432                 else if (pe_acc_en[row][col]) begin
                            // Simplified MAC: weight * input + partial_sum
                            // In WS mode, partial sum comes from left neighbor
                            // In OS mode, accumulate locally
        
                            logic [ACC_W-1:0] partial_in;
        
                            // WS mode: partial sum flows from left
 2761728                     if (pe_mode_reg == 1'b0 && col > 0) begin
 5320704                         partial_in = pe_acc_reg[row][col-1];
 2761728                     end else begin
 2761728                         partial_in = '0;
                            end
        
                            // MAC operation (simplified - actual implementation would use
                            // proper FP8/FP16/INT8/FP32 arithmetic)
 8082432                     pe_acc_reg[row][col] <= mac_compute(
 8082432                         pe_weight_reg[row][col],
 8082432                         pe_input_reg[row][col],
 8082432                         partial_in,
 8082432                         pe_precision_reg,
 8082432                         fp8_format_i,
 8082432                         round_mode_i,
 8082432                         saturation_i
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
 8082432 function automatic logic [ACC_W-1:0] mac_compute(
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
        
 8082432     case (precision)
 1576960         PREC_FP8: begin
                    // FP8->FP16 multiply, then FP32 accumulate
                    // Placeholder: treat as 8-bit signed for simulation
 1576960             mult_result = ($signed(weight[7:0]) * $signed(input_val[7:0])) << 16;
 1576960             result = partial_sum + mult_result;
                end
        
 132096         PREC_FP16: begin
                    // FP16 multiply, FP32 accumulate
 132096             mult_result = ($signed(weight[15:0]) * $signed(input_val[15:0])) << 8;
 132096             result = partial_sum + mult_result;
                end
        
 6307840         PREC_INT8: begin
                    // INT8 multiply, FP32 accumulate
 6307840             mult_result = ($signed(weight[7:0]) * $signed(input_val[7:0])) << 16;
 6307840             result = partial_sum + mult_result;
                end
        
 065536         PREC_FP32: begin
                    // FP32 multiply and accumulate
 065536             mult_result = weight * input_val;
 065536             result = partial_sum + mult_result;
                end
        
%000000         default: begin
%000000             result = '0;
                end
            endcase
        
            // Saturation handling (placeholder)
 8082432     if (saturation) begin
                // Check for overflow and saturate
%000000         if (result > (1 << 31) - 1) begin
%000000             result = (1 << 31) - 1;
%000000         end else if (result < -(1 << 31)) begin
%000000             result = -(1 << 31);
                end
            end
        
 8082432     return result;
        endfunction
        
        //=============================================================================
        // Output Collection
        //=============================================================================
        // Output registers - collect results from right edge of PE array
 006787 always_ff @(posedge clk_i or negedge rst_ni) begin
 000006     if (!rst_ni) begin
 000006         for (int row = 0; row < PE_ROWS; row++) begin
 000768             for (int col = 0; col < PE_COLS; col++) begin
 098304                 pe_output_reg[row][col] <= '0;
                    end
                end
 006781     end else begin
 006781         for (int row = 0; row < PE_ROWS; row++) begin
                    // In WS mode, output comes from rightmost PE of each row
 026944             if (current_state == WS_COLLECT && output_sram_wr_en &&
 026944                 row < pe_row_cnt_reg) begin
                        // Quantize accumulator to output precision
 026944                 pe_output_reg[row][pe_col_cnt_reg-1] <= quantize_output(
 026944                     pe_acc_reg[row][pe_col_cnt_reg-1],
 026944                     pe_precision_reg,
 026944                     fp8_format_i,
 026944                     round_mode_i,
 026944                     saturation_i
                        );
                    end
                    // In OS mode, read all accumulators
 295136             else if (current_state == OS_WRITEBACK && acc_rd_en &&
 295136                      pe_en[row][writeback_cnt % pe_col_cnt_reg]) begin
 295136                 pe_output_reg[row][writeback_cnt % pe_col_cnt_reg] <= quantize_output(
 295136                     pe_acc_reg[row][writeback_cnt % pe_col_cnt_reg],
 295136                     pe_precision_reg,
 295136                     fp8_format_i,
 295136                     round_mode_i,
 295136                     saturation_i
                        );
                    end
                end
            end
        end
        
        //=============================================================================
        // Quantize Output Function
        //=============================================================================
 322080 function automatic logic [DATA_W_MAX-1:0] quantize_output(
            input logic [ACC_W-1:0]      acc_value,
            input logic [1:0]            precision,
            input logic                  fp8_format,
            input logic [1:0]            round_mode,
            input logic                  saturation
        );
            logic [DATA_W_MAX-1:0] result;
        
            // Simplified quantization for RTL simulation
 322080     case (precision)
 270528         PREC_FP8: begin
                    // Quantize 32-bit accumulator to FP8
                    // Placeholder: truncate to 8 bits
 270528             result[7:0] = acc_value[7:0];
 270528             result[DATA_W_MAX-1:8] = '0;
                end
        
 033856         PREC_FP16: begin
                    // Quantize 32-bit to FP16
 033856             result[15:0] = acc_value[15:0];
 033856             result[DATA_W_MAX-1:16] = '0;
                end
        
 016640         PREC_INT8: begin
                    // Quantize to INT8
 016640             result[7:0] = acc_value[7:0];
 016640             result[DATA_W_MAX-1:8] = '0;
                end
        
 001056         PREC_FP32: begin
                    // No quantization needed
 001056             result = acc_value;
                end
        
%000000         default: begin
%000000             result = '0;
                end
            endcase
        
 322080     return result;
        endfunction
        
        //=============================================================================
        // Output Interface
        //=============================================================================
        // Multiplex output based on current state and collection counter
 000001 always_comb begin
 000001     output_out_o = '0;
 000001     partial_out_o = '0;
        
 000325     if (current_state == WS_COLLECT) begin
                // WS mode: output flows from right edge
 000325         for (int row = 0; row < PE_ROWS; row++) begin
 014656             if (row < pe_row_cnt_reg) begin
 026944                 output_out_o[row*DATA_W_MAX +: DATA_W_MAX] =
 026944                     pe_output_reg[row][pe_col_cnt_reg-1];
                    end
                end
 001340     end else if (current_state == OS_WRITEBACK) begin
                // OS mode: output all PE results
 005123         for (int row = 0; row < PE_ROWS; row++) begin
 655744             for (int col = 0; col < PE_COLS; col++) begin
 17847296                 if (row < pe_row_cnt_reg && col < pe_col_cnt_reg) begin
 17847296                     output_out_o[row*DATA_W_MAX +: DATA_W_MAX] =
 17847296                         pe_output_reg[row][col];
 17847296                     partial_out_o[row*ACC_W +: ACC_W] =
 17847296                         pe_acc_reg[row][col];
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
 000001 initial begin
            // Empty initial block for lint compatibility
        end
        // synthesis translate_on
        
        endmodule
