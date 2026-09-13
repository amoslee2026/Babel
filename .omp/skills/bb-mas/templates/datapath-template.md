---
# datapath-template.md — 数据通路设计模板
---

# {{ MODULE_NAME }} 数据通路设计

## 1. 数据通路概述

### 1.1 数据流方向
- 输入：`{{ INPUT_DESC }}`
- 处理：`{{ PROCESS_DESC }}`
- 输出：`{{ OUTPUT_DESC }}`

### 1.2 吞吐规格
- 输入吞吐：`{{ INPUT_TP }} Gbps`
- 处理吞吐：`{{ PROCESS_TP }} ops/s`
- 输出吞吐：`{{ OUTPUT_TP }} Gbps`

---

## 2. 模块框图

### 2.1 顶层结构 (Mermaid)

```mermaid
graph TB
    subgraph Input_Interface
        IN1[输入端口 1]
        IN2[输入端口 2]
    end
    
    subgraph Pipeline
        S1[Stage 1: {{ OP1 }}]
        S2[Stage 2: {{ OP2 }}]
        S3[Stage 3: {{ OP3 }}]
    end
    
    subgraph Output_Interface
        OUT1[输出端口 1]
    end
    
    subgraph Control
        FSM[状态机控制]
        CFG[配置寄存器]
    end
    
    IN1 --> S1
    IN2 --> S1
    S1 --> S2
    S2 --> S3
    S3 --> OUT1
    
    FSM --> S1
    FSM --> S2
    FSM --> S3
    CFG --> FSM
```

### 2.2 模块实例表

| 模块 | 实例名 | 类型 | 描述 |
|------|--------|------|------|
| `{{ MODULE }}` | `{{ INSTANCE }}` | {{ TYPE }} | {{ DESC }} |

---

## 3. 流水线结构

### 3.1 流水线级定义

| 级别 | 名称 | 操作 | 延迟 (cycles) | 输入寄存器 | 输出寄存器 |
|------|------|------|---------------|-----------|-----------|
| S1 | `{{ STAGE_NAME }}` | {{ OP }} | {{ DELAY }} | {{ IN_REGS }} | {{ OUT_REGS }} |
| S2 | `{{ STAGE_NAME }}` | {{ OP }} | {{ DELAY }} | {{ IN_REGS }} | {{ OUT_REGS }} |

### 3.2 流水线时序图

```wavedrom
{signal: [
  {name: 'clk', wave: 'p................'},
  {name: 'stage1_in', wave: '0.1...........0'},
  {name: 'stage1_out', wave: '0..1..........'},
  {name: 'stage2_out', wave: '0...1.........'},
  {name: 'stage3_out', wave: '0....1........'},
  {name: 'final_out', wave: '0.....1.......'}
]}
```

### 3.3 流水线冲突处理

| 冲突类型 | 检测方式 | 处理方式 |
|----------|---------|----------|
| `{{ HAZARD }}` | {{ DETECT }} | {{ HANDLE }} |

---

## 4. 数据处理单元

### 4.1 计算单元

| 单元 | 功能 | 输入位宽 | 输出位宽 | 延迟 (cycles) |
|------|------|---------|---------|---------------|
| `{{ UNIT }}` | {{ FUNC }} | {{ IN_W }} | {{ OUT_W }} | {{ DELAY }} |

### 4.2 数据格式

| 数据 | 格式 | 位宽 | 范围 |
|------|------|------|------|
| `{{ DATA }}` | {{ FORMAT }} | {{ WIDTH }} | {{ RANGE }} |

---

## 5. 关键路径分析

### 5.1 最大延迟路径

```mermaid
graph LR
    A[起点] --> B[{{ NODE1 }}]
    B --> C[{{ NODE2 }}]
    C --> D[终点]
    
    linkStyle 0 stroke:red,stroke-width:4px
    linkStyle 1 stroke:red,stroke-width:4px
    linkStyle 2 stroke:red,stroke-width:4px
```

**路径延迟分解**：
| 节点 | 延迟 (cycles) | 类型 |
|------|---------------|------|
| `{{ NODE }}` | {{ DELAY }} | {{ TYPE }} |
| **总计** | **{{ TOTAL }} cycles** | - |

### 5.2 时序约束
- 目标频率：`{{ TARGET_FREQ }} MHz`
- 流水线深度：`{{ PIPE_DEPTH }} stages`
- 最大单级延迟：`{{ MAX_STAGE_LAT }} cycles`

### 5.3 优化建议

| 优化点 | 当前延迟 (cycles) | 优化后延迟 (cycles) | 方法 |
|--------|------------------|--------------------|------|
| `{{ POINT }}` | {{ CUR }} | {{ OPT }} | {{ METHOD }} |

---

## 6. 数据缓冲

### 6.1 FIFO 配置

| FIFO | 深度 | 宽度 | 类型 | 用途 |
|------|------|------|------|------|
| `{{ FIFO }}` | {{ DEPTH }} | {{ WIDTH }} | {{ TYPE }} | {{ PURPOSE }} |

### 6.2 反压机制

| 反压点 | 触发条件 | 反压信号 | 效果 |
|--------|---------|----------|------|
| `{{ POINT }}` | {{ COND }} | {{ SIGNAL }} | {{ EFFECT }} |

---

## 7. 控制信号

### 7.1 数据通路控制

| 控制信号 | 来源 | 作用 | 时序 |
|----------|------|------|------|
| `{{ SIGNAL }}` | {{ SOURCE }} | {{ ACTION }} | {{ TIMING }} |

### 7.2 控制字格式

| 位域 | 名称 | 值 | 描述 |
|------|------|---|------|
| `[{{ BITS }}]` | `{{ NAME }}` | `{{ VAL }}` | {{ DESC }} |

---

## 8. Chiplet 间数据传输（如有）

### 8.1 D2D 数据通路

```mermaid
graph LR
    A[本地处理] --> B[封装]
    B --> C[D2D PHY]
    C --> D[远端 PHY]
    D --> E[解包]
    E --> F[远端处理]
```

### 8.2 数据包格式

| 字段 | 位宽 | 描述 |
|------|------|------|
| `{{ FIELD }}` | {{ WIDTH }} | {{ DESC }} |

---

## 9. RTL 实现建议

### 9.1 推荐代码结构

```verilog
// 流水线寄存器示例
always_ff @(posedge clk) begin
    stage1_reg <= stage1_data;
    stage2_reg <= stage2_data;
    stage3_reg <= stage3_data;
end
```

### 9.2 综合约束
- 最大延迟：`{{ MAX_DELAY }} cycles`
- 多周期路径：`{{ MULTI_CYCLE }} cycles`

---

## 10. 附录

### A. 详细数据流图
[完整数据通路详细图]

### B. 寄存器传递链
[各级寄存器数据传递详表]