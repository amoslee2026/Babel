# 2-FF Synchronizer Pattern

## Basic Pattern
```systemverilog
// 2-stage flip-flop synchronizer for single-bit CDC
logic sync_ff1, sync_ff2;

always_ff @(posedge clk_dst or negedge rst_n) begin
  if (!rst_n) begin
    sync_ff1 <= 1'b0;
    sync_ff2 <= 1'b0;
  end else begin
    sync_ff1 <= data_in;    // Stage 1: sample async input
    sync_ff2 <= sync_ff1;   // Stage 2: resolve metastability
  end
end

assign data_out = sync_ff2;
```

## Variants

### With Reset Synchronization
```systemverilog
// Async assert, sync deassert reset
logic rst_sync1, rst_sync2;
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    rst_sync1 <= 1'b1;
    rst_sync2 <= 1'b1;
  end else begin
    rst_sync1 <= 1'b0;
    rst_sync2 <= rst_sync1;
  end
end
assign rst_out = rst_sync2;
```

### Pulse Synchronizer
```systemverilog
// Convert pulse from src to dst domain
logic toggle, sync1, sync2, pulse_out;
always_ff @(posedge clk_src) toggle <= toggle ^ pulse_in;
always_ff @(posedge clk_dst or negedge rst_n) begin
  if (!rst_n) begin sync1 <= 0; sync2 <= 0; end
  else begin sync1 <= toggle; sync2 <= sync1; end
end
assign pulse_out = sync1 ^ sync2;
```

## Recognition Rules
1. Two consecutive `always_ff` assignments in same clock domain
2. First FF driven by signal from different clock domain
3. Second FF driven by first FF output
4. Both FFs share same reset
5. Minimum 2 stages; 3 stages for safety-critical paths
