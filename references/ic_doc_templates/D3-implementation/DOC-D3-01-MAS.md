---
doc_id: DOC-D3-01-MAS
doc_type: MAS
title: Micro Architecture Specification (per IP Block)
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: IP Designer
approvers: [Chief Architect, Verification Lead]
parent: DOC-D2-01-ARCH
children: [DOC-D3-02-IPXACT, DOC-D6-01-VPLAN]
references: [IEEE 1685 IP-XACT, IEEE 1800 SystemVerilog, IEEE 1801 UPF, AMBA AXI/CHI, UCIe 2.0]
generated: 2026-04-23T22:45:00+08:00
---

# Micro Architecture Specification — {{ Block Name }}

> **实例化命名**: `DOC-D3-01-MAS-<BLOCK>`（例：`DOC-D3-01-MAS-D2DCTRL`, `DOC-D3-01-MAS-HBM3PHY`）

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Designer }} | Initial |

**Freeze Point**: RTL v1.0. Post-freeze changes require MAS CR.

---

## 1. Block Overview

- **Block Name**: {{ e.g., D2D Link Controller }}
- **Purpose** (1–2 句): {{ ... }}
- **Target frequency**: {{ 1.5 GHz }} @ TT/1.0V/25°C
- **Estimated area**: {{ 0.5 mm² @ N5 }}
- **Estimated power**: {{ 50 mW typical, 120 mW peak }}
- **Parent die**: {{ CCD0 / IOD / ... }}

## 2. Top-Level Interface Table

| Port | Direction | Width | Clock Domain | Type | Description |
|---|---|---|---|---|---|
| clk | IN | 1 | — | — | Primary clock |
| rstn | IN | 1 | clk (async assert, sync deassert) | — | Active-low reset |
| axi_aw_*  | IN | (AXI bundle) | clk | Sync | Config AXI write address |
| axi_w_* | IN | (AXI bundle) | clk | Sync | Config AXI write data |
| ... | | | | | |
| ucie_tx_lane[63:0] | OUT | 64 | clk_d2d | Source-sync | UCIe TX data lanes |
| ucie_rx_lane[63:0] | IN | 64 | clk_d2d | Source-sync | UCIe RX data lanes |
| irq | OUT | 1 | clk | Sync | Error / event interrupt |

## 3. Clock Domains

| Domain | Frequency | Source | Usage |
|---|---|---|---|
| clk | 1.5 GHz | Local PLL | Control + datapath |
| clk_d2d | 16 GHz (½ rate) | D2D source-sync | UCIe PHY interface |
| clk_mgmt | 100 MHz | Always-on | Sideband / debug |

### 3.1 CDC Paths

| From | To | Synchronizer | Cycles |
|---|---|---|---|
| clk_d2d → clk | 2-FF for control; async FIFO for data | FIFO depth 16 | - |
| clk_mgmt → clk | 2-FF | - | - |

## 4. Power & Reset Domains (UPF)

```tcl
create_power_domain PD_core -elements {u_dp u_ctrl}
create_power_domain PD_d2d -elements {u_ucie_phy}
# Isolation cells between PD_core and PD_d2d
set_isolation ...
```

- **Reset Strategy**: Async assert, sync deassert
- **Reset ordering**: clk_mgmt first → core → D2D

## 5. Functional Block Diagram

```
                ┌─────────────┐
  AXI cfg ────► │  CSR block  │◄───┐
                └──────┬──────┘    │
                       │           │
                ┌──────▼──────┐    │
                │  Control FSM│────┘
                │   (LTSM)    │
                └──────┬──────┘
                       │
  ┌───────────────────┼───────────────────┐
  ▼                   ▼                   ▼
┌───────────┐   ┌─────────────┐   ┌─────────────┐
│ TX pipe   │   │ Credit mgmt │   │ RX pipe     │
│ (Flit gen)│   │ & Arbiter   │   │ (Flit parse)│
└──────┬────┘   └─────────────┘   └──────┬──────┘
       │                                  │
       ▼                                  ▼
   ucie_tx_lane                      ucie_rx_lane
```

## 6. Datapath

### 6.1 TX Path
- Pipeline depth: {{ 5 stages }}
- Stages: CSR read → Flit gen → CRC → Retry buffer → Serializer → PHY
- Backpressure: credit-based, stalls at Flit gen

### 6.2 RX Path
- Pipeline depth: {{ 6 stages }}
- Stages: PHY → Deserializer → CRC check → Retry ack → Flit parse → Dispatcher

### 6.3 Key Arithmetic
- CRC: CRC-16-CCITT on full flit
- Scrambling: UCIe 2.0 scrambler

## 7. Control FSM

### 7.1 LTSM (Link Training State Machine)

```
    ┌─────────┐
    │ RESET   │
    └────┬────┘
         │ power_on
         ▼
    ┌─────────┐  lane_error  ┌──────────┐
    │ DETECT  │──────────────►│ DETECT_Q │
    └────┬────┘               └────┬─────┘
         │ detect_ok               │
         ▼                         │
    ┌─────────┐                    │
    │ TRAINING│◄───────────────────┘
    └────┬────┘
         │ train_done
         ▼
    ┌─────────┐  error    ┌──────────┐
    │   L0    │───────────►│  RETRAIN │
    └────┬────┘           └────┬──────┘
         │ link_down            │ ok
         └──────────────────────┘
```

- State encoding: 4-bit one-hot
- Timeout watchdog per state: {{ N }} μs

### 7.2 Transitions Table

