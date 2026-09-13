# Chiplet 相关标准

## UCIe (Universal Chiplet Interconnect Express)

### 版本演进

| 版本 | 发布时间 | 主要特性 |
|------|----------|----------|
| UCIe 1.0 | 2022 | 基础互连规范 |
| UCIe 1.1 | 2023 | 增强协议层 |
| UCIe 2.0 | 2024 | Retimer 支持、高级封装 |
| UCIe 3.0 | TBD | 混合键合支持 |

### 合规等级

| Level | 特性 | 适用场景 |
|-------|------|----------|
| Standard | 基础功能 | 一般应用 |
| Advanced Retimer | 信号重定时 | 长距离互连 |
| Bridge | 封装桥接 | 多芯片封装 |

### 关键规格

| 参数 | UCIe 2.0 规格 |
|------|---------------|
| 单通道带宽 | 4 GT/s (Standard), 32 GT/s (Advanced) |
| 通道宽度 | 16/64 lanes |
| 能效 | ≤ 0.5 pJ/bit (目标) |
| 延迟 | ≤ 10 ns round-trip |

## IEEE 1838 (Die Wrapper Standard)

### 栀准定义

IEEE 1838 定义 2.5D/3D 封装中 Die wrapper 的测试访问架构。

### 关键要素

| Element | 描述 |
|---------|------|
| Die Wrapper | Die 级测试访问接口 |
| Test Access Mechanism (TAM) | 测试数据传输通道 |
| DFT Architecture | 芯片级测试架构协调 |

### 应用场景

- Multi-die packages (2.5D/3D)
- Known-Good-Die (KGD) testing
- Post-package test

## IEEE 1685 (IP-XACT)

### 标准用途

IP-XACT 定义 IP 模块元数据的 XML 格式，用于：
- IP 集成自动化
- 工具间数据交换
- 配置管理

### 核心元素

| Element | 描述 |
|---------|------|
| Component | IP 模块定义 |
| Bus Interface | 接口规格 |
| Register | 寄存器映射 |
| Memory Map | 地址映射 |
| File Set | 文件组织 |

## JEDEC Standards

### JEP30 (Package Outline)

定义封装外形尺寸标准。

### JESD235D (HBM3)

HBM3 (High Bandwidth Memory) 规范：

| 参数 | HBM3 规格 |
|------|-----------|
| 堆叠高度 | 8/12/16 layers |
| 单栈容量 | 16/24/32 GB |
| 总带宽 | ≥ 600 GB/s |
| 接口位宽 | 1024-bit per stack |

## 其他相关标准

### IEEE 1149.1 (JTAG)

测试访问端口标准。

### IEEE 1687 (IJTAG)

内部 JTAG 访问标准。

### IEEE 1800 (SystemVerilog)

硬件描述语言标准。

### IEEE 1801 (UPF)

统一功耗格式标准。

---

## PRD 中合规声明格式

```markdown
## Standards Compliance Summary

- [ ] UCIe {{ 2.0 / 3.0 }}
- [ ] IEEE 1838 (Die Wrapper, if 3D/2.5D)
- [ ] IEEE 1685-2022 (IP-XACT)
- [ ] JEDEC JESD235D (HBM3)
- [ ] {{ 其他适用标准 }}
```