//=============================================================================
// Module: M04_SystemBus
// Type:   System Interconnect
// Description:
//   System Bus implementing TileLink-UH/AXI4 dual-protocol crossbar with
//   5 Masters (M00-M15) arbitration, address routing, and CDC synchronization.
//
// Masters:
//   M0 (tl_m0):  M00 Systolic Array - TileLink-UH, Priority 0 (Highest)
//   M1 (tl_m1):  M02 SRAM Scratchpad - TileLink-UH, Priority 2
//   M2 (tl_m2):  M03 DRAM Controller - TileLink-UH, Priority 2
//   M3 (axi_m3): M13 ISA Decoder - AXI4, Priority 1
//   M4 (axi_m4): M15 JTAG Interface - AXI4 (CLK_IO), Priority 3 (Lowest)
//
// Slaves:
//   S0 (tl_s0):  DRAM Controller - TileLink-UH (via M03)
//   S1 (tl_s1):  SRAM Scratchpad - TileLink-UH (via M02)
//   S2 (reg_s2): Bus Registers - Register Interface
//   S3 (reg_s3): ISA Decoder Registers
//   S4 (reg_s4): Secure Boot Registers
//   S5 (reg_s5): ECC Status Registers
//   S6 (reg_s6): Power Manager Registers (CLK_AON via CDC)
//
// Address Map:
//   0x0000_0000 - 0x7FFF_FFFF -> S0 (DRAM)
//   0x8000_0000 - 0x8007_FFFF -> S1 (SRAM)
//   0x8008_0000 - 0x8008_FFFF -> S2 (Bus Regs)
//   0x8009_0000 - 0x8009_FFFF -> S3 (ISA Regs)
//   0x800A_0000 - 0x800A_FFFF -> S4 (Secure Regs)
//   0x800B_0000 - 0x800B_FFFF -> S5 (ECC Regs)
//   0x800C_0000 - 0x800C_FFFF -> S6 (Power Regs)
//
// FSM States:
//   IDLE (3'b000): Wait for requests
//   ARB  (3'b001): Arbitrate among pending masters
//   ROUTE(3'b010): Decode address, select slave
//   XFER (3'b011): Transfer to slave, wait response
//   RESP (3'b100): Return response to master
//
// Reference: spec_mas/M04/MAS.md, FSM.md, datapath.md
//=============================================================================

