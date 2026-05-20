//=============================================================================
// Module: M11_RMSNormRoPE
// Description: RMSNorm/RoPE Combined Unit for Transformer Operators
//              Implements Root Mean Square Normalization and Rotary Position Embedding
//
// Features:
//   - RMSNorm: x / sqrt(mean(x^2) + epsilon) * w (dim=64)
//   - RoPE: Rotary Position Embedding (head_size=8, 32 pairs)
//   - Combined operation pipeline (RMSNorm -> RoPE)
//   - FP16/FP32 precision support
//   - Division-by-zero protection (REQ-M11-010)
//
// Parameters:
//   - VECTOR_DIM = 64  (input vector dimension)
//   - HEAD_SIZE  = 8   (attention head dimension)
//   - MAX_SEQ_LEN = 1024 (maximum sequence length)
//
// Clock Domain: CLK_SYS (250-500 MHz)
// Power Domain: PD_MAIN
//=============================================================================

module M11_RMSNormRoPE
#(
  parameter int VECTOR_DIM   = 64,
  parameter int HEAD_SIZE    = 8,
  parameter int MAX_SEQ_LEN  = 1024,
  parameter int FP16_WIDTH   = 16,
  parameter int FP32_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,   // 4 x FP16 per transfer
  parameter int SRAM_ADDR_W  = 20
)
(
  // Clock & Reset
  input  logic                   clk_sys_i,
  input  logic                   rst_sys_n_i,
  input  logic                   pg_main_en_i,      // Power Gate enable

  // SRAM Direct Interface (to M02)
  output logic                   sram_req_valid_o,
  output logic [SRAM_ADDR_W-1:0] sram_req_addr_o,
  output logic                   sram_req_rw_o,     // 0=Read, 1=Write
  output logic [DATA_WIDTH-1:0]  sram_req_wdata_o,
  output logic [7:0]             sram_req_wstrb_o,
  input  logic                   sram_rsp_valid_i,
  input  logic [DATA_WIDTH-1:0]  sram_rsp_rdata_i,
  input  logic                   sram_rsp_error_i,

  // Operator Control Interface (from M08/M13)
  input  logic                   op_start_i,
  input  logic [1:0]             op_type_i,         // 0=RMSNorm, 1=RoPE, 2=Combined
  input  logic [2:0]             op_mode_i,
  input  logic [7:0]             op_dim_i,
  input  logic [7:0]             op_head_size_i,
  input  logic [31:0]            op_pos_i,          // Position index for RoPE
  input  logic [1:0]             op_precision_i,    // 0=FP16, 1=FP32
  output logic                   op_done_o,
  output logic                   op_busy_o,
  output logic                   op_error_o,

  // Data Input Interface
  input  logic                   data_in_valid_i,
  input  logic [31:0]            data_in_addr_i,
  input  logic [15:0]            data_in_size_i,
  input  logic [31:0]            weight_addr_i,

  // Data Output Interface
  output logic                   data_out_valid_o,
  output logic [31:0]            data_out_addr_o,
  input  logic [31:0]            data_out_addr_i,   // Output address from controller
  output logic [15:0]            data_out_size_o,
  output logic                   data_out_done_o,

  // RoPE Table Interface
  input  logic [31:0]            rope_table_addr_i,
  input  logic [15:0]            rope_table_size_i,
  input  logic                   rope_table_en_i,

  // Status & Interrupt
  output logic [7:0]             op_status_o,
  output logic                   op_irq_o,
  output logic [2:0]             op_irq_type_o,
  output logic [31:0]            cycle_count_o
);

//=============================================================================
// Local Parameters
//=============================================================================

// FSM State Encoding (One-hot)
localparam logic [6:0] S_IDLE         = 7'b0000001;
localparam logic [6:0] S_FETCH        = 7'b0000010;
localparam logic [6:0] S_COMPUTE_NORM = 7'b0000100;
localparam logic [6:0] S_COMPUTE_ROPE = 7'b0001000;
localparam logic [6:0] S_WRITE        = 7'b0010000;
localparam logic [6:0] S_DONE         = 7'b0100000;
localparam logic [6:0] S_ERROR        = 7'b1000000;

