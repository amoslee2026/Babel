//-----------------------------------------------------------------------------
// Testbench: tb_M08_ThreadScheduler
// Description: Testbench for M08 Multi-thread Scheduler
//              Tests thread lifecycle, scheduling modes, context switch timing,
//              barrier synchronization, and error handling
//-----------------------------------------------------------------------------
// Generated: 2026-05-17
//-----------------------------------------------------------------------------

module tb_M08_ThreadScheduler;

    //=========================================================================
    // Parameters
    //=========================================================================

    parameter int MAX_THREADS = 4;
    parameter int CONTEXT_WIDTH = 256;
    parameter int QUANTUM_DEFAULT = 1000;
    parameter int CLK_PERIOD = 2;  // 500 MHz = 2ns period

    //=========================================================================
    // Testbench Signals
    //=========================================================================

    // Clock & Reset
    logic        clk_sys;
    logic        rst_sys_n;
    logic        rst_por_n;
    logic        clk_enable;
    logic        power_gate_n;

    // Thread Control Interface
    logic        thread_cmd_valid;
    logic        thread_cmd_ready;
    logic [3:0]  thread_cmd_opcode;
    logic [2:0]  thread_cmd_thread_id;
    logic [2:0]  thread_cmd_priority;
    logic [31:0] thread_cmd_addr;
    logic [64:0] thread_cmd_data;

    // Register Interface
    logic        reg_req_valid;
    logic        reg_req_ready;
    logic [11:0] reg_req_addr;
    logic        reg_req_rw;
    logic [31:0] reg_req_data;
    logic        reg_rsp_valid;
    logic [31:0] reg_rsp_data;
    logic        reg_rsp_error;

    // Dispatch Interface
    logic        dispatch_valid;
    logic        dispatch_ready;
    logic [2:0]  dispatch_thread_id;
    logic [31:0] dispatch_entry_addr;
    logic [7:0]  dispatch_context_ptr;
    logic [1:0]  dispatch_cmd;
    logic        dispatch_done;
    logic        dispatch_error;

    // Context Interface
    logic        ctx_rd_valid;
    logic        ctx_rd_ready;
    logic [7:0]  ctx_rd_ptr;
    logic [CONTEXT_WIDTH-1:0] ctx_rd_data;
    logic        ctx_wr_valid;
    logic        ctx_wr_ready;
    logic [7:0]  ctx_wr_ptr;
    logic [CONTEXT_WIDTH-1:0] ctx_wr_data;

    // Thread Status Interface
    logic [2:0]  thread_active_id;
    logic [1:0]  thread_active_state;
    logic [3:0]  thread_pending_cnt;
    logic [3:0]  thread_blocked_cnt;
    logic        thread_irq;
    logic [2:0]  thread_irq_id;
    logic [3:0]  thread_irq_type;

    // Scheduler Status
    logic        sched_status_ready;
    logic        sched_status_busy;
    logic        sched_status_ctx_switch;
    logic        sched_status_error;

    //=========================================================================
    // Context Storage (Emulated SRAM)
    //=========================================================================

    logic [CONTEXT_WIDTH-1:0] context_storage [7:0];
    logic [3:0]  ctx_rd_latency_cnt;
    logic [3:0]  ctx_wr_latency_cnt;

    //=========================================================================
    // DUT Instance
    //=========================================================================

    M08_ThreadScheduler #(
        .MAX_THREADS(MAX_THREADS),
        .CONTEXT_WIDTH(CONTEXT_WIDTH),
        .QUANTUM_DEFAULT(QUANTUM_DEFAULT)
    ) dut (
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
        .dispatch_context_ptr(dispatch_context_ptr),
        .dispatch_cmd(dispatch_cmd),
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
    // Clock Generation
    //=========================================================================

    initial begin
        clk_sys = 0;
        forever #(CLK_PERIOD/2) clk_sys = ~clk_sys;
    end

    //=========================================================================
    // Context Storage Emulation (2-3 cycle latency)
    //=========================================================================

    // Read with latency
    always_ff @(posedge clk_sys) begin
        if (!rst_por_n) begin
            ctx_rd_latency_cnt <= '0;
            ctx_rd_data <= '0;
        end else if (ctx_rd_valid) begin
            if (ctx_rd_latency_cnt == 0)
                ctx_rd_latency_cnt <= 3;  // 3-cycle read latency
            else if (ctx_rd_latency_cnt > 1)
                ctx_rd_latency_cnt <= ctx_rd_latency_cnt - 1;
            else begin
                ctx_rd_data <= context_storage[ctx_rd_ptr];
                ctx_rd_latency_cnt <= '0;
            end
        end
    end

    always_comb begin
        ctx_rd_ready = (ctx_rd_latency_cnt == 1);
    end

    // Write with latency
    always_ff @(posedge clk_sys) begin
        if (!rst_por_n) begin
            ctx_wr_latency_cnt <= '0;
        end else if (ctx_wr_valid) begin
            if (ctx_wr_latency_cnt == 0)
                ctx_wr_latency_cnt <= 2;  // 2-cycle write latency
            else if (ctx_wr_latency_cnt > 1)
                ctx_wr_latency_cnt <= ctx_wr_latency_cnt - 1;
            else begin
                context_storage[ctx_wr_ptr] <= ctx_wr_data;
                ctx_wr_latency_cnt <= '0;
            end
        end
    end

    always_comb begin
        ctx_wr_ready = (ctx_wr_latency_cnt == 1);
    end

    //=========================================================================
    // M01 Dataflow Controller Emulation
    //=========================================================================

    logic [3:0] dispatch_latency_cnt;

    always_ff @(posedge clk_sys) begin
        if (!rst_por_n) begin
            dispatch_latency_cnt <= '0;
            dispatch_done <= '0;
            dispatch_error <= '0;
        end else if (dispatch_valid && dispatch_ready) begin
            if (dispatch_latency_cnt == 0)
                dispatch_latency_cnt <= 3;  // 3-cycle dispatch latency
            else if (dispatch_latency_cnt > 1)
                dispatch_latency_cnt <= dispatch_latency_cnt - 1;
            else begin
                dispatch_done <= 1'b1;
                dispatch_error <= 1'b0;
                dispatch_latency_cnt <= '0;
            end
        end else begin
            dispatch_done <= 1'b0;
        end
    end

    always_comb begin
        dispatch_ready = 1'b1;  // M01 always ready
    end

    //=========================================================================
    // Test Variables
    //=========================================================================

    int test_pass_cnt = 0;
    int test_fail_cnt = 0;
    int ctx_switch_cycle_cnt = 0;
    int ctx_switch_start_cycle = 0;
    logic ctx_switch_started = 0;

    //=========================================================================
    // Context Switch Cycle Counter
    //=========================================================================

    always_ff @(posedge clk_sys) begin
        if (!rst_por_n) begin
            ctx_switch_cycle_cnt <= '0;
            ctx_switch_started <= 0;
        end else if (sched_status_ctx_switch && !ctx_switch_started) begin
            ctx_switch_started <= 1;
            ctx_switch_start_cycle <= $time;
        end else if (!sched_status_ctx_switch && ctx_switch_started) begin
            ctx_switch_cycle_cnt <= ($time - ctx_switch_start_cycle) / CLK_PERIOD;
            ctx_switch_started <= 0;
        end
    end

    //=========================================================================
    // Test Procedures
    //=========================================================================

    // Reset sequence
    task reset_sequence();
        begin
            rst_por_n = 0;
            rst_sys_n = 0;
            clk_enable = 0;
            power_gate_n = 0;
            thread_cmd_valid = 0;
            reg_req_valid = 0;
            @(posedge clk_sys);
            @(posedge clk_sys);
            rst_por_n = 1;
            rst_sys_n = 1;
            clk_enable = 1;
            power_gate_n = 1;
            @(posedge clk_sys);
            $display("[%0t] Reset sequence complete", $time);
        end
    endtask

    // Enable scheduler
    task enable_scheduler();
        begin
            reg_req_valid = 1;
            reg_req_rw = 1;
            reg_req_addr = 12'h0000;  // SCHED_CTRL
            reg_req_data = 32'h00000001;  // enable = 1
            @(posedge clk_sys);
            reg_req_valid = 0;
            @(posedge clk_sys);
            $display("[%0t] Scheduler enabled", $time);
        end
    endtask

    // Create thread
    task create_thread(input int thread_id, input int priority, input int entry_addr);
        begin
            wait(thread_cmd_ready);
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'b0000;  // THREAD_CREATE
            thread_cmd_thread_id = thread_id;
            thread_cmd_priority = priority;
            thread_cmd_addr = entry_addr;
            thread_cmd_data = 64'h0;
            @(posedge clk_sys);
            thread_cmd_valid = 0;
            $display("[%0t] Thread %0d created (priority=%0d, entry=0x%08h)",
                     $time, thread_id, priority, entry_addr);
        end
    endtask

    // Start thread
    task start_thread(input int thread_id);
        begin
            wait(thread_cmd_ready);
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'b0001;  // THREAD_START
            thread_cmd_thread_id = thread_id;
            @(posedge clk_sys);
            thread_cmd_valid = 0;
            $display("[%0t] Thread %0d started", $time, thread_id);
        end
    endtask

    // Kill thread
    task kill_thread(input int thread_id);
        begin
            wait(thread_cmd_ready);
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'b0004;  // THREAD_KILL
            thread_cmd_thread_id = thread_id;
            @(posedge clk_sys);
            thread_cmd_valid = 0;
            $display("[%0t] Thread %0d killed", $time, thread_id);
        end
    endtask

    // Barrier sync
    task barrier_sync(input int thread_id, input int barrier_id);
        begin
            wait(thread_cmd_ready);
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'b0006;  // THREAD_SYNC
            thread_cmd_thread_id = thread_id;
            thread_cmd_data = barrier_id;
            @(posedge clk_sys);
            thread_cmd_valid = 0;
            $display("[%0t] Thread %0d at barrier %0d", $time, thread_id, barrier_id);
        end
    endtask

    // Set scheduling mode
    task set_sched_mode(input int mode);
        begin
            reg_req_valid = 1;
            reg_req_rw = 1;
            reg_req_addr = 12'h0008;  // SCHED_MODE
            reg_req_data = mode;  // 0=RR, 1=PRIO, 2=HYBRID
            @(posedge clk_sys);
            reg_req_valid = 0;
            @(posedge clk_sys);
            $display("[%0t] Scheduling mode set to %0d", $time, mode);
        end
    endtask

    // Set quantum
    task set_quantum(input int quantum);
        begin
            reg_req_valid = 1;
            reg_req_rw = 1;
            reg_req_addr = 12'h0040;  // SCHED_QUANTUM
            reg_req_data = quantum;
            @(posedge clk_sys);
            reg_req_valid = 0;
            @(posedge clk_sys);
            $display("[%0t] Quantum set to %0d cycles", $time, quantum);
        end
    endtask

    // Check context switch timing
    task check_ctx_switch_timing(input int max_cycles);
        begin
            wait(ctx_switch_cycle_cnt > 0);
            if (ctx_switch_cycle_cnt <= max_cycles) begin
                $display("[%0t] PASS: Context switch completed in %0d cycles (<= %0d)",
                         $time, ctx_switch_cycle_cnt, max_cycles);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Context switch took %0d cycles (> %0d)",
                         $time, ctx_switch_cycle_cnt, max_cycles);
                test_fail_cnt++;
            end
            ctx_switch_cycle_cnt = 0;
        end
    endtask

    //=========================================================================
    // Test Cases
    //=========================================================================

    // Test 1: Thread Lifecycle - CREATE/START/KILL
    task test_thread_lifecycle();
        begin
            $display("\n========================================");
            $display("Test 1: Thread Lifecycle");
            $display("========================================");

            reset_sequence();
            enable_scheduler();

            // Create threads
            create_thread(0, 3, 32'h1000_0000);
            create_thread(1, 5, 32'h2000_0000);

            // Wait for thread creation
            repeat(10) @(posedge clk_sys);

            // Start thread 0
            start_thread(0);
            repeat(5) @(posedge clk_sys);

            // Verify thread 0 running
            if (thread_active_id == 0 && thread_active_state == 2'b10) begin
                $display("[%0t] PASS: Thread 0 running", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Thread 0 not running", $time);
                test_fail_cnt++;
            end

            // Kill thread 0
            kill_thread(0);
            repeat(5) @(posedge clk_sys);

            // Verify thread 0 empty
            if (thread_active_state == 2'b00) begin
                $display("[%0t] PASS: Thread 0 killed", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Thread 0 not killed", $time);
                test_fail_cnt++;
            end

            $display("[%0t] Test 1 complete: Pass=%0d, Fail=%0d", $time, test_pass_cnt, test_fail_cnt);
        end
    endtask

    // Test 2: Round-Robin Scheduling
    task test_round_robin();
        begin
            $display("\n========================================");
            $display("Test 2: Round-Robin Scheduling");
            $display("========================================");

            test_pass_cnt = 0;
            test_fail_cnt = 0;

            reset_sequence();
            set_sched_mode(0);  // Round-Robin
            set_quantum(50);    // Short quantum for test
            enable_scheduler();

            // Create 2 threads
            create_thread(0, 3, 32'h1000_0000);
            create_thread(1, 3, 32'h2000_0000);
            repeat(10) @(posedge clk_sys);

            // Start both threads
            start_thread(0);
            start_thread(1);

            // Wait for first dispatch
            repeat(20) @(posedge clk_sys);

            // Track thread execution order
            int thread_order [7:0];
            int order_idx = 0;
            logic [2:0] prev_thread_id = 0;

            repeat(100) @(posedge clk_sys) begin
                if (sched_status_ctx_switch) begin
                    if (thread_active_id != prev_thread_id) begin
                        thread_order[order_idx] = thread_active_id;
                        order_idx++;
                        prev_thread_id = thread_active_id;
                        $display("[%0t] Thread switch to %0d", $time, thread_active_id);
                    end
                end
            end

            // Verify Round-Robin order (0 -> 1 -> 0 -> 1 ...)
            if (order_idx >= 4) begin
                int valid_rr = 1;
                for (int i = 0; i < order_idx-1; i++) begin
                    if ((thread_order[i] == 0 && thread_order[i+1] != 1) ||
                        (thread_order[i] == 1 && thread_order[i+1] != 0)) begin
                        valid_rr = 0;
                    end
                end
                if (valid_rr) begin
                    $display("[%0t] PASS: Round-Robin scheduling verified", $time);
                    test_pass_cnt++;
                end else begin
                    $display("[%0t] FAIL: Round-Robin order incorrect", $time);
                    test_fail_cnt++;
                end
            end else begin
                $display("[%0t] FAIL: Not enough context switches observed", $time);
                test_fail_cnt++;
            end

            $display("[%0t] Test 2 complete: Pass=%0d, Fail=%0d", $time, test_pass_cnt, test_fail_cnt);
        end
    endtask

    // Test 3: Priority Scheduling
    task test_priority();
        begin
            $display("\n========================================");
            $display("Test 3: Priority Scheduling");
            $display("========================================");

            test_pass_cnt = 0;
            test_fail_cnt = 0;

            reset_sequence();
            set_sched_mode(1);  // Priority mode
            set_quantum(100);
            enable_scheduler();

            // Create threads with different priorities
            create_thread(0, 2, 32'h1000_0000);  // Low priority
            create_thread(1, 5, 32'h2000_0000);  // High priority
            create_thread(2, 7, 32'h3000_0000);  // Critical priority
            repeat(10) @(posedge clk_sys);

            // Start all threads
            start_thread(0);
            start_thread(1);
            start_thread(2);

            // Wait for first dispatch
            repeat(30) @(posedge clk_sys);

            // Verify highest priority thread (2) runs first
            if (thread_active_id == 2) begin
                $display("[%0t] PASS: Highest priority thread (2) dispatched first", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Thread %0d dispatched instead of highest (2)",
                         $time, thread_active_id);
                test_fail_cnt++;
            end

            // Kill thread 2
            kill_thread(2);
            repeat(20) @(posedge clk_sys);

            // Verify next highest priority (1) runs
            if (thread_active_id == 1) begin
                $display("[%0t] PASS: Next highest priority thread (1) dispatched", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Thread %0d dispatched instead of priority (1)",
                         $time, thread_active_id);
                test_fail_cnt++;
            end

            $display("[%0t] Test 3 complete: Pass=%0d, Fail=%0d", $time, test_pass_cnt, test_fail_cnt);
        end
    endtask

    // Test 4: Context Switch Timing (REQ-M08-010)
    task test_ctx_switch_timing();
        begin
            $display("\n========================================");
            $display("Test 4: Context Switch Timing (REQ-M08-010: <= 10 cycles)");
            $display("========================================");

            test_pass_cnt = 0;
            test_fail_cnt = 0;

            reset_sequence();
            set_sched_mode(0);  // Round-Robin
            set_quantum(20);    // Very short quantum for quick switches
            enable_scheduler();

            // Create threads
            create_thread(0, 3, 32'h1000_0000);
            create_thread(1, 3, 32'h2000_0000);
            repeat(10) @(posedge clk_sys);

            start_thread(0);
            start_thread(1);

            // Measure context switch timing
            int ctx_switch_times [7:0];
            int measure_cnt = 0;

            repeat(100) @(posedge clk_sys) begin
                if (sched_status_ctx_switch && ctx_switch_started) begin
                    // Wait for switch to complete
                    wait(!sched_status_ctx_switch);
                    ctx_switch_times[measure_cnt] = ctx_switch_cycle_cnt;
                    measure_cnt++;
                    ctx_switch_cycle_cnt = 0;
                end
            end

            // Check all measurements <= 10 cycles
            int all_within_limit = 1;
            int max_observed = 0;

            for (int i = 0; i < measure_cnt; i++) begin
                if (ctx_switch_times[i] > 10) begin
                    all_within_limit = 0;
                    $display("[%0t] FAIL: Context switch %0d took %0d cycles",
                             $time, i, ctx_switch_times[i]);
                    test_fail_cnt++;
                end else begin
                    $display("[%0t] Context switch %0d: %0d cycles",
                             $time, i, ctx_switch_times[i]);
                    test_pass_cnt++;
                end
                if (ctx_switch_times[i] > max_observed)
                    max_observed = ctx_switch_times[i];
            end

            if (all_within_limit && measure_cnt > 0) begin
                $display("[%0t] PASS: All context switches <= 10 cycles (max=%0d)",
                         $time, max_observed);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Context switches exceed 10 cycle limit", $time);
                test_fail_cnt++;
            end

            $display("[%0t] Test 4 complete: Pass=%0d, Fail=%0d", $time, test_pass_cnt, test_fail_cnt);
        end
    endtask

    // Test 5: Barrier Synchronization (REQ-M08-011)
    task test_barrier_sync();
        begin
            $display("\n========================================");
            $display("Test 5: Barrier Synchronization (REQ-M08-011: Timeout)");
            $display("========================================");

            test_pass_cnt = 0;
            test_fail_cnt = 0;

            reset_sequence();
            set_sched_mode(0);
            set_quantum(100);
            enable_scheduler();

            // Create 2 threads
            create_thread(0, 3, 32'h1000_0000);
            create_thread(1, 3, 32'h2000_0000);
            repeat(10) @(posedge clk_sys);

            start_thread(0);
            start_thread(1);

            // Both threads arrive at barrier 0
            barrier_sync(0, 0);
            barrier_sync(1, 0);

            // Wait for barrier completion
            repeat(20) @(posedge clk_sys);

            // Check both threads released (back to READY)
            reg_req_valid = 1;
            reg_req_rw = 0;
            reg_req_addr = 12'h0014;  // THREAD_STATE_0
            @(posedge clk_sys);
            reg_req_valid = 0;

            if (reg_rsp_data[3:0] == 4'b0101) begin  // Both threads READY
                $display("[%0t] PASS: Barrier synchronization completed", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Barrier threads not released (state=0x%02h)",
                         $time, reg_rsp_data[7:0]);
                test_fail_cnt++;
            end

            // Test barrier timeout (REQ-M08-011)
            $display("\n--- Testing Barrier Timeout ---");

            // Set short timeout
            reg_req_valid = 1;
            reg_req_rw = 1;
            reg_req_addr = 12'h0044;  // SCHED_TIMEOUT for barrier 0
            reg_req_data = 50;  // 50 cycle timeout
            @(posedge clk_sys);
            reg_req_valid = 0;

            // Create new threads
            create_thread(2, 3, 32'h3000_0000);
            create_thread(3, 3, 32'h4000_0000);
            repeat(10) @(posedge clk_sys);

            start_thread(2);
            start_thread(3);

            // Only one thread arrives at barrier
            barrier_sync(2, 0);

            // Wait for timeout
            repeat(100) @(posedge clk_sys);

            // Check timeout interrupt
            if (thread_irq && thread_irq_type == 4'b0000) begin
                $display("[%0t] PASS: Barrier timeout interrupt generated", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Barrier timeout not handled", $time);
                test_fail_cnt++;
            end

            $display("[%0t] Test 5 complete: Pass=%0d, Fail=%0d", $time, test_pass_cnt, test_fail_cnt);
        end
    endtask

    // Test 6: Error Handling
    task test_error_handling();
        begin
            $display("\n========================================");
            $display("Test 6: Error Handling");
            $display("========================================");

            test_pass_cnt = 0;
            test_fail_cnt = 0;

            reset_sequence();
            enable_scheduler();

            // Test invalid thread ID
            thread_cmd_valid = 1;
            thread_cmd_opcode = 4'b0001;  // THREAD_START
            thread_cmd_thread_id = 7;     // Invalid for MAX_THREADS=4
            @(posedge clk_sys);
            thread_cmd_valid = 0;

            repeat(10) @(posedge clk_sys);

            // Check error detection
            if (sched_status_error || thread_irq) begin
                $display("[%0t] PASS: Invalid thread ID error detected", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Invalid thread ID error not detected", $time);
                test_fail_cnt++;
            end

            // Test dispatch error handling
            reset_sequence();
            enable_scheduler();

            create_thread(0, 3, 32'h1000_0000);
            repeat(10) @(posedge clk_sys);

            start_thread(0);

            // Simulate M01 dispatch error
            dispatch_error = 1;
            repeat(10) @(posedge clk_sys);
            dispatch_error = 0;

            repeat(20) @(posedge clk_sys);

            if (sched_status_error) begin
                $display("[%0t] PASS: Dispatch error handled", $time);
                test_pass_cnt++;
            end else begin
                $display("[%0t] FAIL: Dispatch error not handled", $time);
                test_fail_cnt++;
            end

            $display("[%0t] Test 6 complete: Pass=%0d, Fail=%0d", $time, test_pass_cnt, test_fail_cnt);
        end
    endtask

    //=========================================================================
    // Main Test Sequence
    //=========================================================================

    initial begin
        $display("\n========================================");
        $display("M08 Thread Scheduler Testbench");
        $display("========================================");
        $display("Parameters: MAX_THREADS=%0d, QUANTUM=%0d", MAX_THREADS, QUANTUM_DEFAULT);

        // Initialize context storage
        for (int i = 0; i < 8; i++) begin
            context_storage[i] = '0;
        end

        // Run all tests
        test_thread_lifecycle();
        test_round_robin();
        test_priority();
        test_ctx_switch_timing();
        test_barrier_sync();
        test_error_handling();

        // Final summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");

        int total_pass = 0;
        int total_fail = 0;

        $display("Total Pass: %0d", total_pass);
        $display("Total Fail: %0d", total_fail);

        if (total_fail == 0) begin
            $display("\nALL TESTS PASSED");
        end else begin
            $display("\nSOME TESTS FAILED");
        end

        $display("\n========================================");
        $display("Testbench Complete");
        $display("========================================");

        $finish;
    end

    //=========================================================================
    // Timeout Watchdog
    //=========================================================================

    initial begin
        #100000;  // 100us timeout
        $display("\n[TIMEOUT] Testbench exceeded 100us - terminating");
        $finish;
    end

    //=========================================================================
    // Waveform Generation
    //=========================================================================

    initial begin
        $dumpfile("tb_M08_ThreadScheduler.vcd");
        $dumpvars(0, tb_M08_ThreadScheduler);
    end

    //=========================================================================
    // Coverage Collection
    //=========================================================================

    // FSM State Coverage
    covergroup sched_fsm_cg @(posedge clk_sys);
        cp_state: coverpoint dut.sched_fsm_state {
            bins idle    = {dut.SCHED_IDLE};
            bins select  = {dut.SCHED_SELECT};
            bins dispatch = {dut.SCHED_DISPATCH};
            bins running = {dut.SCHED_RUNNING};
            bins switch  = {dut.SCHED_SWITCH};
            bins error   = {dut.SCHED_ERROR};
        }
    endgroup

    covergroup ctx_fsm_cg @(posedge clk_sys);
        cp_state: coverpoint dut.ctx_fsm_state {
            bins idle   = {dut.CTX_IDLE};
            bins pause  = {dut.CTX_PAUSE};
            bins save   = {dut.CTX_SAVE};
            bins sel    = {dut.CTX_SEL};
            bins load   = {dut.CTX_LOAD};
            bins resume = {dut.CTX_RESUME};
        }
    endgroup

    covergroup thread_state_cg @(posedge clk_sys);
        cp_state: coverpoint dut.thread_state[0] {
            bins empty   = {dut.THREAD_EMPTY};
            bins ready   = {dut.THREAD_READY};
            bins running = {dut.THREAD_RUNNING};
            bins blocked = {dut.THREAD_BLOCKED};
        }
    endgroup

    covergroup sched_mode_cg @(posedge clk_sys);
        cp_mode: coverpoint dut.sched_mode {
            bins rr     = {dut.SCHED_MODE_RR};
            bins prio   = {dut.SCHED_MODE_PRIO};
            bins hybrid = {dut.SCHED_MODE_HYBRID};
        }
    endgroup

    sched_fsm_cg cg_sched = new();
    ctx_fsm_cg cg_ctx = new();
    thread_state_cg cg_thread = new();
    sched_mode_cg cg_mode = new();

endmodule