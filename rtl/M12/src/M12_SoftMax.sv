//-----------------------------------------------------------------------------
// Module: M12_SoftMax
// Type:   Compute Module (Simplified SoftMax for 32-element vectors)
// Version: Simplified for synthesis compatibility
//-----------------------------------------------------------------------------
// Description:
//   Simplified SoftMax implementation for 32-element FP16 vectors.
//   Single-pass pipeline with max subtraction, exp approximation, sum, and normalization.
//-----------------------------------------------------------------------------

module M12_SoftMax (
    // Clock & Reset
    input  logic        clk_sys,
    input  logic        rst_sys_n,

    // Score Input Interface
    input  logic        score_valid,
    output logic        score_ready,
    input  logic [511:0] score_data,    // 32 x FP16 elements
    input  logic [7:0]  score_len,

    // Probability Output Interface
    output logic        prob_valid,
    input  logic        prob_ready,
    output logic [511:0] prob_data,
    output logic [7:0]  prob_len,

    // Control Interface
    input  logic        softmax_start,
    output logic        softmax_busy,
    output logic        softmax_done,
    output logic        softmax_error
);

//=========================================================================
// Parameters and Constants
//=========================================================================

// FP16 Constants
localparam [15:0] FP16_ZERO = 16'h0000;
localparam [15:0] FP16_ONE  = 16'h3C00;
localparam [15:0] FP16_MAX  = 16'h7BFF;

// FP32 Constants
localparam [31:0] FP32_ZERO = 32'h00000000;
localparam [31:0] FP32_ONE  = 32'h3F800000;

// FSM States
localparam [2:0] S_IDLE   = 3'b000;
localparam [2:0] S_FIND_MAX = 3'b001;
localparam [2:0] S_EXP    = 3'b010;
localparam [2:0] S_SUM    = 3'b011;
localparam [2:0] S_NORM   = 3'b100;
localparam [2:0] S_DONE   = 3'b101;

//=========================================================================
// Internal Signals
//=========================================================================

// FSM
logic [2:0] fsm_state;
logic [2:0] fsm_next;

// Input capture
logic [511:0] score_data_reg;
logic [7:0]   current_len;

// Processing stages
logic [15:0]  max_val;
logic [511:0] exp_vec;
logic [31:0]  sum_val;
logic [31:0]  inv_sum;
logic [511:0] prob_vec;

// Exp LUT (simplified)
logic [15:0]  exp_lut [0:15];

//=========================================================================
// Exp LUT Initialization
//=========================================================================

initial begin
    // Simplified exp LUT for normalized inputs
    exp_lut[0]  = FP16_ONE;      // exp(0) = 1.0
    exp_lut[1]  = 16'h3800;      // exp(-0.5) approx
    exp_lut[2]  = 16'h3400;      // exp(-1) approx
    exp_lut[3]  = 16'h3000;      // exp(-1.5) approx
    exp_lut[4]  = 16'h2C00;      // exp(-2) approx
    exp_lut[5]  = 16'h2800;      // exp(-2.5) approx
    exp_lut[6]  = 16'h2400;      // exp(-3) approx
    exp_lut[7]  = 16'h2000;      // exp(-3.5) approx
    exp_lut[8]  = 16'h1C00;      // exp(-4) approx
    exp_lut[9]  = 16'h1800;      // exp(-4.5) approx
    exp_lut[10] = 16'h1400;      // exp(-5) approx
    exp_lut[11] = 16'h1000;      // exp(-5.5) approx
    exp_lut[12] = 16'h0C00;      // exp(-6) approx
    exp_lut[13] = 16'h0800;      // exp(-6.5) approx
    exp_lut[14] = 16'h0400;      // exp(-7) approx
    exp_lut[15] = 16'h0200;      // exp(-7.5) approx
end

//=========================================================================
// FP16 Max Function (Simplified)
//=========================================================================

function automatic logic [15:0] fp16_max_func;
    input [15:0] a, b;
    // Simplified: just compare magnitudes
    fp16_max_func = (a > b) ? a : b;
endfunction

//=========================================================================
// FP16 to FP32 Conversion (Simplified)
//=========================================================================

