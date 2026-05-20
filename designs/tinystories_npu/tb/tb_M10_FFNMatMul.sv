//=============================================================================
// Testbench: M10_FFNMatMul
// Cycle-based testbench for Verilator coverage collection
//-----------------------------------------------------------------------------

module tb_M10_FFNMatMul (
    input logic clk_ext  // External clock from C++
);

    //=========================================================================
    // Parameters
    //=========================================================================
    localparam DIM = 64;
    localparam HIDDEN_DIM = 256;
    localparam DATA_WIDTH = 32;
    localparam VECTOR_WIDTH = 256;

    //=========================================================================
    // Signals
    //=========================================================================
    logic clk;
    logic rst_n;
    logic enable;

    // Control
    logic start;
    logic [1:0] mode;
    logic busy;
    logic done;
    logic error;
    logic [7:0] error_code;

    // Data Input
    logic [VECTOR_WIDTH-1:0] x_in;
    logic x_valid;
    logic x_ready;

    // Data Output
    logic [VECTOR_WIDTH-1:0] y_out;
    logic y_valid;
    logic y_ready;

    // Configuration
    logic [15:0] s_dim;
    logic [31:0] w_base;
    logic [31:0] w1_offset;
    logic [31:0] w3_offset;
    logic [31:0] w2_offset;

    // Systolic Array Port 1
    logic [3:0] sa_cmd_1;
    logic [VECTOR_WIDTH-1:0] sa_input_1;
    logic [VECTOR_WIDTH-1:0] sa_result_1;
    logic sa_done_1;

    // Systolic Array Port 2
    logic [3:0] sa_cmd_2;
    logic [VECTOR_WIDTH-1:0] sa_input_2;
    logic [VECTOR_WIDTH-1:0] sa_result_2;
    logic sa_done_2;

    logic sa_error_in;

    //=========================================================================
    // DUT Instance
    //=========================================================================
    M10_FFNMatMul dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .start(start),
        .mode(mode),
        .busy(busy),
        .done(done),
        .error(error),
        .error_code(error_code),
        .x_in(x_in),
        .x_valid(x_valid),
        .x_ready(x_ready),
        .y_out(y_out),
        .y_valid(y_valid),
        .y_ready(y_ready),
        .s_dim(s_dim),
        .w_base(w_base),
        .w1_offset(w1_offset),
        .w3_offset(w3_offset),
        .w2_offset(w2_offset),
        .sa_cmd_1(sa_cmd_1),
        .sa_dim_1(),
        .sa_w_base_1(),
        .sa_w_row_1(),
        .sa_input_1(sa_input_1),
        .sa_result_1(sa_result_1),
        .sa_done_1(sa_done_1),
        .sa_cmd_2(sa_cmd_2),
        .sa_dim_2(),
        .sa_w_base_2(),
        .sa_w_row_2(),
        .sa_input_2(sa_input_2),
        .sa_result_2(sa_result_2),
        .sa_done_2(sa_done_2),
        .sa_error_in(sa_error_in)
    );

    //=========================================================================
    // Clock Assignment
    //=========================================================================
    assign clk = clk_ext;

    //=========================================================================
    // Systolic Array Response Simulation
    //=========================================================================
    always_ff @(posedge clk) begin
        if (sa_cmd_1 != 0) begin
            sa_done_1 <= 1;
            sa_result_1 <= {VECTOR_WIDTH{1'b1}};
        end else begin
            sa_done_1 <= 0;
        end

        if (sa_cmd_2 != 0) begin
            sa_done_2 <= 1;
            sa_result_2 <= {VECTOR_WIDTH{1'b1}};
        end else begin
            sa_done_2 <= 0;
        end
    end

    //=========================================================================
    // Test FSM States
    //=========================================================================
    typedef enum {
        INIT, RESET,
        TEST_MATMUL, TEST_FFN_COMPLETE,
        TEST_ACTIVATION, TEST_FFNGLU,
        TEST_DATA_FLOW, TEST_ERROR_HANDLE,
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
        rst_n = 0;
        enable = 1;
        start = 0;
        mode = 0;
        x_in = 0;
        x_valid = 0;
        y_ready = 1;
        s_dim = 64;
        w_base = 32'h8000_0000;
        w1_offset = 32'h0000_0000;
        w3_offset = 32'h0001_0000;
        w2_offset = 32'h0002_0000;
        sa_result_1 = 0;
        sa_result_2 = 0;
        sa_error_in = 0;

        // Reset phase
        repeat(10) @(posedge clk);
        rst_n = 1;
        state = RESET;
        repeat(10) @(posedge clk);

        // Test MatMul Only
        state = TEST_MATMUL;
        for (int i = 0; i < 20; i++) begin
            start = 1;
            mode = 0;  // MatMul only
            x_in = {VECTOR_WIDTH{1'b1}};
            x_valid = 1;
            @(posedge clk);
            start = 0;
            x_valid = 0;
            wait_counter = 0;
            while (!done && wait_counter < 200) begin
                @(posedge clk);
                wait_counter++;
            end
            if (done) test_pass_count++;
        end

        // Test FFN Complete
        state = TEST_FFN_COMPLETE;
        for (int i = 0; i < 20; i++) begin
            start = 1;
            mode = 1;  // FFN complete
            x_in = {VECTOR_WIDTH{1'b1}};
            x_valid = 1;
            @(posedge clk);
            start = 0;
            x_valid = 0;
            repeat(100) @(posedge clk);
        end

        // Test Activation Only
        state = TEST_ACTIVATION;
        for (int i = 0; i < 20; i++) begin
            start = 1;
            mode = 2;  // Activation only
            @(posedge clk);
            start = 0;
            repeat(50) @(posedge clk);
        end

        // Test FFN with SwiGLU
        state = TEST_FFNGLU;
        start = 1;
        mode = 1;
        x_valid = 1;
        @(posedge clk);
        start = 0;
        x_valid = 0;
        repeat(100) @(posedge clk);

        // Test Data Flow
        state = TEST_DATA_FLOW;
        for (int i = 0; i < 50; i++) begin
            x_valid = 1;
            x_in = i;
            @(posedge clk);
            x_valid = 0;
            repeat(20) @(posedge clk);
        end

        // Test Error Handle
        state = TEST_ERROR_HANDLE;
        sa_error_in = 1;
        start = 1;
        @(posedge clk);
        start = 0;
        repeat(20) @(posedge clk);
        sa_error_in = 0;

        state = DONE;
        repeat(10) @(posedge clk);
    end

endmodule