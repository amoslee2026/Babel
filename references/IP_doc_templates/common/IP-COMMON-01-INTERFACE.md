---
ip_id: IP-COMMON-01-INTERFACE
ip_type: common
ip_class: interface
title: IP Interface Specification Template
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: TBD
parent_doc: IP-COMP-02-MAS / IP-MEM-02-MAS
derived_from: []
references: [AMBA AXI5, AMBA CHI, UCIe 2.0, TL-UL]
generated: 2026-04-23T23:00:00+08:00
---

# IP 接口规范模板

## 0. Document Control

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. 接口概述

- **IP名称**: {{ IP_NAME }}
- **接口类型**: {{ 接口类型列表 }}
- **总线协议**: {{ AXI4/AXI5/CHI/TL-UL/APB/UCIe }}

---

## 2. 总线接口

### 2.1 AXI4/AXI5 接口

#### 信号列表

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| awid | OUT | {{ N }} | Write address ID |
| awaddr | OUT | {{ WIDTH }} | Write address |
| awlen | OUT | 8 | Burst length |
| awsize | OUT | 3 | Transfer size |
| awburst | OUT | 2 | Burst type |
| awvalid | OUT | 1 | Write address valid |
| awready | IN | 1 | Write address ready |
| wdata | OUT | {{ WIDTH }} | Write data |
| wstrb | OUT | {{ WIDTH/8 }} | Write strobe |
| wlast | OUT | 1 | Last transfer |
| wvalid | OUT | 1 | Write data valid |
| wready | IN | 1 | Write data ready |
| bid | IN | {{ N }} | Write response ID |
| bresp | IN | 2 | Write response |
| bvalid | IN | 1 | Write response valid |
| bready | OUT | 1 | Write response ready |
| arid | OUT | {{ N }} | Read address ID |
| araddr | OUT | {{ WIDTH }} | Read address |
| arlen | OUT | 8 | Burst length |
| arsize | OUT | 3 | Transfer size |
| arburst | OUT | 2 | Burst type |
| arvalid | OUT | 1 | Read address valid |
| arready | IN | 1 | Read address ready |
| rid | IN | {{ N }} | Read ID |
| rdata | IN | {{ WIDTH }} | Read data |
| rresp | IN | 2 | Read response |
| rlast | IN | 1 | Last transfer |
| rvalid | IN | 1 | Read data valid |
| rready | OUT | 1 | Read data ready |

#### 时序图

```wavejson
{
  signal: [
    {name: 'clk', wave: 'p........'},
    {name: 'awvalid', wave: '01.0.....'},
    {name: 'awready', wave: '0.1......'},
    {name: 'wvalid', wave: '01.0.....'},
    {name: 'wready', wave: '0.1......'},
    {name: 'bvalid', wave: '0..10....'},
    {name: 'bready', wave: '1........'},
  ],
  head: {text: 'AXI Write Transaction'}
}
```

### 2.2 AXI-Lite 接口

#### 信号列表

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| awaddr | OUT | {{ WIDTH }} | Write address |
| awvalid | OUT | 1 | Write address valid |
| awready | IN | 1 | Write address ready |
| wdata | OUT | {{ WIDTH }} | Write data |
| wstrb | OUT | {{ WIDTH/8 }} | Write strobe |
| wvalid | OUT | 1 | Write data valid |
| wready | IN | 1 | Write data ready |
| bresp | IN | 2 | Write response |
| bvalid | IN | 1 | Write response valid |
| bready | OUT | 1 | Write response ready |
| araddr | OUT | {{ WIDTH }} | Read address |
| arvalid | OUT | 1 | Read address valid |
| arready | IN | 1 | Read address ready |
| rdata | IN | {{ WIDTH }} | Read data |
| rresp | IN | 2 | Read response |
| rvalid | IN | 1 | Read data valid |
| rready | OUT | 1 | Read data ready |

### 2.3 APB4 接口

#### 信号列表

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| pclk | IN | 1 | Clock |
| presetn | IN | 1 | Reset |
| paddr | OUT | {{ WIDTH }} | Address |
| pprot | OUT | 3 | Protection type |
| psel | OUT | 1 | Select |
| penable | OUT | 1 | Enable |
| pwrite | OUT | 1 | Write enable |
| pwdata | OUT | {{ WIDTH }} | Write data |
| pstrb | OUT | {{ WIDTH/8 }} | Write strobe |
| pready | IN | 1 | Ready |
| prdata | IN | {{ WIDTH }} | Read data |
| pslverr | IN | 1 | Slave error |