module M04_SystemBus #(
  parameter DATA_WIDTH     = 128,
  parameter ADDR_WIDTH     = 32,
  parameter MASTER_COUNT   = 5,
  parameter SLAVE_COUNT    = 7,
  parameter TIMEOUT_DEFAULT = 1000,
  parameter CDC_SYNC_CYCLES = 3
)(
  // Clock & Reset
  input  logic                   clk_sys,      // System clock (250-500 MHz)
  input  logic                   clk_io,       // IO clock (50 MHz)
  input  logic                   clk_aon,      // Always-On clock (1 MHz)
  input  logic                   rst_por_n,    // Power-On Reset (async)
  input  logic                   rst_sys_n,    // System Reset (async)

  // Control & Status
  input  logic                   bus_enable,   // Bus enable from M05
  output logic                   bus_busy,     // Transaction in progress
  output logic                   bus_error,    // Error detected
  output logic [3:0]             arb_winner,   // Current arbitration winner ID
  output logic [2:0]             route_target, // Current routing target ID
  output logic                   timeout_irq,  // Timeout interrupt
  output logic                   error_irq,    // Error interrupt

  // Register Interface for Bus Registers (S2)
  output logic                   reg_s2_req_valid,
  input  logic                   reg_s2_req_ready,
  output logic [15:0]            reg_s2_req_addr,
  output logic                   reg_s2_req_rw,
  output logic [31:0]            reg_s2_req_data,
  input  logic                   reg_s2_rsp_valid,
  input  logic [31:0]            reg_s2_rsp_data,
  input  logic                   reg_s2_rsp_error,

  //---------------------------------------------------------------------------
  // TileLink-UH Master Ports (M0, M1, M2) - Channel A (Request)
  //---------------------------------------------------------------------------
  // M0: M00 Systolic Array (Highest Priority)
  input  logic                   tl_m0_a_valid,
  output logic                   tl_m0_a_ready,
  input  logic [2:0]             tl_m0_a_opcode,  // PutFullData=0, Get=4
  input  logic [2:0]             tl_m0_a_param,
  input  logic [2:0]             tl_m0_a_size,    // log2(bytes)
  input  logic [3:0]             tl_m0_a_source,  // Master ID
  input  logic [ADDR_WIDTH-1:0]  tl_m0_a_address,
  input  logic [DATA_WIDTH/8-1:0]tl_m0_a_mask,
  input  logic [DATA_WIDTH-1:0]  tl_m0_a_data,
  input  logic                   tl_m0_a_corrupt,
  // M0: Channel D (Response)
  output logic                   tl_m0_d_valid,
  input  logic                   tl_m0_d_ready,
  output logic [2:0]             tl_m0_d_opcode,  // AccessAck=0, AccessAckData=1
  output logic [1:0]             tl_m0_d_param,
  output logic [2:0]             tl_m0_d_size,
  output logic [3:0]             tl_m0_d_source,
  output logic [1:0]             tl_m0_d_sink,
  output logic [DATA_WIDTH-1:0]  tl_m0_d_data,
  output logic                   tl_m0_d_corrupt,
  output logic                   tl_m0_d_denied,

  // M1: M02 SRAM Scratchpad (Priority 2)
  input  logic                   tl_m1_a_valid,
  output logic                   tl_m1_a_ready,
  input  logic [2:0]             tl_m1_a_opcode,
  input  logic [2:0]             tl_m1_a_param,
  input  logic [2:0]             tl_m1_a_size,
  input  logic [3:0]             tl_m1_a_source,
  input  logic [ADDR_WIDTH-1:0]  tl_m1_a_address,
  input  logic [DATA_WIDTH/8-1:0]tl_m1_a_mask,
  input  logic [DATA_WIDTH-1:0]  tl_m1_a_data,
  input  logic                   tl_m1_a_corrupt,
  output logic                   tl_m1_d_valid,
  input  logic                   tl_m1_d_ready,
  output logic [2:0]             tl_m1_d_opcode,
  output logic [1:0]             tl_m1_d_param,
  output logic [2:0]             tl_m1_d_size,
  output logic [3:0]             tl_m1_d_source,
  output logic [1:0]             tl_m1_d_sink,
  output logic [DATA_WIDTH-1:0]  tl_m1_d_data,
  output logic                   tl_m1_d_corrupt,
  output logic                   tl_m1_d_denied,

  // M2: M03 DRAM Controller (Priority 2)
  input  logic                   tl_m2_a_valid,
  output logic                   tl_m2_a_ready,
  input  logic [2:0]             tl_m2_a_opcode,
  input  logic [2:0]             tl_m2_a_param,
  input  logic [2:0]             tl_m2_a_size,
  input  logic [3:0]             tl_m2_a_source,
  input  logic [ADDR_WIDTH-1:0]  tl_m2_a_address,
  input  logic [DATA_WIDTH/8-1:0]tl_m2_a_mask,
  input  logic [DATA_WIDTH-1:0]  tl_m2_a_data,
  input  logic                   tl_m2_a_corrupt,
  output logic                   tl_m2_d_valid,
  input  logic                   tl_m2_d_ready,
  output logic [2:0]             tl_m2_d_opcode,
  output logic [1:0]             tl_m2_d_param,
  output logic [2:0]             tl_m2_d_size,
  output logic [3:0]             tl_m2_d_source,
  output logic [1:0]             tl_m2_d_sink,
  output logic [DATA_WIDTH-1:0]  tl_m2_d_data,
  output logic                   tl_m2_d_corrupt,
  output logic                   tl_m2_d_denied,

  //---------------------------------------------------------------------------
  // AXI4 Master Ports (M3, M4)
  //---------------------------------------------------------------------------
  // M3: M13 ISA Decoder (Priority 1) - AXI4
  input  logic [3:0]             axi_m3_awid,
  input  logic [ADDR_WIDTH-1:0]  axi_m3_awaddr,
  input  logic [7:0]             axi_m3_awlen,
  input  logic [2:0]             axi_m3_awsize,
  input  logic [1:0]             axi_m3_awburst,
  input  logic                   axi_m3_awvalid,
  output logic                   axi_m3_awready,
  input  logic [DATA_WIDTH-1:0]  axi_m3_wdata,
  input  logic [DATA_WIDTH/8-1:0]axi_m3_wstrb,
  input  logic                   axi_m3_wlast,
  input  logic                   axi_m3_wvalid,
  output logic                   axi_m3_wready,
  output logic [3:0]             axi_m3_bid,
  output logic [1:0]             axi_m3_bresp,
  output logic                   axi_m3_bvalid,
  input  logic                   axi_m3_bready,
  input  logic [3:0]             axi_m3_arid,
  input  logic [ADDR_WIDTH-1:0]  axi_m3_araddr,
  input  logic [7:0]             axi_m3_arlen,
  input  logic [2:0]             axi_m3_arsize,
  input  logic [1:0]             axi_m3_arburst,
  input  logic                   axi_m3_arvalid,
  output logic                   axi_m3_arready,
  output logic [3:0]             axi_m3_rid,
  output logic [DATA_WIDTH-1:0]  axi_m3_rdata,
  output logic [1:0]             axi_m3_rresp,
  output logic                   axi_m3_rlast,
  output logic                   axi_m3_rvalid,
  input  logic                   axi_m3_rready,

  // M4: M15 JTAG Interface (Priority 3) - AXI4 (CLK_IO domain via CDC)
  input  logic [3:0]             axi_m4_awid,
  input  logic [ADDR_WIDTH-1:0]  axi_m4_awaddr,
  input  logic [7:0]             axi_m4_awlen,
  input  logic [2:0]             axi_m4_awsize,
  input  logic [1:0]             axi_m4_awburst,
  input  logic                   axi_m4_awvalid,
  output logic                   axi_m4_awready,
  input  logic [DATA_WIDTH-1:0]  axi_m4_wdata,
  input  logic [DATA_WIDTH/8-1:0]axi_m4_wstrb,
  input  logic                   axi_m4_wlast,
  input  logic                   axi_m4_wvalid,
  output logic                   axi_m4_wready,
  output logic [3:0]             axi_m4_bid,
  output logic [1:0]             axi_m4_bresp,
  output logic                   axi_m4_bvalid,
  input  logic                   axi_m4_bready,
  input  logic [3:0]             axi_m4_arid,
  input  logic [ADDR_WIDTH-1:0]  axi_m4_araddr,
  input  logic [7:0]             axi_m4_arlen,
  input  logic [2:0]             axi_m4_arsize,
  input  logic [1:0]             axi_m4_arburst,
  input  logic                   axi_m4_arvalid,
  output logic                   axi_m4_arready,
  output logic [3:0]             axi_m4_rid,
  output logic [DATA_WIDTH-1:0]  axi_m4_rdata,
  output logic [1:0]             axi_m4_rresp,
  output logic                   axi_m4_rlast,
  output logic                   axi_m4_rvalid,
  input  logic                   axi_m4_rready,

  //---------------------------------------------------------------------------
  // TileLink-UH Slave Ports (S0, S1)
  //---------------------------------------------------------------------------
  // S0: M03 DRAM Controller
  output logic                   tl_s0_a_valid,
  input  logic                   tl_s0_a_ready,
  output logic [2:0]             tl_s0_a_opcode,
  output logic [2:0]             tl_s0_a_param,
  output logic [2:0]             tl_s0_a_size,
  output logic [3:0]             tl_s0_a_source,
  output logic [ADDR_WIDTH-1:0]  tl_s0_a_address,
  output logic [DATA_WIDTH/8-1:0]tl_s0_a_mask,
  output logic [DATA_WIDTH-1:0]  tl_s0_a_data,
  output logic                   tl_s0_a_corrupt,
  input  logic                   tl_s0_d_valid,
  output logic                   tl_s0_d_ready,
  input  logic [2:0]             tl_s0_d_opcode,
  input  logic [1:0]             tl_s0_d_param,
  input  logic [2:0]             tl_s0_d_size,
  input  logic [3:0]             tl_s0_d_source,
  input  logic [1:0]             tl_s0_d_sink,
  input  logic [DATA_WIDTH-1:0]  tl_s0_d_data,
  input  logic                   tl_s0_d_corrupt,
  input  logic                   tl_s0_d_denied,

  // S1: M02 SRAM Scratchpad
  output logic                   tl_s1_a_valid,
  input  logic                   tl_s1_a_ready,
  output logic [2:0]             tl_s1_a_opcode,
  output logic [2:0]             tl_s1_a_param,
  output logic [2:0]             tl_s1_a_size,
  output logic [3:0]             tl_s1_a_source,
  output logic [ADDR_WIDTH-1:0]  tl_s1_a_address,
  output logic [DATA_WIDTH/8-1:0]tl_s1_a_mask,
  output logic [DATA_WIDTH-1:0]  tl_s1_a_data,
  output logic                   tl_s1_a_corrupt,
  input  logic                   tl_s1_d_valid,
  output logic                   tl_s1_d_ready,
  input  logic [2:0]             tl_s1_d_opcode,
  input  logic [1:0]             tl_s1_d_param,
  input  logic [2:0]             tl_s1_d_size,
  input  logic [3:0]             tl_s1_d_source,
  input  logic [1:0]             tl_s1_d_sink,
  input  logic [DATA_WIDTH-1:0]  tl_s1_d_data,
  input  logic                   tl_s1_d_corrupt,
  input  logic                   tl_s1_d_denied,

  //---------------------------------------------------------------------------
  // Register Slave Ports (S3-S6)
  //---------------------------------------------------------------------------
  // S3: M13 ISA Decoder Registers
  output logic                   reg_s3_req_valid,
  input  logic                   reg_s3_req_ready,
  output logic [15:0]            reg_s3_req_addr,
  output logic                   reg_s3_req_rw,
  output logic [31:0]            reg_s3_req_data,
  input  logic                   reg_s3_rsp_valid,
  input  logic [31:0]            reg_s3_rsp_data,
  input  logic                   reg_s3_rsp_error,

  // S4: M14 Secure Boot Registers
  output logic                   reg_s4_req_valid,
  input  logic                   reg_s4_req_ready,
  output logic [15:0]            reg_s4_req_addr,
  output logic                   reg_s4_req_rw,
  output logic [31:0]            reg_s4_req_data,
  input  logic                   reg_s4_rsp_valid,
  input  logic [31:0]            reg_s4_rsp_data,
  input  logic                   reg_s4_rsp_error,

  // S5: M02/M03 ECC Status Registers
  output logic                   reg_s5_req_valid,
  input  logic                   reg_s5_req_ready,
  output logic [15:0]            reg_s5_req_addr,
  output logic                   reg_s5_req_rw,
  output logic [31:0]            reg_s5_req_data,
  input  logic                   reg_s5_rsp_valid,
  input  logic [31:0]            reg_s5_rsp_data,
  input  logic                   reg_s5_rsp_error,

  // S6: M05 Power Manager Registers (CLK_AON domain)
  output logic                   reg_s6_req_valid,
  input  logic                   reg_s6_req_ready,
  output logic [15:0]            reg_s6_req_addr,
  output logic                   reg_s6_req_rw,
  output logic [31:0]            reg_s6_req_data,
  input  logic                   reg_s6_rsp_valid,
  input  logic [31:0]            reg_s6_rsp_data,
  input  logic                   reg_s6_rsp_error
);

