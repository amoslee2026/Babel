---
module: M04
type: DFT
status: complete
parent: MAS
generated: 2026-05-12T09:20:00Z
---

# M04_SystemBus - DFT 规范

## 扫描链配置

### 扫描链划分

| Chain | Flip-Flops | Description |
|-------|-----------|-------------|
| SCAN_CHAIN_0 | ~200 | 仲裁器状态机 + 控制寄存器 |
| SCAN_CHAIN_1 | ~300 | 写数据 FIFO 控制逻辑 |
| SCAN_CHAIN_2 | ~300 | 读数据 FIFO 控制逻辑 |
| SCAN_CHAIN_3 | ~200 | 带宽计数器 + 状态寄存器 |

**总计:** ~1000 FF，4条扫描链并行，测试时间 < 1ms。

### 扫描链接口

| Signal | Direction | Description |
|--------|-----------|-------------|
| scan_en | IN | 扫描使能（高有效） |
| scan_in[3:0] | IN | 4条扫描链输入 |
| scan_out[3:0] | OUT | 4条扫描链输出 |
| scan_clk | IN | 扫描时钟（独立于 CLK_SYS） |

### 扫描模式控制

```verilog
// 扫描模式下 MUX 选择
assign clk_mux = scan_en ? scan_clk : clk_sys;
assign rst_mux = scan_en ? 1'b0 : rst_n;

// FIFO 在扫描模式下旁路
assign fifo_bypass = scan_en;
```

## 总线协议测试

### MBIST (Memory Built-In Self-Test)

FIFO 内嵌 MBIST 控制器：

| Signal | Direction | Description |
|--------|-----------|-------------|
| mbist_en | IN | MBIST 使能 |
| mbist_done | OUT | MBIST 完成 |
| mbist_fail | OUT | MBIST 失败标志 |

**测试算法:** March-C，覆盖 SA0/SA1/跳变故障。

**测试时间:** 8 entries × 256-bit × 2 FIFO = 4096 bits，< 100 cycles。

### 总线功能测试模式

通过 JTAG 注入测试向量，验证：

1. **地址解码测试:** 遍历所有地址边界
2. **数据通路测试:** 全0/全1/棋盘格图案
3. **仲裁逻辑测试:** 强制各 master 请求组合

## JTAG 接口

### TAP 控制器

符合 IEEE 1149.1 标准：

| Signal | Direction | Description |
|--------|-----------|-------------|
| tck | IN | JTAG 时钟 |
| tms | IN | 测试模式选择 |
| tdi | IN | 测试数据输入 |
| tdo | OUT | 测试数据输出 |
| trst_n | IN | JTAG 复位（低有效） |

### JTAG 指令集

| Instruction | Code | Description |
|-------------|------|-------------|
| BYPASS | 4'hF | 旁路模式 |
| IDCODE | 4'h1 | 读取器件 ID |
| SAMPLE | 4'h2 | 边界扫描采样 |
| EXTEST | 4'h3 | 外部测试 |
| INTEST | 4'h4 | 内部测试 |
| MBIST_CTRL | 4'h5 | 触发 MBIST |

### 器件 ID

```
IDCODE = {4'b0001, 16'hA004, 11'h0C5, 1'b1}
       = 32'h1A004_18B
```

- [31:28] = 版本号 (0001)
- [27:12] = 器件号 (A004 = M04_SystemBus)
- [11:1]  = 厂商 ID (0C5 = Samsung)
- [0]     = 固定 1

## 边界扫描

### 边界扫描单元

所有 I/O 引脚配置边界扫描单元（BSC），支持：
- SAMPLE/PRELOAD：采样/预置引脚状态
- EXTEST：驱动/观测引脚

**BSC 数量:** 4 masters × 12 signals + 2 slaves × 12 signals = 72 BSC

## 故障覆盖率目标

| Fault Model | Target |
|-------------|--------|
| Stuck-At (SA0/SA1) | >= 98% |
| Transition Fault | >= 95% |
| Path Delay | >= 90% |
| Bridging Fault | >= 85% |

## DFT 约束

- 扫描时钟频率：100MHz（扫描模式）
- 扫描链长度：< 300 FF/chain（避免测试时间过长）
- 禁止跨时钟域扫描链
- FIFO 读写指针在扫描模式下固定为 0
