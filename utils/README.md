# utils/ — 可复用脚本索引

| 脚本 | 用途 | 何时用 |
|------|------|--------|
| `run_yosys_asap7_map.sh` | 单模块 RTL → ASAP7 标准单元映射（`synth -noabc` → `dfflibmap` SEQ → `abc -script "+strash;map"` → 两次 `stat`），产出网表 / log / 面积明细 | 快速验证 SYNTH 段、复现 ASAP7 映射结果、排查 ABC 崩溃 |
| `check_babel_install.sh` | 校验 `.omp` agents/skills/commands 是否被 omp 正确加载 | 迁移或改动 `.omp/` 结构后 |

## run_yosys_asap7_map.sh

```bash
# 需要 yosys（原生，含 yosys-abc）；OSS CAD Suite:
#   PATH=/tmp/babel-pdk/oss/bin:$PATH
utils/run_yosys_asap7_map.sh --top M13_ISADecoder --rtl path/to/M13.sv \
    --comb-lib <SIMPLE_*.lib> --seq-lib <SEQ_*.lib> --out-dir /tmp/babel-synth/M13

# 从 file_list.f + 库根目录自动解析 liberty
utils/run_yosys_asap7_map.sh --top NPU_top --file-list file_list.f \
    --lib-root libs/asap7/asap7sc7p5t_28 --corner SS --vt RVT
```

环境变量：`YOSYS_BIN`、`ASAP7_LIB_ROOT`、`ASAP7_CORNER`、`ASAP7_VT`、`ABC_SCRIPT`。

退出码语义：`0` = 映射成功且无 `$_` 通用单元残留；非 0 即失败（log 里给原因）。

已知约束：`-script "+strash;map"` 不含 AO/OAI 复合门，面积是保守上界；
stock ABC 脚本（supergate `&nf`）在 ASAP7 liberty 上 SIGSEGV（status 8B）。