//=============================================================================
// FSM State Definitions
//=============================================================================
localparam [2:0] FSM_IDLE  = 3'b000;
localparam [2:0] FSM_ARB   = 3'b001;
localparam [2:0] FSM_ROUTE = 3'b010;
localparam [2:0] FSM_XFER  = 3'b011;
localparam [2:0] FSM_RESP  = 3'b100;

// Slave IDs
localparam [2:0] SLAVE_S0_DRAM   = 3'd0;
localparam [2:0] SLAVE_S1_SRAM   = 3'd1;
localparam [2:0] SLAVE_S2_BUSREG = 3'd2;
localparam [2:0] SLAVE_S3_ISAREG = 3'd3;
localparam [2:0] SLAVE_S4_SECURE = 3'd4;
localparam [2:0] SLAVE_S5_ECC    = 3'd5;
localparam [2:0] SLAVE_S6_POWER  = 3'd6;
localparam [2:0] SLAVE_ERROR     = 3'd7;

// TileLink Opcodes
localparam [2:0] TL_PUT_FULL_DATA = 3'd0;
localparam [2:0] TL_PUT_PARTIAL   = 3'd1;
localparam [2:0] TL_GET           = 3'd4;
localparam [2:0] TL_ACCESS_ACK    = 3'd0;
localparam [2:0] TL_ACCESS_ACK_DATA = 3'd1;

