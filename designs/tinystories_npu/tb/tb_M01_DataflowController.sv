//=============================================================================
// Testbench: M01_DataflowController
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M01_DataflowController (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 64;
    localparam OP_PARAMS_WIDTH = 128;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys;
    logic rst_sys_n;

    // Systolic Array Interface
    logic        syst_mode;
    logic [1:0]  syst_precision;
    logic        syst_start;
    logic        syst_done;
    logic [1:0]  syst_err;
    logic [7:0]  syst_row_cnt;
    logic [7:0]  syst_col_cnt;
    logic [ADDR_WIDTH-1:0] syst_src_addr;
    logic [ADDR_WIDTH-1:0] syst_dst_addr;
    logic [63:0] syst_shape;

    // Operator Interface
    logic        op_valid;
    logic [3:0]  op_ready;
    logic [7:0]  op_code;
    logic [3:0]  op_unit_sel;
    logic        op_tid;
    logic [1:0]  op_precision;
    logic [ADDR_WIDTH-1:0] op_src_addr;
    logic [ADDR_WIDTH-1:0] op_dst_addr;
    logic [OP_PARAMS_WIDTH-1:0] op_params;
    logic [3:0]  op_done;
    logic [7:0]  op_err;

    // Memory Request Interface
    logic        mem_req_valid;
    logic        mem_req_ready;
    logic [ADDR_WIDTH-1:0] mem_req_addr;
    logic        mem_req_rw;
    logic [DATA_WIDTH-1:0] mem_req_data;
    logic        mem_req_last;
    logic        mem_rsp_valid;
    logic [DATA_WIDTH-1:0] mem_rsp_data;
    logic        mem_rsp_error;

    // Thread Interface
    logic [1:0]  thread_status;
    logic        thread_switch_req;
    logic        thread_switch_ack;

    // Status
    logic        controller_busy;
    logic        controller_error;
    logic [31:0] perf_cycle_count;
    logic [15:0] timeout_counter;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M01_DataflowController dut (
        .clk_sys(clk_sys),
        .rst_sys_n(rst_sys_n),
        .syst_mode(syst_mode),
        .syst_precision(syst_precision),
        .syst_start(syst_start),
        .syst_done(syst_done),
        .syst_err(syst_err),
        .syst_row_cnt(syst_row_cnt),
        .syst_col_cnt(syst_col_cnt),
        .syst_src_addr(syst_src_addr),
        .syst_dst_addr(syst_dst_addr),
        .syst_shape(syst_shape),
        .op_valid(op_valid),
        .op_ready(op_ready),
        .op_code(op_code),
        .op_unit_sel(op_unit_sel),
        .op_tid(op_tid),
        .op_precision(op_precision),
        .op_src_addr(op_src_addr),
        .op_dst_addr(op_dst_addr),
        .op_params(op_params),
        .op_done(op_done),
        .op_err(op_err),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_addr(mem_req_addr),
        .mem_req_rw(mem_req_rw),
        .mem_req_data(mem_req_data),
        .mem_req_last(mem_req_last),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_data(mem_rsp_data),
        .mem_rsp_error(mem_rsp_error),
        .thread_status(thread_status),
        .thread_switch_req(thread_switch_req),
        .thread_switch_ack(thread_switch_ack),
        .controller_busy(controller_busy),
        .controller_error(controller_error),
        .perf_cycle_count(perf_cycle_count),
        .timeout_counter(timeout_counter)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys = clk_sys_ext;

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_ATTENTION_OP, TEST_FFN_OP, TEST_RMSNORM_OP,
        TEST_ROPE_OP, TEST_SOFTMAX_OP,
        TEST_THREAD_SWITCH, TEST_TIMEOUT_ERROR,
        TEST_PIPELINE_UTIL, DONE
    } test_state_t;

    test_state_t state;
    int wait_counter;
    int test_pass_count;
    int test_fail_count;

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        state = INIT;
        test_pass_count = 0;
        test_fail_count = 0;
        wait_counter = 0;

        // Initialize signals
        rst_sys_n = 0;
        syst_done = 0;
        syst_err = 0;
        op_ready = 4'b1111;
        op_done = 4'b0000;
        op_err = 8'b0000_0000;
        mem_req_ready = 1;
        mem_rsp_valid = 0;
        mem_rsp_data = 0;
        mem_rsp_error = 0;

        // Reset phase
        repeat(10) @(posedge clk_sys);
        rst_sys_n = 1;
        state = RESET;
        repeat(5) @(posedge clk_sys);

        // Test Attention Operator (op_code=0x01)
        state = TEST_ATTENTION_OP;
        repeat(100) begin
            @(posedge clk_sys);
            if (dut.current_state == dut.STATE_COMPLETE) begin
                test_pass_count++;
            end
        end

        // Test FFN Operator (op_code=0x02)
        state = TEST_FFN_OP;
        repeat(100) @(posedge clk_sys);

        // Test RMSNorm Operator (op_code=0x03)
        state = TEST_RMSNORM_OP;
        repeat(50) @(posedge clk_sys);

        // Test RoPE Operator (op_code=0x04)
        state = TEST_ROPE_OP;
        repeat(50) @(posedge clk_sys);

        // Test SoftMax Operator (op_code=0x05)
        state = TEST_SOFTMAX_OP;
        repeat(50) @(posedge clk_sys);

        // Test Thread Switch
        state = TEST_THREAD_SWITCH;
        repeat(20) @(posedge clk_sys);

        // Test Timeout Error
        state = TEST_TIMEOUT_ERROR;
        syst_done = 0;
        repeat(10000) @(posedge clk_sys);
        if (controller_error) test_pass_count++;
        syst_done = 1;

        // Test Pipeline Utilization
        state = TEST_PIPELINE_UTIL;
        repeat(200) @(posedge clk_sys);

        state = DONE;
        repeat(10) @(posedge clk_sys);
    end

endmodule