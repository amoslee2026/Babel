---
title: "IC 专业术语参考"
type: reference
purpose: api
audience: llm
direction: input
status: approved
version: "1.0.0"
---

# IC 专业术语参考

芯片设计领域常用术语和缩写对照表。

---

## 基本术语

| 术语 | 中文 | 说明 |
|------|------|------|
| ASIC | 专用集成电路 | Application Specific Integrated Circuit |
| SoC | 系统芯片 | System on Chip |
| FPGA | 现场可编程门阵列 | Field Programmable Gate Array |
| IP | 知识产权模块 | Intellectual Property (design block) |
| RTL | 寄存器传输级 | Register Transfer Level |
| HDL | 硬件描述语言 | Hardware Description Language |
| VLSI | 超大规模集成电路 | Very Large Scale Integration |
| CAD | 计算机辅助设计 | Computer Aided Design |
| EDA | 电子设计自动化 | Electronic Design Automation |

---

## 设计流程术语

| 术语 | 中文 | 说明 |
|------|------|------|
| Specification | 规格说明 | 设计需求文档 |
| Architecture | 架构 | 高层设计方案 |
| Microarchitecture | 微架构 | 详细实现设计 |
| Synthesis | 综合 | RTL → Gate 转换 |
| Place & Route | 布局布线 | 物理设计 |
| Signoff | 签核 | 最终验证确认 |
| Tape-out | 流片 | 交付制造 |
| Shuttle | Shuttle run | 共享制造批次 |
| MPW | 多项目晶圆 | Multi-Project Wafer |

---

## 时钟与复位术语

| 术语 | 中文 | 说明 |
|------|------|------|
| Clock Domain | 时钟域 | 同一时钟控制的逻辑范围 |
| CDC | 时钟域穿越 | Clock Domain Crossing |
| PLL | 锁相环 | Phase Locked Loop |
| DLL | 延迟锁相环 | Delay Locked Loop |
| CG | 时钟门控 | Clock Gating |
| ICG | 集成时钟门控单元 | Integrated Clock Gate |
| POR | 上电复位 | Power On Reset |
| WDT | 看门狗定时器 | Watchdog Timer |
| Async Reset | 异步复位 |与时钟无关的复位 |
| Sync Reset | 同步复位 | 时钟同步的复位 |

---

## 电源术语

| 术语 | 中文 | 说明 |
|------|------|------|
| Power Domain | 电源域 | 可独立控制的供电区域 |
| Power Gating | 电源门控 | 关闭电源节省功耗 |
| DVFS | 动态电压频率调整 | Dynamic Voltage Frequency Scaling |
| IR Drop | IR 压降 | 电源网络电压降 |
| EM | 电迁移 | Electromigration |
| Decap | 去耦电容 | Decoupling Capacitor |
| Isolation Cell | 隔离单元 | 电源域边界隔离 |
| Level Shifter | 电平转换器 | 电压域转换 |
| Retention | 状态保持 | 关电时保持数据 |
| Leakage | 漏电 | 静态功耗来源 |

---

## 存储术语

| 术语 | 中文 | 说明 |
|------|------|------|
| SRAM | 静态随机存储器 | Static Random Access Memory |
| DRAM | 动态随机存储器 | Dynamic Random Access Memory |
| Flash | 闪存 | 非易失性存储 |
| ROM | 只读存储器 | Read Only Memory |
| OTP | 一次性可编程 | One Time Programmable |
| eFuse | 电子熔丝 | Electrically Programmable Fuse |
| Memory Map | 地址映射 | 存储地址分配 |
| ECC | 纠错码 | Error Correction Code |
| Scrambling | 扰码 | 数据随机化 |

---

## IO 与总线术语

| 术语 | 中文 | 说明 |
|------|------|------|
| GPIO | 通用输入输出 | General Purpose IO |
| Pad | 焊盘 | IO 物理接口 |
| Pinout | 引脚图 | 芯片引脚定义 |
| Muxed IO | 多路复用 IO | 功能可选 IO |
| TileLink | - | RISC-V 总线协议 |
| AXI | - | ARM 高级扩展接口 |
| APB | - | ARM 外设总线 |
| AHB | - | ARM 高速总线 |
| UART | 通用异步收发 | Universal Async Receiver Transmitter |
| SPI | 串行外设接口 | Serial Peripheral Interface |
| I2C | 内部集成电路 | Inter-Integrated Circuit |

---

## DFT 术语

| 术语 | 中文 | 说明 |
|------|------|------|
| DFT | 可测试性设计 | Design for Testability |
| Scan | 扫描测试 | Scan chain test |
| ATPG | 自动测试向量生成 | Automatic Test Pattern Generation |
| BIST | 内置自测试 | Built-In Self Test |
| MBIST | 存储器自测试 | Memory BIST |
| LBIST | 逻辑自测试 | Logic BIST |
| JTAG | 联合测试行动组 | IEEE 1149.1 标准 |
| TAP | 测试访问端口 | Test Access Port |
| Boundary Scan | 边界扫描 | IO 测试方法 |
| Fault Coverage | 故障覆盖率 | 缺陷检测能力 |

---

## 验证术语

| 术语 | 中文 | 说明 |
|------|------|------|
| Testbench | 测试平台 | 验证环境 |
| UVM | 通用验证方法学 | Universal Verification Methodology |
| Assertion | 断言 | 设计属性检查 |
| Coverage | 覆盖率 | 验证完整度度量 |
| Formal | 形式验证 | 数学证明验证 |
| Emulation | 硬件仿真 | 加速验证 |
| Regression | 回归测试 | 批量测试运行 |
| Signoff | 签核 | 验证完成确认 |
| Gate Simulation | 门级仿真 | 综合后仿真 |

---

## 安全术语

| 术语 | 中文 | 说明 |
|------|------|------|
| RoT | 根信任 | Root of Trust |
| Secure Boot | 安全启动 | 验证启动代码 |
| Crypto | 加密 | Cryptography |
| AES | 高级加密标准 | Advanced Encryption Standard |
| SHA | 安全哈希算法 | Secure Hash Algorithm |
| HMAC | 基于哈希的消息认证 | Hash-based Message Auth Code |
| RNG | 随机数生成器 | Random Number Generator |
| TRNG | 真随机数生成器 | True RNG |
| CSRNG | 密码安全 RNG | Cryptographically Secure RNG |
| Key Manager | 密钥管理器 | Key derivation/storage |
| Lifecycle | 生命周期 | 设备状态（Test/Dev/Prod） |

---

## 工艺术语

| 术语 | 中文 | 说明 |
|------|------|------|
| Technology Node | 技术节点 | 制造精度（28nm, 40nm 等） |
| Gate Count | 门数 | 逻辑规模度量 |
| kGE | 千门当量 | Thousand Gate Equivalent |
| Timing Library | 时序库 | 标准单元时序数据 |
| Standard Cell | 标准单元 | 基本逻辑单元 |
| Macro | 宏单元 | 大型功能块 |
| Hard Macro | 硬宏 | 物理固定模块 |
| Soft Macro | 软宏 | RTL 可配置模块 |
| PDK | 工艺设计包 | Process Design Kit |

---

## 信号命名规范

### 推荐命名格式

| 类型 | 格式 | 示例 |
|------|------|------|
| Clock | `clk_<domain>` | `clk_sys`, `clk_peri` |
| Reset | `rst_<domain>_n` | `rst_main_n`, `rst_peri_n` |
| Data | `<name>_<direction>` | `data_in`, `data_out` |
| Control | `<name>_i/o` | `enable_i`, `valid_o` |
| Bus | `<bus>_<dir>_<signal>` | `tl_h2d_addr` |

### 方向后缀

| 后缀 | 含义 |
|------|------|
| `_i` | Input (input to module) |
| `_o` | Output (output from module) |
| `_io` | Bidirectional |
| `_n` | Active low |
| `_p/_n` | Differential pair |

---

## 常用缩写对照

| 缩写 | 全称 |
|------|------|
| DV | Design Verification |
| PD | Physical Design |
| FE | Front-End (RTL) |
| BE | Back-End (Physical) |
| AON | Always-On |
| MCU | Microcontroller Unit |
| DMA | Direct Memory Access |
| NVIC | Nested Vectored Interrupt Controller |
| PLIC | Platform Level Interrupt Controller |