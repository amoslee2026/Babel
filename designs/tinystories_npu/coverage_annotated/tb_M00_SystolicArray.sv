//      // verilator_coverage annotation
        //=============================================================================
        // Testbench: M00_SystolicArray
        // Cycle-based testbench for Verilator coverage collection
        //-----------------------------------------------------------------------------
        
        module tb_M00_SystolicArray (
 013573     input logic clk_i_ext  // External clock from C++
        );
        
            //=========================================================================
            // Parameters
            //=========================================================================
            localparam PE_ROWS    = 128;
            localparam PE_COLS    = 128;
            localparam DATA_W_MAX = 32;
            localparam ACC_W      = 32;
        
            //=========================================================================
            // Signals
            //=========================================================================
 013573     logic clk_i;
 000001     logic rst_ni;
 000002     logic pe_mode_i;
 000004     logic [1:0] pe_precision_i;
 000022     logic pe_start_i;
 000016     logic pe_done_o;
 000003     logic [7:0] pe_row_cnt_i;
 000003     logic [7:0] pe_col_cnt_i;
            logic [PE_COLS*DATA_W_MAX-1:0] weight_in_i;
            logic [PE_ROWS*DATA_W_MAX-1:0] input_in_i;
            logic [PE_ROWS*DATA_W_MAX-1:0] output_out_o;
            logic [PE_ROWS*ACC_W-1:0] partial_out_o;
%000000     logic [15:0] weight_addr_i;
%000000     logic [15:0] input_addr_i;
%000000     logic [15:0] output_addr_i;
 000002     logic fp8_format_i;
