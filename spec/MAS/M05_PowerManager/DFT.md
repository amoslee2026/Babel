---
module: M05
type: DFT
status: complete
parent: MAS
generated: 2026-05-12T09:20:00Z
---

# M05 PowerManager — DFT

## 扫描链配置

### 扫描链划分

PowerManager 运行于 PD_AON 域，独立于 PD_MAIN 扫描链。

| 扫描链 | 电源域 | 触发器数量（估计） | 时钟 |
|--------|--------|-------------------|------|
| SCAN_AON_0 | PD_AON | ~50 | CLK_AON（测试模式下可替换为高速扫描时钟） |

### 扫描使能信号

| 信号 | 方向 | 描述 |
|------|------|------|
| scan_en | input | 扫描模式使能，高有效 |
| scan_in_aon | input | AON 扫描链输入 |
| scan_out_aon | output | AON 扫描链输出 |
| scan_clk | input | 扫描时钟（测试模式下替换 clk_aon） |

### 扫描时钟复用

```
// 测试模式下时钟选择
clk_func = scan_en ? scan_clk : clk_aon;
```

扫描时钟频率建议：≤ 10MHz（受 SF4 4nm AON 单元时序约束）。

## 电源感知测试（Power-Aware DFT）

### 隔离单元测试

| 测试项 | 方法 | 通过条件 |
|--------|------|----------|
| iso_en 功能验证 | 强制 iso_en=1，检查 PD_MAIN 输出 | 所有输出被钳位至安全值（0） |
| iso_en 释放验证 | 强制 iso_en=0，检查信号透传 | 输出跟随 PD_MAIN 内部值 |

### 电源门控测试

| 测试项 | 方法 | 通过条件 |
|--------|------|----------|
| PD_MAIN 断电扫描 | pd_main_en=0 时，仅测试 AON 链 | AON 扫描链完整性 100% |
| PD_MAIN 上电扫描 | pd_main_en=1 时，测试 MAIN 链 | MAIN 扫描链完整性 100% |
| 跨域信号完整性 | 检查 AON→MAIN 同步器 | 无亚稳态，同步器可测 |

### MBIST（内存 BIST）

PowerManager 本身无 SRAM，不需要 MBIST。

### 低功耗测试模式

在扫描测试期间，DVFS 切换逻辑需被旁路：

```
// 测试模式下固定工作点，避免扫描期间电压切换
dvfs_bypass = scan_en;
vdd_main_sel_test = scan_en ? 2'b10 : vdd_main_sel;  // 测试时固定 0.9V
```

## JTAG 接口

### TAP 控制器集成

PowerManager 通���芯片级 JTAG TAP 访问，不单独实现 TAP。

| JTAG 信号 | 描述 |
|-----------|------|
| tck | JTAG 测试时钟 |
| tms | 测试模式选择 |
| tdi | 测试数据输入 |
| tdo | 测试数据输出 |
| trst_n | JTAG 复位，低有效 |

### JTAG 可访问寄存器

通过 JTAG DR 扫描可直接读写以下寄存器（调试用途）：

| 寄存器 | JTAG IR 编码 | 访问类型 |
|--------|-------------|----------|
| PWR_CTRL | 5'b00101 | RW |
| DVFS_CFG | 5'b00110 | RW |
| PWR_STATUS | 5'b00111 | RO |

### 边界扫描（Boundary Scan）

PowerManager 的 IO 信号（pmic_en, pd_main_en, clk_gate_en 等）纳入芯片级 BSDL 描述，支持 IEEE 1149.1 边界扫描测试。

| 信号 | 边界扫描单元类型 |
|------|----------------|
| pmic_en | BC_1（输出控制） |
| pmic_pg | BC_4（输入采样） |
| pd_main_en | BC_1（输出控制） |
| iso_en | BC_1（输出控制） |
| clk_gate_en | BC_1（输出控制） |

## DFT 覆盖率目标

| 测试类型 | 目标覆盖率 |
|----------|-----------|
| 扫描故障覆盖（stuck-at） | ≥ 95% |
| 跳变故障覆盖（transition） | ≥ 90% |
| 路径延迟覆盖 | ≥ 85% |
| 电源感知故障覆盖 | ≥ 90% |
