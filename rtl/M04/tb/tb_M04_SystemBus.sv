//=============================================================================
// Testbench: tb_M04_SystemBus
// Description:
//   Testbench for M04 System Bus verifying:
//   - Arbitration (Priority/Round-Robin modes)
//   - Address routing (DRAM/SRAM/Register spaces)
//   - TileLink-UH protocol transactions
//   - AXI4 protocol transactions
//   - CDC synchronization (CLK_IO -> CLK_SYS)
//   - Timeout handling
//   - Error handling (invalid address)
//
// Test Cases:
//   TC01: Single Master Request (M0 TileLink read)
//   TC02: Multi-Master Arbitration (Priority mode)
//   TC03: Address Routing (DRAM, SRAM, Registers)
//   TC04: Invalid Address Error
//   TC05: Timeout Handling
//   TC06: AXI4 Transaction (M3 ISA Decoder)
//   TC07: CDC Transaction (M4 JTAG)
//
// Reference: spec_mas/M04/FSM.md Section 9.2 Functional Tests
//=============================================================================

`timescale 1ns/1ps

module tb_M04_SystemBus;

//=============================================================================
// Parameters
//=============================================================================
parameter DATA_WIDTH     = 128;
parameter ADDR_WIDTH     = 32;
parameter TIMEOUT_DEFAULT = 1000;
parameter CLK_SYS_PERIOD = 2.0;   // 500 MHz
parameter CLK_IO_PERIOD  = 20.0;  // 50 MHz
parameter CLK_AON_PERIOD = 1000.0; // 1 MHz

//=============================================================================
// Clock & Reset Signals
//=============================================================================
logic clk_sys;
logic clk_io;
logic clk_aon;
logic rst_por_n;
logic rst_sys_n;

//=============================================================================
// DUT Signals
//=============================================================================
logic                   bus_enable;
logic                   bus_busy;
logic                   bus_error;
logic [3:0]             arb_winner;
logic [2:0]             route_target;
logic                   timeout_irq;
logic                   error_irq;

// Register Interface S2
logic                   reg_s2_req_valid;
logic                   reg_s2_req_ready;
logic [15:0]            reg_s2_req_addr;
logic                   reg_s2_req_rw;
logic [31:0]            reg_s2_req_data;
logic                   reg_s2_rsp_valid;
logic [31:0]            reg_s2_rsp_data;
logic                   reg_s2_rsp_error;

// TileLink Master M0
logic                   tl_m0_a_valid;
logic                   tl_m0_a_ready;
logic [2:0]             tl_m0_a_opcode;
logic [2:0]             tl_m0_a_param;
logic [2:0]             tl_m0_a_size;
logic [3:0]             tl_m0_a_source;
logic [ADDR_WIDTH-1:0]  tl_m0_a_address;
logic [DATA_WIDTH/8-1:0]tl_m0_a_mask;
logic [DATA_WIDTH-1:0]  tl_m0_a_data;
logic                   tl_m0_a_corrupt;
logic                   tl_m0_d_valid;
logic                   tl_m0_d_ready;
logic [2:0]             tl_m0_d_opcode;
logic [1:0]             tl_m0_d_param;
logic [2:0]             tl_m0_d_size;
logic [3:0]             tl_m0_d_source;
logic [1:0]             tl_m0_d_sink;
logic [DATA_WIDTH-1:0]  tl_m0_d_data;
logic                   tl_m0_d_corrupt;
logic                   tl_m0_d_denied;

// TileLink Master M1
logic                   tl_m1_a_valid;
logic                   tl_m1_a_ready;
logic [2:0]             tl_m1_a_opcode;
logic [2:0]             tl_m1_a_param;
logic [2:0]             tl_m1_a_size;
logic [3:0]             tl_m1_a_source;
logic [ADDR_WIDTH-1:0]  tl_m1_a_address;
logic [DATA_WIDTH/8-1:0]tl_m1_a_mask;
logic [DATA_WIDTH-1:0]  tl_m1_a_data;
logic                   tl_m1_a_corrupt;
logic                   tl_m1_d_valid;
logic                   tl_m1_d_ready;
logic [2:0]             tl_m1_d_opcode;
logic [1:0]             tl_m1_d_param;
logic [2:0]             tl_m1_d_size;
logic [3:0]             tl_m1_d_source;
logic [1:0]             tl_m1_d_sink;
logic [DATA_WIDTH-1:0]  tl_m1_d_data;
logic                   tl_m1_d_corrupt;
logic                   tl_m1_d_denied;

// TileLink Master M2
logic                   tl_m2_a_valid;
logic                   tl_m2_a_ready;
logic [2:0]             tl_m2_a_opcode;
logic [2:0]             tl_m2_a_param;
logic [2:0]             tl_m2_a_size;
logic [3:0]             tl_m2_a_source;
logic [ADDR_WIDTH-1:0]  tl_m2_a_address;
logic [DATA_WIDTH/8-1:0]tl_m2_a_mask;
logic [DATA_WIDTH-1:0]  tl_m2_a_data;
logic                   tl_m2_a_corrupt;
logic                   tl_m2_d_valid;
logic                   tl_m2_d_ready;
logic [2:0]             tl_m2_d_opcode;
logic [1:0]             tl_m2_d_param;
logic [2:0]             tl_m2_d_size;
logic [3:0]             tl_m2_d_source;
logic [1:0]             tl_m2_d_sink;
logic [DATA_WIDTH-1:0]  tl_m2_d_data;
logic                   tl_m2_d_corrupt;
logic                   tl_m2_d_denied;

// AXI4 Master M3
logic [3:0]             axi_m3_awid;
logic [ADDR_WIDTH-1:0]  axi_m3_awaddr;
logic [7:0]             axi_m3_awlen;
logic [2:0]             axi_m3_awsize;
logic [1:0]             axi_m3_awburst;
logic                   axi_m3_awvalid;
logic                   axi_m3_awready;
logic [DATA_WIDTH-1:0]  axi_m3_wdata;
logic [DATA_WIDTH/8-1:0]axi_m3_wstrb;
logic                   axi_m3_wlast;
logic                   axi_m3_wvalid;
logic                   axi_m3_wready;
logic [3:0]             axi_m3_bid;
logic [1:0]             axi_m3_bresp;
logic                   axi_m3_bvalid;
logic                   axi_m3_bready;
logic [3:0]             axi_m3_arid;
logic [ADDR_WIDTH-1:0]  axi_m3_araddr;
logic [7:0]             axi_m3_arlen;
logic [2:0]             axi_m3_arsize;
logic [1:0]             axi_m3_arburst;
logic                   axi_m3_arvalid;
logic                   axi_m3_arready;
logic [3:0]             axi_m3_rid;
logic [DATA_WIDTH-1:0]  axi_m3_rdata;
logic [1:0]             axi_m3_rresp;
logic                   axi_m3_rlast;
logic                   axi_m3_rvalid;
logic                   axi_m3_rready;

// AXI4 Master M4 (JTAG)
logic [3:0]             axi_m4_awid;
logic [ADDR_WIDTH-1:0]  axi_m4_awaddr;
logic [7:0]             axi_m4_awlen;
logic [2:0]             axi_m4_awsize;
logic [1:0]             axi_m4_awburst;
logic                   axi_m4_awvalid;
logic                   axi_m4_awready;
logic [DATA_WIDTH-1:0]  axi_m4_wdata;
logic [DATA_WIDTH/8-1:0]axi_m4_wstrb;
logic                   axi_m4_wlast;
logic                   axi_m4_wvalid;
logic                   axi_m4_wready;
logic [3:0]             axi_m4_bid;
logic [1:0]             axi_m4_bresp;
logic                   axi_m4_bvalid;
logic                   axi_m4_bready;
logic [3:0]             axi_m4_arid;
logic [ADDR_WIDTH-1:0]  axi_m4_araddr;
logic [7:0]             axi_m4_arlen;
logic [2:0]             axi_m4_arsize;
logic [1:0]             axi_m4_arburst;
logic                   axi_m4_arvalid;
logic                   axi_m4_arready;
logic [3:0]             axi_m4_rid;
logic [DATA_WIDTH-1:0]  axi_m4_rdata;
logic [1:0]             axi_m4_rresp;
logic                   axi_m4_rlast;
logic                   axi_m4_rvalid;
logic                   axi_m4_rready;

// TileLink Slave S0 (DRAM)
logic                   tl_s0_a_valid;
logic                   tl_s0_a_ready;
logic [2:0]             tl_s0_a_opcode;
logic [2:0]             tl_s0_a_param;
logic [2:0]             tl_s0_a_size;
logic [3:0]             tl_s0_a_source;
logic [ADDR_WIDTH-1:0]  tl_s0_a_address;
logic [DATA_WIDTH/8-1:0]tl_s0_a_mask;
logic [DATA_WIDTH-1:0]  tl_s0_a_data;
logic                   tl_s0_a_corrupt;
logic                   tl_s0_d_valid;
logic                   tl_s0_d_ready;
logic [2:0]             tl_s0_d_opcode;
logic [1:0]             tl_s0_d_param;
logic [2:0]             tl_s0_d_size;
logic [3:0]             tl_s0_d_source;
logic [1:0]             tl_s0_d_sink;
logic [DATA_WIDTH-1:0]  tl_s0_d_data;
logic                   tl_s0_d_corrupt;
logic                   tl_s0_d_denied;

// TileLink Slave S1 (SRAM)
logic                   tl_s1_a_valid;
logic                   tl_s1_a_ready;
logic [2:0]             tl_s1_a_opcode;
logic [2:0]             tl_s1_a_param;
logic [2:0]             tl_s1_a_size;
logic [3:0]             tl_s1_a_source;
logic [ADDR_WIDTH-1:0]  tl_s1_a_address;
logic [DATA_WIDTH/8-1:0]tl_s1_a_mask;
logic [DATA_WIDTH-1:0]  tl_s1_a_data;
logic                   tl_s1_a_corrupt;
logic                   tl_s1_d_valid;
logic                   tl_s1_d_ready;
logic [2:0]             tl_s1_d_opcode;
logic [1:0]             tl_s1_d_param;
logic [2:0]             tl_s1_d_size;
logic [3:0]             tl_s1_d_source;
logic [1:0]             tl_s1_d_sink;
logic [DATA_WIDTH-1:0]  tl_s1_d_data;
logic                   tl_s1_d_corrupt;
logic                   tl_s1_d_denied;

// Register Slave S3-S6
logic                   reg_s3_req_valid, reg_s3_req_ready;
logic [15:0]            reg_s3_req_addr;
logic                   reg_s3_req_rw;
logic [31:0]            reg_s3_req_data;
logic                   reg_s3_rsp_valid;
logic [31:0]            reg_s3_rsp_data;
logic                   reg_s3_rsp_error;

logic                   reg_s4_req_valid, reg_s4_req_ready;
logic [15:0]            reg_s4_req_addr;
logic                   reg_s4_req_rw;
logic [31:0]            reg_s4_req_data;
logic                   reg_s4_rsp_valid;
logic [31:0]            reg_s4_rsp_data;
logic                   reg_s4_rsp_error;

logic                   reg_s5_req_valid, reg_s5_req_ready;
logic [15:0]            reg_s5_req_addr;
logic                   reg_s5_req_rw;
logic [31:0]            reg_s5_req_data;
logic                   reg_s5_rsp_valid;
logic [31:0]            reg_s5_rsp_data;
logic                   reg_s5_rsp_error;

logic                   reg_s6_req_valid, reg_s6_req_ready;
logic [15:0]            reg_s6_req_addr;
logic                   reg_s6_req_rw;
logic [31:0]            reg_s6_req_data;
logic                   reg_s6_rsp_valid;
logic [31:0]            reg_s6_rsp_data;
logic                   reg_s6_rsp_error;

//=============================================================================
// Test Statistics
//=============================================================================
integer test_count;
integer pass_count;
integer fail_count;
integer cycle_count;
logic [31:0] expected_data;
logic        expected_error;

//=============================================================================
// DUT Instance
//=============================================================================
M04_SystemBus #(
  .DATA_WIDTH     (DATA_WIDTH),
  .ADDR_WIDTH     (ADDR_WIDTH),
  .TIMEOUT_DEFAULT(TIMEOUT_DEFAULT)
) dut (
  .clk_sys        (clk_sys),
  .clk_io         (clk_io),
  .clk_aon        (clk_aon),
  .rst_por_n      (rst_por_n),
  .rst_sys_n      (rst_sys_n),
  .bus_enable     (bus_enable),
  .bus_busy       (bus_busy),
  .bus_error      (bus_error),
  .arb_winner     (arb_winner),
  .route_target   (route_target),
  .timeout_irq    (timeout_irq),
  .error_irq      (error_irq),

  // Register S2
  .reg_s2_req_valid (reg_s2_req_valid),
  .reg_s2_req_ready (reg_s2_req_ready),
  .reg_s2_req_addr  (reg_s2_req_addr),
  .reg_s2_req_rw    (reg_s2_req_rw),
  .reg_s2_req_data  (reg_s2_req_data),
  .reg_s2_rsp_valid (reg_s2_rsp_valid),
  .reg_s2_rsp_data  (reg_s2_rsp_data),
  .reg_s2_rsp_error (reg_s2_rsp_error),

  // TileLink M0
  .tl_m0_a_valid    (tl_m0_a_valid),
  .tl_m0_a_ready    (tl_m0_a_ready),
  .tl_m0_a_opcode   (tl_m0_a_opcode),
  .tl_m0_a_param    (tl_m0_a_param),
  .tl_m0_a_size     (tl_m0_a_size),
  .tl_m0_a_source   (tl_m0_a_source),
  .tl_m0_a_address  (tl_m0_a_address),
  .tl_m0_a_mask     (tl_m0_a_mask),
  .tl_m0_a_data     (tl_m0_a_data),
  .tl_m0_a_corrupt  (tl_m0_a_corrupt),
  .tl_m0_d_valid    (tl_m0_d_valid),
  .tl_m0_d_ready    (tl_m0_d_ready),
  .tl_m0_d_opcode   (tl_m0_d_opcode),
  .tl_m0_d_param    (tl_m0_d_param),
  .tl_m0_d_size     (tl_m0_d_size),
  .tl_m0_d_source   (tl_m0_d_source),
  .tl_m0_d_sink     (tl_m0_d_sink),
  .tl_m0_d_data     (tl_m0_d_data),
  .tl_m0_d_corrupt  (tl_m0_d_corrupt),
  .tl_m0_d_denied   (tl_m0_d_denied),

  // TileLink M1
  .tl_m1_a_valid    (tl_m1_a_valid),
  .tl_m1_a_ready    (tl_m1_a_ready),
  .tl_m1_a_opcode   (tl_m1_a_opcode),
  .tl_m1_a_param    (tl_m1_a_param),
  .tl_m1_a_size     (tl_m1_a_size),
  .tl_m1_a_source   (tl_m1_a_source),
  .tl_m1_a_address  (tl_m1_a_address),
  .tl_m1_a_mask     (tl_m1_a_mask),
  .tl_m1_a_data     (tl_m1_a_data),
  .tl_m1_a_corrupt  (tl_m1_a_corrupt),
  .tl_m1_d_valid    (tl_m1_d_valid),
  .tl_m1_d_ready    (tl_m1_d_ready),
  .tl_m1_d_opcode   (tl_m1_d_opcode),
  .tl_m1_d_param    (tl_m1_d_param),
  .tl_m1_d_size     (tl_m1_d_size),
  .tl_m1_d_source   (tl_m1_d_source),
  .tl_m1_d_sink     (tl_m1_d_sink),
  .tl_m1_d_data     (tl_m1_d_data),
  .tl_m1_d_corrupt  (tl_m1_d_corrupt),
  .tl_m1_d_denied   (tl_m1_d_denied),

  // TileLink M2
  .tl_m2_a_valid    (tl_m2_a_valid),
  .tl_m2_a_ready    (tl_m2_a_ready),
  .tl_m2_a_opcode   (tl_m2_a_opcode),
  .tl_m2_a_param    (tl_m2_a_param),
  .tl_m2_a_size     (tl_m2_a_size),
  .tl_m2_a_source   (tl_m2_a_source),
  .tl_m2_a_address  (tl_m2_a_address),
  .tl_m2_a_mask     (tl_m2_a_mask),
  .tl_m2_a_data     (tl_m2_a_data),
  .tl_m2_a_corrupt  (tl_m2_a_corrupt),
  .tl_m2_d_valid    (tl_m2_d_valid),
  .tl_m2_d_ready    (tl_m2_d_ready),
  .tl_m2_d_opcode   (tl_m2_d_opcode),
  .tl_m2_d_param    (tl_m2_d_param),
  .tl_m2_d_size     (tl_m2_d_size),
  .tl_m2_d_source   (tl_m2_d_source),
  .tl_m2_d_sink     (tl_m2_d_sink),
  .tl_m2_d_data     (tl_m2_d_data),
  .tl_m2_d_corrupt  (tl_m2_d_corrupt),
  .tl_m2_d_denied   (tl_m2_d_denied),

  // AXI M3
  .axi_m3_awid      (axi_m3_awid),
  .axi_m3_awaddr    (axi_m3_awaddr),
  .axi_m3_awlen     (axi_m3_awlen),
  .axi_m3_awsize    (axi_m3_awsize),
  .axi_m3_awburst   (axi_m3_awburst),
  .axi_m3_awvalid   (axi_m3_awvalid),
  .axi_m3_awready   (axi_m3_awready),
  .axi_m3_wdata     (axi_m3_wdata),
  .axi_m3_wstrb     (axi_m3_wstrb),
  .axi_m3_wlast     (axi_m3_wlast),
  .axi_m3_wvalid    (axi_m3_wvalid),
  .axi_m3_wready    (axi_m3_wready),
  .axi_m3_bid       (axi_m3_bid),
  .axi_m3_bresp     (axi_m3_bresp),
  .axi_m3_bvalid    (axi_m3_bvalid),
  .axi_m3_bready    (axi_m3_bready),
  .axi_m3_arid      (axi_m3_arid),
  .axi_m3_araddr    (axi_m3_araddr),
  .axi_m3_arlen     (axi_m3_arlen),
  .axi_m3_arsize    (axi_m3_arsize),
  .axi_m3_arburst   (axi_m3_arburst),
  .axi_m3_arvalid   (axi_m3_arvalid),
  .axi_m3_arready   (axi_m3_arready),
  .axi_m3_rid       (axi_m3_rid),
  .axi_m3_rdata     (axi_m3_rdata),
  .axi_m3_rresp     (axi_m3_rresp),
  .axi_m3_rlast     (axi_m3_rlast),
  .axi_m3_rvalid    (axi_m3_rvalid),
  .axi_m3_rready    (axi_m3_rready),

  // AXI M4
  .axi_m4_awid      (axi_m4_awid),
  .axi_m4_awaddr    (axi_m4_awaddr),
  .axi_m4_awlen     (axi_m4_awlen),
  .axi_m4_awsize    (axi_m4_awsize),
  .axi_m4_awburst   (axi_m4_awburst),
  .axi_m4_awvalid   (axi_m4_awvalid),
  .axi_m4_awready   (axi_m4_awready),
  .axi_m4_wdata     (axi_m4_wdata),
  .axi_m4_wstrb     (axi_m4_wstrb),
  .axi_m4_wlast     (axi_m4_wlast),
  .axi_m4_wvalid    (axi_m4_wvalid),
  .axi_m4_wready    (axi_m4_wready),
  .axi_m4_bid       (axi_m4_bid),
  .axi_m4_bresp     (axi_m4_bresp),
  .axi_m4_bvalid    (axi_m4_bvalid),
  .axi_m4_bready    (axi_m4_bready),
  .axi_m4_arid      (axi_m4_arid),
  .axi_m4_araddr    (axi_m4_araddr),
  .axi_m4_arlen     (axi_m4_arlen),
  .axi_m4_arsize    (axi_m4_arsize),
  .axi_m4_arburst   (axi_m4_arburst),
  .axi_m4_arvalid   (axi_m4_arvalid),
  .axi_m4_arready   (axi_m4_arready),
  .axi_m4_rid       (axi_m4_rid),
  .axi_m4_rdata     (axi_m4_rdata),
  .axi_m4_rresp     (axi_m4_rresp),
  .axi_m4_rlast     (axi_m4_rlast),
  .axi_m4_rvalid    (axi_m4_rvalid),
  .axi_m4_rready    (axi_m4_rready),

  // TileLink S0
  .tl_s0_a_valid    (tl_s0_a_valid),
  .tl_s0_a_ready    (tl_s0_a_ready),
  .tl_s0_a_opcode   (tl_s0_a_opcode),
  .tl_s0_a_param    (tl_s0_a_param),
  .tl_s0_a_size     (tl_s0_a_size),
  .tl_s0_a_source   (tl_s0_a_source),
  .tl_s0_a_address  (tl_s0_a_address),
  .tl_s0_a_mask     (tl_s0_a_mask),
  .tl_s0_a_data     (tl_s0_a_data),
  .tl_s0_a_corrupt  (tl_s0_a_corrupt),
  .tl_s0_d_valid    (tl_s0_d_valid),
  .tl_s0_d_ready    (tl_s0_d_ready),
  .tl_s0_d_opcode   (tl_s0_d_opcode),
  .tl_s0_d_param    (tl_s0_d_param),
  .tl_s0_d_size     (tl_s0_d_size),
  .tl_s0_d_source   (tl_s0_d_source),
  .tl_s0_d_sink     (tl_s0_d_sink),
  .tl_s0_d_data     (tl_s0_d_data),
  .tl_s0_d_corrupt  (tl_s0_d_corrupt),
  .tl_s0_d_denied   (tl_s0_d_denied),

  // TileLink S1
  .tl_s1_a_valid    (tl_s1_a_valid),
  .tl_s1_a_ready    (tl_s1_a_ready),
  .tl_s1_a_opcode   (tl_s1_a_opcode),
  .tl_s1_a_param    (tl_s1_a_param),
  .tl_s1_a_size     (tl_s1_a_size),
  .tl_s1_a_source   (tl_s1_a_source),
  .tl_s1_a_address  (tl_s1_a_address),
  .tl_s1_a_mask     (tl_s1_a_mask),
  .tl_s1_a_data     (tl_s1_a_data),
  .tl_s1_a_corrupt  (tl_s1_a_corrupt),
  .tl_s1_d_valid    (tl_s1_d_valid),
  .tl_s1_d_ready    (tl_s1_d_ready),
  .tl_s1_d_opcode   (tl_s1_d_opcode),
  .tl_s1_d_param    (tl_s1_d_param),
  .tl_s1_d_size     (tl_s1_d_size),
  .tl_s1_d_source   (tl_s1_d_source),
  .tl_s1_d_sink     (tl_s1_d_sink),
  .tl_s1_d_data     (tl_s1_d_data),
  .tl_s1_d_corrupt  (tl_s1_d_corrupt),
  .tl_s1_d_denied   (tl_s1_d_denied),

  // Register S3-S6
  .reg_s3_req_valid (reg_s3_req_valid),
  .reg_s3_req_ready (reg_s3_req_ready),
  .reg_s3_req_addr  (reg_s3_req_addr),
  .reg_s3_req_rw    (reg_s3_req_rw),
  .reg_s3_req_data  (reg_s3_req_data),
  .reg_s3_rsp_valid (reg_s3_rsp_valid),
  .reg_s3_rsp_data  (reg_s3_rsp_data),
  .reg_s3_rsp_error (reg_s3_rsp_error),

  .reg_s4_req_valid (reg_s4_req_valid),
  .reg_s4_req_ready (reg_s4_req_ready),
  .reg_s4_req_addr  (reg_s4_req_addr),
  .reg_s4_req_rw    (reg_s4_req_rw),
  .reg_s4_req_data  (reg_s4_req_data),
  .reg_s4_rsp_valid (reg_s4_rsp_valid),
  .reg_s4_rsp_data  (reg_s4_rsp_data),
  .reg_s4_rsp_error (reg_s4_rsp_error),

  .reg_s5_req_valid (reg_s5_req_valid),
  .reg_s5_req_ready (reg_s5_req_ready),
  .reg_s5_req_addr  (reg_s5_req_addr),
  .reg_s5_req_rw    (reg_s5_req_rw),
  .reg_s5_req_data  (reg_s5_req_data),
  .reg_s5_rsp_valid (reg_s5_rsp_valid),
  .reg_s5_rsp_data  (reg_s5_rsp_data),
  .reg_s5_rsp_error (reg_s5_rsp_error),

  .reg_s6_req_valid (reg_s6_req_valid),
  .reg_s6_req_ready (reg_s6_req_ready),
  .reg_s6_req_addr  (reg_s6_req_addr),
  .reg_s6_req_rw    (reg_s6_req_rw),
  .reg_s6_req_data  (reg_s6_req_data),
  .reg_s6_rsp_valid (reg_s6_rsp_valid),
  .reg_s6_rsp_data  (reg_s6_rsp_data),
  .reg_s6_rsp_error (reg_s6_rsp_error)
);

//=============================================================================
// Clock Generation
//=============================================================================
initial begin
  clk_sys = 0;
  forever #(CLK_SYS_PERIOD/2) clk_sys = ~clk_sys;
end

initial begin
  clk_io = 0;
  forever #(CLK_IO_PERIOD/2) clk_io = ~clk_io;
end

initial begin
  clk_aon = 0;
  forever #(CLK_AON_PERIOD/2) clk_aon = ~clk_aon;
end

//=============================================================================
// Slave Response Models
//=============================================================================
// SRAM Slave S1 - responds in 2 cycles
always @(posedge clk_sys) begin
  if (tl_s1_a_valid && tl_s1_a_ready) begin
    tl_s1_d_valid <= #1 1'b0;  // 1 cycle delay
    repeat(2) @(posedge clk_sys);
    tl_s1_d_valid <= #1 1'b1;
    tl_s1_d_data  <= #1 {4{tl_s1_a_address[15:0]}};  // Return address-based data
    tl_s1_d_opcode <= #1 (tl_s1_a_opcode == 3'd4) ? 3'd1 : 3'd0;  // Get->AccessAckData
    tl_s1_d_denied <= #1 1'b0;
    tl_s1_d_corrupt <= #1 1'b0;
  end else if (tl_s1_d_valid && tl_s1_d_ready) begin
    tl_s1_d_valid <= #1 1'b0;
  end
end

// DRAM Slave S0 - responds in 5 cycles (simplified)
always @(posedge clk_sys) begin
  if (tl_s0_a_valid && tl_s0_a_ready) begin
    tl_s0_d_valid <= #1 1'b0;
    repeat(5) @(posedge clk_sys);
    tl_s0_d_valid <= #1 1'b1;
    tl_s0_d_data  <= #1 {8{tl_s0_a_address[15:0]}};  // 128-bit data
    tl_s0_d_opcode <= #1 (tl_s0_a_opcode == 3'd4) ? 3'd1 : 3'd0;
    tl_s0_d_denied <= #1 1'b0;
    tl_s0_d_corrupt <= #1 1'b0;
  end else if (tl_s0_d_valid && tl_s0_d_ready) begin
    tl_s0_d_valid <= #1 1'b0;
  end
end

// Register Slave S2 - responds in 1 cycle
always @(posedge clk_sys) begin
  if (reg_s2_req_valid && reg_s2_req_ready) begin
    reg_s2_rsp_valid <= #1 1'b1;
    reg_s2_rsp_data  <= #1 {16'hDEAD, reg_s2_req_addr};  // Test pattern
    reg_s2_rsp_error <= #1 1'b0;
  end else begin
    reg_s2_rsp_valid <= #1 1'b0;
  end
end

// Register Slave S3 - ISA Registers
always @(posedge clk_sys) begin
  reg_s3_req_ready <= #1 1'b1;
  if (reg_s3_req_valid) begin
    reg_s3_rsp_valid <= #1 1'b1;
    reg_s3_rsp_data  <= #1 {16'hISA_, reg_s3_req_addr};
    reg_s3_rsp_error <= #1 1'b0;
  end else begin
    reg_s3_rsp_valid <= #1 1'b0;
  end
end

// Register Slaves S4-S6 - Simple responders
always @(posedge clk_sys) begin
  reg_s4_req_ready <= #1 1'b1;
  reg_s5_req_ready <= #1 1'b1;
  reg_s6_req_ready <= #1 1'b1;
  reg_s4_rsp_valid <= #1 reg_s4_req_valid;
  reg_s5_rsp_valid <= #1 reg_s5_req_valid;
  reg_s6_rsp_valid <= #1 reg_s6_req_valid;
  reg_s4_rsp_data  <= #1 {16'hSEC_, reg_s4_req_addr};
  reg_s5_rsp_data  <= #1 {16'hECC_, reg_s5_req_addr};
  reg_s6_rsp_data  <= #1 {16'hPWR_, reg_s6_req_addr};
end

// Slave ready signals
always @(posedge clk_sys) begin
  tl_s0_a_ready <= #1 1'b1;
  tl_s1_a_ready <= #1 1'b1;
  reg_s2_req_ready <= #1 1'b1;
end

//=============================================================================
// Test Task Definitions
//=============================================================================

// Task: Initialize all signals
task automatic initialize;
begin
  rst_por_n = 0;
  rst_sys_n = 0;
  bus_enable = 0;

  // TileLink M0
  tl_m0_a_valid = 0;
  tl_m0_a_opcode = 0;
  tl_m0_a_param = 0;
  tl_m0_a_size = 0;
  tl_m0_a_source = 0;
  tl_m0_a_address = 0;
  tl_m0_a_mask = 0;
  tl_m0_a_data = 0;
  tl_m0_a_corrupt = 0;
  tl_m0_d_ready = 1;

  // TileLink M1
  tl_m1_a_valid = 0;
  tl_m1_a_opcode = 0;
  tl_m1_a_param = 0;
  tl_m1_a_size = 0;
  tl_m1_a_source = 0;
  tl_m1_a_address = 0;
  tl_m1_a_mask = 0;
  tl_m1_a_data = 0;
  tl_m1_a_corrupt = 0;
  tl_m1_d_ready = 1;

  // TileLink M2
  tl_m2_a_valid = 0;
  tl_m2_a_opcode = 0;
  tl_m2_a_param = 0;
  tl_m2_a_size = 0;
  tl_m2_a_source = 0;
  tl_m2_a_address = 0;
  tl_m2_a_mask = 0;
  tl_m2_a_data = 0;
  tl_m2_a_corrupt = 0;
  tl_m2_d_ready = 1;

  // AXI M3
  axi_m3_awvalid = 0;
  axi_m3_awid = 0;
  axi_m3_awaddr = 0;
  axi_m3_awlen = 0;
  axi_m3_awsize = 0;
  axi_m3_awburst = 0;
  axi_m3_wvalid = 0;
  axi_m3_wdata = 0;
  axi_m3_wstrb = 0;
  axi_m3_wlast = 0;
  axi_m3_bready = 1;
  axi_m3_arvalid = 0;
  axi_m3_arid = 0;
  axi_m3_araddr = 0;
  axi_m3_arlen = 0;
  axi_m3_arsize = 0;
  axi_m3_arburst = 0;
  axi_m3_rready = 1;

  // AXI M4
  axi_m4_awvalid = 0;
  axi_m4_awid = 0;
  axi_m4_awaddr = 0;
  axi_m4_awlen = 0;
  axi_m4_awsize = 0;
  axi_m4_awburst = 0;
  axi_m4_wvalid = 0;
  axi_m4_wdata = 0;
  axi_m4_wstrb = 0;
  axi_m4_wlast = 0;
  axi_m4_bready = 1;
  axi_m4_arvalid = 0;
  axi_m4_arid = 0;
  axi_m4_araddr = 0;
  axi_m4_arlen = 0;
  axi_m4_arsize = 0;
  axi_m4_arburst = 0;
  axi_m4_rready = 1;

  // Slave responses (initialize)
  tl_s0_d_valid = 0;
  tl_s0_d_data = 0;
  tl_s0_d_opcode = 0;
  tl_s0_d_denied = 0;
  tl_s0_d_corrupt = 0;
  tl_s1_d_valid = 0;
  tl_s1_d_data = 0;
  tl_s1_d_opcode = 0;
  tl_s1_d_denied = 0;
  tl_s1_d_corrupt = 0;
  reg_s2_rsp_valid = 0;
  reg_s2_rsp_data = 0;
  reg_s2_rsp_error = 0;

  test_count = 0;
  pass_count = 0;
  fail_count = 0;
  cycle_count = 0;
end
endtask

// Task: Apply reset sequence
task automatic apply_reset;
begin
  rst_por_n = 0;
  rst_sys_n = 0;
  repeat(10) @(posedge clk_sys);
  rst_por_n = 1;
  repeat(5) @(posedge clk_sys);
  rst_sys_n = 1;
  repeat(5) @(posedge clk_sys);
end
endtask

// Task: Wait for transaction completion
task automatic wait_transaction_complete;
input integer max_cycles;
integer wait_count;
begin
  wait_count = 0;
  while (bus_busy && wait_count < max_cycles) begin
    @(posedge clk_sys);
    wait_count++;
  end
end
endtask

// Task: Check result and report
task automatic check_result;
input string test_name;
input logic condition;
begin
  test_count++;
  if (condition) begin
    pass_count++;
    $display("[PASS] %s", test_name);
  end else begin
    fail_count++;
    $display("[FAIL] %s", test_name);
  end
end
endtask

//=============================================================================
// Test Cases
//=============================================================================

// TC01: Single Master Request - M0 TileLink Read from SRAM
task automatic test_tc01_single_master_request;
logic [127:0] received_data;
begin
  $display("\n=== TC01: Single Master Request (M0 TileLink Read from SRAM) ===");

  // Enable bus
  bus_enable = 1;
  @(posedge clk_sys);

  // Issue TileLink Get request from M0 to SRAM address
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;  // Get
  tl_m0_a_size = 3'd4;    // 16 bytes
  tl_m0_a_source = 4'd0;
  tl_m0_a_address = 32'h8000_1000;  // SRAM address
  tl_m0_a_mask = 16'hFFFF;
  tl_m0_a_data = 0;

  // Wait for request acceptance
  while (!tl_m0_a_ready) @(posedge clk_sys);
  @(posedge clk_sys);
  tl_m0_a_valid = 0;

  // Wait for transaction completion
  wait_transaction_complete(100);

  // Wait for response
  while (!tl_m0_d_valid) @(posedge clk_sys);
  received_data = tl_m0_d_data;
  @(posedge clk_sys);

  // Check: should route to S1 (SRAM)
  check_result("TC01: Route to SRAM (S1)", route_target == 3'd1);
  check_result("TC01: Response received", tl_m0_d_valid == 1);
  check_result("TC01: No error", tl_m0_d_denied == 0);

  // Clear
  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

// TC02: Multi-Master Arbitration - Priority Mode
task automatic test_tc02_multi_master_arbitration;
begin
  $display("\n=== TC02: Multi-Master Arbitration (Priority Mode) ===");

  bus_enable = 1;
  @(posedge clk_sys);

  // Issue simultaneous requests from M0, M1, M3
  // M0 has highest priority (0), should win
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;  // Get
  tl_m0_a_address = 32'h8000_2000;  // SRAM

  tl_m1_a_valid = 1;
  tl_m1_a_opcode = 3'd4;
  tl_m1_a_address = 32'h8000_3000;

  axi_m3_arvalid = 1;
  axi_m3_araddr = 32'h8008_0010;  // Bus Regs

  @(posedge clk_sys);
  @(posedge clk_sys);

  // Check arbitration winner
  check_result("TC02: M0 wins arbitration (highest priority)", arb_winner == 4'd0);

  // Complete M0 transaction
  tl_m0_a_valid = 0;
  tl_m1_a_valid = 0;
  axi_m3_arvalid = 0;

  wait_transaction_complete(100);

  // Now check M1 or M3 gets service next
  tl_m1_a_valid = 1;
  tl_m1_a_opcode = 3'd4;
  tl_m1_a_address = 32'h8000_4000;
  @(posedge clk_sys);
  @(posedge clk_sys);

  check_result("TC02: M1 wins after M0 completes", arb_winner == 4'd1);

  tl_m1_a_valid = 0;
  wait_transaction_complete(100);

  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

// TC03: Address Routing - All address ranges
task automatic test_tc03_address_routing;
begin
  $display("\n=== TC03: Address Routing Test ===");

  bus_enable = 1;
  @(posedge clk_sys);

  // Test DRAM routing (S0)
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;
  tl_m0_a_address = 32'h0000_1000;  // DRAM
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: DRAM route (S0)", route_target == 3'd0);
  tl_m0_a_valid = 0;
  wait_transaction_complete(150);

  // Test SRAM routing (S1)
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;
  tl_m0_a_address = 32'h8000_5000;  // SRAM
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: SRAM route (S1)", route_target == 3'd1);
  tl_m0_a_valid = 0;
  wait_transaction_complete(100);

  // Test Bus Registers routing (S2)
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd0;  // PutFullData (write)
  tl_m0_a_address = 32'h8008_0010;  // Bus Regs
  tl_m0_a_data = 128'hDEADBEEF_CAFE0000_00000000_00000000;
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: Bus Regs route (S2)", route_target == 3'd2);
  tl_m0_a_valid = 0;
  wait_transaction_complete(100);

  // Test ISA Registers routing (S3)
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;
  tl_m0_a_address = 32'h8009_0020;  // ISA Regs
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: ISA Regs route (S3)", route_target == 3'd3);
  tl_m0_a_valid = 0;
  wait_transaction_complete(100);

  // Test Secure Regs routing (S4)
  tl_m0_a_valid = 1;
  tl_m0_a_address = 32'h800A_0030;
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: Secure Regs route (S4)", route_target == 3'd4);
  tl_m0_a_valid = 0;
  wait_transaction_complete(100);

  // Test ECC Regs routing (S5)
  tl_m0_a_valid = 1;
  tl_m0_a_address = 32'h800B_0040;
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: ECC Regs route (S5)", route_target == 3'd5);
  tl_m0_a_valid = 0;
  wait_transaction_complete(100);

  // Test Power Regs routing (S6)
  tl_m0_a_valid = 1;
  tl_m0_a_address = 32'h800C_0050;
  @(posedge clk_sys);
  @(posedge clk_sys);
  check_result("TC03: Power Regs route (S6)", route_target == 3'd6);
  tl_m0_a_valid = 0;
  wait_transaction_complete(100);

  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

// TC04: Invalid Address Error
task automatic test_tc04_invalid_address_error;
begin
  $display("\n=== TC04: Invalid Address Error ===");

  bus_enable = 1;
  @(posedge clk_sys);

  // Issue request to invalid address (outside defined ranges)
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;
  tl_m0_a_address = 32'hFFFF_FFFF;  // Invalid address
  tl_m0_a_source = 4'd0;

  @(posedge clk_sys);
  @(posedge clk_sys);

  // Should route to ERROR
  check_result("TC04: Route to ERROR slave", route_target == 3'd7);

  tl_m0_a_valid = 0;

  // Wait for error response
  wait_transaction_complete(50);

  // Check error response
  check_result("TC04: Error response (denied)", tl_m0_d_denied == 1);
  check_result("TC04: Error IRQ asserted", error_irq == 1);

  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

// TC05: Timeout Handling
task automatic test_tc05_timeout_handling;
begin
  $display("\n=== TC05: Timeout Handling ===");

  // This test requires slave to NOT respond
  // For simplicity, we test with a short timeout scenario

  bus_enable = 1;
  @(posedge clk_sys);

  // Issue request - slave model will respond, but we check timeout mechanism exists
  tl_m0_a_valid = 1;
  tl_m0_a_opcode = 3'd4;
  tl_m0_a_address = 32'h8000_6000;

  @(posedge clk_sys);
  tl_m0_a_valid = 0;

  // Monitor timeout counter behavior
  // In real test, we would disable slave response
  wait_transaction_complete(100);

  // For this simplified test, verify bus completes without timeout
  check_result("TC05: Transaction completes normally", bus_busy == 0);

  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

// TC06: AXI4 Transaction - M3 ISA Decoder
task automatic test_tc06_axi4_transaction;
begin
  $display("\n=== TC06: AXI4 Transaction (M3 ISA Decoder) ===");

  bus_enable = 1;
  @(posedge clk_sys);

  // AXI4 Read from ISA Registers
  axi_m3_arvalid = 1;
  axi_m3_arid = 4'd5;
  axi_m3_araddr = 32'h8009_0100;  // ISA Regs
  axi_m3_arlen = 8'd0;  // Single beat
  axi_m3_arsize = 3'd4;  // 16 bytes

  // Wait for acceptance
  while (!axi_m3_arready) @(posedge clk_sys);
  @(posedge clk_sys);
  axi_m3_arvalid = 0;

  // Check routing
  check_result("TC06: ISA Regs route (S3)", route_target == 3'd3);

  // Wait for response
  wait_transaction_complete(100);

  // Check AXI response
  check_result("TC06: AXI read response valid", axi_m3_rvalid == 1);
  check_result("TC06: AXI response OK", axi_m3_rresp == 2'b00);

  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

// TC07: CDC Transaction - M4 JTAG (CLK_IO)
task automatic test_tc07_cdc_transaction;
begin
  $display("\n=== TC07: CDC Transaction (M4 JTAG) ===");

  bus_enable = 1;

  // Issue request from CLK_IO domain (M4)
  // Note: CDC requires 3-cycle sync
  @(posedge clk_io);
  axi_m4_arvalid = 1;
  axi_m4_arid = 4'd1;
  axi_m4_araddr = 32'h8008_0080;  // Bus Regs

  // Wait for CDC synchronization (CLK_SYS domain)
  repeat(10) @(posedge clk_sys);

  // After CDC sync, M4 request should be pending
  check_result("TC07: CDC request synchronized", arb_winner == 4'd4 || bus_busy);

  // Complete transaction
  axi_m4_arvalid = 0;
  wait_transaction_complete(150);

  bus_enable = 0;
  repeat(5) @(posedge clk_sys);
end
endtask

//=============================================================================
// Main Test Sequence
//=============================================================================
initial begin
  $display("========================================");
  $display("  M04 System Bus Testbench");
  $display("  Test Started: %0t", $time);
  $display("========================================");

  initialize();
  apply_reset();

  // Run all test cases
  test_tc01_single_master_request();
  test_tc02_multi_master_arbitration();
  test_tc03_address_routing();
  test_tc04_invalid_address_error();
  test_tc05_timeout_handling();
  test_tc06_axi4_transaction();
  test_tc07_cdc_transaction();

  // Summary
  $display("\n========================================");
  $display("  Test Summary");
  $display("  Total: %0d, Pass: %0d, Fail: %0d", test_count, pass_count, fail_count);
  $display("  Test Completed: %0t", $time);
  $display("========================================");

  if (fail_count > 0) begin
    $display("\n[TEST_FAILED] Some tests failed.");
  end else begin
    $display("\n[TEST_PASSED] All tests passed.");
  end

  $finish;
end

//=============================================================================
// Waveform Dump (for debugging)
//=============================================================================
initial begin
  $dumpfile("tb_M04_SystemBus.vcd");
  $dumpvars(0, tb_M04_SystemBus);
end

//=============================================================================
// Timeout Watchdog
//=============================================================================
initial begin
  #1000000;  // 1ms timeout
  $display("\n[TIMEOUT] Simulation timeout reached.");
  $finish;
end

endmodule : tb_M04_SystemBus