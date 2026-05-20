//=============================================================================
// Testbench: M11_RMSNormRoPE
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M11_RMSNormRoPE (
    input logic clk_sys_i_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam VECTOR_DIM = 64;
    localparam DATA_WIDTH = 64;
    localparam SRAM_ADDR_W = 20;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys_i;
    logic rst_sys_n_i;
    logic pg_main_en_i;

    // SRAM Interface
    logic sram_req_valid_o;
    logic [SRAM_ADDR_W-1:0] sram_req_addr_o;
    logic sram_req_rw_o;
    logic [DATA_WIDTH-1:0] sram_req_wdata_o;
    logic sram_rsp_valid_i;
    logic [DATA_WIDTH-1:0] sram_rsp_rdata_i;
    logic sram_rsp_error_i;

    // Operator Control
    logic op_start_i;
    logic [1:0] op_type_i;
    logic [2:0] op_mode_i;
    logic [7:0] op_dim_i;
    logic [7:0] op_head_size_i;
    logic [31:0] op_pos_i;
    logic [1:0] op_precision_i;
    logic op_done_o;
    logic op_busy_o;
    logic op_error_o;

    // Data Input
    logic data_in_valid_i;
    logic [31:0] data_in_addr_i;
    logic [15:0] data_in_size_i;
    logic [31:0] weight_addr_i;

    // Data Output
    logic data_out_valid_o;
    logic data_out_addr_i;
    logic [31:0] data_out_addr_o;
    logic data_out_size_o;
    logic data_out_done_o;

    // RoPE Table
    logic [31:0] rope_table_addr_i;
    logic [15:0] rope_table_size_i;
    logic rope_table_en_i;

    // Status
    logic [7:0] op_status_o;
    logic op_irq_o;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M11_RMSNormRoPE dut (
        .clk_sys_i(clk_sys_i),
        .rst_sys_n_i(rst_sys_n_i),
        .pg_main_en_i(pg_main_en_i),
        .sram_req_valid_o(sram_req_valid_o),
        .sram_req_addr_o(sram_req_addr_o),
        .sram_req_rw_o(sram_req_rw_o),
        .sram_req_wdata_o(sram_req_wdata_o),
        .sram_req_wstrb_o(),
        .sram_rsp_valid_i(sram_rsp_valid_i),
        .sram_rsp_rdata_i(sram_rsp_rdata_i),
        .sram_rsp_error_i(sram_rsp_error_i),
        .op_start_i(op_start_i),
        .op_type_i(op_type_i),
        .op_mode_i(op_mode_i),
        .op_dim_i(op_dim_i),
        .op_head_size_i(op_head_size_i),
        .op_pos_i(op_pos_i),
        .op_precision_i(op_precision_i),
        .op_done_o(op_done_o),
        .op_busy_o(op_busy_o),
        .op_error_o(op_error_o),
        .data_in_valid_i(data_in_valid_i),
        .data_in_addr_i(data_in_addr_i),
        .data_in_size_i(data_in_size_i),
        .weight_addr_i(weight_addr_i),
        .data_out_valid_o(data_out_valid_o),
        .data_out_addr_o(data_out_addr_o),
        .data_out_addr_i(data_out_addr_i),
        .data_out_size_o(data_out_size_o),
        .data_out_done_o(data_out_done_o),
        .rope_table_addr_i(rope_table_addr_i),
        .rope_table_size_i(rope_table_size_i),
        .rope_table_en_i(rope_table_en_i),
        .op_status_o(op_status_o),
        .op_irq_o(op_irq_o)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys_i = clk_sys_i_ext;

    //=========================================================================
    // SRAM Response Simulation
    //=========================================================================
    always_ff @(posedge clk_sys_i) begin
        if (sram_req_valid_o) begin
            sram_rsp_valid_i <= 1;
            sram_rsp_rdata_i <= {DATA_WIDTH{1'b1}};
            sram_rsp_error_i <= 0;
        end else begin
            sram_rsp_valid_i <= 0;
        end
    end

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_RMSNORM, TEST_ROPE,
        TEST_COMBINED, TEST_FP16,
        TEST_FP32, TEST_POSITION_RANGE,
        TEST_DIM_RANGE, TEST_DIV_ZERO,
        DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;

        // Initialize signals
        rst_sys_n_i = 0;
        pg_main_en_i = 1;
        op_start_i = 0;
        op_type_i = 0;
        op_mode_i = 0;
        op_dim_i = 64;
        op_head_size_i = 8;
        op_pos_i = 0;
        op_precision_i = 0;
        data_in_valid_i = 0;
        data_in_addr_i = 32'h8000_0000;
        data_in_size_i = 64;
        weight_addr_i = 32'h8000_1000;
        data_out_addr_i = 32'h8000_2000;
        rope_table_addr_i = 32'h8000_3000;
        rope_table_size_i = 256;
        rope_table_en_i = 1;
        sram_rsp_valid_i = 0;
        sram_rsp_rdata_i = 0;
        sram_rsp_error_i = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys_i);
        rst_sys_n_i = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys_i);

        // Test RMSNorm Only
        state = TEST_RMSNORM;
        for (int i = 0; i < 20; i++) begin
            op_start_i = 1;
            op_type_i = 0;  // RMSNorm
            op_precision_i = 0;  // FP16
            @(posedge clk_sys_i);
            op_start_i = 0;
            wait_counter = 0;
            while (!op_done_o && wait_counter < 200) begin
                @(posedge clk_sys_i);
                wait_counter++;
            end
            if (op_done_o) test_pass_count++;
        end

        // Test RoPE Only
        state = TEST_ROPE;
        for (int i = 0; i < 20; i++) begin
            op_start_i = 1;
            op_type_i = 1;  // RoPE
            op_pos_i = i;
            @(posedge clk_sys_i);
            op_start_i = 0;
            repeat(100) @(posedge clk_sys_i);
        end

        // Test Combined (RMSNorm + RoPE)
        state = TEST_COMBINED;
        for (int i = 0; i < 20; i++) begin
            op_start_i = 1;
            op_type_i = 2;  // Combined
            op_pos_i = i;
            @(posedge clk_sys_i);
            op_start_i = 0;
            repeat(150) @(posedge clk_sys_i);
        end

        // Test FP16 Precision
        state = TEST_FP16;
        op_precision_i = 0;
        op_start_i = 1;
        op_type_i = 0;
        @(posedge clk_sys_i);
        op_start_i = 0;
        repeat(100) @(posedge clk_sys_i);

        // Test FP32 Precision
        state = TEST_FP32;
        op_precision_i = 1;
        op_start_i = 1;
        @(posedge clk_sys_i);
        op_start_i = 0;
        repeat(100) @(posedge clk_sys_i);

        // Test Position Range (0-1023)
        state = TEST_POSITION_RANGE;
        for (int p = 0; p < 50; p++) begin
            op_pos_i = p * 20;
            op_start_i = 1;
            op_type_i = 1;
            @(posedge clk_sys_i);
            op_start_i = 0;
            repeat(50) @(posedge clk_sys_i);
        end

        // Test Dimension Range
        state = TEST_DIM_RANGE;
        for (int d = 16; d <= 64; d += 16) begin
            op_dim_i = d;
            op_start_i = 1;
            op_type_i = 0;
            @(posedge clk_sys_i);
            op_start_i = 0;
            repeat(100) @(posedge clk_sys_i);
        end

        // Test Division-by-zero protection
        state = TEST_DIV_ZERO;
        sram_rsp_rdata_i = 0;  // Zero input
        op_start_i = 1;
        @(posedge clk_sys_i);
        op_start_i = 0;
        repeat(100) @(posedge clk_sys_i);
        sram_rsp_rdata_i = {DATA_WIDTH{1'b1}};  // Restore

        state = DONE;
        repeat(10) @(posedge clk_sys_i);
    end

endmodule