// Error Types
localparam [7:0] ERR_ADDR_INVALID = 8'd1;
localparam [7:0] ERR_TIMEOUT      = 8'd2;
localparam [7:0] ERR_SLAVE_ERROR  = 8'd3;

//=============================================================================
// Internal Registers
//=============================================================================
logic [2:0]       fsm_state, fsm_next;
logic [4:0]       pending_status;      // Bit per master: requests pending
logic [3:0]       current_master;      // Winner master ID
logic [2:0]       current_slave;       // Target slave ID
logic [3:0]       last_winner;         // For Round-Robin

// Captured Transaction
logic [2:0]       captured_opcode;
logic [ADDR_WIDTH-1:0] captured_address;
logic [DATA_WIDTH-1:0] captured_data;
logic [DATA_WIDTH/8-1:0] captured_mask;
logic [3:0]       captured_source;
logic             captured_is_write;
logic             captured_is_axi;     // Protocol flag
logic [3:0]       captured_axi_id;
logic [7:0]       captured_axi_len;

// Timeout Counter
logic [15:0]      timeout_counter;
logic [15:0]      timeout_threshold;
logic             timeout_event;

// Response Capture
logic [DATA_WIDTH-1:0] response_data;
logic             response_denied;
logic             response_corrupt;
logic             response_error;
logic [2:0]       response_opcode;

// Performance Counter
logic [31:0]      perf_counter;
logic [31:0]      latency_acc;
logic [31:0]      transaction_start_time;

// CDC Sync Registers (simplified 3-cycle sync)
logic             cdc_m4_req_sync [0:2];
logic             cdc_m4_rsp_sync [0:2];
logic             cdc_m4_awvalid_synced;
logic             cdc_m4_arvalid_synced;

//=============================================================================
// Request Pending Detection
//=============================================================================
logic m0_req_pending = tl_m0_a_valid;
logic m1_req_pending = tl_m1_a_valid;
logic m2_req_pending = tl_m2_a_valid;
logic m3_req_pending = axi_m3_awvalid | axi_m3_arvalid;
logic m4_req_pending_raw = axi_m4_awvalid | axi_m4_arvalid;

// CDC synchronization for M4 (CLK_IO -> CLK_SYS)
always_ff @(posedge clk_sys or negedge rst_por_n) begin
  if (!rst_por_n) begin
    cdc_m4_req_sync[0] <= '0;
    cdc_m4_req_sync[1] <= '0;
    cdc_m4_req_sync[2] <= '0;
    cdc_m4_awvalid_synced <= '0;
    cdc_m4_arvalid_synced <= '0;
  end else begin
    cdc_m4_req_sync[0] <= axi_m4_awvalid | axi_m4_arvalid;
    cdc_m4_req_sync[1] <= cdc_m4_req_sync[0];
    cdc_m4_req_sync[2] <= cdc_m4_req_sync[1];
    cdc_m4_awvalid_synced <= cdc_m4_req_sync[2];
  end
