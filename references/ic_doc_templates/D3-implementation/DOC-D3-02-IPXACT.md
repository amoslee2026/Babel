---
doc_id: DOC-D3-02-IPXACT
doc_type: IPXACT
title: IP-XACT Metadata Bundle (IEEE 1685)
version: 0.1-template
status: template
tier: 0
domain: Implementation
owner: IP Integration Lead
approvers: [Chief Architect, IP Owners]
parent: [DOC-D2-01-ARCH, DOC-D3-01-MAS]
children: [DOC-D6-01-VPLAN, DOC-D5-01-DFT]
references: [IEEE 1685-2022, Accellera IP-XACT XSD]
generated: 2026-04-23T22:45:00+08:00
---

# IP-XACT Metadata Bundle — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ Owner }} | Initial |

---

## 1. Purpose

提供**机器可读**的 IP 元数据（IEEE 1685-2022 IP-XACT XML），用于：
- 从 MAS 自动生成 RTL wrapper
- 自动生成 UVM testbench skeleton
- 自动生成寄存器 header (C/H) 和驱动
- SoC 集成（端口连接、地址 map）
- 验证计划中的寄存器/接口检查自动化

## 2. Deliverable Structure

```
ipxact/
├── components/
│   ├── d2d_ctrl.xml           # 单个 IP 的 component 定义
│   ├── hbm_phy.xml
│   ├── ... (per block)
├── designs/
│   ├── ccd0_top.xml           # 顶层 design（实例化 + 连接）
│   ├── iod_top.xml
│   └── chip_top.xml
├── abstractionDefinitions/
│   ├── ucie_bus.xml           # UCIe 接口抽象
│   └── ...
├── busDefinitions/
│   ├── ucie.xml
│   └── axi5.xml
└── generators/
    └── regmap_header.tcl      # 寄存器 C header 生成器
```

## 3. IP-XACT Component Schema (per block)

每个 IP block 的 `<component>` 必须包含以下章节：

### 3.1 Header
```xml
<ipxact:component xmlns:ipxact="http://www.accellera.org/XMLSchema/IPXACT/1685-2022">
  <ipxact:vendor>{{ Company }}</ipxact:vendor>
  <ipxact:library>chiplet_lib</ipxact:library>
  <ipxact:name>d2d_ctrl</ipxact:name>
  <ipxact:version>1.0</ipxact:version>
  ...
</ipxact:component>
```

### 3.2 Required Sections

| Section | 内容 | MAS 对应 |
|---|---|---|
| `<busInterfaces>` | 所有总线端口（AXI/AXI-Lite/UCIe） | MAS §2 |
| `<ports>` | 非总线端口（clock/reset/flat wires） | MAS §2 |
| `<memoryMaps>` | 寄存器地址 map | MAS §8 |
| `<addressSpaces>` | 本 IP 的寻址空间 | MAS §8 |
| `<parameters>` | 可配置参数（宽度、深度） | MAS §4 |
| `<cpus>` | 若含处理器 | - |
| `<views>` | RTL / TLM / gate 视图 | - |
| `<fileSets>` | RTL/TB 文件清单 | - |

### 3.3 Register Map Example

```xml
<ipxact:memoryMap>
  <ipxact:name>cfg_map</ipxact:name>
  <ipxact:addressBlock>
    <ipxact:name>cfg</ipxact:name>
    <ipxact:baseAddress>0x0</ipxact:baseAddress>
    <ipxact:range>0x1000</ipxact:range>
    <ipxact:register>
      <ipxact:name>CTRL</ipxact:name>
      <ipxact:addressOffset>0x0</ipxact:addressOffset>
      <ipxact:size>32</ipxact:size>
      <ipxact:access>read-write</ipxact:access>
      <ipxact:reset><ipxact:value>0x0</ipxact:value></ipxact:reset>
      <ipxact:field>
        <ipxact:name>LINK_EN</ipxact:name>
        <ipxact:bitOffset>0</ipxact:bitOffset>
        <ipxact:bitWidth>1</ipxact:bitWidth>
        <ipxact:access>read-write</ipxact:access>
      </ipxact:field>
    </ipxact:register>
  </ipxact:addressBlock>
</ipxact:memoryMap>
```

## 4. Generation Flow

```
MAS (Markdown + tables) ──┐
                          ├──► [converter script] ──► IP-XACT XML ──► EDA tools
RTL (SystemVerilog) ──────┘                                    │
                                                               ├──► Reg C header
                                                               ├──► UVM reg model
                                                               ├──► Driver stubs
                                                               └──► SoC connectivity
```

## 5. Tools

| Task | Tool |
|---|---|
| Authoring | Kactus2 (open source) / Synopsys IP-XACT Tool / Magillem |
| RegMap auto-gen | SystemRDL → IP-XACT via PeakRDL |
| C header gen | IP-XACT `<generator>` + Tcl |
| UVM reg model gen | Cadence / Synopsys / Mentor |
| SoC assembly | Synopsys coreAssembler / Cadence Helium |

## 6. Validation

- **Schema check**: XSD validation against IEEE 1685-2022
- **Semantic check**: Kactus2 validate / custom lint
- **Consistency with RTL**: 自动 diff — 端口方向/宽度/命名

## 7. Quality Checklist

- [ ] 所有 P1 blocks 有 IP-XACT 描述
- [ ] XSD schema validation 通过
- [ ] RTL 端口与 IP-XACT `<ports>` 完全一致（脚本验证）
- [ ] 所有寄存器 reset value 与 MAS 一致
- [ ] Register access type 与 MAS 一致
- [ ] 地址冲突检查通过
- [ ] C header / UVM reg model 已生成并通过单元测试
- [ ] Version 与 MAS version 锁定

## 8. Traceability

每个 IP-XACT `<component>` 文件 frontmatter（XML 注释）中标注：
```xml
<!--
  Derived from: DOC-D3-01-MAS-D2DCTRL v1.0
  IP-XACT version: 1.0
  Last synced: 2026-04-23
-->
```

## 9. References
- IEEE 1685-2022: https://standards.ieee.org/ieee/1685/
- Accellera IP-XACT schemas: https://www.accellera.org/downloads/standards/ip-xact
- Kactus2: https://kactus2.cs.tut.fi/
