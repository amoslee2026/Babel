# TB Harness Contract

`bb-generate-testbench` 生成的每个 `tb_<Module>.sv` 暴露以下 API；`bb-generate-testcases` 生成的 `tc_<Module>.sv` **只能**通过它们操作 DUT，不得直接引用未声明信号。

| API | 签名 | 语义 |
|-----|------|------|
| `drive_defaults()` | `task automatic` | 所有非时钟、非复位输入置 0；**复位置为无效电平**（低有效 `rst_*_n` → 1，高有效 → 0） |
| `apply_reset()` | `task automatic` | 先 `drive_defaults()`，复位有效 2 拍后释放，再等 1 拍 |
| `check_tp(idx, ok)` | `task automatic (int idx, bit ok)` | 记录一次检查；失败打印 `[FAIL] TP-<id>`；`idx` 为 TP 在模块内的序号 |
| `mark_tp(idx)` | `task automatic (int idx)` | 置 `tp_hit[idx]=1`，供 covergroup `cp_tp` 统计 |
| `sb_check(idx)` | `task automatic (int idx)` | 结构性检查：所有输出无 X/Z，再 `mark_tp(idx)`（不是 golden model 比对） |
| `tp_id(idx)` | `function automatic string (int idx)` | 返回 `TP-...` 字符串，用于日志 |

## 变量
| 名称 | 类型 | 说明 |
|------|------|------|
| `checks` / `errors` | `int` | 全局计数，仿真末按 `errors>0 → $fatal` |
| `tp_hit` | `logic [N-1:0]` | 每 TP 一位，N = 模块 TP 数 |
| `dut` | RTL 真名（如 `M11_RMSNormRoPE`，不是 `tb_M11_RMSNormUnit`） | DUT 实例名；测试可观察内部信号，但驱动只走 TB 信号 |
| `v_<port>` | 按 RTL 端口位宽 | TB 侧信号名统一加 `v_` 前缀（避免与 SV/Verilator 内建名冲突），连接形如 `.port_i(v_port_i)`。测试代码必须用 `v_<port>`，manifest `ports[].signal` 即该名 |

## 测试选择
`tc_<Module>.sv` 里的 `run_all()` 负责解析 `+TC=<id>`：

- 无 `+TC` → 跑全部
- `+TC=TP-M00-003` → 只跑该点
