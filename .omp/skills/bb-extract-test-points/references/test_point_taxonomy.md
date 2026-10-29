# Test Point Taxonomy

每个测试点必须落入且只落入一个 `category`，决定 `bb-generate-testcases` 生成哪种激励骨架。

| category | 来源 | 典型激励 | 典型检查 |
|----------|------|----------|----------|
| `functional` | seed 表 / plan `F-*` | 正常工作模式驱动 | scoreboard / golden model 比对 |
| `branch` | plan `B-*` | 直接驱动选择信号到目标值 | 观察对应分支副作用（输出/标志位） |
| `boundary` | MAS 端口位宽 ≥8 | 驱动全 0 / 全 1 / 最大值 | 无溢出截断，错误标志符合规范 |
| `cdc` | MAS `clock_domains` ≥2 | 在源时钟域翻转，等待同步延迟 | 目的域采样值稳定，无亚稳态传播 |
| `reset` | MAS 存在 `rst*` 输入 | 复位期间注入随机输入，再释放 | 复位值恒定，释放后首拍行为正确 |

## 优先级
- `HIGH`：协议握手、模式切换、精度模式、复位/CDC 正确性
- `MEDIUM`：边界值、错误注入、性能相关
- `LOW`：可观测性、调试接口、冗余路径

## 命名
- ID：`TP-<module_code>-<NNN>`，`module_code` 取模块名首段（`M00_SystolicArray` → `M00`；顶层 → `TOP`）
- coverage bin：`cg_<module_code>.cp_<id_lower_snake>`，与 `bb-generate-testbench` 生成的 covergroup 对齐
- 去重键：`(module_code, title 小写去标点)`；同键保留首次出现，其余记入 `also_in`