end

logic m4_req_pending = cdc_m4_awvalid_synced;

logic any_req_pending = m0_req_pending | m1_req_pending | m2_req_pending |
                         m3_req_pending | m4_req_pending;

//=============================================================================
// Priority Arbitration Logic
//=============================================================================
// Default Priority: M0=0(highest), M3=1, M1=2, M2=2, M4=3(lowest)
// Higher priority value means lower priority (inverted for easier comparison)
logic [3:0] master_priority [0:4];
assign master_priority[0] = 4'd0;  // Highest
assign master_priority[1] = 4'd2;
assign master_priority[2] = 4'd2;
assign master_priority[3] = 4'd1;
assign master_priority[4] = 4'd3;  // Lowest

// Priority-based winner selection
logic [3:0] arb_winner_selected;
always_comb begin
  arb_winner_selected = 4'd0;
  // Check pending requests, select highest priority (lowest value)
  if (m0_req_pending) arb_winner_selected = 4'd0;
  else if (m3_req_pending) arb_winner_selected = 4'd3;
  else if (m1_req_pending) arb_winner_selected = 4'd1;
  else if (m2_req_pending) arb_winner_selected = 4'd2;
  else if (m4_req_pending) arb_winner_selected = 4'd4;
end

//=============================================================================
// Address Decode Logic
//=============================================================================
logic [2:0] decoded_slave;
logic       addr_valid;

always_comb begin
  decoded_slave = SLAVE_S0_DRAM;
  addr_valid = 1'b1;

  // Address decode based on MAS.md spec
  case (captured_address[31:29])
    3'b00: decoded_slave = SLAVE_S0_DRAM;  // 0x0000_0000 - 0x7FFF_FFFF
    3'b10: begin  // Register space 0x8000_0000+
      case (captured_address[28:16])
        13'h000: decoded_slave = SLAVE_S1_SRAM;   // 0x8000_0000
        13'h008: decoded_slave = SLAVE_S2_BUSREG; // 0x8008_0000
        13'h009: decoded_slave = SLAVE_S3_ISAREG; // 0x8009_0000
        13'h00A: decoded_slave = SLAVE_S4_SECURE; // 0x800A_0000
        13'h00B: decoded_slave = SLAVE_S5_ECC;    // 0x800B_0000
        13'h00C: decoded_slave = SLAVE_S6_POWER;  // 0x800C_0000
        default: begin
          decoded_slave = SLAVE_ERROR;
          addr_valid = 1'b0;
        end
      endcase
    end
    default: begin
      decoded_slave = SLAVE_ERROR;
      addr_valid = 1'b0;
    end
  endcase
end

//=============================================================================
// Request Capture (MUX based on winner)
//=============================================================================
always_comb begin
  // Default values
  captured_opcode     = tl_m0_a_opcode;
  captured_address    = tl_m0_a_address;
  captured_data       = tl_m0_a_data;
  captured_mask       = tl_m0_a_mask;
  captured_source     = tl_m0_a_source;
  captured_is_write   = (tl_m0_a_opcode == TL_PUT_FULL_DATA) ||
                        (tl_m0_a_opcode == TL_PUT_PARTIAL);
  captured_is_axi     = 1'b0;
  captured_axi_id     = 4'd0;
  captured_axi_len    = 8'd0;

  case (current_master)
    4'd0: begin // M0: TileLink
      captured_opcode   = tl_m0_a_opcode;
      captured_address  = tl_m0_a_address;
      captured_data     = tl_m0_a_data;
      captured_mask     = tl_m0_a_mask;
      captured_source   = tl_m0_a_source;
      captured_is_write = (tl_m0_a_opcode == TL_PUT_FULL_DATA);
      captured_is_axi   = 1'b0;
    end
    4'd1: begin // M1: TileLink
      captured_opcode   = tl_m1_a_opcode;
      captured_address  = tl_m1_a_address;
      captured_data     = tl_m1_a_data;
      captured_mask     = tl_m1_a_mask;
      captured_source   = tl_m1_a_source;
      captured_is_write = (tl_m1_a_opcode == TL_PUT_FULL_DATA);
      captured_is_axi   = 1'b0;
    end
    4'd2: begin // M2: TileLink
      captured_opcode   = tl_m2_a_opcode;
      captured_address  = tl_m2_a_address;
      captured_data     = tl_m2_a_data;
      captured_mask     = tl_m2_a_mask;
      captured_source   = tl_m2_a_source;
      captured_is_write = (tl_m2_a_opcode == TL_PUT_FULL_DATA);
      captured_is_axi   = 1'b0;
    end
    4'd3: begin // M3: AXI4
      if (axi_m3_awvalid) begin // Write
        captured_opcode   = TL_PUT_FULL_DATA;
        captured_address  = axi_m3_awaddr;
        captured_data     = axi_m3_wdata;
        captured_mask     = axi_m3_wstrb;
        captured_source   = axi_m3_awid;
        captured_is_write = 1'b1;
        captured_axi_id   = axi_m3_awid;
        captured_axi_len  = axi_m3_awlen;
      end else begin // Read
        captured_opcode   = TL_GET;
        captured_address  = axi_m3_araddr;
        captured_data     = '0;
        captured_mask     = '1;
        captured_source   = axi_m3_arid;
        captured_is_write = 1'b0;
        captured_axi_id   = axi_m3_arid;
        captured_axi_len  = axi_m3_arlen;
      end
      captured_is_axi   = 1'b1;
    end
    4'd4: begin // M4: AXI4 (CDC synced)
      // Simplified: use synced signals
      captured_opcode   = TL_GET;  // Default read
      captured_address  = axi_m4_araddr;
      captured_data     = '0;
      captured_mask     = '1;
      captured_source   = axi_m4_arid;
      captured_is_write = 1'b0;
      captured_is_axi   = 1'b1;
      captured_axi_id   = axi_m4_arid;
      captured_axi_len  = axi_m4_arlen;
    end
    default: begin
      // Keep default values
    end
  endcase