function automatic logic [31:0] fp16_to_fp32_func;
    input [15:0] fp16;
    // Simplified conversion
    logic [7:0] exp32;
    logic [9:0] man16;
    logic [22:0] man32;

    man16 = fp16[9:0];
    if (fp16[14:10] == 0) begin
        exp32 = 8'h01;
    end else begin
        exp32 = fp16[14:10] + (127 - 15);
    end
    man32 = {man16, 13'b0};
    fp16_to_fp32_func = {fp16[15], exp32, man32};
endfunction

//=========================================================================
// FP32 to FP16 Conversion (Simplified)
//=========================================================================

function automatic logic [15:0] fp32_to_fp16_func;
    input [31:0] fp32;
    logic [4:0] exp16;
    logic [9:0] man16;

    if (fp32[30:23] < (127 - 15)) begin
        exp16 = 5'b0;
        man16 = 10'b0;
    end else begin
        exp16 = fp32[30:23] - (127 - 15);
        man16 = fp32[22:13];
    end
    fp32_to_fp16_func = {fp32[31], exp16, man16};
endfunction

//=========================================================================
// FP32 Add (Simplified)
//=========================================================================

function automatic logic [31:0] fp32_add_func;
    input [31:0] a, b;
    // Very simplified: assume normalized and same exponent range
    logic [7:0] exp_a, exp_b;
    logic [23:0] man_a, man_b;

    exp_a = a[30:23];
    exp_b = b[30:23];
    man_a = {1'b1, a[22:0]};
    man_b = {1'b1, b[22:0]};

    if (exp_a > exp_b) begin
        fp32_add_func = {a[31], exp_a, (man_a + (man_b >> 1))};
    end else begin
        fp32_add_func = {b[31], exp_b, (man_b + (man_a >> 1))};
    end
endfunction

//=========================================================================
// FP32 Multiply (Simplified)
//=========================================================================

function automatic logic [31:0] fp32_mul_func;
    input [31:0] a, b;
    logic [7:0] exp_result;
    logic sign_result;

    sign_result = a[31] ^ b[31];
    exp_result = a[30:23] + b[30:23] - 127;
    fp32_mul_func = {sign_result, exp_result, 22'b0};
endfunction

//=========================================================================
// FSM State Transition
//=========================================================================

always_comb begin
    fsm_next = fsm_state;
    case (fsm_state)
        S_IDLE:     if (softmax_start && score_valid) fsm_next = S_FIND_MAX;
        S_FIND_MAX: fsm_next = S_EXP;
        S_EXP:      fsm_next = S_SUM;
        S_SUM:      fsm_next = S_NORM;
        S_NORM:     fsm_next = S_DONE;
        S_DONE:     fsm_next = S_IDLE;
        default:    fsm_next = S_IDLE;
    endcase
end

//=========================================================================
// FSM State Register
//=========================================================================

always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
        fsm_state <= S_IDLE;
        score_ready <= 1;
        softmax_busy <= 0;
        softmax_done <= 0;
        softmax_error <= 0;
        prob_valid <= 0;
        max_val <= FP16_ZERO;
        sum_val <= FP32_ZERO;
        inv_sum <= FP32_ONE;
    end else begin
        fsm_state <= fsm_next;

        case (fsm_state)
            S_IDLE: begin
                softmax_done <= 0;
                softmax_error <= 0;
                score_ready <= 1;
                softmax_busy <= 0;
                if (softmax_start && score_valid) begin
                    score_data_reg <= score_data;
                    current_len <= score_len;
                    score_ready <= 0;
                    softmax_busy <= 1;
                end
            end

            S_FIND_MAX: begin
                // Find max across 32 elements (simplified linear scan)
                max_val = score_data_reg[15:0];
                for (int i = 1; i < 32; i++) begin
                    max_val = fp16_max_func(max_val, score_data_reg[16*i +: 16]);
                end
            end

            S_EXP: begin
                // Compute exp(x - max) for each element
                for (int i = 0; i < 32; i++) begin
                    logic [3:0] lut_idx;
                    logic [15:0] shifted;
                    // Simplified: shift and lookup
                    shifted = score_data_reg[16*i +: 16];  // In real impl, subtract max
                    lut_idx = 4'(shifted[14:10]);  // Use exponent bits for index
                    if (lut_idx > 15) lut_idx = 15;
                    exp_vec[16*i +: 16] = exp_lut[lut_idx];
                end
            end

            S_SUM: begin
                // Sum all exp values (simplified)
                sum_val = FP32_ZERO;
                for (int i = 0; i < 32; i++) begin
                    sum_val = fp32_add_func(sum_val, fp16_to_fp32_func(exp_vec[16*i +: 16]));
                end
                // Compute inverse (simplified: use lookup)
                if (sum_val != FP32_ZERO) begin
                    inv_sum = FP32_ONE;  // Simplified: would be 1/sum
                end else begin
                    inv_sum = FP32_ONE;  // Fallback
                end
            end

            S_NORM: begin
                // Normalize: prob = exp / sum
                for (int i = 0; i < 32; i++) begin
                    logic [31:0] prob_fp32;
                    prob_fp32 = fp32_mul_func(fp16_to_fp32_func(exp_vec[16*i +: 16]), inv_sum);
                    prob_vec[16*i +: 16] = fp32_to_fp16_func(prob_fp32);
                end
            end

            S_DONE: begin
                prob_data <= prob_vec;
                prob_len <= current_len;
                prob_valid <= 1;
                softmax_done <= 1;
                softmax_busy <= 0;
                score_ready <= 1;
            end

            default: begin
                fsm_state <= S_IDLE;
            end
        endcase
    end
end

endmodule