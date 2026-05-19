---
# FSM-template.md — 状态机设计模板
---

# {{ MODULE_NAME }} 状态机设计

## 1. FSM 概述

### 1.1 状态机列表

| FSM 名称 | 类型 | 状态数 | 描述 |
|----------|------|--------|------|
| `{{ FSM_NAME }}` | Moore/Mealy | {{ STATE_COUNT }} | {{ DESC }} |

---

## 2. {{ FSM_NAME }} 详细设计

### 2.1 状态定义

| 状态名 | 编码 (二进制) | 编码 (十六进制) | 描述 |
|--------|--------------|----------------|------|
| `IDLE` | `000` | `0x0` | 初始/空闲状态 |
| `{{ STATE }}` | `{{ BIN }}` | `{{ HEX }}` | {{ DESC }} |

### 2.2 状态编码策略
- 编码方式：`{{ ENCODING_TYPE }}` (binary/one-hot/gray)
- 选择理由：`{{ REASON }}`

### 2.3 状态转移表

| # | 当前状态 | 转移条件 | 目标状态 | 输出变化 | 延迟 |
|---|----------|---------|----------|----------|------|
| 1 | `IDLE` | `start == 1` | `ACTIVE` | `busy = 1` | 1 cycle |
| {{ N }} | `{{ CUR }}` | `{{ COND }}` | `{{ NEXT }}` | {{ OUTPUT }} | {{ DELAY }} |

### 2.4 输出函数

| 状态 | 输出信号 | 输出值 | Moore/Mealy |
|------|----------|--------|-------------|
| `IDLE` | `busy` | `0` | Moore |
| `{{ STATE }}` | `{{ SIGNAL }}` | `{{ VALUE }}` | {{ TYPE }} |

---

## 3. 状态图 (Mermaid)

```mermaid
stateDiagram-v2
    [*] --> IDLE
    
    IDLE --> ACTIVE: start == 1
    IDLE --> IDLE: start == 0
    
    ACTIVE --> PROCESS: data_valid
    
    PROCESS --> DONE: complete
    PROCESS --> ERROR: fault
    
    DONE --> IDLE: ack
    ERROR --> IDLE: reset
    
    note right of IDLE: 输出: busy = 0
    note right of ACTIVE: 输出: busy = 1
```

---

## 4. 转移条件详细定义

### 4.1 条件表达式

| 条件名 | 表达式 | 描述 |
|--------|--------|------|
| `{{ COND_NAME }}` | `{{ EXPRESSION }}` | {{ DESC }} |

### 4.2 条件优先级

当多个条件同时满足时：
1. `{{ PRIORITY_1 }}`
2. `{{ PRIORITY_2 }}`

---

## 5. 异常处理

### 5.1 异常状态

| 异常 | 触发条件 | 处理状态 | 恢复方式 |
|------|---------|----------|----------|
| `{{ EXCEPTION }}` | `{{ TRIGGER }}` | `{{ HANDLER }}` | `{{ RECOVERY }}` |

### 5.2 复位处理
- 复位类型：`{{ RST_TYPE }}` (同步/异步)
- 复位后状态：`IDLE`
- 复位脉冲宽度：`{{ WIDTH }} cycles`

---

## 6. 时序规格

### 6.1 状态保持时间

| 状态 | 最小保持 | 最大保持 | 条件 |
|------|---------|----------|------|
| `{{ STATE }}` | {{ MIN }} cycles | {{ MAX }} cycles | {{ COND }} |

### 6.2 关键路径延迟
- 状态转移延迟：`{{ TRANS_DELAY }} cycles`
- 输出稳定延迟：`{{ OUTPUT_DELAY }} cycles`

---

## 7. RTL 实现建议

### 7.1 推荐实现结构

```verilog
// 三段式 FSM 实现示例
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always_comb begin
    case (state)
        IDLE: next_state = start ? ACTIVE : IDLE;
        {{ STATE }}: next_state = {{ NEXT_STATE_LOGIC }};
        default: next_state = IDLE;
    endcase
end

always_ff @(posedge clk) begin
    case (state)
        IDLE: busy <= 0;
        {{ STATE }}: {{ OUTPUT_LOGIC }};
    endcase
end
```

### 7.2 综合约束
- 状态寄存器：`{{ CONSTRAINT }}`
- 最大频率：`{{ MAX_FREQ }} MHz`

---

## 8. 验证要点

### 8.1 状态覆盖

| 状态 | 覆盖要求 | 测试方法 |
|------|---------|----------|
| `{{ STATE }}` | 必须覆盖 | {{ TEST_METHOD }} |

### 8.2 转移覆盖

| 转移路径 | 覆盖要求 | 测试场景 |
|----------|---------|----------|
| `{{ PATH }}` | 必须覆盖 | {{ SCENARIO }} |

详见 [verification.md](./verification.md) 断言定义。

---

## 9. 附录

### A. 状态机时序波形

```wavedrom
{signal: [
  {name: 'clk', wave: 'p........'},
  {name: 'state', wave: '0.1.2.3.0'},
  {name: 'output', wave: 'x.=.=.=x'}
]}
```

### B. 条件逻辑真值表
[详细条件判断真值表]