end

//=============================================================================
// FSM State Transition
//=============================================================================
always_ff @(posedge clk_sys or negedge rst_por_n) begin
  if (!rst_por_n) begin
    fsm_state <= FSM_IDLE;
    pending_status <= '0;
    current_master <= '0;
    current_slave <= '0;
    last_winner <= '0;
    timeout_counter <= '0;
    timeout_threshold <= TIMEOUT_DEFAULT[15:0];
    perf_counter <= '0;
    latency_acc <= '0;
    transaction_start_time <= '0;
  end else if (!rst_sys_n) begin
    fsm_state <= FSM_IDLE;
    pending_status <= '0;
  end else if (bus_enable) begin
    fsm_state <= fsm_next;

    // FSM state actions
    case (fsm_state)
      FSM_IDLE: begin
        pending_status <= {m4_req_pending, m3_req_pending,
                           m2_req_pending, m1_req_pending, m0_req_pending};
      end
      FSM_ARB: begin
        current_master <= arb_winner_selected;
        last_winner <= arb_winner_selected;
        transaction_start_time <= '0; // Could use cycle counter
      end
      FSM_ROUTE: begin
        current_slave <= decoded_slave;
        timeout_counter <= '0;
      end
      FSM_XFER: begin
        timeout_counter <= timeout_counter + 1'b1;
        if (timeout_counter >= timeout_threshold) begin
          timeout_event <= 1'b1;
        end
      end
      FSM_RESP: begin
        perf_counter <= perf_counter + 1'b1;
        timeout_event <= 1'b0;
        pending_status[current_master] <= 1'b0;
      end
    endcase
  end
end

