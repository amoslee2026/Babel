//=============================================================================
// Testbench: M08_ThreadScheduler
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M08_ThreadScheduler (
    input logic clk_sys_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam MAX_THREADS = 4;
    localparam CONTEXT_WIDTH = 256;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk_sys;
    logic rst_sys_n;
    logic rst_por_n;
    logic clk_enable;
    logic power_gate_n;

    // Thread Control
    logic thread_cmd_valid;
    logic thread_cmd_ready;
    logic [3:0] thread_cmd_opcode;
    logic [2:0] thread_cmd_thread_id;
    logic [2:0] thread_cmd_priority;
    logic [31:0] thread_cmd_addr;
    logic [63:0] thread_cmd_data;

    // Register Interface
    logic reg_req_valid;
    logic reg_req_ready;
    logic [11:0] reg_req_addr;
    logic reg_req_rw;
    logic [31:0] reg_req_data;
    logic reg_rsp_valid;
    logic [31:0] reg_rsp_data;
    logic reg_rsp_error;

    // Dispatch Interface
    logic dispatch_valid;
    logic dispatch_ready;
    logic [2:0] dispatch_thread_id;
    logic [31:0] dispatch_entry_addr;
    logic dispatch_done;
    logic dispatch_error;

    // Context Interface
    logic ctx_rd_valid;
    logic ctx_rd_ready;
    logic [7:0] ctx_rd_ptr;
    logic [CONTEXT_WIDTH-1:0] ctx_rd_data;
    logic ctx_wr_valid;
    logic ctx_wr_ready;
    logic [7:0] ctx_wr_ptr;
    logic [CONTEXT_WIDTH-1:0] ctx_wr_data;

    // Thread Status
    logic [2:0] thread_active_id;
    logic [1:0] thread_active_state;
    logic [3:0] thread_pending_cnt;
    logic [3:0] thread_blocked_cnt;
    logic thread_irq;
    logic [2:0] thread_irq_id;
    logic [3:0] thread_irq_type;

    // Scheduler Status
    logic sched_status_ready;
    logic sched_status_busy;
    logic sched_status_ctx_switch;
    logic sched_status_error;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M08_ThreadScheduler dut (
        .clk_sys(clk_sys),
        .rst_sys_n(rst_sys_n),
        .rst_por_n(rst_por_n),
        .clk_enable(clk_enable),
        .power_gate_n(power_gate_n),
        .thread_cmd_valid(thread_cmd_valid),
        .thread_cmd_ready(thread_cmd_ready),
        .thread_cmd_opcode(thread_cmd_opcode),
        .thread_cmd_thread_id(thread_cmd_thread_id),
        .thread_cmd_priority(thread_cmd_priority),
        .thread_cmd_addr(thread_cmd_addr),
        .thread_cmd_data(thread_cmd_data),
        .reg_req_valid(reg_req_valid),
        .reg_req_ready(reg_req_ready),
        .reg_req_addr(reg_req_addr),
        .reg_req_rw(reg_req_rw),
        .reg_req_data(reg_req_data),
        .reg_rsp_valid(reg_rsp_valid),
        .reg_rsp_data(reg_rsp_data),
        .reg_rsp_error(reg_rsp_error),
        .dispatch_valid(dispatch_valid),
        .dispatch_ready(dispatch_ready),
        .dispatch_thread_id(dispatch_thread_id),
        .dispatch_entry_addr(dispatch_entry_addr),
        .dispatch_context_ptr(),
        .dispatch_cmd(),
        .dispatch_done(dispatch_done),
        .dispatch_error(dispatch_error),
        .ctx_rd_valid(ctx_rd_valid),
        .ctx_rd_ready(ctx_rd_ready),
        .ctx_rd_ptr(ctx_rd_ptr),
        .ctx_rd_data(ctx_rd_data),
        .ctx_wr_valid(ctx_wr_valid),
        .ctx_wr_ready(ctx_wr_ready),
        .ctx_wr_ptr(ctx_wr_ptr),
        .ctx_wr_data(ctx_wr_data),
        .thread_active_id(thread_active_id),
        .thread_active_state(thread_active_state),
        .thread_pending_cnt(thread_pending_cnt),
        .thread_blocked_cnt(thread_blocked_cnt),
        .thread_irq(thread_irq),
        .thread_irq_id(thread_irq_id),
        .thread_irq_type(thread_irq_type),
        .sched_status_ready(sched_status_ready),
        .sched_status_busy(sched_status_busy),
        .sched_status_ctx_switch(sched_status_ctx_switch),
        .sched_status_error(sched_status_error)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk_sys = clk_sys_ext;

    //=========================================================================
    // Context Memory Simulation
    //=========================================================================
    logic [CONTEXT_WIDTH-1:0] context_mem [0:255];

    always_ff @(posedge clk_sys) begin
        if (ctx_rd_valid && ctx_rd_ready) begin
            ctx_rd_data <= context_mem[ctx_rd_ptr];
        end
        if (ctx_wr_valid && ctx_wr_ready) begin
            context_mem[ctx_wr_ptr] <= ctx_wr_data;
        end
    end

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_THREAD_CREATE, TEST_THREAD_START,
        TEST_THREAD_YIELD, TEST_THREAD_EXIT,
        TEST_ROUND_ROBIN, TEST_PRIORITY_SCHED,
        TEST_CTX_SWITCH, TEST_MULTI_THREAD,
        TEST_DISPATCH, TEST_STATUS_CHECK,
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
        rst_sys_n = 0;
        rst_por_n = 0;
        clk_enable = 1;
        power_gate_n = 1;
        thread_cmd_valid = 0;
        thread_cmd_opcode = 0;
        thread_cmd_thread_id = 0;
        thread_cmd_priority = 0;
        thread_cmd_addr = 0;
        thread_cmd_data = 0;
        dispatch_ready = 1;
        dispatch_done = 0;
        dispatch_error = 0;
        ctx_rd_ready = 1;
        ctx_wr_ready = 1;
        reg_req_valid = 0;
        reg_req_addr = 0;
        reg_req_rw = 0;
        reg_req_data = 0;

        // Initialize context memory
        for (int i = 0; i < 256; i++) begin
            context_mem[i] = {CONTEXT_WIDTH{1'b0}};
        end

        // Reset phase
        repeat(10) @(posedge clk_sys);
        rst_por_n = 1;
        rst_sys_n = 1;
        state = RESET;
        repeat(10) @(posedge clk_sys);

        // Test Thread Create
        state = TEST_THREAD_CREATE;
        for (int tid = 0; tid < MAX_THREADS; tid++) begin
            @(posedge clk_sys);
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'h1;  // CREATE
            thread_cmd_thread_id = tid;
            thread_cmd_priority = tid % 4;
            thread_cmd_addr = 32'h8000_0000 + tid*256;
            thread_cmd_data = 64'h0;
            wait_counter = 0;
            while (!thread_cmd_ready && wait_counter < 50) begin
                @(posedge clk_sys);
                wait_counter++;
            end
            thread_cmd_valid = 0;
            repeat(10) @(posedge clk_sys);
        end

        // Test Thread Start
        state = TEST_THREAD_START;
        for (int tid = 0; tid < MAX_THREADS; tid++) begin
            @(posedge clk_sys);
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'h2;  // START
            thread_cmd_thread_id = tid;
            repeat(20) @(posedge clk_sys);
            thread_cmd_valid = 0;
        end

        // Simulate dispatch completion
        repeat(100) @(posedge clk_sys);
        dispatch_done = 1;
        repeat(10) @(posedge clk_sys);
        dispatch_done = 0;

        // Test Thread Yield
        state = TEST_THREAD_YIELD;
        thread_cmd_valid = 1;
        thread_cmd_opcode = 4'h3;  // YIELD
        thread_cmd_thread_id = 0;
        repeat(20) @(posedge clk_sys);
        thread_cmd_valid = 0;

        // Test Round Robin
        state = TEST_ROUND_ROBIN;
        for (int i = 0; i < 50; i++) begin
            @(posedge clk_sys);
            dispatch_done = (i % 10 == 0);
            repeat(1) @(posedge clk_sys);
            dispatch_done = 0;
        end

        // Test Priority Scheduling
        state = TEST_PRIORITY_SCHED;
        for (int p = 0; p < 4; p++) begin
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'h4;  // SET_PRIORITY
            thread_cmd_thread_id = p;
            thread_cmd_priority = 3 - p;
            repeat(20) @(posedge clk_sys);
            thread_cmd_valid = 0;
        end

        // Test Context Switch
        state = TEST_CTX_SWITCH;
        repeat(50) @(posedge clk_sys);
        if (sched_status_ctx_switch) test_pass_count++;

        // Test Multi Thread
        state = TEST_MULTI_THREAD;
        for (int i = 0; i < 100; i++) begin
            @(posedge clk_sys);
            dispatch_done = (i % 5 == 0);
        end

        // Test Thread Exit
        state = TEST_THREAD_EXIT;
        thread_cmd_valid = 1;
        thread_cmd_opcode = 4'h5;  // EXIT
        thread_cmd_thread_id = 0;
        repeat(20) @(posedge clk_sys);
        thread_cmd_valid = 0;

        // Test Dispatch
        state = TEST_DISPATCH;
        repeat(50) @(posedge clk_sys);

        // Test Status Check
        state = TEST_STATUS_CHECK;
        reg_req_valid = 1;
        reg_req_addr = 12'h000;
        reg_req_rw = 0;
        repeat(20) @(posedge clk_sys);
        reg_req_valid = 0;

        state = DONE;
        repeat(10) @(posedge clk_sys);
    end

endmodule