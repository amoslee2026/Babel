---
title: "IC 架构设计陷阱与常见错误"
type: reference
purpose: api
audience: llm
direction: input
status: approved
version: "1.0.0"
---

# Gotcha: IC 架构设计陷阱

芯片架构设计中容易被忽略的陷阱和常见错误。

---

## 时钟设计陷阱

### ❌ CDC 直接同步多 bit

**错误**：用 2 级同步器直接同步多 bit 数据
**后果**：数据 skew 导致采样错误
**正确**：使用 handshake 或 FIFO

```
// WRONG
assign sync_data[31:0] = {2-stage sync for each bit};

// CORRECT
// Use handshake protocol
assign ready_out = valid_in && ack_in;
```

### ❌ 时钟门控毛刺

**错误**：用 AND gate 做时钟门控
**后果**：产生时钟 glitch，逻辑错误
**正确**：使用 ICG (Integrated Clock Gate) cell

```
// WRONG
assign gated_clk = clk & enable;

// CORRECT
// Use library ICG cell
ICG u_icg (.CLK(clk), .EN(enable), .CLKOUT(gated_clk));
```

### ❌ PLL 稳定前释放复位

**错误**：PLL 未锁定就释放 Main domain 复位
**后果**：时钟不稳定，系统启动失败
**正确**：等待 PLL lock 信号后再释放复位

---

## 电源设计陷阱

### ❌ 跨电源域无隔离

**错误**：关闭域的输出直接连接到开启域
**后果**：未定义信号，逻辑错误或漏电
**正确**：加 Isolation Cell

### ❌ 复位顺序错误

**错误**：先释放 Main domain，后释放 AON
**后果**：系统状态不一致
**正确**：AON → Main → Peripheral

### ❌ IR Drop 估算不足

**错误**：电源网格设计过于稀疏
**后果**：IR Drop > 5%，时序不满足
**正确**：迭代优化网格密度

---

## 存储设计陷阱

### ❌ 地址冲突

**错误**：多个模块映射到相同地址范围
**后果**：总线响应冲突
**正确**：严格检查 Memory Map 无重叠

### ❌ Memory Map 空洞无处理

**错误**：访问未映射地址无错误响应
**后果**：软件访问错误地址未检测
**正确**：未映射地址返回 bus error

---

## DFT 设计陷阱

### ❌ Scan Chain 跨时钟域

**错误**：一条 Scan Chain 包含多个时钟域
**后果**：测试时序问题
**正确**：每域独立 Scan Chain

### ❌ 测试模式隔离不足

**错误**：安全功能在 Test 模式下仍可用
**后果**：安全漏洞
**正确**：Test 模式禁用安全功能

---

## 接口设计陷阱

### ❌ 时序未定义

**错误**：接口信号无 setup/hold 要求
**后果**：集成时序问题
**正确**：明确时序要求（通常 ns 级）

### ❌ 缺少默认值

**错误**：控制信号无复位默认值
**后果**：启动状态不确定
**正确**：所有控制信号有明确复位值

---

## 安全设计陷阱

### ❌ 安全启动仅验证一次

**错误**：仅验证 boot loader，不验证应用
**后果**：恶意应用可执行
**正确**：链式验证或每次加载验证

### ❌ RNG 不做健康检查

**错误**：直接使用 RNG 输出
**后果**：熵不足导致密钥弱
**正确**：FIPS/CC-compliant health check

---

## 文档陷阱

### ❌ Block Diagram 不标注域

**错误**：Block Diagram 不标注时钟/电源域
**后果**：读者误解模块关系
**正确**：用 subgraph 标注各域

### ❌ 寄存器地址不对齐

**错误**：寄存器地址不在 4 字节边界
**后果**：总线访问问题
**正确**：所有寄存器 4-byte aligned

---

## 验证陷阱

### ❌ Coverage 虚高

**错误**：覆盖率数值达标但场景不足
**后果**：缺陷漏检
**正确**：深度覆盖检查（corner case）

### ❌ CDC 未 Formal 验证

**错误**：CDC 仅做 Simulation
**后果**：CDC 问题漏检
**正确**：必须 Formal CDC check