//=============================================================================
// FSM Next State Logic
//=============================================================================
always_comb begin
  fsm_next = FSM_IDLE;

  case (fsm_state)
    FSM_IDLE: begin
      if (any_req_pending && bus_enable)
        fsm_next = FSM_ARB;
      else
        fsm_next = FSM_IDLE;
    end
    FSM_ARB: begin
      fsm_next = FSM_ROUTE;  // Always proceed after arbitration
    end
    FSM_ROUTE: begin
      if (addr_valid)
        fsm_next = FSM_XFER;
      else
        fsm_next = FSM_RESP;  // Invalid address -> error response
    end
    FSM_XFER: begin
      // Check for slave response or timeout
      case (current_slave)
        SLAVE_S0_DRAM:   fsm_next = (tl_s0_d_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        SLAVE_S1_SRAM:   fsm_next = (tl_s1_d_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        SLAVE_S2_BUSREG: fsm_next = (reg_s2_rsp_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        SLAVE_S3_ISAREG: fsm_next = (reg_s3_rsp_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        SLAVE_S4_SECURE: fsm_next = (reg_s4_rsp_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        SLAVE_S5_ECC:    fsm_next = (reg_s5_rsp_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        SLAVE_S6_POWER:  fsm_next = (reg_s6_rsp_valid | timeout_event) ? FSM_RESP : FSM_XFER;
        default:         fsm_next = FSM_RESP;  // Error case
      endcase
    end
    FSM_RESP: begin
      fsm_next = FSM_IDLE;  // Always return to IDLE after response
    end
    default: fsm_next = FSM_IDLE;
  endcase
end

//=============================================================================
// Slave Interface Driving (Output Mux)
//=============================================================================
// Default: all slave valid signals = 0
always_comb begin
  // TileLink Slave S0 (DRAM)
  tl_s0_a_valid   = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S0_DRAM);
  tl_s0_a_opcode  = captured_opcode;
  tl_s0_a_param   = '0;
  tl_s0_a_size    = 3'd4;  // 16 bytes = 128 bits
  tl_s0_a_source  = captured_source;
  tl_s0_a_address = captured_address;
  tl_s0_a_mask    = captured_mask;
  tl_s0_a_data    = captured_data;
  tl_s0_a_corrupt = 1'b0;
  tl_s0_d_ready   = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S0_DRAM);

  // TileLink Slave S1 (SRAM)
  tl_s1_a_valid   = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S1_SRAM);
  tl_s1_a_opcode  = captured_opcode;
  tl_s1_a_param   = '0;
  tl_s1_a_size    = 3'd4;
  tl_s1_a_source  = captured_source;
  tl_s1_a_address = captured_address;
  tl_s1_a_mask    = captured_mask;
  tl_s1_a_data    = captured_data;
  tl_s1_a_corrupt = 1'b0;
  tl_s1_d_ready   = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S1_SRAM);

  // Register Slave S2 (Bus Registers)
  reg_s2_req_valid = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S2_BUSREG);
  reg_s2_req_addr  = captured_address[15:0];
  reg_s2_req_rw    = captured_is_write;
  reg_s2_req_data  = captured_data[31:0];

  // Register Slave S3 (ISA Registers)
  reg_s3_req_valid = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S3_ISAREG);
  reg_s3_req_addr  = captured_address[15:0];
  reg_s3_req_rw    = captured_is_write;
  reg_s3_req_data  = captured_data[31:0];

  // Register Slave S4 (Secure Registers)
  reg_s4_req_valid = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S4_SECURE);
  reg_s4_req_addr  = captured_address[15:0];
  reg_s4_req_rw    = captured_is_write;
  reg_s4_req_data  = captured_data[31:0];

  // Register Slave S5 (ECC Registers)
  reg_s5_req_valid = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S5_ECC);
  reg_s5_req_addr  = captured_address[15:0];
  reg_s5_req_rw    = captured_is_write;
  reg_s5_req_data  = captured_data[31:0];

  // Register Slave S6 (Power Registers)
  reg_s6_req_valid = (fsm_state == FSM_XFER) && (current_slave == SLAVE_S6_POWER);
  reg_s6_req_addr  = captured_address[15:0];
  reg_s6_req_rw    = captured_is_write;
  reg_s6_req_data  = captured_data[31:0];
end

//=============================================================================
// Response Capture (Slave Response Mux)
//=============================================================================
always_comb begin
  response_data   = '0;
  response_denied = 1'b0;
  response_corrupt = 1'b0;
  response_error  = 1'b0;
  response_opcode = TL_ACCESS_ACK;

  case (current_slave)
    SLAVE_S0_DRAM: begin
      response_data    = tl_s0_d_data;
      response_denied  = tl_s0_d_denied;
      response_corrupt = tl_s0_d_corrupt;
      response_opcode  = tl_s0_d_opcode;
    end
    SLAVE_S1_SRAM: begin
      response_data    = tl_s1_d_data;
      response_denied  = tl_s1_d_denied;
      response_corrupt = tl_s1_d_corrupt;
      response_opcode  = tl_s1_d_opcode;
    end
    SLAVE_S2_BUSREG: begin
      response_data[31:0] = reg_s2_rsp_data;
      response_error      = reg_s2_rsp_error;
      response_opcode     = captured_is_write ? TL_ACCESS_ACK : TL_ACCESS_ACK_DATA;
    end
    SLAVE_S3_ISAREG: begin
      response_data[31:0] = reg_s3_rsp_data;
      response_error      = reg_s3_rsp_error;
      response_opcode     = captured_is_write ? TL_ACCESS_ACK : TL_ACCESS_ACK_DATA;
    end
    SLAVE_S4_SECURE: begin
      response_data[31:0] = reg_s4_rsp_data;
      response_error      = reg_s4_rsp_error;
      response_opcode     = captured_is_write ? TL_ACCESS_ACK : TL_ACCESS_ACK_DATA;
    end
    SLAVE_S5_ECC: begin
      response_data[31:0] = reg_s5_rsp_data;
      response_error      = reg_s5_rsp_error;
      response_opcode     = captured_is_write ? TL_ACCESS_ACK : TL_ACCESS_ACK_DATA;
    end
    SLAVE_S6_POWER: begin
      response_data[31:0] = reg_s6_rsp_data;
      response_error      = reg_s6_rsp_error;
      response_opcode     = captured_is_write ? TL_ACCESS_ACK : TL_ACCESS_ACK_DATA;
    end
    SLAVE_ERROR: begin
      response_denied  = 1'b1;
      response_opcode  = TL_ACCESS_ACK;
    end
    default: begin
      response_denied = 1'b1;
    end
  endcase

  // Timeout override
  if (timeout_event) begin
    response_corrupt = 1'b1;
    response_opcode  = TL_ACCESS_ACK;
  end
end

