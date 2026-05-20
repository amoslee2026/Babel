//=============================================================================
// Testbench: tb_M01_DataflowController (Interface Fixed)
// Matches RTL interface from M01_DataflowController.sv
//=============================================================================

module tb_M01_DataflowController (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Parameters (match RTL)
    //=========================================================================
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 64;
    localparam OP_PARAMS_WIDTH = 128;
    localparam TIMEOUT_ATTENTION = 10000;
    localparam TIMEOUT_FFN = 15000;

    //=========================================================================
    // Signals (match RTL interface exactly)
    //=========================================================================
    logic clk_sys;
    logic rst_sys_n;

    // Systolic Array Control Interface (M00)
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

    // Operator Unit Dispatch Interface (M09-M12)
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

    // Memory Request Interface (M02/M03 via M04) - MATCH RTL NAMES
    logic        mem_req_valid;
    logic        mem_req_ready;
    logic [1:0]  mem_req_type;
    logic [ADDR_WIDTH-1:0] mem_req_addr;
    logic [15:0] mem_req_size;
    logic        mem_req_tid;
    logic        mem_resp_valid;  // Note: RTL uses mem_resp not mem_rsp
    logic [DATA_WIDTH-1:0] mem_resp_data;
    logic        mem_resp_last;
    logic [1:0]  mem_resp_err;

    // Thread Scheduler Interface (M08) - MATCH RTL NAMES
    logic [1:0]  sched_thread_en;
    logic [1:0]  sched_priority;
    logic        sched_yield;
    logic        sched_current_tid;
    logic [3:0]  sched_status;

    // Interrupt Interface
    logic        irq_op_done;
    logic        irq_err;
    logic        irq_tid;

    // Register Interface (APB/AXI-lite slave)
    logic [ADDR_WIDTH-1:0] reg_addr;
    logic [31:0] reg_wdata;
    logic        reg_write;
    logic        reg_read;
    logic [31:0] reg_rdata;

    // Control Inputs
    logic        start_en;
    logic        soft_reset;

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
        .mem_req_type(mem_req_type),
        .mem_req_addr(mem_req_addr),
        .mem_req_size(mem_req_size),
        .mem_req_tid(mem_req_tid),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_data(mem_resp_data),
        .mem_resp_last(mem_resp_last),
        .mem_resp_err(mem_resp_err),
        .sched_thread_en(sched_thread_en),
        .sched_priority(sched_priority),
        .sched_yield(sched_yield),
        .sched_current_tid(sched_current_tid),
        .sched_status(sched_status),
        .irq_op_done(irq_op_done),
        .irq_err(irq_err),
        .irq_tid(irq_tid),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_write(reg_write),
        .reg_read(reg_read),
        .reg_rdata(reg_rdata),
        .start_en(start_en),
        .soft_reset(soft_reset)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys = clk_sys_ext;

    //=========================================================================
    // Coverage Covergroups
    //=========================================================================
    covergroup cg_fsm_states @(posedge clk_sys);
        coverpoint dut.fsm_state {
            bins idle = {6'b000001};
            bins fetch = {6'b000010};
            bins decode = {6'b000100};
            bins dispatch = {6'b001000};
            bins wait_done = {6'b010000};
            bins complete = {6'b100000};
        }
    endgroup

    covergroup cg_opcodes @(posedge clk_sys);
        coverpoint dut.op_code {
            bins attention = {8'h01};
            bins ffn = {8'h02};
            bins rmsnorm = {8'h03};
            bins rope = {8'h04};
            bins softmax = {8'h05};
            bins matmul = {8'h10};
        }
    endgroup

    covergroup cg_precision @(posedge clk_sys);
        coverpoint dut.op_precision {
            bins fp8 = {2'b00};
            bins fp16 = {2'b01};
            bins int8 = {2'b10};
            bins fp32 = {2'b11};
        }
    endgroup

    covergroup cg_thread @(posedge clk_sys);
        coverpoint dut.current_tid {
            bins tid0 = {0};
            bins tid1 = {1};
        }
    endgroup

    cg_fsm_states cg_fsm;
    cg_opcodes cg_ops;
    cg_precision cg_prec;
    cg_thread cg_t;

    initial begin
        cg_fsm = new();
        cg_ops = new();
        cg_prec = new();
        cg_t = new();
    end

    //=========================================================================
    // Test Stimulus
    //=========================================================================
    initial begin
        // Initialize all signals
        rst_sys_n = 0;
        syst_done = 0;
        syst_err = 0;
        op_ready = 4'b1111;
        op_done = 4'b0000;
        op_err = 8'b0;
        mem_req_ready = 1;
        mem_resp_valid = 0;
        mem_resp_data = 0;
        mem_resp_last = 0;
        mem_resp_err = 0;
        sched_thread_en = 2'b11;
        sched_priority = 2'b00;
        reg_addr = 0;
        reg_wdata = 0;
        reg_write = 0;
        reg_read = 0;
        start_en = 0;
        soft_reset = 0;

        // Reset phase
        repeat(20) @(posedge clk_sys);
        rst_sys_n = 1;
        repeat(10) @(posedge clk_sys);

        // Test 1: Configure registers
        reg_write = 1;
        reg_addr = 32'h000;
        reg_wdata = 32'h00000001; // Enable
        @(posedge clk_sys);
        reg_write = 0;
        repeat(5) @(posedge clk_sys);

        // Test 2: Configure op queue
        reg_write = 1;
        reg_addr = 32'h014;
        reg_wdata = 32'h0000_0010; // Queue depth 16
        @(posedge clk_sys);
        reg_write = 0;
        repeat(5) @(posedge clk_sys);

        // Test 3: Start enable
        start_en = 1;
        repeat(5) @(posedge clk_sys);

        // Test 4: Wait for FSM transitions
        repeat(500) begin
            @(posedge clk_sys);
            // Simulate memory responses
            if (mem_req_valid && mem_req_ready) begin
                repeat(10) @(posedge clk_sys);
                mem_resp_valid = 1;
                mem_resp_data = 64'hDEAD_BEEF_CAFE_DADA;
                mem_resp_last = 1;
                @(posedge clk_sys);
                mem_resp_valid = 0;
                mem_resp_last = 0;
            end

            // Simulate systolic completion
            if (dut.fsm_state == dut.S_WAIT_DONE) begin
                repeat(20) @(posedge clk_sys);
                syst_done = 1;
                @(posedge clk_sys);
                syst_done = 0;
            end

            // Simulate operator completion
            if (op_valid) begin
                repeat(10) @(posedge clk_sys);
                op_done[op_unit_sel] = 1;
                @(posedge clk_sys);
                op_done = 4'b0;
            end
        end

        // Test 5: Thread switch
        sched_thread_en = 2'b01; // Only T0 enabled
        repeat(100) @(posedge clk_sys);
        sched_thread_en = 2'b10; // Only T1 enabled
        repeat(100) @(posedge clk_sys);
        sched_thread_en = 2'b11; // Both enabled

        // Test 6: Timeout handling
        repeat(15000) begin
            @(posedge clk_sys);
            if (dut.timeout_err) break;
        end

        // Test 7: Error handling
        syst_err = 2'b01; // Inject error
        repeat(100) @(posedge clk_sys);
        syst_err = 0;
        soft_reset = 1;
        repeat(10) @(posedge clk_sys);
        soft_reset = 0;

        // Test 8: Multiple op codes
        for (int i = 0; i < 1000; i++) begin
            @(posedge clk_sys);
        end

        start_en = 0;
        repeat(100) @(posedge clk_sys);
    end

endmodule