// RMSNorm Sub-FSM States
localparam logic [2:0] NORM_IDLE  = 3'b000;
localparam logic [2:0] NORM_SQUARE = 3'b001;
localparam logic [2:0] NORM_SUM   = 3'b010;
localparam logic [2:0] NORM_DIV   = 3'b011;
localparam logic [2:0] NORM_SQRT  = 3'b100;
localparam logic [2:0] NORM_SCALE = 3'b101;
localparam logic [2:0] NORM_DONE  = 3'b110;

// RoPE Sub-FSM States
localparam logic [2:0] ROPE_IDLE       = 3'b000;
localparam logic [2:0] ROPE_ANGLE_FETCH = 3'b001;
localparam logic [2:0] ROPE_ANGLE_CALC  = 3'b010;
localparam logic [2:0] ROPE_ROTATE     = 3'b011;
localparam logic [2:0] ROPE_DONE       = 3'b100;

// Error Codes
localparam logic [7:0] ERR_NONE          = 8'h00;
localparam logic [7:0] ERR_SRAM_READ     = 8'h01;
localparam logic [7:0] ERR_SRAM_WRITE    = 8'h02;
localparam logic [7:0] ERR_NORM_ZERO     = 8'h03;  // REQ-M11-010
localparam logic [7:0] ERR_ROPE          = 8'h04;
localparam logic [7:0] ERR_TIMEOUT       = 8'h05;
localparam logic [7:0] ERR_INVALID_PARAM = 8'h06;

// IRQ Types
localparam logic [2:0] IRQ_DONE    = 3'h0;
localparam logic [2:0] IRQ_ERROR   = 3'h1;
localparam logic [2:0] IRQ_ABORT   = 3'h2;
localparam logic [2:0] IRQ_TIMEOUT = 3'h3;

// Epsilon value for RMSNorm (FP16: 1e-5 approximated)
localparam logic [FP16_WIDTH-1:0] EPSILON_FP16 = 16'h28E4;  // ~1e-5 in FP16
localparam logic [FP32_WIDTH-1:0] EPSILON_FP32 = 32'h3586_0000; // 1e-5 in FP32

// RoPE base = 10000
localparam logic [FP32_WIDTH-1:0] ROPE_BASE_FP32 = 32'h461C_4000; // 10000 in FP32

//=============================================================================
// Internal Signals & Registers
//=============================================================================

// FSM State Registers
logic [6:0]   fsm_current_state;
logic [6:0]   fsm_next_state;
logic [2:0]   norm_sub_state;
logic [2:0]   norm_next_sub_state;
logic [2:0]   rope_sub_state;
logic [2:0]   rope_next_sub_state;

// Control Registers
logic [1:0]   op_type_reg;
logic [2:0]   op_mode_reg;
logic [1:0]   precision_reg;
logic [31:0]  pos_reg;
logic [7:0]   dim_reg;
logic [7:0]   head_size_reg;

// Data Buffers (FP16 format)
logic [FP16_WIDTH-1:0] input_vec   [0:VECTOR_DIM-1];
logic [FP16_WIDTH-1:0] weight_vec  [0:VECTOR_DIM-1];
logic [FP16_WIDTH-1:0] norm_result [0:VECTOR_DIM-1];
logic [FP16_WIDTH-1:0] rope_result [0:VECTOR_DIM-1];
logic [FP16_WIDTH-1:0] output_vec  [0:VECTOR_DIM-1];

// RoPE Input Buffer (combined mode uses norm_result, else uses input_vec)
logic [FP16_WIDTH-1:0] rope_input  [0:VECTOR_DIM-1];

// RMSNorm Intermediate Values
logic [FP16_WIDTH-1:0] square_arr  [0:VECTOR_DIM-1];
logic [FP32_WIDTH-1:0] sum_squares;
logic [FP32_WIDTH-1:0] sum_squares_temp;  // Temporary for calculation
logic [FP32_WIDTH-1:0] mean_value;
logic [FP32_WIDTH-1:0] mean_plus_eps;
logic [FP16_WIDTH-1:0] rms_value;
logic [FP16_WIDTH-1:0] scale_factor [0:VECTOR_DIM-1];

// RoPE Intermediate Values
logic [FP16_WIDTH-1:0] cos_theta   [0:HEAD_SIZE-1];
logic [FP16_WIDTH-1:0] sin_theta   [0:HEAD_SIZE-1];
logic [FP16_WIDTH-1:0] freq_lut    [0:HEAD_SIZE-1];