| From | To | Condition | Output |
|---|---|---|---|
| RESET | DETECT | power_on && rstn | detect_start=1 |
| DETECT | TRAINING | detect_ok | — |
| TRAINING | L0 | train_done && crc_ok | link_up=1 |
| L0 | RETRAIN | persistent_err | — |
| ... | | | |

## 8. Register Map

| Name | Offset | Width | Access | Reset | Description |
|---|---|---|---|---|---|
| CTRL | 0x000 | 32 | RW | 0x00 | Master control |
| STATUS | 0x004 | 32 | RO | 0x00 | Link status (LTSM state, flags) |
| LINK_UP | 0x008 | 1 | RO | 0x0 | Link operational |
| CRC_ERR_CNT | 0x010 | 32 | RC | 0x00 | CRC error count (read-clear) |
| RETRY_CNT | 0x014 | 32 | RC | 0x00 | Retry count |
| INT_EN | 0x020 | 32 | RW | 0x00 | Interrupt enable mask |
| INT_STATUS | 0x024 | 32 | W1C | 0x00 | Interrupt status (write-1-clear) |
| ECC_SYNDROME | 0x030 | 16 | RO | 0x00 | Last ECC syndrome |
| LANE_MARGIN | 0x100 | 64 × N | RW | 0x00 | Per-lane margin calibration |

### 8.1 CTRL Register Bit Definition

| Bit | Name | Access | Reset | Description |
|---|---|---|---|---|
| 0 | LINK_EN | RW | 0 | Enable link training |
| 1 | LOOPBACK | RW | 0 | Loopback test mode |
| 2 | RETRY_DIS | RW | 0 | Disable retry (for debug) |
| 31:3 | Reserved | RO | 0 | - |

## 9. Timing Diagrams

### 9.1 AXI Config Write

```
CLK      ┐_┌─┐_┌─┐_┌─┐_┌─┐_┌─┐_┌─
AWVALID  │_│█│█│_│_│_│_│_│_│_│_│
AWREADY  │_│_│█│_│_│_│_│_│_│_│_│
WVALID   │_│_│█│█│_│_│_│_│_│_│_│
WREADY   │_│_│_│█│_│_│_│_│_│_│_│
BVALID   │_│_│_│_│_│_│█│_│_│_│_│
BREADY   │_│_│_│_│_│_│█│_│_│_│_│
```

- Setup time: 200 ps typ
- Hold time: 100 ps typ

### 9.2 UCIe Flit Transmission
（给出完整的 flit 发送波形，含 preamble、header、payload、CRC）

## 10. Chiplet-Specific Sections

### 10.1 D2D Link Controller (LTSM)
（如上）

### 10.2 Multi-Die Debug Hooks
- IJTAG instruments: {{ scan chains, BIST runners }}
- Cross-die trace: {{ VC3 used for debug }}
- Breakpoint signaling to IOD: sideband bit {{ N }}

### 10.3 RAS Integration
- ECC coverage: datapath registers (+SEC-DED), retry buffer (+parity)
- Error injection: `ERR_INJ` register @ 0x040
- Error upload path: syndrome → IOD MCA handler

### 10.4 Thermal / Power Management
- Per-lane DVFS: coupled to IOD-wide thermal budget
- Clock gating: at flit gen stage when idle > 8 cycles

## 11. Operating Modes
| Mode | Trigger | Behavior |
|---|---|---|
| Normal | Default | Full BW, retry enabled |
| Loopback | CTRL.LOOPBACK=1 | TX→RX internal, for BIST |
| Retrain | LTSM internal | Relink after persistent err |
| Power-save | Idle timeout | Gate clk_d2d |
| Debug | Sideband command | Dump state + counters |

## 12. Error Handling

| Error | Detection | Logged in | Action |
|---|---|---|---|
| Single-bit lane | FEC | ECC_SYNDROME | Corrected, counter inc |
| CRC fail | Link layer | CRC_ERR_CNT | Retry (hw) |
| Retry exhausted | Link layer | INT_STATUS[0] | IRQ, SW recovery |
| Lane unrecoverable | PHY | INT_STATUS[1] | Retrain; if fail, link down |
| Watchdog timeout | FSM | INT_STATUS[2] | IRQ, dump state |

## 13. Initialization Sequence

```
1. Apply power, assert rstn (async)
2. Wait clk stable
3. Deassert rstn (sync to clk)
4. SW writes CTRL.LINK_EN = 1
5. FSM enters DETECT → TRAINING
6. On train_done, STATUS.LINK_UP = 1, IRQ asserted
7. SW reads STATUS to confirm
```

## 14. Quality Checklist

- [ ] 所有 port 与 RTL 头文件匹配（自动脚本验证）
- [ ] 所有寄存器有 IEEE 1685 IP-XACT 描述 (→ DOC-D3-02-IPXACT)
- [ ] FSM 所有状态可达（formal proof）
- [ ] 所有 CDC 路径有同步器规范
- [ ] 时序图标注具体 setup/hold (ps)
- [ ] Chiplet 特有章节齐全（D2D / Debug / RAS / Thermal）
- [ ] UVM sequence 可从时序图直接推导
- [ ] 与 Arch Spec RTM 覆盖 100%
- [ ] 所有寄存器位有复位值
- [ ] Reserved bit = RO, Reset = 0
- [ ] 无歧义语言（无 "should" / "might"）

## 15. Traceability

| ARCH Section | MAS Section |
|---|---|
| DOC-D2-01-ARCH §9 (D2D) | §§2, 7, 10.1 |
| DOC-D2-05-DIC §3.1 | §§7, 8, 12 |

## 16. References
- UCIe Spec 2.0
- IEEE 1685 IP-XACT
- AMBA AXI / CHI
