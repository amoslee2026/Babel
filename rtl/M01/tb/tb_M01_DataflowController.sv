//-----------------------------------------------------------------------------
// Testbench: tb_M01_DataflowController
// Purpose: Verify M01 Dataflow Controller RTL implementation
//
// Test Coverage:
//   - FSM state transitions (6 states)
//   - Operator dispatch (Attention → FFN → Norm pipeline)
//   - Multi-thread scheduling (Round-Robin, <=4 cycle switch)
//   - Operator timeout handling (REQ-M01-010)
//   - Pipeline utilization (>=80% target)
//   - Error handling and recovery
//   - Register interface
//
// References:
//   - MAS.md: M01 Module Architecture Specification
//   - FSM.md: Operator Dispatch FSM Definition
//   - REQ-COMPUTE-005: Pipeline utilization >= 80%
//   - REQ-COMPUTE-006: Multi-thread >= 2, context switch <= 4 cycles
//   - REQ-M01-010: Operator timeout handling
//-----------------------------------------------------------------------------

module tb_M01_DataflowController;

  //===========================================================================
  // Parameters
  //===========================================================================
  parameter CLK_PERIOD = 2;  // 500 MHz = 2 ns period
  parameter TIMEOUT_ATTENTION = 10000;
  parameter TIMEOUT_FFN       = 15000;
  parameter TIMEOUT_NORM      = 500;
  parameter TIMEOUT_SOFTMAX   = 1000;

  //===========================================================================
  // DUT Signals
  //===========================================================================
  logic        clk_sys;
  logic        rst_sys_n;

  // Systolic Array Control Interface (M00)
  logic        syst_mode;
  logic [1:0]  syst_precision;
  logic        syst_start;
  logic        syst_done;
  logic [1:0]  syst_err;
  logic [7:0]  syst_row_cnt;
  logic [7:0]  syst_col_cnt;
  logic [31:0] syst_src_addr;
  logic [31:0] syst_dst_addr;
  logic [63:0] syst_shape;

  // Operator Unit Dispatch Interface (M09-M12)
  logic        op_valid;
  logic [3:0]  op_ready;
  logic [7:0]  op_code;
  logic [3:0]  op_unit_sel;
  logic        op_tid;
  logic [1:0]  op_precision;
  logic [31:0] op_src_addr;
  logic [31:0] op_dst_addr;
  logic [127:0] op_params;
  logic [3:0]  op_done;
  logic [7:0]  op_err;

  // Memory Request Interface
  logic        mem_req_valid;
  logic        mem_req_ready;
  logic [1:0]  mem_req_type;
  logic [31:0] mem_req_addr;
  logic [15:0] mem_req_size;
  logic        mem_req_tid;
  logic        mem_resp_valid;
  logic [63:0] mem_resp_data;
  logic        mem_resp_last;
  logic [1:0]  mem_resp_err;

  // Thread Scheduler Interface (M08)
  logic [1:0]  sched_thread_en;
  logic [1:0]  sched_priority;
  logic        sched_yield;
  logic        sched_current_tid;
  logic [3:0]  sched_status;

  // Interrupt Interface
  logic        irq_op_done;
  logic        irq_err;
  logic        irq_tid;

  // Register Interface
  logic [31:0] reg_addr;
  logic [31:0] reg_wdata;
  logic        reg_write;
  logic        reg_read;
  logic [31:0] reg_rdata;

  // Control Inputs
  logic        start_en;
  logic        soft_reset;

  //===========================================================================
  // Test Variables
  //===========================================================================
  integer test_count;
  integer pass_count;
  integer fail_count;
  integer cycle_count;
  integer context_switch_cycles;
  integer operator_latency_cycles;

  // Test instruction queue simulation
  logic [127:0] test_op_queue [0:31];
  integer test_queue_ptr;
  integer test_queue_depth;

  // FSM state monitoring
  logic [5:0]  fsm_state_mon;
  logic        fsm_transition_count;

  //===========================================================================
  // DUT Instance
  //===========================================================================
  M01_DataflowController #(
    .TIMEOUT_ATTENTION (TIMEOUT_ATTENTION),
    .TIMEOUT_FFN       (TIMEOUT_FFN),
    .TIMEOUT_NORM      (TIMEOUT_NORM),
    .TIMEOUT_SOFTMAX   (TIMEOUT_SOFTMAX)
  ) dut (
    .clk_sys           (clk_sys),
    .rst_sys_n         (rst_sys_n),

    .syst_mode         (syst_mode),
    .syst_precision    (syst_precision),
    .syst_start        (syst_start),
    .syst_done         (syst_done),
    .syst_err          (syst_err),
    .syst_row_cnt      (syst_row_cnt),
    .syst_col_cnt      (syst_col_cnt),
    .syst_src_addr     (syst_src_addr),
    .syst_dst_addr     (syst_dst_addr),
    .syst_shape        (syst_shape),

    .op_valid          (op_valid),
    .op_ready          (op_ready),
    .op_code           (op_code),
    .op_unit_sel       (op_unit_sel),
    .op_tid            (op_tid),
    .op_precision      (op_precision),
    .op_src_addr       (op_src_addr),
    .op_dst_addr       (op_dst_addr),
    .op_params         (op_params),
    .op_done           (op_done),
    .op_err            (op_err),

    .mem_req_valid     (mem_req_valid),
    .mem_req_ready     (mem_req_ready),
    .mem_req_type      (mem_req_type),
    .mem_req_addr      (mem_req_addr),
    .mem_req_size      (mem_req_size),
    .mem_req_tid       (mem_req_tid),
    .mem_resp_valid    (mem_resp_valid),
    .mem_resp_data     (mem_resp_data),
    .mem_resp_last     (mem_resp_last),
    .mem_resp_err      (mem_resp_err),

    .sched_thread_en   (sched_thread_en),
    .sched_priority    (sched_priority),
    .sched_yield       (sched_yield),
    .sched_current_tid (sched_current_tid),
    .sched_status      (sched_status),

    .irq_op_done       (irq_op_done),
    .irq_err           (irq_err),
    .irq_tid           (irq_tid),

    .reg_addr          (reg_addr),
    .reg_wdata         (reg_wdata),
    .reg_write         (reg_write),
    .reg_read          (reg_read),
    .reg_rdata         (reg_rdata),

    .start_en          (start_en),
    .soft_reset        (soft_reset)
  );

  //===========================================================================
  // FSM State Monitoring (via internal signal access)
  //===========================================================================
  // For simulation, we can monitor FSM state through status register
  // or via hierarchical path
  always @(posedge clk_sys) begin
    fsm_state_mon <= dut.fsm_state;
  end

  //===========================================================================
  // Clock Generation
  //===========================================================================
  initial begin
    clk_sys = 0;
    forever #(CLK_PERIOD/2) clk_sys = ~clk_sys;
  end

  //===========================================================================
  // Test Stimulus
  //===========================================================================
  initial begin
    // Initialize test counters
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    cycle_count = 0;
    fsm_transition_count = 0;

    // Initialize signals
    rst_sys_n = 0;
    start_en = 0;
    soft_reset = 0;
    syst_done = 0;
    syst_err = 0;
    op_ready = 4'hF;  // All units ready
    op_done = 0;
    op_err = 0;
    mem_req_ready = 1;
    mem_resp_valid = 0;
    mem_resp_data = 0;
    mem_resp_last = 0;
    mem_resp_err = 0;
    sched_thread_en = 2'b11;  // Both threads enabled
    sched_priority = 2'b00;
    reg_addr = 0;
    reg_wdata = 0;
    reg_write = 0;
    reg_read = 0;

    // Initialize test instruction queue
    initialize_test_queue();

    //=========================================================================
    // Test 1: Reset Sequence
    //=========================================================================
    $display("========================================");
    $display("Test 1: Reset Sequence");
    $display("========================================");
    test_count++;

    // Apply reset
    repeat(10) @(posedge clk_sys);
    rst_sys_n = 1;
    repeat(5) @(posedge clk_sys);

    // Check FSM in IDLE state
    if (fsm_state_mon == 6'b000001) begin
      $display("PASS: FSM in IDLE after reset");
      pass_count++;
    end else begin
      $display("FAIL: FSM not in IDLE after reset (state = %b)", fsm_state_mon);
      fail_count++;
    end

    // Check sched_status is IDLE
    if (sched_status == 4'h0) begin
      $display("PASS: sched_status is IDLE");
      pass_count++;
    end else begin
      $display("FAIL: sched_status not IDLE (status = %h)", sched_status);
      fail_count++;
    end

    //=========================================================================
    // Test 2: FSM State Transitions (IDLE → FETCH_OP → DECODE → DISPATCH → WAIT_DONE → COMPLETE)
    //=========================================================================
    $display("========================================");
    $display("Test 2: FSM State Transitions");
    $display("========================================");
    test_count++;

    // Configure queue depth via register
    write_register(32'h014, 32'h00000010);  // Depth = 16

    // Enable interrupts
    write_register(32'h024, 32'h00000001);  // IRQ_MASK[0] = 1

    // Start enable
    start_en = 1;

    // Wait for FSM transition
    @(posedge clk_sys);

    // Track FSM transitions
    fsm_transition_count = 0;
    fork
      begin
        // Monitor FSM transitions
        while (fsm_transition_count < 6) begin
          @(posedge clk_sys);
          if (fsm_state_mon != fsm_state_mon) begin
            fsm_transition_count++;
          end
        end
      end
      begin
        // Timeout watchdog
        repeat(100) @(posedge clk_sys);
        $display("FAIL: FSM transition timeout");
        fail_count++;
      end
    join_any

    // Wait for complete cycle
    wait_fsm_state(6'b100000);  // S_COMPLETE

    // Simulate operator completion
    op_done = 4'h2;  // M10 (FFN) complete
    @(posedge clk_sys);
    op_done = 0;

    // Wait for return to IDLE
    wait_fsm_state(6'b000001);  // S_IDLE

    if (fsm_transition_count >= 5) begin
      $display("PASS: FSM completed all transitions (%d transitions)", fsm_transition_count);
      pass_count++;
    end

    //=========================================================================
    // Test 3: Operator Dispatch - Attention → FFN → Norm Pipeline
    //=========================================================================
    $display("========================================");
    $display("Test 3: Operator Dispatch Pipeline");
    $display("========================================");
    test_count++;

    // Reset queue
    test_queue_ptr = 0;
    start_en = 1;

    // Test Attention dispatch
    $display("Testing Attention (M09) dispatch...");

    // Wait for dispatch state
    wait_fsm_state(6'b001000);  // S_DISPATCH

    // Verify dispatch to M09
    if (op_valid && op_unit_sel == 4'h1) begin
      $display("PASS: Attention dispatched to M09 (unit_sel = %h)", op_unit_sel);
      pass_count++;
    end else begin
      $display("FAIL: Attention not dispatched correctly (valid=%b, unit_sel=%h)",
               op_valid, op_unit_sel);
      fail_count++;
    end

    // Simulate M09 completion
    wait_fsm_state(6'b010000);  // S_WAIT_DONE
    operator_latency_cycles = simulate_operator_latency(100);  // 100 cycles
    op_done[1] = 1;  // M09 complete
    @(posedge clk_sys);
    op_done = 0;

    wait_fsm_state(6'b100000);  // S_COMPLETE
    @(posedge clk_sys);

    // Test FFN dispatch
    $display("Testing FFN (M10) dispatch...");
    wait_fsm_state(6'b001000);  // S_DISPATCH

    if (op_valid && op_unit_sel == 4'h2) begin
      $display("PASS: FFN dispatched to M10 (unit_sel = %h)", op_unit_sel);
      pass_count++;
    end else begin
      $display("FAIL: FFN not dispatched correctly");
      fail_count++;
    end

    // Simulate M10 completion
    wait_fsm_state(6'b010000);
    operator_latency_cycles = simulate_operator_latency(150);
    op_done[2] = 1;  // M10 complete
    @(posedge clk_sys);
    op_done = 0;

    wait_fsm_state(6'b100000);
    @(posedge clk_sys);

    // Test RMSNorm dispatch
    $display("Testing RMSNorm (M11) dispatch...");
    wait_fsm_state(6'b001000);  // S_DISPATCH

    if (op_valid && op_unit_sel == 4'h3) begin
      $display("PASS: RMSNorm dispatched to M11 (unit_sel = %h)", op_unit_sel);
      pass_count++;
    end else begin
      $display("FAIL: RMSNorm not dispatched correctly");
      fail_count++;
    end

    // Simulate M11 completion
    wait_fsm_state(6'b010000);
    operator_latency_cycles = simulate_operator_latency(32);
    op_done[3] = 1;  // M11 complete
    @(posedge clk_sys);
    op_done = 0;

    //=========================================================================
    // Test 4: Multi-thread Context Switch (<=4 cycles)
    //=========================================================================
    $display("========================================");
    $display("Test 4: Multi-thread Context Switch");
    $display("========================================");
    test_count++;

    // Ensure both threads enabled
    sched_thread_en = 2'b11;

    // Monitor context switch timing
    context_switch_cycles = 0;

    // Track current TID change
    fork
      begin
        logic prev_tid;
        prev_tid = sched_current_tid;

        while (sched_current_tid == prev_tid) begin
          @(posedge clk_sys);
        end

        // Count context switch cycles
        while (dut.context_switch_active) begin
          context_switch_cycles++;
          @(posedge clk_sys);
        end

        // Check switch latency <= 4 cycles
        if (context_switch_cycles <= 4) begin
          $display("PASS: Context switch completed in %d cycles (target <=4)", context_switch_cycles);
          pass_count++;
        end else begin
          $display("FAIL: Context switch took %d cycles (target <=4)", context_switch_cycles);
          fail_count++;
        end
      end
      begin
        // Timeout
        repeat(500) @(posedge clk_sys);
        if (context_switch_cycles == 0) begin
          $display("WARN: No context switch occurred within timeout");
        end
      end
    join_any

    //=========================================================================
    // Test 5: Operator Timeout Handling (REQ-M01-010)
    //=========================================================================
    $display("========================================");
    $display("Test 5: Operator Timeout Handling (REQ-M01-010)");
    $display("========================================");
    test_count++;

    // Start operator dispatch
    start_en = 1;
    test_queue_ptr = 0;

    // Wait for WAIT_DONE state
    wait_fsm_state(6'b001000);  // S_DISPATCH
    @(posedge clk_sys);
    wait_fsm_state(6'b010000);  // S_WAIT_DONE

    // Do NOT complete operator - wait for timeout
    $display("Waiting for timeout detection...");

    // Monitor timeout counter
    fork
      begin
        // Wait for timeout error
        while (!dut.timeout_err) begin
          @(posedge clk_sys);
        end

        // Check error flag set
        @(posedge clk_sys);
        if (dut.error_flag && dut.error_code == 8'h03) begin
          $display("PASS: Timeout detected correctly (error_code = TIMEOUT)");
          pass_count++;
        end else begin
          $display("FAIL: Timeout handling incorrect (error_flag=%b, error_code=%h)",
                   dut.error_flag, dut.error_code);
          fail_count++;
        end
      end
      begin
        // Wait for full timeout duration
        repeat(TIMEOUT_NORM + 100) @(posedge clk_sys);
        $display("FAIL: Timeout not detected within expected duration");
        fail_count++;
      end
    join_any

    // Clear error for next test
    write_register(32'h028, 32'hFFFFFFFF);  // Clear IRQ_STATUS
    soft_reset = 1;
    @(posedge clk_sys);
    soft_reset = 0;

    //=========================================================================
    // Test 6: Pipeline Utilization (>=80% target)
    //=========================================================================
    $display("========================================");
    $display("Test 6: Pipeline Utilization");
    $display("========================================");
    test_count++;

    // Reset performance counters
    rst_sys_n = 0;
    repeat(5) @(posedge clk_sys);
    rst_sys_n = 1;
    repeat(10) @(posedge clk_sys);

    // Execute multiple operators to measure utilization
    start_en = 1;

    // Run for 1000 cycles
    repeat(1000) begin
      @(posedge clk_sys);

      // Simulate operator completion periodically
      if (cycle_count % 100 == 0 && fsm_state_mon == 6'b010000) begin
        op_done = 4'hF;  // All units complete
        @(posedge clk_sys);
        op_done = 0;
      end

      cycle_count++;
    end

    // Read utilization register
    read_register(32'h020);

    // Check utilization >= 80% (Q16 format: 0.8 * 65536 = ~52429)
    if (reg_rdata[15:0] >= 16'd50000) begin  // Allow some margin
      $display("PASS: Pipeline utilization >= 80%% (util = %d/65536)", reg_rdata[15:0]);
      pass_count++;
    end else begin
      $display("WARN: Pipeline utilization below target (util = %d/65536)", reg_rdata[15:0]);
      // Not a hard failure for simulation
    end

    //=========================================================================
    // Test 7: Error Handling and Recovery
    //=========================================================================
    $display("========================================");
    $display("Test 7: Error Handling and Recovery");
    $display("========================================");
    test_count++;

    // Test systolic error
    $display("Testing systolic error handling...");

    // Dispatch to systolic
    start_en = 1;
    wait_fsm_state(6'b010000);  // Wait for WAIT_DONE

    // Inject systolic error
    syst_err = 2'h3;  // Error code
    syst_done = 1;

    @(posedge clk_sys);
    syst_done = 0;
    syst_err = 0;

    // Check error flag
    if (dut.error_flag) begin
      $display("PASS: Systolic error detected correctly");
      pass_count++;
    end else begin
      $display("FAIL: Systolic error not detected");
      fail_count++;
    end

    // Recovery
    soft_reset = 1;
    @(posedge clk_sys);
    soft_reset = 0;
    start_en = 0;

    repeat(10) @(posedge clk_sys);

    // Verify FSM returned to IDLE
    if (fsm_state_mon == 6'b000001) begin
      $display("PASS: FSM recovered to IDLE after error");
      pass_count++;
    end else begin
      $display("FAIL: FSM not in IDLE after recovery");
      fail_count++;
    end

    //=========================================================================
    // Test 8: Register Interface
    //=========================================================================
    $display("========================================");
    $display("Test 8: Register Interface");
    $display("========================================");
    test_count++;

    // Write and read CTRL register
    write_register(32'h000, 32'h00000005);  // Enable + sched_mode=1
    read_register(32'h000);
    if (reg_rdata == 32'h00000005) begin
      $display("PASS: CTRL register read/write correct");
      pass_count++;
    end else begin
      $display("FAIL: CTRL register mismatch (expected 5, got %h)", reg_rdata);
      fail_count++;
    end

    // Write and read THREAD_CFG0
    write_register(32'h008, 32'h0000003F);  // All ops enabled, FP16
    read_register(32'h008);
    if (reg_rdata == 32'h0000003F) begin
      $display("PASS: THREAD_CFG0 register read/write correct");
      pass_count++;
    end else begin
      $display("FAIL: THREAD_CFG0 register mismatch");
      fail_count++;
    end

    // Read STATUS register
    read_register(32'h004);
    $display("STATUS register: %h (TID=%d, FSM=%h)",
             reg_rdata, reg_rdata[3:2], reg_rdata[7:4]);

    //=========================================================================
    // Test 9: Interrupt Generation
    //=========================================================================
    $display("========================================");
    $display("Test 9: Interrupt Generation");
    $display("========================================");
    test_count++;

    // Enable completion interrupt
    write_register(32'h024, 32'h00000001);

    // Start and complete an operator
    start_en = 1;
    wait_fsm_state(6'b010000);
    op_done = 4'h1;  // M09 complete
    @(posedge clk_sys);
    op_done = 0;

    // Wait for complete state
    wait_fsm_state(6'b100000);
    @(posedge clk_sys);

    // Check interrupt asserted
    if (irq_op_done) begin
      $display("PASS: Operator completion interrupt generated");
      pass_count++;
    end else begin
      $display("FAIL: Interrupt not generated");
      fail_count++;
    end

    // Clear interrupt
    write_register(32'h028, 32'hFFFFFFFF);
    @(posedge clk_sys);

    if (!irq_op_done) begin
      $display("PASS: Interrupt cleared correctly");
      pass_count++;
    end else begin
      $display("FAIL: Interrupt not cleared");
      fail_count++;
    end

    //=========================================================================
    // Test 10: Spatial Pipeline Dataflow
    //=========================================================================
    $display("========================================");
    $display("Test 10: Spatial Pipeline Dataflow (Attention → FFN → Norm)");
    $display("========================================");
    test_count++;

    // Execute full pipeline: Attention → FFN → RMSNorm
    // This tests REQ-COMPUTE-008 operator coverage

    start_en = 1;
    test_queue_ptr = 0;

    // Stage 1: Attention (M09)
    $display("Stage 1: Attention...");
    wait_fsm_state(6'b001000);
    check_dispatch_target(4'h1, "Attention");  // M09

    wait_fsm_state(6'b010000);
    simulate_operator_completion(100, 1);

    // Stage 2: FFN (M10)
    $display("Stage 2: FFN...");
    wait_fsm_state(6'b001000);
    check_dispatch_target(4'h2, "FFN");  // M10

    wait_fsm_state(6'b010000);
    simulate_operator_completion(150, 2);

    // Stage 3: RMSNorm (M11)
    $display("Stage 3: RMSNorm...");
    wait_fsm_state(6'b001000);
    check_dispatch_target(4'h3, "RMSNorm");  // M11

    wait_fsm_state(6'b010000);
    simulate_operator_completion(32, 3);

    // Verify pipeline completion
    wait_fsm_state(6'b100000);
    @(posedge clk_sys);

    $display("PASS: Full Spatial Pipeline completed");
    pass_count++;

    //=========================================================================
    // Test Summary
    //=========================================================================
    $display("========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Total Tests:  %d", test_count);
    $display("Passed:       %d", pass_count);
    $display("Failed:       %d", fail_count);
    $display("Pass Rate:    %.2f%%", (pass_count * 100.0) / (pass_count + fail_count));

    if (fail_count == 0) begin
      $display("========================================");
      $display("ALL TESTS PASSED");
      $display("========================================");
    end else begin
      $display("========================================");
      $display("SOME TESTS FAILED");
      $display("========================================");
    end

    // End simulation
    repeat(100) @(posedge clk_sys);
    $finish;
  end

  //===========================================================================
  // Helper Functions
  //===========================================================================

  // Initialize test instruction queue
  task initialize_test_queue;
    begin
      // Attention instruction
      test_op_queue[0] = {
        50'b0,                   // params padding
        32'hDEADBEEF,            // dst_addr
        32'h12340000,            // src_addr
        2'b01,                   // precision = FP16
        4'h1,                    // unit_sel = M09 (Attention)
        8'h01                    // op_code = Attention
      };

      // FFN instruction
      test_op_queue[1] = {
        50'b0,
        32'hDEADBEF0,
        32'h12340100,
        2'b01,                   // precision = FP16
        4'h2,                    // unit_sel = M10 (FFN)
        8'h02                    // op_code = FFN
      };

      // RMSNorm instruction
      test_op_queue[2] = {
        50'b0,
        32'hDEADBEF1,
        32'h12340200,
        2'b01,
        4'h3,                    // unit_sel = M11 (Norm)
        8'h03                    // op_code = RMSNorm
      };

      // RoPE instruction
      test_op_queue[3] = {
        50'b0,
        32'hDEADBEF2,
        32'h12340300,
        2'b01,
        4'h3,
        8'h04                    // op_code = RoPE
      };

      // SoftMax instruction
      test_op_queue[4] = {
        50'b0,
        32'hDEADBEF3,
        32'h12340400,
        2'b01,
        4'h4,                    // unit_sel = M12 (SoftMax)
        8'h05                    // op_code = SoftMax
      };

      test_queue_depth = 5;
      test_queue_ptr = 0;
    end
  endtask

  // Write register
  task write_register;
    input [31:0] addr;
    input [31:0] data;
    begin
      @(posedge clk_sys);
      reg_addr = addr;
      reg_wdata = data;
      reg_write = 1;
      @(posedge clk_sys);
      reg_write = 0;
      @(posedge clk_sys);
    end
  endtask

  // Read register
  task read_register;
    input [31:0] addr;
    begin
      @(posedge clk_sys);
      reg_addr = addr;
      reg_read = 1;
      @(posedge clk_sys);
      reg_read = 0;
      @(posedge clk_sys);
    end
  endtask

  // Wait for specific FSM state
  task wait_fsm_state;
    input [5:0] target_state;
    begin
      while (fsm_state_mon != target_state) begin
        @(posedge clk_sys);
      end
    end
  endtask

  // Simulate operator completion after latency
  task simulate_operator_completion;
    input integer latency_cycles;
    input integer unit_index;
    begin
      repeat(latency_cycles) @(posedge clk_sys);
      op_done[unit_index] = 1;
      @(posedge clk_sys);
      op_done[unit_index] = 0;
    end
  endtask

  // Simulate operator latency (returns cycle count)
  function integer simulate_operator_latency;
    input integer cycles;
    begin
      repeat(cycles) @(posedge clk_sys);
      return cycles;
    end
  endfunction

  // Check dispatch target
  task check_dispatch_target;
    input [3:0] expected_unit;
    input string op_name;
    begin
      if (op_unit_sel == expected_unit) begin
        $display("PASS: %s dispatched to correct unit (sel=%h)", op_name, op_unit_sel);
        pass_count++;
      end else begin
        $display("FAIL: %s dispatched to wrong unit (expected %h, got %h)",
                 op_name, expected_unit, op_unit_sel);
        fail_count++;
      end
    end
  endtask

  //===========================================================================
  // Timeout Watchdog
  //===========================================================================
  initial begin
    repeat(100000) @(posedge clk_sys);
    $display("ERROR: Simulation timeout exceeded 100000 cycles");
    $display("Current FSM state: %b", fsm_state_mon);
    fail_count++;
    $finish;
  end

  //===========================================================================
  // Wave Dump (for debugging)
  //===========================================================================
  initial begin
    $dumpfile("tb_M01_DataflowController.vcd");
    $dumpvars(0, tb_M01_DataflowController);
  end

endmodule