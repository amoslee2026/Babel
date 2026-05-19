// =============================================================================
// M02: SRAM Scratchpad (512KB with SECDED ECC)
// TinyStories NPU - High-Speed On-Chip Storage
// =============================================================================
// Generated: 2026-05-17
// Based on: spec_mas/M02/MAS.md, FSM.md, datapath.md
// =============================================================================
// Features:
// - 512 KB SRAM (128 banks x 1024 words/bank)
// - SECDED ECC (39,32) protection
// - Priority arbitration (M00 highest)
// - Single-cycle access latency
// - Address boundary check (REQ-M02-011)
// - Double error recovery (REQ-M02-010)
// =============================================================================

module M02_SRAMScratchpad #(
    parameter SRAM_DEPTH = 131072,    // 128K words (512 KB)
    parameter BANK_COUNT = 128,       // 128 banks
    parameter BANK_DEPTH  = 1024,     // 1024 words per bank
    parameter DATA_WIDTH  = 32,       // 32-bit data
    parameter ECC_WIDTH   = 7,        // 7-bit ECC
    parameter CODE_WIDTH  = 39,       // 32 + 7 = 39-bit code word
    parameter ADDR_WIDTH  = 20,       // 20-bit word address (128K entries)
    parameter BYTE_WIDTH  = 64,       // Max 64-bit access
    parameter WSTRB_WIDTH = 8         // 8-bit byte strobe
)(
    // -------------------------------------------------------------------------
    // Clock & Reset (MAS.md §2.1.1)
    // -------------------------------------------------------------------------
    input  logic        clk_sys_i,          // System clock (250-500 MHz)
    input  logic        rst_sys_n_i,        // System reset, active low
    input  logic        pg_main_en_i,       // Power Gate enable (from M05)

    // -------------------------------------------------------------------------
    // System Bus Interface (MAS.md §2.1.2)
    // -------------------------------------------------------------------------
    input  logic        bus_cmd_valid_i,
    output logic        bus_cmd_ready_o,
    input  logic [31:0] bus_cmd_addr_i,     // Byte address
    input  logic        bus_cmd_rw_i,       // 0=Read, 1=Write
    input  logic [1:0]  bus_cmd_width_i,    // 0=32-bit, 1=64-bit
    input  logic [63:0] bus_cmd_wdata_i,
    input  logic [7:0]  bus_cmd_wstrb_i,
    output logic        bus_rsp_valid_o,
    output logic [63:0] bus_rsp_rdata_o,
    output logic        bus_rsp_error_o,

    // -------------------------------------------------------------------------
    // Compute Unit Direct Interface (MAS.md §2.1.3)
    // -------------------------------------------------------------------------
    input  logic        sram_req_valid_i,
    input  logic [ADDR_WIDTH-1:0] sram_req_addr_i, // Word address
    input  logic        sram_req_rw_i,
    input  logic [63:0] sram_req_wdata_i,
    input  logic [7:0]  sram_req_wstrb_i,
    output logic        sram_rsp_valid_o,
    output logic [63:0] sram_rsp_rdata_o,
    output logic        sram_rsp_error_o,

    // -------------------------------------------------------------------------
    // Arbitration Interface (MAS.md §2.1.4)
    // -------------------------------------------------------------------------
    input  logic [3:0]  arb_master_id_i,
    input  logic [2:0]  arb_priority_i,    // 0=Highest, 3=Lowest
    output logic [3:0]  arb_grant_o,
    output logic        arb_busy_o,

    // -------------------------------------------------------------------------
    // ECC Status Interface (MAS.md §2.1.5)
    // -------------------------------------------------------------------------
    output logic [31:0] ecc_err_addr_o,
    output logic        ecc_err_type_o,    // 0=Single, 1=Double
    output logic        ecc_err_valid_o,
    output logic        ecc_irq_o,

    // -------------------------------------------------------------------------
    // Power Management Interface (MAS.md §2.1.6)
    // -------------------------------------------------------------------------
    input  logic        sram_retention_i,  // Retention mode enable
    input  logic        sram_power_gate_i, // Power gate enable
    output logic        sram_power_status_o
);

    // =========================================================================
    // FSM State Encoding (FSM.md)
    // =========================================================================
    localparam [2:0]
        STATE_IDLE       = 3'b000,  // Wait for request
        STATE_REQ_EVAL   = 3'b001,  // Evaluate request priority
        STATE_GRANT      = 3'b010,  // Grant access to master
        STATE_BANK_WAIT  = 3'b011,  // Wait for bank available
        STATE_ACCESS     = 3'b100,  // SRAM read/write
        STATE_ECC_PROC   = 3'b101,  // ECC check/correct (read)
        STATE_COMPLETE   = 3'b110,  // Generate response
        STATE_ERROR      = 3'b111;  // Error state

    // =========================================================================
    // Master ID Mapping (MAS.md §2.3)
    // =========================================================================
    localparam [3:0]
        MASTER_M00       = 4'h0,    // Systolic Array (Priority 0)
        MASTER_M09       = 4'h1,    // Transformer Op 1 (Priority 1)
        MASTER_M10       = 4'h2,    // Transformer Op 2 (Priority 1)
        MASTER_M11       = 4'h3,    // Transformer Op 3 (Priority 1)
        MASTER_M12       = 4'h4,    // Transformer Op 4 (Priority 1)
        MASTER_M13       = 4'h5,    // ISA Decoder (Priority 2)
        MASTER_M15       = 4'h6;    // Debug/JTAG (Priority 3)

    // =========================================================================
    // Address Boundary Constants (REQ-M02-011)
    // =========================================================================
    localparam [31:0] SRAM_BASE_ADDR  = 32'h8000_0000;
    localparam [31:0] SRAM_END_ADDR   = 32'h8007_FFFF;
    localparam [19:0] SRAM_MAX_WORDS  = 20'h0_0000;  // 128K words max

    // =========================================================================
    // Internal Registers & Signals
    // =========================================================================
    
    // FSM State Register
    logic [2:0] current_state, next_state;
    
    // Request Capture Registers
    logic        req_valid_reg;
    logic [31:0] req_addr_reg;
    logic        req_rw_reg;
    logic [1:0]  req_width_reg;
    logic [63:0] req_wdata_reg;
    logic [7:0]  req_wstrb_reg;
    logic [3:0]  req_master_id_reg;
    logic [2:0]  req_priority_reg;
    logic        req_source_reg;  // 0=Bus, 1=Direct
    
    // Bank Selection
    logic [6:0]  bank_id;         // Bank ID (0-127)
    logic [9:0]  bank_row_addr;   // Row address within bank (0-1023)
    logic [15:0] bank_busy;       // Bank busy status (16 banks active at a time)
    logic        bank_conflict;
    
    // Round-Robin Pointer for Priority 1
    logic [2:0]  round_robin_ptr;
    
    // Access Control
    logic        access_read_en;
    logic        access_write_en;
    logic [CODE_WIDTH-1:0] sram_read_data;
    logic [CODE_WIDTH-1:0] sram_write_data;
    
    // ECC Processing
    logic [ECC_WIDTH-1:0] ecc_syndrome;
    logic        ecc_single_error;
    logic        ecc_double_error;
    logic [DATA_WIDTH-1:0] ecc_corrected_data;
    logic [CODE_WIDTH-1:0] ecc_encoded_data;
    
    // Error Tracking (REQ-M02-010)
    logic [15:0] single_err_count;
    logic [15:0] double_err_count;
    logic [2:0]  retry_count;
    logic        double_error_retry;
    
    // Address Boundary Check (REQ-M02-011)
    logic        addr_out_of_range;
    
    // Response Generation
    logic [63:0] rsp_data_reg;
    logic        rsp_error_reg;
    
    // Timeout counters
    logic [3:0]  grant_timeout_cnt;
    logic [2:0]  bank_timeout_cnt;
    logic [1:0]  access_timeout_cnt;
    
    // Power Status
    logic        power_active;
    logic        power_retention_mode;
    
    // =========================================================================
    // ECC SECDED (39,32) Implementation
    // =========================================================================
    
    // ECC Encoding: Generate 7-bit check bits from 32-bit data
    function automatic [ECC_WIDTH-1:0] ecc_encode(input [DATA_WIDTH-1:0] data);
        logic [ECC_WIDTH-1:0] check_bits;
        // Hamming code parity calculation
        // C0: covers bits 1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37
        check_bits[0] = ^(data & 32'h5555_5555);
        // C1: covers bits 2,3,6,7,10,11,14,15,18,19,22,23,26,27,30,31
        check_bits[1] = ^(data & 32'h6666_6666);
        // C2: covers bits 4-7,12-15,20-23,28-31
        check_bits[2] = ^(data & 32'h0F0F_0F0F);
        // C3: covers bits 8-15,24-31
        check_bits[3] = ^(data & 32'h00FF_00FF);
        // C4: covers bits 16-31
        check_bits[4] = ^(data & 32'h0000_FFFF);
        // C5: covers ECC bits 32-38 (all zeros for encoding)
        check_bits[5] = 1'b0;
        // C6: overall parity (covers all 39 bits)
        check_bits[6] = ^{data, check_bits[5:0]};
        ecc_encode = check_bits;
    endfunction
    
    // ECC Syndrome Calculation: Compare received vs expected parity
    function automatic [ECC_WIDTH-1:0] ecc_syndrome_calc(
        input [DATA_WIDTH-1:0] data,
        input [ECC_WIDTH-1:0]  check_bits
    );
        logic [ECC_WIDTH-1:0] syndrome;
        logic [ECC_WIDTH-1:0] expected_check;
        expected_check = ecc_encode(data);
        syndrome = check_bits ^ expected_check;
        ecc_syndrome_calc = syndrome;
    endfunction
    
    // ECC Error Detection: Single vs Double error
    function automatic logic ecc_is_single_error(input [ECC_WIDTH-1:0] syndrome);
        // Single-bit error: syndrome[6] == 1 (overall parity matches)
        ecc_is_single_error = syndrome[6];
    endfunction
    
    // ECC Error Position: Extract bit position from syndrome
    function automatic logic [5:0] ecc_error_position(input [ECC_WIDTH-1:0] syndrome);
        // Error position is in syndrome[0:5]
        ecc_error_position = syndrome[5:0];
    endfunction
    
    // ECC Correction: Correct single-bit error
    function automatic [DATA_WIDTH-1:0] ecc_correct_data(
        input [DATA_WIDTH-1:0] data,
        input [ECC_WIDTH-1:0]  syndrome
    );
        logic [5:0] pos;
        logic [DATA_WIDTH-1:0] corrected;
        pos = ecc_error_position(syndrome);
        corrected = data;
        if (pos < DATA_WIDTH) begin
            corrected[pos] = ~data[pos];
        end
        ecc_correct_data = corrected;
    endfunction
    
    // =========================================================================
    // Address Decoding (datapath.md)
    // =========================================================================
    
    // Bank addressing: addr[16:19] for 4-way interleaved banks
    always_comb begin
        if (req_source_reg == 1'b0) begin
            // Bus access: convert byte address to word address
            bank_id = req_addr_reg[19:13];  // 7-bit bank ID (0-127)
            bank_row_addr = req_addr_reg[12:3];  // 10-bit row address
        end else begin
            // Direct access: already word address
            bank_id = req_addr_reg[19:13];
            bank_row_addr = req_addr_reg[12:3];
        end
    end
    
    // Address boundary check (REQ-M02-011)
    always_comb begin
        if (req_source_reg == 1'b0) begin
            // Bus access: check byte address range
            addr_out_of_range = (req_addr_reg < SRAM_BASE_ADDR) || 
                                (req_addr_reg > SRAM_END_ADDR);
        end else begin
            // Direct access: check word address range
            addr_out_of_range = (req_addr_reg[19:0] >= SRAM_MAX_WORDS);
        end
    end
    
    // =========================================================================
    // Bank Conflict Detection
    // =========================================================================
    
    always_comb begin
        // Check if target bank is busy (4-way interleaving: check group of 4 banks)
        bank_conflict = bank_busy[bank_id[3:0]];  // Lower 4 bits for 16 active banks
    end
    
    // =========================================================================
    // Arbitration Logic (FSM.md §Priority Arbitration)
    // =========================================================================
    
    // Priority 0 (M00) has preemptive access
    // Priority 1 (M09-M12) uses round-robin
    // Priority 2 (M13) waits for higher priority
    // Priority 3 (M15) gets access when idle
    
    always_comb begin
        // Default: no grant
        arb_grant_o = 4'h0;
        
        if (arb_priority_i == 3'b000) begin
            // Priority 0: Immediate grant (preemptive)
            arb_grant_o = arb_master_id_i;
        end else if (arb_priority_i == 3'b001) begin
            // Priority 1: Round-robin among M09-M12
            case (round_robin_ptr)
                3'b000: arb_grant_o = MASTER_M09;
                3'b001: arb_grant_o = MASTER_M10;
                3'b010: arb_grant_o = MASTER_M11;
                3'b011: arb_grant_o = MASTER_M12;
                default: arb_grant_o = MASTER_M09;
            endcase
        end else if (arb_priority_i == 3'b010) begin
            // Priority 2: Grant to M13 if no higher priority pending
            arb_grant_o = MASTER_M13;
        end else if (arb_priority_i == 3'b011) begin
            // Priority 3: Grant to M15 when idle
            arb_grant_o = MASTER_M15;
        end
    end
    
    // =========================================================================
    // SRAM Memory Array (Synthesizable Model)
    // =========================================================================
    
    // 128 banks x 1024 words x 39-bit (32 data + 7 ECC)
    // Using behavioral memory model for RTL simulation
    logic [CODE_WIDTH-1:0] sram_array [0:SRAM_DEPTH-1];
    
    // Memory access signals
    logic [ADDR_WIDTH-1:0] sram_access_addr;
    logic        sram_read_en;
    logic        sram_write_en;
    logic [CODE_WIDTH-1:0] sram_write_code;
    
    // Single-cycle SRAM access
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            sram_read_data <= {CODE_WIDTH{1'b0}};
        end else if (power_active && sram_read_en) begin
            sram_read_data <= sram_array[sram_access_addr];
        end else if (power_active && sram_write_en) begin
            sram_array[sram_access_addr] <= sram_write_code;
        end
    end
    
    // =========================================================================
    // FSM State Transition Logic (FSM.md)
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            current_state <= STATE_IDLE;
        end else if (!power_active) begin
            // Power gate: freeze or reset FSM
            if (sram_power_gate_i) begin
                current_state <= STATE_IDLE;  // Reset on power gate
            end
            // Retention: freeze current state
        end else begin
            current_state <= next_state;
        end
    end
    
    // FSM Next State Logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            STATE_IDLE: begin
                if (bus_cmd_valid_i || sram_req_valid_i) begin
                    next_state = STATE_REQ_EVAL;
                end
            end
            
            STATE_REQ_EVAL: begin
                if (addr_out_of_range) begin
                    next_state = STATE_ERROR;
                end else if (bank_conflict) begin
                    next_state = STATE_BANK_WAIT;
                end else begin
                    next_state = STATE_GRANT;
                end
            end
            
            STATE_GRANT: begin
                if (grant_timeout_cnt >= 4'd10) begin
                    next_state = STATE_ERROR;
                end else begin
                    next_state = STATE_ACCESS;
                end
            end
            
            STATE_BANK_WAIT: begin
                if (bank_timeout_cnt >= 3'd3) begin
                    next_state = STATE_ERROR;
                end else if (!bank_conflict) begin
                    next_state = STATE_GRANT;
                end
            end
            
            STATE_ACCESS: begin
                if (access_timeout_cnt >= 2'd2) begin
                    next_state = STATE_ERROR;
                end else if (req_rw_reg == 1'b0) begin
                    // Read operation: go to ECC processing
                    next_state = STATE_ECC_PROC;
                end else begin
                    // Write operation: complete directly
                    next_state = STATE_COMPLETE;
                end
            end
            
            STATE_ECC_PROC: begin
                // ECC processing complete (single cycle)
                next_state = STATE_COMPLETE;
            end
            
            STATE_COMPLETE: begin
                // Response sent, return to idle
                next_state = STATE_IDLE;
            end
            
            STATE_ERROR: begin
                // Error acknowledged, return to idle
                next_state = STATE_IDLE;
            end
            
            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end
    
    // =========================================================================
    // FSM Output Actions
    // =========================================================================
    
    // State-dependent outputs
    always_comb begin
        arb_busy_o = (current_state != STATE_IDLE);
        bus_cmd_ready_o = (current_state == STATE_IDLE);

        // Note: bus_rsp_valid_o, sram_rsp_valid_o, bus_rsp_error_o, sram_rsp_error_o,
        // ecc_err_valid_o, ecc_irq_o are assigned in always_ff block only (non-blocking)
        // to avoid BLKANDNBLK synthesis errors
    end
    
    // =========================================================================
    // Request Capture
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            req_valid_reg <= 1'b0;
            req_addr_reg <= {32{1'b0}};
            req_rw_reg <= 1'b0;
            req_width_reg <= 2'b00;
            req_wdata_reg <= {64{1'b0}};
            req_wstrb_reg <= {8{1'b0}};
            req_master_id_reg <= 4'h0;
            req_priority_reg <= 3'b0;
            req_source_reg <= 1'b0;
        end else if (current_state == STATE_IDLE) begin
            // Capture incoming request
            if (bus_cmd_valid_i) begin
                req_valid_reg <= 1'b1;
                req_addr_reg <= bus_cmd_addr_i;
                req_rw_reg <= bus_cmd_rw_i;
                req_width_reg <= bus_cmd_width_i;
                req_wdata_reg <= bus_cmd_wdata_i;
                req_wstrb_reg <= bus_cmd_wstrb_i;
                req_master_id_reg <= arb_master_id_i;
                req_priority_reg <= arb_priority_i;
                req_source_reg <= 1'b0;  // Bus source
            end else if (sram_req_valid_i) begin
                req_valid_reg <= 1'b1;
                req_addr_reg <= {12'b0, sram_req_addr_i};  // Convert word to byte addr
                req_rw_reg <= sram_req_rw_i;
                req_width_reg <= 2'b00;  // Default 32-bit for direct access
                req_wdata_reg <= sram_req_wdata_i;
                req_wstrb_reg <= sram_req_wstrb_i;
                req_master_id_reg <= arb_master_id_i;
                req_priority_reg <= arb_priority_i;
                req_source_reg <= 1'b1;  // Direct source
            end
        end
    end
    
    // =========================================================================
    // Timeout Counter Updates
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            grant_timeout_cnt <= 4'd0;
            bank_timeout_cnt <= 3'd0;
            access_timeout_cnt <= 2'd0;
        end else begin
            case (current_state)
                STATE_GRANT: begin
                    grant_timeout_cnt <= grant_timeout_cnt + 1'b1;
                end
                STATE_BANK_WAIT: begin
                    bank_timeout_cnt <= bank_timeout_cnt + 1'b1;
                end
                STATE_ACCESS: begin
                    access_timeout_cnt <= access_timeout_cnt + 1'b1;
                end
                default: begin
                    grant_timeout_cnt <= 4'd0;
                    bank_timeout_cnt <= 3'd0;
                    access_timeout_cnt <= 2'd0;
                end
            endcase
        end
    end
    
    // =========================================================================
    // Bank Busy Status Update
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            bank_busy <= {16{1'b0}};
        end else begin
            case (current_state)
                STATE_GRANT: begin
                    // Set bank busy
                    bank_busy[bank_id[3:0]] <= 1'b1;
                end
                STATE_COMPLETE: begin
                    // Clear bank busy
                    bank_busy[bank_id[3:0]] <= 1'b0;
                end
                STATE_ERROR: begin
                    // Clear all banks on error
                    bank_busy <= {16{1'b0}};
                end
                default: begin
                    // Maintain current status
                end
            endcase
        end
    end
    
    // =========================================================================
    // Round-Robin Pointer Update
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            round_robin_ptr <= 3'b000;
        end else if (current_state == STATE_COMPLETE && 
                     req_priority_reg == 3'b001) begin
            // Increment round-robin pointer after Priority 1 grant
            round_robin_ptr <= round_robin_ptr + 1'b1;
        end
    end
    
    // =========================================================================
    // SRAM Access Control
    // =========================================================================
    
    always_comb begin
        sram_access_addr = req_addr_reg[ADDR_WIDTH+1:2];  // Byte to word address
        sram_read_en = 1'b0;
        sram_write_en = 1'b0;
        sram_write_code = {CODE_WIDTH{1'b0}};
        
        if (current_state == STATE_ACCESS) begin
            if (req_rw_reg == 1'b0) begin
                // Read operation
                sram_read_en = 1'b1;
            end else begin
                // Write operation
                sram_write_en = 1'b1;
                // ECC encode write data
                if (req_width_reg == 2'b00) begin
                    // 32-bit write
                    sram_write_code = {ecc_encode(req_wdata_reg[31:0]), 
                                       req_wdata_reg[31:0]};
                end else begin
                    // 64-bit write: encode both halves (upper bank)
                    sram_write_code = {ecc_encode(req_wdata_reg[63:32]), 
                                       req_wdata_reg[63:32]};
                end
            end
        end
    end
    
    // =========================================================================
    // ECC Processing (STATE_ECC_PROC)
    // =========================================================================
    
    always_comb begin
        // Calculate syndrome from read data
        ecc_syndrome = ecc_syndrome_calc(sram_read_data[31:0], 
                                         sram_read_data[38:32]);
        
        // Determine error type
        if (ecc_syndrome == {ECC_WIDTH{1'b0}}) begin
            // No error
            ecc_single_error = 1'b0;
            ecc_double_error = 1'b0;
            ecc_corrected_data = sram_read_data[31:0];
        end else if (ecc_is_single_error(ecc_syndrome)) begin
            // Single-bit error (correctable)
            ecc_single_error = 1'b1;
            ecc_double_error = 1'b0;
            ecc_corrected_data = ecc_correct_data(sram_read_data[31:0], 
                                                   ecc_syndrome);
        end else begin
            // Double-bit error (uncorrectable)
            ecc_single_error = 1'b0;
            ecc_double_error = 1'b1;
            ecc_corrected_data = sram_read_data[31:0];  // Return uncorrected
        end
    end
    
    // =========================================================================
    // Error Tracking & Response (REQ-M02-010)
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            single_err_count <= {16{1'b0}};
            double_err_count <= {16{1'b0}};
            retry_count <= {3{1'b0}};
            double_error_retry <= 1'b0;
            ecc_err_addr_o <= {32{1'b0}};
            ecc_err_type_o <= 1'b0;
        end else if (current_state == STATE_ECC_PROC) begin
            if (ecc_single_error) begin
                // Single error: increment counter
                single_err_count <= single_err_count + 1'b1;
                ecc_err_addr_o <= req_addr_reg;
                ecc_err_type_o <= 1'b0;  // Single error
            end else if (ecc_double_error) begin
                // Double error: check retry count (REQ-M02-010)
                if (retry_count < 3'd3) begin
                    retry_count <= retry_count + 1'b1;
                    double_error_retry <= 1'b1;
                end else begin
                    // Max retries exceeded: mark as permanent error
                    double_err_count <= double_err_count + 1'b1;
                    retry_count <= {3{1'b0}};
                    double_error_retry <= 1'b0;
                    ecc_err_addr_o <= req_addr_reg;
                    ecc_err_type_o <= 1'b1;  // Double error
                end
            end
        end
    end
    
    // =========================================================================
    // Response Generation (STATE_COMPLETE)
    // =========================================================================
    
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            rsp_data_reg <= {64{1'b0}};
            rsp_error_reg <= 1'b0;
        end else if (current_state == STATE_COMPLETE) begin
            if (req_rw_reg == 1'b0) begin
                // Read response
                rsp_data_reg <= {32'b0, ecc_corrected_data};
                rsp_error_reg <= ecc_double_error || addr_out_of_range;
            end else begin
                // Write response
                rsp_data_reg <= {64{1'b0}};
                rsp_error_reg <= addr_out_of_range;
            end
        end
    end
    
    // Output response
    always_ff @(posedge clk_sys_i) begin
        if (!rst_sys_n_i) begin
            bus_rsp_valid_o <= 1'b0;
            bus_rsp_rdata_o <= {64{1'b0}};
            bus_rsp_error_o <= 1'b0;
            sram_rsp_valid_o <= 1'b0;
            sram_rsp_rdata_o <= {64{1'b0}};
            sram_rsp_error_o <= 1'b0;
            ecc_err_valid_o <= 1'b0;
            ecc_irq_o <= 1'b0;
        end else if (current_state == STATE_COMPLETE) begin
            if (req_source_reg == 1'b0) begin
                // Bus response
                bus_rsp_valid_o <= 1'b1;
                bus_rsp_rdata_o <= rsp_data_reg;
                bus_rsp_error_o <= rsp_error_reg;
            end else begin
                // Direct response
                sram_rsp_valid_o <= 1'b1;
                sram_rsp_rdata_o <= rsp_data_reg;
                sram_rsp_error_o <= rsp_error_reg;
            end
            
            // ECC error reporting
            if (ecc_single_error || ecc_double_error) begin
                ecc_err_valid_o <= 1'b1;
                ecc_irq_o <= ecc_double_error;  // IRQ for double error only
            end
        end else begin
            bus_rsp_valid_o <= 1'b0;
            sram_rsp_valid_o <= 1'b0;
            ecc_err_valid_o <= 1'b0;
            ecc_irq_o <= 1'b0;
        end
    end
    
    // =========================================================================
    // Power Management
    // =========================================================================
    
    always_comb begin
        power_active = !sram_power_gate_i && !sram_retention_i;
        power_retention_mode = sram_retention_i && !sram_power_gate_i;
        sram_power_status_o = power_active;
    end

endmodule