# SystemVerilog 可综合编码规范

## 基本原则

1. **RTL ≠ Behavior Modeling**：可综合 RTL 描述硬件结构，不是行为模拟
2. **时钟域单一**：每个模块只使用一个时钟；CDC 需专门处理
3. **同步设计**：所有寄存器使用同一时钟边沿触发

---

## 禁止使用的构造

| 构造 | 原因 | 替代方案 |
|------|------|---------|
| `initial` | 综合忽略，仿真不一致 | 使用 reset 信号初始化 |
| `#delay` | 综合忽略，掩盖时序问题 | 用时钟周期描述延迟 |
| `force/release` | 不可综合 | 不使用 |
| `wait` | 不可综合 | 使用状态机等待 |
| `repeat` | 综合结果不确定 | 用计数器替代 |
| `fork/join` | 并行执行，不可综合 | 不使用 |
| `recursive module` | 实例化深度不确定 | 固定实例化层级 |
| `event` | 仿真专用 | 使用状态机 |

---

## 推荐编码风格

### 时钟与复位

```systemverilog
// 推荐：同步复位
always_ff @(posedge clk) begin
    if (!rst_n) begin
        reg_a <= '0;
    end else begin
        reg_a <= data_in;
    end
end

// 推荐：异步复位（某些工艺更优）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_a <= '0;
    end else begin
        reg_a <= data_in;
    end
end
```

### 状态机编码

```systemverilog
// 推荐：三段式 FSM
typedef enum logic [2:0] {
    IDLE   = 3'b000,
    ACTIVE = 3'b001,
    DONE   = 3'b010
} state_t;

state_t current_state, next_state;

// 状态寄存器
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= IDLE;
    else        current_state <= next_state;
end

// 状态转移逻辑
always_comb begin
    next_state = current_state;
    case (current_state)
        IDLE:   if (start) next_state = ACTIVE;
        ACTIVE: if (done)  next_state = DONE;
        DONE:   next_state = IDLE;
    endcase
end

// 输出逻辑
always_comb begin
    out_valid = (current_state == DONE);
end
```

### 组合逻辑

```systemverilog
// 推荐：使用 always_comb
always_comb begin
    case (sel)
        2'b00: data_out = data_a;
        2'b01: data_out = data_b;
        2'b10: data_out = data_c;
        default: data_out = '0;
    endcase
end
```

---

## 端口定义规范

```systemverilog
module example_module (
    input  logic        clk,          // 时钟
    input  logic        rst_n,        // 异步复位（active low）
    input  logic        valid_in,     // 输入有效
    input  logic [31:0] data_in,      // 数据输入
    output logic        valid_out,    // 输出有效
    output logic [31:0] data_out      // 数据输出
);
```

**命名约定**：
- 时钟：`clk` 或 `clk_xxx`（多时钟域）
- 复位：`rst_n`（active low）或 `rst`（active high）
- 有效信号：`valid_xxx`
- 数据：`data_xxx` 或功能命名
- 位宽标注：`[WIDTH-1:0]`

---

## 流水线设计

```systemverilog
// N级流水线
logic [WIDTH-1:0] pipe_reg [N-1:0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < N; i++) begin
            pipe_reg[i] <= '0;
        end
    end else begin
        pipe_reg[0] <= data_in;
        for (int i = 1; i < N; i++) begin
            pipe_reg[i] <= pipe_reg[i-1];
        end
    end
end

assign data_out = pipe_reg[N-1];
```

---

## CDC 处理

```systemverilog
// 两级同步器（单比特）
module two_flop_sync (
    input  logic clk_dest,
    input  logic rst_n,
    input  logic data_in,
    output logic data_out
);
    logic [1:0] sync_reg;

    always_ff @(posedge clk_dest or negedge rst_n) begin
        if (!rst_n) sync_reg <= '0;
        else        sync_reg <= {sync_reg[0], data_in};
    end

    assign data_out = sync_reg[1];
endmodule
```

---

## 避免的组合逻辑陷阱

```systemverilog
// 避免：锁存器（Latch）
always_comb begin
    if (cond) data_out = data_a;  // 缺少 else 分支 → 产生锁存器
end

// 正确：完整的 case/if
always_comb begin
    data_out = '0;  // 默认值
    if (cond) data_out = data_a;
end
```

---

## 综合约束建议

```tcl
# 时钟约束
create_clock -period 10 [get_ports clk]

# 输入延迟
set_input_delay -max 2 [get_ports data_in*]

# 输出延迟
set_output_delay -max 2 [get_ports data_out*]

# 复位约束
set_false_path -from [get_ports rst_n]
```

---

## 调试技巧

1. **仿真与综合不一致**：检查 initial、delay、锁存器
2. **时序违例**：检查关键路径、流水线深度
3. **功能错误**：检查状态机转移条件、边界条件