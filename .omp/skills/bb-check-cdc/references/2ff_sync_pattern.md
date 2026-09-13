# 2-FF Synchronizer Pattern

## When to Use
Required when signal crosses from one clock domain to another, source and destination
clocks are asynchronous, and the signal is single-bit (multi-bit requires FIFO or handshake).

## Standard Pattern

```systemverilog
module sync_2ff #(parameter WIDTH = 1)(
    input  logic             clk_dst,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    logic [WIDTH-1:0] sync_reg1, sync_reg2;
    always_ff @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg1 <= '0;
            sync_reg2 <= '0;
        end else begin
            sync_reg1 <= d;
            sync_reg2 <= sync_reg1;
        end
    end
    assign q = sync_reg2;
endmodule
```

## Key Requirements
1. Two flip-flops minimum to reduce metastability probability
2. Both FFs must be in destination clock domain
3. No combinational logic between the two FFs
4. Use async reset for reliable initialization

## Metastability MTBF (ASAP7 at 1GHz)
- Single FF: MTBF ~ seconds
- 2-FF sync: MTBF ~ years
- 3-FF sync: MTBF > universe age

## Verification Checklist
- Both FFs in destination clock domain
- No logic between sync FFs
- Proper async reset
- Single-bit signals only (use FIFO for multi-bit)
- CDC analysis confirms synchronization