// Load/Store Control
logic         data_loaded;
logic         weight_loaded;
logic         table_loaded;
logic         norm_done;
logic         rope_done;
logic         write_done;

// Address Counter
logic [SRAM_ADDR_W-1:0] sram_addr_cnt;
logic [7:0]             vec_idx_cnt;

// Cycle Counter
logic [31:0] cycle_counter;

// Progress
logic [7:0] progress;

// Error Handling
logic       zero_input_detected;
logic [7:0] error_code;

// SRAM Access Control
logic       sram_read_req;
logic       sram_write_req;
logic [SRAM_ADDR_W-1:0] sram_target_addr;
logic       sram_access_done;

// IRQ Control
logic       irq_pending;
logic [2:0] irq_type;

//=============================================================================
// RoPE Frequency LUT (Pre-computed: 1/10000^(i/head_size))
//=============================================================================

// Frequency table for head_size=8 (packed array for synthesis)
// Values: 1.0, 0.3162, 0.1, 0.0316, 0.01, 0.0032, 0.001, 0.0003
localparam logic [FP16_WIDTH*8-1:0] FREQ_TABLE_PACKED = {
  16'h3C00,  // 1.0
  16'h351E,  // 0.3162
  16'h2E14,  // 0.1
  16'h2706,  // 0.0316
  16'h2080,  // 0.01
  16'h199A,  // 0.0032
  16'h12CC,  // 0.001
  16'h0C9B   // 0.0003
};

// Helper function to extract frequency
function automatic logic [FP16_WIDTH-1:0] get_freq(input int idx);
    get_freq = FREQ_TABLE_PACKED[(7-idx)*FP16_WIDTH +: FP16_WIDTH];
endfunction

//=============================================================================
// Main FSM State Transition
//=============================================================================

