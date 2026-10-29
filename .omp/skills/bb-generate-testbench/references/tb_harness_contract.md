# TB Harness Contract

`bb-generate-testbench` 生成的每个 `tb_<Module>.sv` 暴露以下 API；`bb-generate-testcases` 生成的 `tc_<Module>.sv` **只能**通过它们操作 DUT，不得直接引用未声明信号。

| API | 签名 | 语义 |
|-----|------|------|
| `drive_defaults()` | `task automatic` | 所有非时钟输入置 0；不改复位 |
| `apply_reset()` | `task automatic` | 先 `drive_defaults()`，复位有效 2 拍后释放，再等 1 拍 |
| `check_tp(idx, ok)` | `task automatic (int idx, bit ok)` | 记录一次检查；失败打印 `[FAIL] TP-<id>`；`idx` 为 TP 在模块内的序号 |
| `mark_tp(idx)` | `task automatic (int idx)` | 置 `tp_hit[idx]=1`，供 covergroup `cp_tp` 统计 |
| `sb_check(idx)` | `task automatic (int idx)` | 基础 scoreboard：检查所有输出无 X/Z，再 `mark_tp(idx)` |
| `tp_id(idx)` | `function automatic string (int idx)` | 返回 `TP-...` 字符串，用于日志 |

## 变量
| 名称 | 类型 | 说明 |
|------|------|------|
| `checks` / `errors` | `int` | 全局计数，仿真末按 `errors>0 → $fatal` |
| `tp_hit` | `logic [N-1:0]` | 每 TP 一位，N = 模块 TP 数 |
| `dut` | `<Module>` | DUT 实例名，测试可直接观察内部信号，但驱动只走 TB 信号 |

## 测试选择
`tc_<Module>.sv` 里的 `run_all()` 负责解析 `+TC=<id>`：

- 无 `+TC` → 跑全部
- `+TC=TP-M00-003` → 只跑该点
