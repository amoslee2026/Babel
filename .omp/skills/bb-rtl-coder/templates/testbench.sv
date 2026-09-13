// tb_{{ MODULE_NAME }}.sv
// Testbench for {{ MODULE_NAME }}
// ---
// module: tb_{{ MODULE_ID }}
// type: tb
// status: pending
// generated: {{ TIMESTAMP }}
// ---

`timescale 1ns/1ps

module tb_{{ MODULE_NAME }};

    // ============================================
    // Parameters
    // ============================================
    parameter CLOCK_PERIOD = 10;
    parameter RESET_PERIOD = 50;
    parameter DATA_WIDTH    = {{ WIDTH }};
    parameter TEST_CYCLES   = 1000;

    // ============================================
    // Clock & Reset Generation
    // ============================================
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #RESET_PERIOD;
        rst_n = 1;
    end

    // ============================================
    // DUT Signals
    // ============================================
    logic              valid_in;
    logic [DATA_WIDTH-1:0] data_in;
    logic              valid_out;
    logic [DATA_WIDTH-1:0] data_out;

    // ============================================
    // DUT Instance
    // ============================================
    {{ MODULE_NAME }} dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .data_in  (data_in),
        .valid_out(valid_out),
        .data_out (data_out)
    );

    // ============================================
    // Test Sequences (from verification.md)
    // ============================================
    initial begin
        valid_in = 0;
        data_in  = 0;

        @(posedge rst_n);
        #(CLOCK_PERIOD * 2);

        $display("=== Test 1: Basic Operation ===");
        @(posedge clk);
        valid_in = 1;
        data_in  = {{ test_value_1 }};
        @(posedge clk);
        valid_in = 0;

        wait(valid_out);
        $display("Output: data_out = %h", data_out);

        {{ test_sequence_2 }}
        {{ test_sequence_3 }}

        #TEST_CYCLES;
        $display("=== All Tests Completed ===");
        $finish;
    end

    // ============================================
    // Assertions (from verification.md)
    // ============================================
    assert property (@(posedge clk) disable iff (!rst_n)
        valid_out |-> {{ expected_condition }});

    // ============================================
    // Waveform Dump
    // ============================================
    initial begin
        $dumpfile("{{ MODULE_NAME }}.vcd");
        $dumpvars(0, tb_{{ MODULE_NAME }});
    end

    // ============================================
    // Error Handling
    // ============================================
    initial begin
        #100000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule