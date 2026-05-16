# IC 专业术语参考

## 通用术语

| Term | 中文 | 定义 |
|------|------|------|
| ASIC | 专用集成电路 | Application-Specific Integrated Circuit |
| SoC | 系统级芯片 | System-on-Chip |
| Chiplet | 芯片模块 | 小型芯片模块，通过封装集成 |
| IP | 知识产权模块 | Intellectual Property core，可复用设计模块 |
| RTL | 寄存器传输级 | Register Transfer Level，硬件描述抽象层 |
| GDSII | 版图数据格式 | Graphic Data System II，芯片版图文件格式 |
| Tape-out | 流片 | 设计完成，提交制造 |
| PRR | 产品准备评审 | Product Readiness Review |

## 性能指标术语

| Term | 中文 | 定义 |
|------|------|------|
| Fmax | 最大频率 | Maximum frequency |
| TDP | 热设计功耗 | Thermal Design Power |
| TOPS | 每秒万亿操作 | Trillion Operations Per Second |
| FLOPS | 每秒浮点操作 | Floating-point Operations Per Second |
| IPC | 每周期指令数 | Instructions Per Cycle |
| Latency | 延迟 | 从输入到输出的时间 |
| Throughput | 吞吐量 | 单位时间处理量 |
| Bandwidth | 带宽 | 数据传输速率 |

## 工艺术语

| Term | 中文 | 定义 |
|------|------|------|
| Process Node | 工艺节点 | 制造工艺特征尺寸（如 28nm, 7nm） |
| TT | 典型工艺角 | Typical-Typical corner |
| FF | 快工艺角 | Fast-Fast corner |
| SS | 慢工艺角 | Slow-Slow corner |
| Corner | 工艺角 | 工艺参数组合的边界情况 |
| Yield | 良率 | 正常产品比例 |

## 封装术语

| Term | 中文 | 定义 |
|------|------|------|
| CoWoS | 晶圆级芯片封装 | Chip-on-Wafer-on-Substrate |
| EMIB | 嵌入式多芯片互连桥 | Embedded Multi-die Interconnect Bridge |
| Foveros | 三维堆叠封装 | Intel 3D stacking technology |
| Bump | 焊球 | 连接芯片和封装的金属球 |
| Pitch | 焊球间距 | Bump pitch |

## 互连术语

| Term | 中文 | 定义 |
|------|------|------|
| UCIe | 统一芯片互连 | Universal Chiplet Interconnect Express |
| D2D | 芯片间互连 | Die-to-Die interconnect |
| AXI | 高级可扩展接口 | Advanced eXtensible Interface (ARM) |
| APB | 高级外设总线 | Advanced Peripheral Bus (ARM) |
| TileLink | RISC-V 互连协议 | Berkeley developed interconnect protocol |
| NoC | 片上网络 | Network-on-Chip |

## 功能安全术语

| Term | 中文 | 定义 |
|------|------|------|
| ASIL | 汽车安全完整性等级 | Automotive Safety Integrity Level |
| SPFM | 单点故障度量 | Single Point Fault Metric |
| LFM | 潜在故障度量 | Latent Fault Metric |
| PMHF | 硬件故障概率度量 | Probabilistic Metric for Hardware Failures |
| FIT | 时间故障率 | Failure In Time (failures per billion hours) |

## 测试术语

| Term | 中文 | 定义 |
|------|------|------|
| DFT | 可测试性设计 | Design for Testability |
| BIST | 内置自测试 | Built-In Self Test |
| Scan Chain | 扫描链 | 测试用的寄存器链 |
| JTAG | 联合测试行动组 | Joint Test Action Group (IEEE 1149.1) |
| ATPG | 自动测试模式生成 | Automatic Test Pattern Generation |
| KGD | 已知良品芯片 | Known-Good-Die |

## 安全术语

| Term | 中文 | 定义 |
|------|------|------|
| Root of Trust | 信任根 | 安全系统的可信起点 |
| Secure Boot | 安全启动 | 验证固件完整性的启动过程 |
| DPA | 差分功耗分析 | Differential Power Analysis attack |
| Side-channel | 侧信道攻击 | 通过非预期信息泄露的攻击 |

## 标准组织

| Acronym | 全称 |
|---------|------|
| IEEE | Institute of Electrical and Electronics Engineers |
| JEDEC | Joint Electron Device Engineering Council |
| ISO | International Organization for Standardization |
| OCP | Open Compute Project |
| UCIe Consortium | Universal Chiplet Interconnect Express Consortium |