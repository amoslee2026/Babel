# SystemVerilog 可综合性规则

本文档详细定义 RTL-Coder 必须遵守的可综合性规则。

---

## CRITICAL 级别规则（违反必须立即修复）

### NO_INITIAL

**规则**：禁止在 RTL 模块中使用 `initial` 块

**检测**：正则表达式 `initial\s+(begin|@(?!posedge|negedge))`

**原因**：综合工具忽略 initial 块，导致仿真与综合结果不一致

**修复**：使用 reset 信号初始化

---

### NO_DELAY

**规则**：禁止使用 `#` 延迟语句

**检测**：正则表达式 `#\d+`

**原因**：综合工具忽略延迟，仿真时序与硬件不一致

**修复**：用时钟周期描述延迟

---

### NO_FORCE_RELEASE

**规则**：禁止使用 `force` 和 `release` 语句

**原因**：仅用于仿真调试，不可综合

---

### NO_WAIT

**规则**：禁止使用 `wait` 语句

**原因**：wait 是阻塞语句，硬件无法实现

**修复**：使用状态机等待

---

### NO_RECURSION

**规则**：禁止递归模块实例化

**原因**：实例化深度不确定，综合无法处理

---

## HIGH 级别规则（强烈建议修复）

### SINGLE_CLOCK

**规则**：每个模块只使用一个时钟

**例外**：CDC 模块专门处理跨时钟域

---

### PORT_WIDTH_MATCH

**规则**：端口连接位宽必须匹配

---

### NO_LATCH

**规则**：禁止生成无意锁存器

**检测**：组合逻辑缺少完整分支覆盖

**修复**：提供默认值或完整 case/if 分支

---

### NO_X_STATE

**规则**：禁止赋值 `'x` 或 `'z`

**例外**：case 语句 default 分支检测

---

## MEDIUM 级别规则（建议修复）

### SYNC_RESET

**规则**：建议使用同步复位

---

### FSM_ENCODING

**规则**：状态机使用显式编码

---

## 综合工具兼容性

| 规则 | Synopsys DC | Cadence RC | Vivado | Quartus |
|------|-------------|------------|--------|---------|
| NO_INITIAL | ✓ | ✓ | ✓ | ✓ |
| NO_DELAY | ✓ | ✓ | ✓ | ✓ |
| NO_LATCH | ✓ | ✓ | ✓ | ✓ |
| NO_WAIT | ✓ | ✓ | ✓ | ✓ |
| SINGLE_CLOCK | ✓ | ✓ | ✓ | ✓ |

---

## 综合检查脚本示例

见 `scripts/synthesis_check.py`