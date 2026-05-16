---
module: M03
type: DFT
status: complete
---

# M03_DRAMController — DFT 规范

## 1. D2D 接口测试

### 1.1 环回测试（Loopback）

| 测试项 | 方法 | 通过标准 |
|--------|------|----------|
| D2D 数据通路环回 | PHY 内部 loopback，发送已知模式 | BER = 0 |
| DQS 对齐验证 | 扫描 DQS 延迟，测量眼图裕量 | 眼图开口 > 0.3 UI |
| 命令总线完整性 | 发送全 0 / 全 1 / 棋盘格模式 | 无误码 |
| CA 奇偶校验 | 注入单比特翻转，验证 alert_n | alert_n 正确拉低 |

### 1.2 边界扫描（JTAG Boundary Scan）

D2D 接口所有 IO 纳入边界扫描链：

| 信号组 | 单元数 | 类型 |
|--------|--------|------|
| d2d_cmd[5:0] | 6 | BC_1（输出） |
| d2d_addr[16:0] | 17 | BC_1（输出） |
| d2d_ba[1:0], d2d_bg[1:0] | 4 | BC_1（输出） |
| d2d_dq[31:0] | 32 | BC_7（双向） |
| d2d_dqs_p/n[3:0] | 8 | BC_7（双向） |
| d2d_dm_dbi[3:0] | 4 | BC_1（输出） |
| d2d_alert_n | 1 | BC_1（输入） |

---

## 2. MBIST 方案

### 2.1 覆盖范围

| 存储器 | 大小 | MBIST 算法 |
|--------|------|------------|
| 读缓冲 FIFO | 4×128b | March-C |
| 写缓冲 FIFO | 8×128b | March-C |
| 行地址缓存（open-page） | 8×17b | March-X |
| ECC syndrome 寄存器 | 8b | March-X |

### 2.2 March-C 算法序列

```
{w0}; {r0,w1}; {r1,w0}; {r0,w1}; {r1,w0}; {r0}
```

覆盖故障类型：SA0、SA1、TF、CF（耦合故障）。

### 2.3 MBIST 控制接口

| 信号 | 方向 | 描述 |
|------|------|------|
| mbist_en | in | MBIST 使能（测试模式下有效） |
| mbist_done | out | 测试完成标志 |
| mbist_fail | out | 测试失败标志 |
| mbist_fail_addr | out[7:0] | 失败地址（FIFO 条目索引） |

MBIST 运行期间，正常读写接口被隔离（mbist_en=1 时 AXI 接口强制 awready=arready=0）。

---

## 3. 扫描链配置

### 3.1 扫描链划分

| 链编号 | 内容 | 触发器数量（估算） |
|--------|------|-------------------|
| SCAN_0 | FSM 状态寄存器 + 计时器 | ~200 FF |
| SCAN_1 | 命令调度器 + 仲裁逻辑 | ~300 FF |
| SCAN_2 | ECC 编解码器 | ~150 FF |
| SCAN_3 | AXI 接口控制逻辑 | ~250 FF |
| SCAN_4 | 配置寄存器（APB） | ~128 FF |

### 3.2 扫描控制信号

| 信号 | 描述 |
|------|------|
| scan_en | 扫描使能（高有效，覆盖功能时钟门控） |
| scan_in[4:0] | 各链扫描输入 |
| scan_out[4:0] | 各链扫描输出 |
| scan_clk | 扫描时钟（独立于 CLK_SYS） |

### 3.3 时钟门控处理

所有时钟门控单元（ICG）在 scan_en=1 时强制打开，确保扫描移位期间时钟连续。

---

## 4. JTAG 接口

遵循 IEEE 1149.1 标准，集成至芯片顶层 JTAG TAP。

| TAP 指令 | 编码 | 功能 |
|----------|------|------|
| BYPASS | 4'b1111 | 旁路 |
| IDCODE | 4'b0001 | 读取器件 ID |
| EXTEST | 4'b0000 | 边界扫描外部测试 |
| SAMPLE | 4'b0010 | 采样/预加载 |
| MBIST_CTRL | 4'b1000 | 启动/查询 MBIST |
| SCAN_ACCESS | 4'b1001 | 访问内部扫描链 |

### 4.1 MBIST via JTAG 流程

```
1. 加载 MBIST_CTRL 指令
2. DR 移入 {mbist_en=1, chain_sel}
3. 等待 mbist_done=1（轮询或 TCK 计数）
4. DR 移出读取 {mbist_fail, mbist_fail_addr}
```

### 4.2 DFT 覆盖率目标

| 类型 | 目标覆盖率 |
|------|-----------|
| 扫描故障覆盖率（stuck-at） | >= 95% |
| 扫描故障覆盖率（transition） | >= 90% |
| MBIST 存储器覆盖率 | 100% |
| D2D 接口边界扫描覆盖率 | 100% |