%000000     logic [1:0] round_mode_i;
%000000     logic saturation_i;
%000000     logic mix_precision_en_i;
 000001     logic pe_size_error_o;
 000001     logic [2:0] pe_size_error_code_o;
 000003     logic [8:0] pe_k_cnt_i;
        
            //=========================================================================
            // DUT Instance
            //=========================================================================
            M00_SystolicArray #(
                .PE_ROWS(PE_ROWS),
                .PE_COLS(PE_COLS),
                .DATA_W_MAX(DATA_W_MAX),
                .ACC_W(ACC_W)
            ) dut (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .pe_mode_i(pe_mode_i),
                .pe_precision_i(pe_precision_i),
                .pe_start_i(pe_start_i),
                .pe_done_o(pe_done_o),
                .pe_row_cnt_i(pe_row_cnt_i),
                .pe_col_cnt_i(pe_col_cnt_i),
                .weight_in_i(weight_in_i),
                .input_in_i(input_in_i),
                .output_out_o(output_out_o),
                .partial_out_o(partial_out_o),
                .weight_addr_i(weight_addr_i),
                .input_addr_i(input_addr_i),
                .output_addr_i(output_addr_i),
                .fp8_format_i(fp8_format_i),
                .round_mode_i(round_mode_i),
                .saturation_i(saturation_i),
                .mix_precision_en_i(mix_precision_en_i),
                .pe_size_error_o(pe_size_error_o),
                .pe_size_error_code_o(pe_size_error_code_o),
                .pe_k_cnt_i(pe_k_cnt_i)
            );
        
            //=========================================================================
            // Clock Assignment
            //=========================================================================
            assign clk_i = clk_i_ext;
        
            //=========================================================================
            // Test FSM States
            //=========================================================================
            typedef enum {
                INIT, RESET,
                TEST_WS_FP16, TEST_WS_FP8_E4M3, TEST_WS_FP8_E5M2,
                TEST_WS_INT8, TEST_WS_FP32,
                TEST_OS_FP16, TEST_OS_FP8, TEST_OS_INT8,
                TEST_BOUNDARY_M, TEST_BOUNDARY_N, TEST_BOUNDARY_K,
                DONE
            } test_state_t;
        
            test_state_t state;
            int wait_counter;
            int test_pass_count;
            int test_fail_count;
            int test_cycle;
        
            //=========================================================================
            // pe_done Detection
            //=========================================================================
 000016     logic pe_done_sampled;
 006786     always @(negedge clk_i) begin
 006786         pe_done_sampled = pe_done_o;
            end
        
            //=========================================================================
            // Initial Values
            //=========================================================================
 000001     initial begin
 000001         state = INIT;
 000001         test_pass_count = 0;
 000001         test_fail_count = 0;
 000001         wait_counter = 0;
 000001         test_cycle = 0;
        
 000001         rst_ni = 0;
 000001         pe_mode_i = 0;
 000001         pe_precision_i = 0;
 000001         pe_start_i = 0;
 000001         pe_row_cnt_i = 0;
 000001         pe_col_cnt_i = 0;
 000001         pe_k_cnt_i = 0;
 000001         weight_in_i = '0;
 000001         input_in_i = '0;
 000001         weight_addr_i = 0;
 000001         input_addr_i = 0;
 000001         output_addr_i = 0;
 000001         fp8_format_i = 0;
 000001         round_mode_i = 0;
 000001         saturation_i = 0;
 000001         mix_precision_en_i = 0;
            end
        
            //=========================================================================
            // Cycle Counter
            //=========================================================================
 006787     always @(posedge clk_i) begin
 006787         test_cycle = test_cycle + 1;
            end
        
            //=========================================================================
            // Test FSM
            //=========================================================================
 006787     always @(posedge clk_i) begin
 006787         case (state)
 000006             INIT: begin
 000001                 if (wait_counter >= 5) begin
 000001                     rst_ni <= 1;
 000001                     state <= RESET;
 000001                     wait_counter <= 0;
 000005                 end else begin
 000005                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000003             RESET: begin
 000001                 if (wait_counter >= 2) begin
 000001                     $display("=== Starting WS Mode Tests ===");
 000001                     state <= TEST_WS_FP16;
 000001                     wait_counter <= 0;
 000002                 end else begin
 000002                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000134             TEST_WS_FP16: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: WS FP16 32x32x64");
 000001                     pe_mode_i <= 0;
 000001                     pe_precision_i <= 2'b01;
 000001                     pe_row_cnt_i <= 32;
 000001                     pe_col_cnt_i <= 32;
 000001                     pe_k_cnt_i <= 64;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_WS_FP8_E4M3;
 000001                     wait_counter <= 0;
 000131                 end else begin
 000131                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000262             TEST_WS_FP8_E4M3: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: WS FP8 E4M3 64x64x128");
 000001                     pe_mode_i <= 0;
 000001                     pe_precision_i <= 2'b00;
 000001                     fp8_format_i <= 0;
 000001                     pe_row_cnt_i <= 64;
 000001                     pe_col_cnt_i <= 64;
 000001                     pe_k_cnt_i <= 128;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_WS_FP8_E5M2;
 000001                     wait_counter <= 0;
 000259                 end else begin
 000259                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000262             TEST_WS_FP8_E5M2: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: WS FP8 E5M2 64x64x128");
 000001                     fp8_format_i <= 1;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     fp8_format_i <= 0;
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_WS_INT8;
 000001                     wait_counter <= 0;
 000259                 end else begin
 000259                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000518             TEST_WS_INT8: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: WS INT8 128x128x256");
 000001                     pe_mode_i <= 0;
 000001                     pe_precision_i <= 2'b10;
 000001                     pe_row_cnt_i <= 128;
 000001                     pe_col_cnt_i <= 128;
 000001                     pe_k_cnt_i <= 256;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_WS_FP32;
 000001                     wait_counter <= 0;
 000515                 end else begin
 000515                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000134             TEST_WS_FP32: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: WS FP32 32x32x64");
 000001                     pe_precision_i <= 2'b11;
 000001                     pe_row_cnt_i <= 32;
 000001                     pe_col_cnt_i <= 32;
 000001                     pe_k_cnt_i <= 64;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_OS_FP16;
 000001                     wait_counter <= 0;
 000131                 end else begin
 000131                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 001095             TEST_OS_FP16: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("=== Starting OS Mode Tests ===");
 000001                     $display("Test: OS FP16 32x32x64");
 000001                     pe_mode_i <= 1;
 000001                     pe_precision_i <= 2'b01;
 000001                     pe_row_cnt_i <= 32;
 000001                     pe_col_cnt_i <= 32;
 000001                     pe_k_cnt_i <= 64;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_OS_FP8;
 000001                     wait_counter <= 0;
 001092                 end else begin
 001092                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 004231             TEST_OS_FP8: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: OS FP8 64x64x128");
 000001                     pe_precision_i <= 2'b00;
 000001                     pe_row_cnt_i <= 64;
 000001                     pe_col_cnt_i <= 64;
 000001                     pe_k_cnt_i <= 128;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_OS_INT8;
 000001                     wait_counter <= 0;
 004228                 end else begin
 004228                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000135             TEST_OS_INT8: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: OS INT8 128x128x128");
 000001                     pe_precision_i <= 2'b10;
 000001                     pe_row_cnt_i <= 128;
 000001                     pe_col_cnt_i <= 128;
 000001                     pe_k_cnt_i <= 128;
 000001                     weight_in_i <= '1;
 000001                     input_in_i <= '1;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
 000001                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
 000001                     wait_counter <= 2;
 000001                 end else if (pe_done_sampled || pe_done_o) begin
 000001                     if (pe_size_error_o) test_fail_count <= test_fail_count + 1;
 000001                     else test_pass_count <= test_pass_count + 1;
 000001                     $display("  PASS");
 000001                     state <= TEST_BOUNDARY_M;
 000001                     wait_counter <= 0;
 000132                 end else begin
 000132                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000002             TEST_BOUNDARY_M: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("=== Boundary Tests ===");
 000001                     $display("Test: M overflow (129x128x128)");
 000001                     pe_mode_i <= 0;
 000001                     pe_precision_i <= 2'b01;
 000001                     pe_row_cnt_i <= 129;
 000001                     pe_col_cnt_i <= 128;
 000001                     pe_k_cnt_i <= 128;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
