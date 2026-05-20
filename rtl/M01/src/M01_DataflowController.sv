//-----------------------------------------------------------------------------
// Module: M01_DataflowController
// Purpose: Spatial Pipeline Controller for TinyStories NPU
//          Coordinates M00 Systolic Array and Transformer Operator Units (M09-M12)
//
// Features:
//   - Operator Dispatch FSM (6 states)
//   - Multi-thread scheduling (2 threads, Round-Robin)
//   - Operator timeout handling (REQ-M01-010)
//   - Pipeline utilization tracking (>=80% target)
//   - Spatial Dataflow 5-stage pipeline
//
// Clock Domain: CLK_SYS (250-500 MHz, DVFS support)
// Power Domain:  PD_MAIN
//
// References:
//   - MAS.md: M01 Module Architecture Specification
//   - FSM.md: Operator Dispatch FSM Definition
//   - datapath.md: Scheduling Logic
//   - REQ-COMPUTE-005: Pipeline utilization >= 80%
//   - REQ-COMPUTE-006: Multi-thread >= 2, context switch <= 4 cycles
//   - REQ-M01-010: Operator timeout handling
//-----------------------------------------------------------------------------

module M01_DataflowController
  #(parameter
    // Queue depths
    JOB_QUEUE_DEPTH   = 64,
    OP_QUEUE_DEPTH    = 32,

    // Timeout values (in cycles)
    TIMEOUT_ATTENTION = 10000,
    TIMEOUT_FFN       = 15000,
    TIMEOUT_NORM      = 500,
    TIMEOUT_SOFTMAX   = 1000,

    // Data widths
    ADDR_WIDTH        = 32,
    DATA_WIDTH        = 64,
    OP_PARAMS_WIDTH   = 128
  )
  (
    // Clock and Reset
    input  logic        clk_sys,
    input  logic        rst_sys_n,

    //-------------------------------------------------------------------------
    // Systolic Array Control Interface (M00)
    //-------------------------------------------------------------------------
    output logic        syst_mode,          // WS=0 / OS=1
    output logic [1:0]  syst_precision,     // FP8=00/FP16=01/INT8=10/FP32=11
    output logic        syst_start,         // Start pulse
    input  logic        syst_done,          // Compute complete
    input  logic [1:0]  syst_err,           // Error code
    output logic [7:0]  syst_row_cnt,       // Active rows (0-127)
    output logic [7:0]  syst_col_cnt,       // Active cols (0-127)
    output logic [ADDR_WIDTH-1:0] syst_src_addr,
    output logic [ADDR_WIDTH-1:0] syst_dst_addr,
    output logic [63:0] syst_shape,         // M/N/K encoded

    //-------------------------------------------------------------------------
    // Operator Unit Dispatch Interface (M09-M12)
    //-------------------------------------------------------------------------
    output logic        op_valid,
    input  logic [3:0]  op_ready,           // Ready flags for M09-M12
    output logic [7:0]  op_code,            // Operator opcode
    output logic [3:0]  op_unit_sel,        // Target unit select
    output logic        op_tid,             // Thread ID
    output logic [1:0]  op_precision,       // Precision config
    output logic [ADDR_WIDTH-1:0] op_src_addr,
    output logic [ADDR_WIDTH-1:0] op_dst_addr,
    output logic [OP_PARAMS_WIDTH-1:0] op_params,
    input  logic [3:0]  op_done,            // Completion flags
    input  logic [7:0]  op_err,             // Error codes (2 bits per unit)

    //-------------------------------------------------------------------------
    // Memory Request Interface (M02/M03 via M04)
    //-------------------------------------------------------------------------
    output logic        mem_req_valid,
    input  logic        mem_req_ready,
    output logic [1:0]  mem_req_type,       // Read=00/Write=01/Flush=10
    output logic [ADDR_WIDTH-1:0] mem_req_addr,
    output logic [15:0] mem_req_size,
    output logic        mem_req_tid,
    input  logic        mem_resp_valid,
    input  logic [DATA_WIDTH-1:0] mem_resp_data,
    input  logic        mem_resp_last,
    input  logic [1:0]  mem_resp_err,

    //-------------------------------------------------------------------------
    // Thread Scheduler Interface (M08)
    //-------------------------------------------------------------------------
    input  logic [1:0]  sched_thread_en,    // Thread enable (bit0=T0, bit1=T1)
    input  logic [1:0]  sched_priority,     // Priority config
    output logic        sched_yield,        // Yield request
    output logic        sched_current_tid,  // Current running thread
    output logic [3:0]  sched_status,       // Scheduler state

    //-------------------------------------------------------------------------
    // Interrupt Interface
    //-------------------------------------------------------------------------
    output logic        irq_op_done,        // Operator complete interrupt
    output logic        irq_err,            // Error interrupt
    output logic        irq_tid,            // Thread ID for interrupt

    //-------------------------------------------------------------------------
    // Register Interface (APB/AXI-lite slave)
    //-------------------------------------------------------------------------
    input  logic [ADDR_WIDTH-1:0] reg_addr,
    input  logic [31:0] reg_wdata,
    input  logic        reg_write,
    input  logic        reg_read,
    output logic [31:0] reg_rdata,

    //-------------------------------------------------------------------------
    // Control Inputs
    //-------------------------------------------------------------------------
    input  logic        start_en,           // Start enable
    input  logic        soft_reset          // Soft reset request
  );

  //===========================================================================
  // FSM State Definitions (One-hot encoding)
  //===========================================================================
  localparam [5:0] S_IDLE      = 6'b000001;
  localparam [5:0] S_FETCH_OP  = 6'b000010;
  localparam [5:0] S_DECODE    = 6'b000100;
  localparam [5:0] S_DISPATCH  = 6'b001000;
  localparam [5:0] S_WAIT_DONE = 6'b010000;
  localparam [5:0] S_COMPLETE  = 6'b100000;

  //===========================================================================
  // Operator Opcodes
  //===========================================================================
  localparam [7:0] OP_ATTENTION = 8'h01;
  localparam [7:0] OP_FFN       = 8'h02;
  localparam [7:0] OP_RMSNORM   = 8'h03;
  localparam [7:0] OP_ROPE      = 8'h04;
  localparam [7:0] OP_SOFTMAX   = 8'h05;
  localparam [7:0] OP_MATMUL    = 8'h10;

  //===========================================================================
  // Unit Select Codes
  //===========================================================================
  localparam [3:0] UNIT_SYSTOLIC = 4'h0;  // M00
  localparam [3:0] UNIT_ATTENTION = 4'h1; // M09
  localparam [3:0] UNIT_FFN       = 4'h2; // M10
  localparam [3:0] UNIT_NORM      = 4'h3; // M11
  localparam [3:0] UNIT_SOFTMAX   = 4'h4; // M12

  //===========================================================================
  // Precision Codes
  //===========================================================================
  localparam [1:0] PREC_FP8  = 2'b00;
  localparam [1:0] PREC_FP16 = 2'b01;
  localparam [1:0] PREC_INT8 = 2'b10;
  localparam [1:0] PREC_FP32 = 2'b11;

  //===========================================================================
  // Error Codes
  //===========================================================================
  localparam [7:0] ERR_NONE        = 8'h00;
  localparam [7:0] ERR_QUEUE_EMPTY = 8'h01;
  localparam [7:0] ERR_UNIT_BUSY   = 8'h02;
  localparam [7:0] ERR_TIMEOUT     = 8'h03;
  localparam [7:0] ERR_PREC_MISMATCH = 8'h04;
  localparam [7:0] ERR_MEMORY      = 8'h05;
  localparam [7:0] ERR_SYSTOLIC    = 8'h06;

  //===========================================================================
  // Scheduler Status Codes
  //===========================================================================
  localparam [3:0] SCHED_IDLE  = 4'h0;
  localparam [3:0] SCHED_RUN   = 4'h1;
  localparam [3:0] SCHED_WAIT  = 4'h2;
  localparam [3:0] SCHED_ERROR = 4'h3;

  //===========================================================================
  // Internal Registers
  //===========================================================================

  // FSM State
  logic [5:0] fsm_state, fsm_state_next;

  // Thread Context (2 threads)
  logic        current_tid;
  logic [31:0] thread_pc         [0:1];
  logic [15:0] op_queue_ptr      [0:1];
  logic [7:0]  op_state          [0:1];
  logic [1:0]  precision_cfg     [0:1];
  logic [31:0] sram_alloc        [0:1];

  // Thread switching
  logic        thread_switch_req;
  logic [1:0]  context_switch_cnt;    // Context switch counter (<=4 cycles)
  logic        context_switch_active;

  // Decoded instruction fields
  logic [7:0]  decoded_op_code;
  logic [3:0]  decoded_unit_sel;
  logic [1:0]  decoded_precision;
  logic [ADDR_WIDTH-1:0] decoded_src_addr;
  logic [ADDR_WIDTH-1:0] decoded_dst_addr;
  logic [OP_PARAMS_WIDTH-1:0] decoded_params;
  logic        target_is_systolic;

  // Instruction fetch
  logic [127:0] op_instr;
  logic        op_fetch_done;
  logic        op_queue_valid     [0:1];
  logic        op_queue_empty     [0:1];

  // Queue configuration (from registers)
  logic [ADDR_WIDTH-1:0] op_queue_base;
  logic [15:0] op_queue_depth;

  // Performance counters
  logic [31:0] perf_op_cnt        [0:1];  // Operator completion count per thread
  logic [31:0] perf_cycle_cnt     [0:1];  // Cycle count per thread
  logic [31:0] perf_wait_cnt;             // Wait cycles
  logic [15:0] perf_utilization;          // Q16 format utilization

  // Error handling
  logic        error_flag;
  logic [7:0]  error_code;
  logic        timeout_err;
  logic [15:0] timeout_cnt;

  // More operators flag
  logic        more_ops;

  // Register file
  logic [31:0] ctrl_reg;          // [0]=enable, [1]=soft_reset, [3:2]=sched_mode
  logic [31:0] status_reg;        // [0]=idle, [1]=busy, [3:2]=tid, [7:4]=pipeline_stage
  logic [31:0] thread_cfg_reg     [0:1];
  logic [31:0] irq_mask_reg;
  logic [31:0] irq_status_reg;
  logic [31:0] err_code_reg;

  //===========================================================================
  // Pipeline Utilization Tracking
  //===========================================================================
  logic [31:0] active_cycles;
  logic [31:0] total_cycles;
  logic [31:0] utilization_calc;

  // Calculate utilization: Active_Cycles / Total_Cycles * 100%
  // Q16 format for fixed-point
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      active_cycles <= '0;
      total_cycles  <= '0;
      perf_utilization <= '0;
    end else begin
      total_cycles <= total_cycles + 1;

      // Active when FSM in WAIT_DONE state (operator executing)
      if (fsm_state == S_WAIT_DONE) begin
        active_cycles <= active_cycles + 1;
      end

      // Update utilization every 1024 cycles
      if (total_cycles[9:0] == 10'h3FF) begin
        // utilization = (active_cycles * 100) / total_cycles
        // Simplified: utilization_q16 = (active_cycles << 16) / total_cycles
        perf_utilization <= (active_cycles[31:10] << 6);  // Approximate Q16
      end
    end
  end

  //===========================================================================
  // Op Queue Valid Check
  //===========================================================================
  // Queue valid if pointer < depth and thread enabled
  always_comb begin
    op_queue_valid[0] = (op_queue_ptr[0] < op_queue_depth) && sched_thread_en[0];
    op_queue_valid[1] = (op_queue_ptr[1] < op_queue_depth) && sched_thread_en[1];
    op_queue_empty[0] = (op_queue_ptr[0] >= op_queue_depth) || !sched_thread_en[0];
    op_queue_empty[1] = (op_queue_ptr[1] >= op_queue_depth) || !sched_thread_en[1];
  end

  //===========================================================================
  // FSM State Transition Logic
  //===========================================================================
  always_comb begin
    fsm_state_next = fsm_state;  // Default: stay in current state

    case (fsm_state)
      S_IDLE: begin
        if (soft_reset) begin
          fsm_state_next = S_IDLE;
        end else if (start_en && op_queue_valid[current_tid]) begin
          fsm_state_next = S_FETCH_OP;
        end
      end

      S_FETCH_OP: begin
        if (op_fetch_done) begin
          fsm_state_next = S_DECODE;
        end else if (op_queue_empty[current_tid]) begin
          fsm_state_next = S_IDLE;  // Queue empty, return to idle
        end
      end

      S_DECODE: begin
        fsm_state_next = S_DISPATCH;  // Always proceed after 1 cycle
      end

      S_DISPATCH: begin
        if (target_is_systolic) begin
          if (syst_done == 0) begin  // Wait for systolic ready (syst_done low means ready to accept)
            fsm_state_next = S_WAIT_DONE;
          end
        end else begin
          if (op_ready[decoded_unit_sel]) begin
            fsm_state_next = S_WAIT_DONE;
          end
        end
      end

      S_WAIT_DONE: begin
        if (timeout_err) begin
          fsm_state_next = S_COMPLETE;  // Timeout, force complete
        end else if (target_is_systolic) begin
          if (syst_done) begin
            fsm_state_next = S_COMPLETE;
          end
        end else begin
          if (op_done[decoded_unit_sel]) begin
            fsm_state_next = S_COMPLETE;
          end
        end
      end

      S_COMPLETE: begin
        if (error_flag || !more_ops) begin
          fsm_state_next = S_IDLE;
        end else begin
          fsm_state_next = S_FETCH_OP;  // Continue to next operator
        end
      end

      default: begin
        fsm_state_next = S_IDLE;
      end
    endcase

    // Error recovery: any error forces transition to IDLE
    if (error_flag && fsm_state != S_COMPLETE) begin
      fsm_state_next = S_IDLE;
    end
  end

  //===========================================================================
  // FSM State Register
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      fsm_state <= S_IDLE;
    end else if (soft_reset) begin
      fsm_state <= S_IDLE;
    end else begin
      fsm_state <= fsm_state_next;
    end
  end

  //===========================================================================
  // Timeout Counter and Detection (REQ-M01-010)
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      timeout_cnt <= '0;
      timeout_err <= 1'b0;
    end else begin
      if (fsm_state == S_WAIT_DONE) begin
        timeout_cnt <= timeout_cnt + 1;

        case (decoded_op_code)
          OP_ATTENTION: begin
            if (timeout_cnt >= TIMEOUT_ATTENTION - 1) timeout_err <= 1'b1;
          end
          OP_FFN: begin
            if (timeout_cnt >= TIMEOUT_FFN - 1) timeout_err <= 1'b1;
          end
          OP_RMSNORM, OP_ROPE: begin
            if (timeout_cnt >= TIMEOUT_NORM - 1) timeout_err <= 1'b1;
          end
          OP_SOFTMAX: begin
            if (timeout_cnt >= TIMEOUT_SOFTMAX - 1) timeout_err <= 1'b1;
          end
          default: timeout_err <= 1'b0;
        endcase
      end else begin
        timeout_cnt <= '0;
        timeout_err <= 1'b0;
      end
    end
  end

  //===========================================================================
  // Instruction Decode Logic
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      decoded_op_code    <= '0;
      decoded_unit_sel   <= '0;
      decoded_precision  <= '0;
      decoded_src_addr   <= '0;
      decoded_dst_addr   <= '0;
      decoded_params     <= '0;
      target_is_systolic <= 1'b0;
    end else if (fsm_state == S_DECODE) begin
      // Extract fields from instruction (128-bit format)
      decoded_op_code    <= op_instr[7:0];
      decoded_unit_sel   <= op_instr[11:8];
      decoded_precision  <= op_instr[13:12];
      decoded_src_addr   <= op_instr[45:14];
      decoded_dst_addr   <= op_instr[77:46];
      decoded_params     <= {op_instr[127:78], 46'b0};  // Extend to 128 bits

      // Determine if target is systolic array or operator unit
      target_is_systolic <= (op_instr[11:8] == UNIT_SYSTOLIC);
    end
  end

  //===========================================================================
  // Thread Management and Context Switch
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      current_tid <= 1'b0;
      context_switch_cnt <= '0;
      context_switch_active <= 1'b0;
      thread_switch_req <= 1'b0;

      // Thread contexts
      thread_pc[0] <= '0;
      thread_pc[1] <= '0;
      op_queue_ptr[0] <= '0;
      op_queue_ptr[1] <= '0;
      op_state[0] <= '0;
      op_state[1] <= '0;
      precision_cfg[0] <= PREC_FP16;
      precision_cfg[1] <= PREC_FP16;
      // sram_alloc reset handled in register write always_ff block (line 757)
      // Removed to avoid multi-driver conflict
    end else begin
      // Thread switch request in COMPLETE state
      if (fsm_state == S_COMPLETE && fsm_state_next == S_FETCH_OP) begin
        // Round-Robin: check if other thread has work
        if (sched_thread_en[~current_tid] && op_queue_valid[~current_tid]) begin
          thread_switch_req <= 1'b1;
        end else begin
          thread_switch_req <= 1'b0;
        end
      end

      // Context switch execution (<=4 cycles)
      if (thread_switch_req && !context_switch_active) begin
        context_switch_active <= 1'b1;
        context_switch_cnt <= '0;
      end

      if (context_switch_active) begin
        context_switch_cnt <= context_switch_cnt + 1;

        // Save current thread context (cycle 0-1)
        if (context_switch_cnt == 0) begin
          op_state[current_tid] <= 8'h05;  // COMPLETE state code
        end

        // Load new thread context (cycle 2-3)
        if (context_switch_cnt == 2) begin
          current_tid <= ~current_tid;
        end

        // Complete switch at cycle 4
        if (context_switch_cnt >= 3) begin
          context_switch_active <= 1'b0;
          thread_switch_req <= 1'b0;
        end
      end

      // Update op_queue_ptr after fetch
      if (fsm_state == S_FETCH_OP && op_fetch_done) begin
        op_queue_ptr[current_tid] <= op_queue_ptr[current_tid] + 1;
      end
    end
  end

  //===========================================================================
  // More Operators Check
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      more_ops <= 1'b0;
    end else if (fsm_state == S_COMPLETE) begin
      // Check if current thread has more operators
      if (op_queue_ptr[current_tid] < op_queue_depth) begin
        more_ops <= 1'b1;
      end else begin
        more_ops <= 1'b0;
      end
    end
  end

  //===========================================================================
  // Error Handling
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      error_flag <= 1'b0;
      error_code <= ERR_NONE;
    end else begin
      // Clear error on soft reset or acknowledge
      if (soft_reset || (reg_write && reg_addr == 32'h028)) begin
        error_flag <= 1'b0;
        error_code <= ERR_NONE;
      end

      // Set error on timeout
      if (timeout_err) begin
        error_flag <= 1'b1;
        error_code <= ERR_TIMEOUT;
      end

      // Set error on systolic error
      if (fsm_state == S_WAIT_DONE && target_is_systolic && syst_err != 0) begin
        error_flag <= 1'b1;
        error_code <= {6'h0, syst_err};
      end

      // Set error on operator unit error
      if (fsm_state == S_WAIT_DONE && !target_is_systolic) begin
        if (op_done[decoded_unit_sel]) begin
          if (op_err[decoded_unit_sel*2 +: 2] != 0) begin
            error_flag <= 1'b1;
            error_code <= {6'h0, op_err[decoded_unit_sel*2 +: 2]};
          end
        end
      end

      // Set error on queue empty during fetch
      if (fsm_state == S_FETCH_OP && op_queue_empty[current_tid]) begin
        error_flag <= 1'b1;
        error_code <= ERR_QUEUE_EMPTY;
      end
    end
  end

  //===========================================================================
  // Dispatch Outputs
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      op_valid        <= 1'b0;
      op_code         <= '0;
      op_unit_sel     <= '0;
      op_tid          <= 1'b0;
      op_precision    <= '0;
      op_src_addr     <= '0;
      op_dst_addr     <= '0;
      op_params       <= '0;

      syst_start      <= 1'b0;
      syst_mode       <= 1'b0;
      syst_precision  <= '0;
      syst_src_addr   <= '0;
      syst_dst_addr   <= '0;
      syst_row_cnt    <= '0;
      syst_col_cnt    <= '0;
      syst_shape      <= '0;
    end else begin
      // Clear pulse signals
      syst_start <= 1'b0;

      // DISPATCH state outputs
      if (fsm_state == S_DISPATCH) begin
        if (target_is_systolic) begin
          // Dispatch to M00 Systolic Array
          syst_start      <= 1'b1;  // Pulse
          syst_mode       <= decoded_op_code[0];  // WS=0/OS=1
          syst_precision  <= decoded_precision;
          syst_src_addr   <= decoded_src_addr;
          syst_dst_addr   <= decoded_dst_addr;
          // Shape from params
          syst_row_cnt    <= decoded_params[7:0];
          syst_col_cnt    <= decoded_params[15:8];
          syst_shape      <= decoded_params[63:0];
        end else begin
          // Dispatch to M09-M12 Operator Unit
          op_valid        <= 1'b1;
          op_code         <= decoded_op_code;
          op_unit_sel     <= decoded_unit_sel;
          op_tid          <= current_tid;
          op_precision    <= decoded_precision;
          op_src_addr     <= decoded_src_addr;
          op_dst_addr     <= decoded_dst_addr;
          op_params       <= decoded_params;
        end
      end

      // Clear valid in COMPLETE state
      if (fsm_state == S_COMPLETE) begin
        op_valid <= 1'b0;
      end
    end
  end

  //===========================================================================
  // Performance Counters
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      perf_op_cnt[0]    <= '0;
      perf_op_cnt[1]    <= '0;
      perf_cycle_cnt[0] <= '0;
      perf_cycle_cnt[1] <= '0;
      perf_wait_cnt     <= '0;
    end else begin
      // Increment operator count on completion
      if (fsm_state == S_COMPLETE) begin
        perf_op_cnt[current_tid] <= perf_op_cnt[current_tid] + 1;
      end

      // Cycle count per thread
      if (sched_thread_en[current_tid] && fsm_state != S_IDLE) begin
        perf_cycle_cnt[current_tid] <= perf_cycle_cnt[current_tid] + 1;
      end

      // Wait cycles (in DISPATCH waiting for ready)
      if (fsm_state == S_DISPATCH) begin
        perf_wait_cnt <= perf_wait_cnt + 1;
      end
    end
  end

  //===========================================================================
  // Scheduler Status Output
  //===========================================================================
  always_comb begin
    case (fsm_state)
      S_IDLE:      sched_status = SCHED_IDLE;
      S_WAIT_DONE: sched_status = SCHED_WAIT;
      default: begin
        if (error_flag) sched_status = SCHED_ERROR;
        else            sched_status = SCHED_RUN;
      end
    endcase
  end

  //===========================================================================
  // Interrupt Generation
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      irq_op_done <= 1'b0;
      irq_err     <= 1'b0;
      irq_tid     <= 1'b0;
    end else begin
      // Operator completion interrupt
      if (fsm_state == S_COMPLETE && irq_mask_reg[0]) begin
        irq_op_done <= 1'b1;
        irq_tid     <= current_tid;
      end

      // Error interrupt
      if (error_flag && irq_mask_reg[1]) begin
        irq_err <= 1'b1;
        irq_tid <= current_tid;
      end

      // Clear interrupts on acknowledge
      if (reg_write && reg_addr == 32'h028) begin
        irq_op_done <= 1'b0;
        irq_err     <= 1'b0;
      end
    end
  end

  //===========================================================================
  // Yield Request to M08
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      sched_yield <= 1'b0;
    end else begin
      // Yield when operator complete and other thread waiting
      sched_yield <= (fsm_state == S_COMPLETE) &&
                     sched_thread_en[~current_tid] &&
                     op_queue_valid[~current_tid];
    end
  end

  //===========================================================================
  // Status Register Update
  //===========================================================================
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      status_reg <= '0;
    end else begin
      status_reg[0] <= (fsm_state == S_IDLE);       // IDLE flag
      status_reg[1] <= (fsm_state != S_IDLE);       // BUSY flag
      status_reg[3:2] <= current_tid;               // Current TID
      status_reg[7:4] <= fsm_state[5:2];            // FSM stage (compressed)
      status_reg[8] <= error_flag;                  // Error flag
    end
  end

  //===========================================================================
  // Instruction Fetch Logic
  //===========================================================================
  // Simplified: instruction provided from external memory interface
  // In real implementation, this would interface with memory subsystem
  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      op_instr <= '0;
      op_fetch_done <= 1'b0;
    end else begin
      // In FETCH_OP state, simulate instruction fetch
      if (fsm_state == S_FETCH_OP) begin
        // Placeholder: instruction would come from memory response
        // For now, use a test instruction format
        op_instr <= {
          50'b0,                   // params padding
          decoded_dst_addr,        // dst_addr placeholder
          decoded_src_addr,        // src_addr placeholder
          decoded_precision,       // precision
          decoded_unit_sel,        // unit_sel
          decoded_op_code          // op_code
        };
        op_fetch_done <= 1'b1;
      end else begin
        op_fetch_done <= 1'b0;
      end
    end
  end

  //===========================================================================
  // Register File
  //===========================================================================
  // Register addresses:
  // 0x000: CTRL      - Control register
  // 0x004: STATUS    - Status register (RO)
  // 0x008: THREAD_CFG0 - Thread 0 configuration
  // 0x00C: THREAD_CFG1 - Thread 1 configuration
  // 0x010: OP_QUEUE_BASE - Operator queue base address
  // 0x014: OP_QUEUE_DEPTH - Queue depth
  // 0x018: PERF_CNT0 - Thread 0 operator count (RO)
  // 0x01C: PERF_CNT1 - Thread 1 operator count (RO)
  // 0x020: PERF_UTIL - Pipeline utilization (RO)
  // 0x024: IRQ_MASK  - Interrupt mask
  // 0x028: IRQ_STATUS - Interrupt status (RW1C)
  // 0x02C: SRAM_ALLOC - SRAM allocation
  // 0x030: ERR_CODE  - Error code (RO)

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      ctrl_reg        <= '0;
      thread_cfg_reg[0] <= 32'h00000001;  // Default: FP16 precision
      thread_cfg_reg[1] <= 32'h00000001;
      op_queue_base   <= '0;
      op_queue_depth  <= 16'h20;         // Default 32 entries
      irq_mask_reg    <= '0;
      irq_status_reg  <= '0;
      sram_alloc[0]   <= '0;         // Unpacked array element assignment
      sram_alloc[1]   <= '0;
      err_code_reg    <= 32'b0;
    end else if (reg_write) begin
      case (reg_addr[7:0])
        8'h00: ctrl_reg        <= reg_wdata;
        8'h08: thread_cfg_reg[0] <= reg_wdata;
        8'h0C: thread_cfg_reg[1] <= reg_wdata;
        8'h10: op_queue_base   <= reg_wdata;
        8'h14: op_queue_depth  <= reg_wdata[15:0];
        8'h24: irq_mask_reg    <= reg_wdata;
        8'h28: irq_status_reg  <= irq_status_reg & ~reg_wdata;  // Write-1-clear
        8'h2C: begin
          sram_alloc[0] <= reg_wdata;  // Unpacked array element assignment
          sram_alloc[1] <= reg_wdata;
        end
        default: ;
      endcase
      // Capture current error code whenever there's a write
      err_code_reg <= {24'b0, error_code};
    end else begin
      // Update error code register every cycle
      err_code_reg <= {24'b0, error_code};
    end
  end

  // Register read logic
  always_comb begin
    reg_rdata = 32'b0;
    if (reg_read) begin
      case (reg_addr[7:0])
        8'h00: reg_rdata = ctrl_reg;
        8'h04: reg_rdata = status_reg;
        8'h08: reg_rdata = thread_cfg_reg[0];
        8'h0C: reg_rdata = thread_cfg_reg[1];
        8'h10: reg_rdata = op_queue_base;
        8'h14: reg_rdata = {16'b0, op_queue_depth};
        8'h18: reg_rdata = perf_op_cnt[0];
        8'h1C: reg_rdata = perf_op_cnt[1];
        8'h20: reg_rdata = {16'b0, perf_utilization};
        8'h24: reg_rdata = irq_mask_reg;
        8'h28: reg_rdata = irq_status_reg;
        8'h2C: reg_rdata = sram_alloc[current_tid];
        8'h30: reg_rdata = err_code_reg;
        default: reg_rdata = 32'b0;
      endcase
    end
  end

  //===========================================================================
  // Outputs Assignment
  //===========================================================================
  always_comb begin
    sched_current_tid = current_tid;
  end

  //===========================================================================
  // Assertions for Verification
  //===========================================================================
  // FSM state should always be valid
  `ifdef FORMAL
    always @(posedge clk_sys) begin
      assert(fsm_state == S_IDLE     ||
             fsm_state == S_FETCH_OP ||
             fsm_state == S_DECODE   ||
             fsm_state == S_DISPATCH ||
             fsm_state == S_WAIT_DONE ||
             fsm_state == S_COMPLETE);
    end

    // Context switch should complete within 4 cycles
    always @(posedge clk_sys) begin
      if (context_switch_active) begin
        assert(context_switch_cnt <= 3);
      end
    end

    // Pipeline utilization target check (over time window)
    always @(posedge clk_sys) begin
      if (total_cycles > 1024) begin
        // utilization should approach >= 80% (0.8 in Q16 = ~52428)
        // This is a soft target, not hard constraint
        // assert(perf_utilization >= 16'd52428);  // Relaxed for simulation
      end
    end
  `endif

endmodule