### 2.4 TL-UL (TileLink Uncached Lightweight) 接口

#### 信号列表

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| a_valid | OUT | 1 | Request valid |
| a_opcode | OUT | 3 | Operation code |
| a_param | OUT | 3 | Parameter |
| a_size | OUT | 3 | Size log2 |
| a_source | OUT | {{ N }} | Source ID |
| a_address | OUT | {{ WIDTH }} | Address |
| a_mask | OUT | {{ WIDTH/8 }} | Byte mask |
| a_data | OUT | {{ WIDTH }} | Data |
| a_ready | IN | 1 | Request ready |
| d_valid | IN | 1 | Response valid |
| d_opcode | IN | 3 | Response opcode |
| d_param | IN | 2 | Response parameter |
| d_size | IN | 3 | Size log2 |
| d_source | IN | {{ N }} | Source ID |
| d_sink | IN | {{ N }} | Sink ID |
| d_data | IN | {{ WIDTH }} | Data |
| d_error | IN | 1 | Error flag |
| d_ready | OUT | 1 | Response ready |

---

## 3. Chiplet 接口（如适用）

### 3.1 UCIe 接口

#### 信号列表（高层抽象）

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| ucie_tx_data | OUT | {{ N }} | TX数据 |
| ucie_tx_valid | OUT | 1 | TX有效 |
| ucie_rx_data | IN | {{ N }} | RX数据 |
| ucie_rx_valid | IN | 1 | RX有效 |
| link_up | OUT | 1 | Link状态 |
| {{ SIGNAL }} | {{ DIR }} | {{ WIDTH }} | {{ FUNC }} |

#### 参数

| 参数 | 值 |
|------|---|
| 速率 | {{ N }} GT/s |
| Lane数 | {{ N }} |
| 协议 | PCIe / CXL / Streaming |

### 3.2 CHI (Coherent Hub Interface) 接口

#### 信号列表（高层抽象）

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| txreqflit | OUT | {{ N }} | TX Request flit |
| txrspflit | OUT | {{ N }} | TX Response flit |
| txdatflit | OUT | {{ N }} | TX Data flit |
| rxreqflit | IN | {{ N }} | RX Request flit |
| rxrspflit | IN | {{ N }} | RX Response flit |
| rxdatflit | IN | {{ N }} | RX Data flit |

---

## 4. 时钟与复位接口

### 4.1 时钟接口

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| clk | IN | 1 | 主时钟 |
| {{ CLK_DOMAIN }} | IN | 1 | {{ 功能描述 }} |

### 4.2 复位接口

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| rst_n | IN | 1 | 异步复位，低有效 |
| {{ RST_SIGNAL }} | IN | {{ WIDTH }} | {{ 功能描述 }} |

---

## 5. 中断接口

### 5.1 中断信号

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| irq | OUT | 1 | 中断请求 |
| irq_ack | IN | 1 | 中断响应（可选）|
| {{ IRQ_SIGNAL }} | OUT | {{ WIDTH }} | {{ 功能描述 }} |

---

## 6. 测试接口

### 6.1 JTAG 接口

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| tck | IN | 1 | Test clock |
| tms | IN | 1 | Test mode select |
| tdi | IN | 1 | Test data in |
| tdo | OUT | 1 | Test data out |
| trst_n | IN | 1 | Test reset |

### 6.2 Scan 接口

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| scan_enable | IN | 1 | Scan enable |
| scan_in | IN | {{ N }} | Scan input |
| scan_out | OUT | {{ N }} | Scan output |

---

## 7. 时序参数

### 7.1 输入时序

| 信号 | Setup Time | Hold Time |
|------|------------|-----------|
| {{ SIGNAL }} | {{ N }} ps | {{ N }} ps |

### 7.2 输出时序

| 信号 | Valid Delay | Output Impedance |
|------|-------------|------------------|
| {{ SIGNAL }} | {{ N }} ps | {{ N }} Ω |

---

## 8. Quality Checklist

- [ ] 所有总线接口定义完整
- [ ] 所有信号位宽明确
- [ ] 时序图完整
- [ ] 时序参数明确
- [ ] Chiplet接口定义（如适用）
- [ ] 中断接口定义
- [ ] 测试接口定义