%000000                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
%000000                     if (pe_size_error_o) begin
 000001                         test_pass_count <= test_pass_count + 1;
 000001                         $display("  PASS: M overflow detected");
%000000                     end else begin
%000000                         test_fail_count <= test_fail_count + 1;
%000000                         $display("  FAIL");
                            end
 000001                     state <= TEST_BOUNDARY_N;
 000001                     wait_counter <= 0;
%000000                 end else begin
%000000                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000002             TEST_BOUNDARY_N: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: N overflow (128x129x128)");
 000001                     pe_row_cnt_i <= 128;
 000001                     pe_col_cnt_i <= 129;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
%000000                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
%000000                     if (pe_size_error_o && pe_size_error_code_o[1]) begin
 000001                         test_pass_count <= test_pass_count + 1;
 000001                         $display("  PASS: N overflow detected");
%000000                     end else begin
%000000                         test_fail_count <= test_fail_count + 1;
%000000                         $display("  FAIL");
                            end
 000001                     state <= TEST_BOUNDARY_K;
 000001                     wait_counter <= 0;
%000000                 end else begin
%000000                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000002             TEST_BOUNDARY_K: begin
 000001                 if (wait_counter == 0) begin
 000001                     $display("Test: K overflow (128x128x257)");
 000001                     pe_row_cnt_i <= 128;
 000001                     pe_col_cnt_i <= 128;
 000001                     pe_k_cnt_i <= 257;
 000001                     pe_start_i <= 1;
 000001                     wait_counter <= 1;
%000000                 end else if (wait_counter == 1) begin
 000001                     pe_start_i <= 0;
%000000                     if (pe_size_error_o && pe_size_error_code_o[2]) begin
 000001                         test_pass_count <= test_pass_count + 1;
 000001                         $display("  PASS: K overflow detected");
%000000                     end else begin
%000000                         test_fail_count <= test_fail_count + 1;
%000000                         $display("  FAIL");
                            end
 000001                     state <= DONE;
 000001                     wait_counter <= 0;
%000000                 end else begin
%000000                     wait_counter <= wait_counter + 1;
                        end
                    end
        
 000001             DONE: begin
 000001                 $display("");
 000001                 $display("=== Test Summary ===");
 000001                 $display("Passed: %0d, Failed: %0d", test_pass_count, test_fail_count);
 000001                 $display("Simulation finished at cycle %0d", test_cycle);
 000001                 $finish;
                    end
                endcase
            end
        
        endmodule
