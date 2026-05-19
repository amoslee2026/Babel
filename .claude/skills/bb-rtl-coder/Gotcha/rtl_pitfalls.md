# RTL 编码常见陷阱

本文档列出 RTL 编写过程中容易被忽略的陷阱和预防措施。

---

## 陷阱 1：无意生成锁存器

**What happens**：组合逻辑缺少完整分支覆盖，综合生成锁存器

**Why**：不完整的 if/case 分支让综合工具认为需要"记住"前值

**Fix**：提供默认值或完整分支

**Prevention**：每个 `always_comb` 提供默认值，每个 `case` 包含 `default`

---

## 陷阱 2：仿真与综合不一致

**What happens**：仿真通过但综合后硬件行为不同

**Why**：综合忽略 `initial`、`#delay` 等

**Fix**：禁止使用不可综合构造

**Prevention**：使用 synthesis_check.py 自动检测

---

## 陷阱 3：状态机编码错误

**What happens**：状态编码与 FSM.md 不一致

**Fix**：显式定义状态编码

**Prevention**：直接复制 FSM.md 编码定义

---

## 陷阱 4：端口位宽不匹配

**What happens**：实例化端口位宽不一致

**Fix**：确保位宽匹配或显式截断

**Prevention**：使用 port_compare.py 检查

---

## 陷阱 5：时钟域混淆

**What happens**：多时钟域信号混合处理

**Fix**：分离模块 + CDC 处理

**Prevention**：每个模块单一时钟域

---

## 陷阱 6：复位策略不一致

**What happens**：异步/同步复位混用

**Fix**：项目统一使用一种复位风格

**Prevention**：所有模块遵循同一策略

---

## 陷阱 7：流水线级数错误

**What happens**：级数与 datapath.md 不一致

**Fix**：使用清晰的寄存器命名

**Prevention**：命名包含级数（`pipe_sN`）

---

## 陷阱 8：Testbench 无断言

**What happens**：仅打印结果无自动验证

**Fix**：添加 SVA 断言

**Prevention**：verification.md 断言完整实现

---

## 陷阱 9：敏感列表错误

**What happens**：always 块敏感列表不完整

**Fix**：使用 `always_comb`/`always_ff`

**Prevention**：不手动编写敏感列表

---

## 陷阱 10：命名冲突

**What happens**：信号名与关键字冲突

**Fix**：添加功能前缀

**Prevention**：避免使用 SV 关键字命名