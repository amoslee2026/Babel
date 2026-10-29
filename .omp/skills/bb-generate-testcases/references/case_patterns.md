# Testcase Patterns

生成器对每个 `category` 用固定范式；手工补测时沿用同一范式，避免风格分裂。

## functional
```systemverilog
drive_defaults();
apply_reset();
<窄输入 $urandom>;
repeat (8) @(posedge clk);
sb_check(idx);
```
坑：`apply_reset()` 会清掉之前驱动；必须先复位再施加激励。

## branch
只驱动 selector 类信号（`*mode*` / `*sel*` / `*prec*` / `*format*` / `*enable*` / `*start*` / `*valid*`），
保证其它输入稳定，否则分支覆盖归因不清。

## boundary
最宽输入分别置 `'1` 与 `'0`，每次等 4 拍后 `sb_check`；不要用 `$urandom` 覆盖边界
（随机值几乎不命中全 1/全 0）。

## reset
`apply_reset()` 后立刻 `sb_check`；复位期间输出必须是确定值，X 会被 `$isunknown` 判失败。

## cdc
至少 16 个目的域时钟周期；每拍翻转源域输入，检查目的域采样无 X、无振荡。

## 通用
- 一个 task 只对应一个 TP，task 名 `tc_<TP id 下划线化>`
- 需要多条断言时用 `check_tp(idx, expr)`，不要自己加 `errors++`
- 单选执行：`run_tests.sh <module> <TP-ID>`