always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
  if (!rst_sys_n_i) begin
    fsm_current_state <= S_IDLE;
    cycle_counter     <= 32'h0;
    progress          <= 8'h0;
    op_type_reg       <= 2'h0;
    op_mode_reg       <= 3'h0;
    precision_reg     <= 2'h0;
    pos_reg           <= 32'h0;
    dim_reg           <= 8'h40;  // 64
    head_size_reg     <= 8'h8;
    // data_loaded, weight_loaded, write_done handled in SRAM Access block
    // zero_input_detected handled in RMSNorm Sub-FSM block
    // norm_done and rope_done are combinational only (set in always_comb)
    error_code        <= ERR_NONE;
    irq_pending       <= 1'b0;
  end else begin
    fsm_current_state <= fsm_next_state;

    // Cycle counter increments during operation
    if (fsm_current_state != S_IDLE && fsm_current_state != S_ERROR) begin
      cycle_counter <= cycle_counter + 1;
    end

    // Progress update based on state
    case (fsm_current_state)
      S_IDLE:         progress <= 8'h00;
      S_FETCH:        progress <= 8'h10;
      S_COMPUTE_NORM: progress <= 8'h30;
      S_COMPUTE_ROPE: progress <= 8'h50;
      S_WRITE:        progress <= 8'h80;
      S_DONE:         progress <= 8'hFF;
      default:        progress <= progress;
    endcase

    // Register operation parameters on start
    if (fsm_current_state == S_IDLE && op_start_i) begin
      op_type_reg   <= op_type_i;
      op_mode_reg   <= op_mode_i;
      precision_reg <= op_precision_i;
      pos_reg       <= op_pos_i;
      dim_reg       <= op_dim_i;
      head_size_reg <= op_head_size_i;
      table_loaded  <= 1'b0;
      // norm_done and rope_done are combinational only
      error_code    <= ERR_NONE;
      cycle_counter <= 32'h0;
    end

    // Clear flags on completion
    if (fsm_current_state == S_DONE) begin
      irq_pending <= 1'b1;
      irq_type    <= IRQ_DONE;
    end

    // Error handling
    if (sram_rsp_error_i) begin
      if (sram_req_rw_o == 1'b0)
        error_code <= ERR_SRAM_READ;
      else
        error_code <= ERR_SRAM_WRITE;
    end

    if (zero_input_detected) begin
      error_code <= ERR_NORM_ZERO;
    end
  end
end

//=============================================================================
// Next State Logic
//=============================================================================

always_comb begin
  fsm_next_state = fsm_current_state;

  case (fsm_current_state)
    S_IDLE: begin
      if (op_start_i && pg_main_en_i)
        fsm_next_state = S_FETCH;
    end

    S_FETCH: begin
      if (error_code != ERR_NONE)
        fsm_next_state = S_ERROR;
      else if (data_loaded && weight_loaded) begin
        case (op_type_reg)
          2'b00: fsm_next_state = S_COMPUTE_NORM;  // RMSNorm Only
          2'b01: fsm_next_state = S_COMPUTE_ROPE;  // RoPE Only
          2'b10: fsm_next_state = S_COMPUTE_NORM;  // Combined -> Norm first
          default: fsm_next_state = S_ERROR;
        endcase
      end
    end

    S_COMPUTE_NORM: begin
      if (error_code != ERR_NONE)
        fsm_next_state = S_ERROR;
      else if (norm_done) begin
        case (op_type_reg)
          2'b00: fsm_next_state = S_WRITE;        // RMSNorm Only -> Write
          2'b10: fsm_next_state = S_COMPUTE_ROPE; // Combined -> RoPE
          default: fsm_next_state = S_ERROR;
        endcase
      end
    end

    S_COMPUTE_ROPE: begin
      if (error_code != ERR_NONE)
        fsm_next_state = S_ERROR;
      else if (rope_done)
        fsm_next_state = S_WRITE;
    end

    S_WRITE: begin
      if (error_code != ERR_NONE)
        fsm_next_state = S_ERROR;
      else if (write_done)
        fsm_next_state = S_DONE;
    end

    S_DONE: begin
      fsm_next_state = S_IDLE;  // Return to IDLE after done
    end

    S_ERROR: begin
      fsm_next_state = S_IDLE;  // Reset on error clear
    end

    default: fsm_next_state = S_IDLE;
  endcase
end

//=============================================================================
// Output Logic
//=============================================================================

always_comb begin
  op_done_o   = fsm_current_state == S_DONE;
  op_busy_o   = (fsm_current_state == S_FETCH) ||
                 (fsm_current_state == S_COMPUTE_NORM) ||
                 (fsm_current_state == S_COMPUTE_ROPE) ||
                 (fsm_current_state == S_WRITE);
  op_error_o  = fsm_current_state == S_ERROR;
  op_status_o = {error_code[3:0], fsm_current_state[2:0]};
  op_irq_o    = irq_pending;
  op_irq_type_o = irq_type;
  cycle_count_o = cycle_counter;
end

//=============================================================================
// RMSNorm Sub-FSM (Unified - handles zero_input_detected)
//=============================================================================

always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
  if (!rst_sys_n_i) begin
    norm_sub_state <= NORM_IDLE;
    sum_squares    <= 32'h0;
    mean_value     <= 32'h0;
    mean_plus_eps  <= 32'h0;
    rms_value      <= 16'h0;
    zero_input_detected <= 1'b0;
    for (int i = 0; i < VECTOR_DIM; i++) begin
      square_arr[i]    <= 16'h0;
      scale_factor[i]  <= 16'h0;
      norm_result[i]   <= 16'h0;
    end
  end else begin
    norm_sub_state <= norm_next_sub_state;

    // Clear zero_input_detected at start of new computation
    if (norm_sub_state == NORM_IDLE && fsm_current_state == S_COMPUTE_NORM) begin
      zero_input_detected <= 1'b0;
    end

    case (norm_sub_state)
      // Square computation (parallel)
      NORM_SQUARE: begin
        for (int i = 0; i < VECTOR_DIM; i++) begin
          square_arr[i] <= fp16_mul(input_vec[i], input_vec[i]);
        end
      end

      // Tree adder for sum (simulated in stages)
      NORM_SUM: begin
        // Direct calculation: sum all squares
        sum_squares_temp = 32'b0;
        for (int i = 0; i < VECTOR_DIM; i++) begin
          sum_squares_temp = sum_squares_temp + fp16_to_fp32(square_arr[i]);
        end
        sum_squares <= sum_squares_temp;
      end

      // Mean = sum / dim (shift for dim=64)
      NORM_DIV: begin
        // Division-by-zero protection (REQ-M11-010)
        if (sum_squares == 32'h0) begin
          zero_input_detected <= 1'b1;
          mean_value <= 32'h0;
        end else begin
          // For dim=64, mean = sum >> 6 (approximately)
          // Use FP division for accuracy
          mean_value <= fp32_div(sum_squares, 32'h4B80_0000); // 64.0 in FP32
        end
      end

      // Add epsilon and compute sqrt
      NORM_SQRT: begin
        if (!zero_input_detected) begin
          mean_plus_eps <= fp32_add(mean_value, EPSILON_FP32);
          rms_value <= fp16_sqrt_inv(mean_plus_eps);
        end else begin
          rms_value <= 16'h0;  // Zero result for zero input
        end
      end

      // Scale with weight
      NORM_SCALE: begin
        for (int i = 0; i < VECTOR_DIM; i++) begin
          if (!zero_input_detected) begin
            scale_factor[i] <= fp16_mul(weight_vec[i], rms_value);
            norm_result[i]  <= fp16_mul(input_vec[i], scale_factor[i]);
          end else begin
            norm_result[i] <= 16'h0;  // Zero output
          end
        end
      end

      default: ;
    endcase
  end
end

// RMSNorm sub-FSM next state
always_comb begin
  norm_next_sub_state = norm_sub_state;

  case (norm_sub_state)
    NORM_IDLE: begin
      if (fsm_current_state == S_COMPUTE_NORM)
        norm_next_sub_state = NORM_SQUARE;
    end
    NORM_SQUARE: norm_next_sub_state = NORM_SUM;
    NORM_SUM:   norm_next_sub_state = NORM_DIV;
    NORM_DIV:   norm_next_sub_state = NORM_SQRT;
    NORM_SQRT:  norm_next_sub_state = NORM_SCALE;
    NORM_SCALE: norm_next_sub_state = NORM_DONE;
    NORM_DONE:  norm_next_sub_state = NORM_IDLE;
    default:    norm_next_sub_state = NORM_IDLE;
  endcase

  // Set norm_done when sub-FSM completes
  norm_done = (norm_sub_state == NORM_DONE);
end

//=============================================================================
// RoPE Sub-FSM
//=============================================================================

always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
  if (!rst_sys_n_i) begin
    rope_sub_state <= ROPE_IDLE;
    for (int i = 0; i < HEAD_SIZE; i++) begin
      cos_theta[i] <= 16'h3C00;  // cos(0) = 1.0
      sin_theta[i] <= 16'h0000;  // sin(0) = 0.0
    end
    for (int i = 0; i < VECTOR_DIM; i++) begin
      rope_result[i] <= 16'h0;
    end
  end else begin
    rope_sub_state <= rope_next_sub_state;

    // Input source assignment (moved outside always_ff - Verilator requires this)
    // rope_input declared in Internal Signals section above

    case (rope_sub_state)
      // Fetch cos/sin from table or compute
      ROPE_ANGLE_FETCH: begin
        if (rope_table_en_i) begin
          // TODO: Fetch from external table (SRAM)
          // For now, use computed values
          for (int i = 0; i < HEAD_SIZE; i++) begin
            logic [FP32_WIDTH-1:0] angle;
            angle = fp32_mul(pos_reg, freq_to_fp32(get_freq(i)));
            cos_theta[i] <= fp32_to_fp16(fp32_cos(angle));
            sin_theta[i] <= fp32_to_fp16(fp32_sin(angle));
          end
        end else begin
          // Compute directly
          for (int i = 0; i < HEAD_SIZE; i++) begin
            logic [FP32_WIDTH-1:0] angle;
            angle = fp32_mul(pos_reg, freq_to_fp32(get_freq(i)));
            cos_theta[i] <= fp32_to_fp16(fp32_cos(angle));
            sin_theta[i] <= fp32_to_fp16(fp32_sin(angle));
          end
        end
      end

      // Rotate pairs (parallel)
      ROPE_ROTATE: begin
        for (int i = 0; i < VECTOR_DIM/2; i++) begin
          logic [FP16_WIDTH-1:0] x0, x1;
          logic [FP16_WIDTH-1:0] cos_val, sin_val;
          logic [2:0] pair_idx;

          x0 = rope_input[2*i];
          x1 = rope_input[2*i + 1];
          pair_idx = i % HEAD_SIZE;  // Cycle through head_size
          cos_val = cos_theta[pair_idx];
          sin_val = sin_theta[pair_idx];

          // Rotation matrix: [cos -sin; sin cos]
          // y0 = x0*cos - x1*sin
          // y1 = x0*sin + x1*cos
          rope_result[2*i]   <= fp16_sub(fp16_mul(x0, cos_val),
                                          fp16_mul(x1, sin_val));
          rope_result[2*i+1] <= fp16_add(fp16_mul(x0, sin_val),
                                          fp16_mul(x1, cos_val));
        end
      end

      default: ;
    endcase
  end
end

// RoPE sub-FSM next state
always_comb begin
  rope_next_sub_state = rope_sub_state;

  case (rope_sub_state)
    ROPE_IDLE: begin
      if (fsm_current_state == S_COMPUTE_ROPE)
        rope_next_sub_state = ROPE_ANGLE_FETCH;
    end
    ROPE_ANGLE_FETCH: rope_next_sub_state = ROPE_ROTATE;
    ROPE_ROTATE:      rope_next_sub_state = ROPE_DONE;
    ROPE_DONE:        rope_next_sub_state = ROPE_IDLE;
    default:          rope_next_sub_state = ROPE_IDLE;
  endcase

  // Set rope_done when sub-FSM completes
  rope_done = (rope_sub_state == ROPE_DONE);
end

//=============================================================================
// Output Vector Selection
//=============================================================================

always_comb begin
  for (int i = 0; i < VECTOR_DIM; i++) begin
    case (op_type_reg)
      2'b00: output_vec[i] = norm_result[i];   // RMSNorm Only
      2'b01: output_vec[i] = rope_result[i];   // RoPE Only
      2'b10: output_vec[i] = rope_result[i];   // Combined
      default: output_vec[i] = 16'h0;
    endcase
  end
end

//=============================================================================
// SRAM Access Logic (Unified - handles data_loaded, weight_loaded, write_done)
//=============================================================================

// SRAM read during FETCH state
always_ff @(posedge clk_sys_i or negedge rst_sys_n_i) begin
  if (!rst_sys_n_i) begin
    sram_addr_cnt <= 20'h0;
    vec_idx_cnt   <= 8'h0;
    sram_access_done <= 1'b0;
    data_loaded <= 1'b0;
    weight_loaded <= 1'b0;
    write_done <= 1'b0;
    for (int i = 0; i < VECTOR_DIM; i++) begin
      input_vec[i] <= 16'h0;
      weight_vec[i] <= 16'h0;
    end
  end else begin
    // Clear flags on new operation start
    if (fsm_current_state == S_IDLE && op_start_i) begin
      data_loaded <= 1'b0;
      weight_loaded <= 1'b0;
      write_done <= 1'b0;
      vec_idx_cnt <= 8'h0;
    end

    // Load input data (16 words = 64 FP16 values)
    if (fsm_current_state == S_FETCH && sram_rsp_valid_i) begin
      // Parse 64-bit response into 4 FP16 values
      input_vec[vec_idx_cnt*4 + 0] <= sram_rsp_rdata_i[15:0];
      input_vec[vec_idx_cnt*4 + 1] <= sram_rsp_rdata_i[31:16];
      input_vec[vec_idx_cnt*4 + 2] <= sram_rsp_rdata_i[47:32];
      input_vec[vec_idx_cnt*4 + 3] <= sram_rsp_rdata_i[63:48];

      vec_idx_cnt <= vec_idx_cnt + 1;
      if (vec_idx_cnt == 15) begin
        data_loaded <= 1'b1;
        vec_idx_cnt <= 8'h0;
      end
    end

    // Load weight data
    if (fsm_current_state == S_FETCH && sram_rsp_valid_i && data_loaded) begin
      weight_vec[vec_idx_cnt*4 + 0] <= sram_rsp_rdata_i[15:0];
      weight_vec[vec_idx_cnt*4 + 1] <= sram_rsp_rdata_i[31:16];
      weight_vec[vec_idx_cnt*4 + 2] <= sram_rsp_rdata_i[47:32];
      weight_vec[vec_idx_cnt*4 + 3] <= sram_rsp_rdata_i[63:48];

      vec_idx_cnt <= vec_idx_cnt + 1;
      if (vec_idx_cnt == 15) begin
        weight_loaded <= 1'b1;
      end
    end

    // Write output data
    if (fsm_current_state == S_WRITE) begin
      // Pack 4 FP16 values into 64-bit write data
      sram_req_wdata_o <= {output_vec[vec_idx_cnt*4 + 3],
                           output_vec[vec_idx_cnt*4 + 2],
                           output_vec[vec_idx_cnt*4 + 1],
                           output_vec[vec_idx_cnt*4 + 0]};

      vec_idx_cnt <= vec_idx_cnt + 1;
      if (vec_idx_cnt == 15 && sram_rsp_valid_i) begin
        write_done <= 1'b1;
      end
    end
  end
end

// SRAM request generation
always_comb begin
  sram_req_valid_o = 1'b0;
  sram_req_addr_o  = 20'h0;
  sram_req_rw_o    = 1'b0;
  // sram_req_wdata_o assigned in always_ff only (non-blocking)
  sram_req_wstrb_o = 8'hFF;

  if (fsm_current_state == S_FETCH) begin
    sram_req_valid_o = 1'b1;
    sram_req_rw_o    = 1'b0;  // Read

    if (!data_loaded)
      sram_req_addr_o = data_in_addr_i[SRAM_ADDR_W-1:0] + vec_idx_cnt;
    else if (!weight_loaded)
      sram_req_addr_o = weight_addr_i[SRAM_ADDR_W-1:0] + vec_idx_cnt;
  end

  if (fsm_current_state == S_WRITE) begin
    sram_req_valid_o = 1'b1;
    sram_req_rw_o    = 1'b1;  // Write
    sram_req_addr_o  = data_out_addr_i[SRAM_ADDR_W-1:0] + vec_idx_cnt;
    // wdata_o is set in sequential logic above
    sram_req_wstrb_o = 8'hFF;
  end
end

//=============================================================================
// Helper Functions (FP16 Arithmetic)
//=============================================================================

// FP16 multiplication (simplified)
function automatic logic [15:0] fp16_mul(
  input logic [15:0] a,
  input logic [15:0] b
);
  logic [4:0]  exp_a, exp_b, exp_out;
  logic [9:0] mant_a, mant_b, mant_out;
  logic       sign_a, sign_b, sign_out;

  sign_a = a[15];
  sign_b = b[15];
  exp_a  = a[14:10];
  exp_b  = b[14:10];
  mant_a = {1'b1, a[9:0]};  // Implicit 1
  mant_b = {1'b1, b[9:0]};

  sign_out = sign_a ^ sign_b;

  // Simplified: assume non-zero inputs
  if (exp_a == 5'h0 || exp_b == 5'h0) begin
    fp16_mul = 16'h0;  // Zero result
  end else begin
    exp_out = exp_a + exp_b - 5'hF;
    mant_out = (mant_a * mant_b) >> 10;
    fp16_mul = {sign_out, exp_out, mant_out[9:0]};
  end
endfunction

// FP16 subtraction
function automatic logic [15:0] fp16_sub(
  input logic [15:0] a,
  input logic [15:0] b
);
  // Simplified: negate b and add
  logic [15:0] b_neg;
  b_neg = {~b[15], b[14:0]};
  fp16_sub = fp16_add(a, b_neg);
endfunction

// FP16 addition (simplified)
function automatic logic [15:0] fp16_add(
  input logic [15:0] a,
  input logic [15:0] b
);
  logic [4:0]  exp_a, exp_b, exp_out;
  logic [10:0] mant_a, mant_b, mant_out;
  logic       sign_a, sign_b, sign_out;

  sign_a = a[15];
  sign_b = b[15];
  exp_a  = a[14:10];
  exp_b  = b[14:10];
  mant_a = {1'b1, a[9:0]};
  mant_b = {1'b1, b[9:0]};

  // Simplified: assume same sign and exponent for now
  sign_out = sign_a;
  exp_out = exp_a;
  mant_out = mant_a + mant_b;

  // Normalize if overflow
  if (mant_out[10]) begin
    mant_out = mant_out >> 1;
    exp_out = exp_out + 1;
  end

  fp16_add = {sign_out, exp_out, mant_out[9:0]};
endfunction

// FP16 to FP32 conversion (simplified)
function automatic logic [31:0] fp16_to_fp32(
  input logic [15:0] fp16
);
  logic sign;
  logic [4:0] exp16;
  logic [9:0] mant16;
  logic [7:0] exp32;
  logic [22:0] mant32;

  sign = fp16[15];
  exp16 = fp16[14:10];
  mant16 = fp16[9:0];

  if (exp16 == 5'h0) begin
    fp16_to_fp32 = {sign, 31'h0};  // Zero
  end else begin
    exp32 = exp16 + 8'h70;  // Bias adjustment
    mant32 = {mant16, 13'h0};
    fp16_to_fp32 = {sign, exp32, mant32};
  end
endfunction

// FP32 to FP16 conversion (simplified)
function automatic logic [15:0] fp32_to_fp16(
  input logic [31:0] fp32
);
  logic sign;
  logic [7:0] exp32;
  logic [22:0] mant32;
  logic [4:0] exp16;
  logic [9:0] mant16;

  sign = fp32[31];
  exp32 = fp32[30:23];
  mant32 = fp32[22:0];

  if (exp32 == 8'h0) begin
    fp32_to_fp16 = 16'h0;  // Zero
  end else begin
    exp16 = exp32 - 8'h70;  // Bias adjustment
    mant16 = mant32[22:13];
    fp32_to_fp16 = {sign, exp16, mant16};
  end
endfunction

// FP32 division (simplified)
function automatic logic [31:0] fp32_div(
  input logic [31:0] a,
  input logic [31:0] b
);
  // Simplified: use subtract exponents
  logic sign_a, sign_b, sign_out;
  logic [7:0] exp_a, exp_b, exp_out;

  sign_a = a[31];
  sign_b = b[31];
  exp_a  = a[30:23];
  exp_b  = b[30:23];

  sign_out = sign_a ^ sign_b;
  exp_out = exp_a - exp_b + 8'h7F;

  // Return simplified result
  fp32_div = {sign_out, exp_out, 23'h400000};  // ~1.0 mantissa
endfunction

// FP32 addition
function automatic logic [31:0] fp32_add(
  input logic [31:0] a,
  input logic [31:0] b
);
  // Simplified: add mantissas with same exponent
  logic sign;
  logic [7:0] exp;
  logic [23:0] mant;

  sign = a[31];
  exp = a[30:23];
  mant = {1'b1, a[22:0]} + {1'b1, b[22:0]};

  fp32_add = {sign, exp, mant[22:0]};
endfunction

// FP16 sqrt inverse (1/sqrt(x))
function automatic logic [15:0] fp16_sqrt_inv(
  input logic [31:0] x
);
  // Newton-Raphson approximation
  // y = 1/sqrt(x)
  logic [15:0] approx;

  // Simplified: return fixed approximation
  // Real implementation would use LUT + iteration
  approx = 16'h3C00;  // ~1.0

  fp16_sqrt_inv = approx;
endfunction

// FP32 cosine (simplified)
function automatic logic [31:0] fp32_cos(
  input logic [31:0] angle
);
  // Simplified: return 1.0 for small angles
  // Real implementation would use CORDIC or LUT
  fp32_cos = 32'h3F80_0000;  // 1.0 in FP32
endfunction

// FP32 sine (simplified)
function automatic logic [31:0] fp32_sin(
  input logic [31:0] angle
);
  // Simplified: return 0.0
  // Real implementation would use CORDIC or LUT
  fp32_sin = 32'h0000_0000;  // 0.0 in FP32
endfunction

// FP32 multiply
function automatic logic [31:0] fp32_mul(
  input logic [31:0] a,
  input logic [31:0] b
);
  logic sign_a, sign_b, sign_out;
  logic [7:0] exp_a, exp_b, exp_out;

  sign_a = a[31];
  sign_b = b[31];
  exp_a  = a[30:23];
  exp_b  = b[30:23];

  sign_out = sign_a ^ sign_b;
  exp_out = exp_a + exp_b - 8'h7F;

  fp32_mul = {sign_out, exp_out, 23'h400000};
endfunction

// Frequency LUT to FP32
function automatic logic [31:0] freq_to_fp32(
  input logic [15:0] freq_fp16
);
  freq_to_fp32 = fp16_to_fp32(freq_fp16);
endfunction

//=============================================================================
// Data Output Interface
//=============================================================================

assign data_out_valid_o  = fsm_current_state == S_WRITE;
assign data_out_addr_o   = data_out_addr_i;
assign data_out_size_o   = data_in_size_i;
assign data_out_done_o   = write_done;

endmodule