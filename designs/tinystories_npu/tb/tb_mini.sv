// Minimal testbench
module tb_mini (
    input logic clk_i_ext
);
    integer cnt;
    always @(posedge clk_i_ext) begin
        cnt <= cnt + 1;
    end
    always @(posedge clk_i_ext) begin
        if (cnt >= 10) begin
            $display("PASS: minimal test");
            $finish;
        end
    end
endmodule