//=============================================================================
// Master Response Driving
//=============================================================================
always_comb begin
  // TileLink Master M0 Response
  tl_m0_d_valid   = (fsm_state == FSM_RESP) && (current_master == 4'd0);
  tl_m0_d_opcode  = response_opcode;
  tl_m0_d_param   = '0;
  tl_m0_d_size    = 3'd4;
  tl_m0_d_source  = captured_source;
  tl_m0_d_sink    = '0;
  tl_m0_d_data    = response_data;
  tl_m0_d_corrupt = response_corrupt;
  tl_m0_d_denied  = response_denied;

  // TileLink Master M1 Response
  tl_m1_d_valid   = (fsm_state == FSM_RESP) && (current_master == 4'd1);
  tl_m1_d_opcode  = response_opcode;
  tl_m1_d_param   = '0;
  tl_m1_d_size    = 3'd4;
  tl_m1_d_source  = captured_source;
  tl_m1_d_sink    = '0;
  tl_m1_d_data    = response_data;
  tl_m1_d_corrupt = response_corrupt;
  tl_m1_d_denied  = response_denied;

  // TileLink Master M2 Response
  tl_m2_d_valid   = (fsm_state == FSM_RESP) && (current_master == 4'd2);
  tl_m2_d_opcode  = response_opcode;
  tl_m2_d_param   = '0;
  tl_m2_d_size    = 3'd4;
  tl_m2_d_source  = captured_source;
  tl_m2_d_sink    = '0;
  tl_m2_d_data    = response_data;
  tl_m2_d_corrupt = response_corrupt;
  tl_m2_d_denied  = response_denied;

  // AXI Master M3 Response
  axi_m3_awready  = (fsm_state == FSM_ARB) && (arb_winner_selected == 4'd3) && axi_m3_awvalid;
  axi_m3_wready   = (fsm_state == FSM_XFER) && (current_master == 4'd3) && captured_is_write;
  axi_m3_arready  = (fsm_state == FSM_ARB) && (arb_winner_selected == 4'd3) && axi_m3_arvalid;
  axi_m3_bid      = captured_axi_id;
  axi_m3_bresp    = response_denied ? 2'b10 : 2'b00;  // OKAY or SLVERR
  axi_m3_bvalid   = (fsm_state == FSM_RESP) && (current_master == 4'd3) && captured_is_write;
  axi_m3_rid      = captured_axi_id;
  axi_m3_rdata    = response_data;
  axi_m3_rresp    = response_denied ? 2'b10 : 2'b00;
  axi_m3_rlast    = 1'b1;
  axi_m3_rvalid   = (fsm_state == FSM_RESP) && (current_master == 4'd3) && !captured_is_write;

  // AXI Master M4 Response (CDC synced back)
  axi_m4_awready  = '0;  // Simplified: CDC required
  axi_m4_wready   = '0;
  axi_m4_arready  = '0;
  axi_m4_bid      = captured_axi_id;
  axi_m4_bresp    = response_denied ? 2'b10 : 2'b00;
  axi_m4_bvalid   = (fsm_state == FSM_RESP) && (current_master == 4'd4) && captured_is_write;
  axi_m4_rid      = captured_axi_id;
  axi_m4_rdata    = response_data;
  axi_m4_rresp    = response_denied ? 2'b10 : 2'b00;
  axi_m4_rlast    = 1'b1;
  axi_m4_rvalid   = (fsm_state == FSM_RESP) && (current_master == 4'd4) && !captured_is_write;

  // Master Ready signals (accept requests when IDLE or ARB)
  tl_m0_a_ready = (fsm_state == FSM_IDLE) || (fsm_state == FSM_ARB && arb_winner_selected == 4'd0);
  tl_m1_a_ready = (fsm_state == FSM_IDLE) || (fsm_state == FSM_ARB && arb_winner_selected == 4'd1);
  tl_m2_a_ready = (fsm_state == FSM_IDLE) || (fsm_state == FSM_ARB && arb_winner_selected == 4'd2);
end

//=============================================================================
// Status Output
//=============================================================================
assign bus_busy     = (fsm_state != FSM_IDLE);
assign bus_error    = response_denied | response_corrupt | response_error | timeout_event;
assign arb_winner   = current_master;
assign route_target = current_slave;
assign timeout_irq  = timeout_event;
assign error_irq    = bus_error;

//=============================================================================
// Assertions (for verification)
//=============================================================================
// pragma translate_off
`ifdef FORMAL
  // FSM should always be in valid state
  assert property (@(posedge clk_sys) disable iff (!rst_por_n)
    fsm_state inside {FSM_IDLE, FSM_ARB, FSM_ROUTE, FSM_XFER, FSM_RESP});

  // Only one master can win arbitration
  assert property (@(posedge clk_sys) disable iff (!rst_por_n)
    (fsm_state == FSM_ARB) |-> (arb_winner_selected < 5));

  // Address should be valid for non-error slaves
  assert property (@(posedge clk_sys) disable iff (!rst_por_n)
    (fsm_state == FSM_ROUTE && addr_valid) |-> (decoded_slave < 7));
`endif
// pragma translate_on

endmodule : M04_SystemBus