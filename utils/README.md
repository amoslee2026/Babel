# utils/ — 可复用脚本索引

| 脚本 | 用途 | 何时用 |
|------|------|--------|
| `run_yosys_asap7_map.sh` | 单模块 RTL → ASAP7 标准单元映射（`synth -noabc` → `dfflibmap` SEQ → `abc -script "+strash;map"` → 两次 `stat`），产出网表 / log / 面积明细 | 快速验证 SYNTH 段、复现 ASAP7 映射结果、排查 ABC 崩溃 |
| `run_orfs_pd.sh` | 容器内跑 OpenROAD-flow-scripts ASAP7 全流程（synth → floorplan → place → CTS → route → fill → GDS + LEC + timing），产出 `6_final.gds` / WNS / area | PD 段验证、需要真实布局布线结果 |

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

## 本机用户态 EDA 工具链（2026-10-29 实测，均不入仓）

| 组件 | 路径 | 用法 |
|------|------|------|
| OSS CAD Suite（yosys 0.70 + yosys-abc、verilator、iverilog） | `/tmp/babel-pdk/oss` | `source /tmp/babel-pdk/oss/environment` |
| ASAP7 liberty/LEF/GDS/tech LEF | `/tmp/babel-pdk/asap7/{LIB,LEF,GDS,TECH}` | SS/RVT：`LIB/asap7sc7p5t_SIMPLE_RVT_SS_nldm_211120.lib`、`..._SEQ_RVT_SS_nldm_220123.lib` |
| OpenSTA 3.1.0（源码构建，gcc-toolset-13 + bison 3.8） | `/tmp/babel-pdk/OpenSTA/build/sta` | `PATH=… LD_LIBRARY_PATH=/tmp/babel-pdk/cudd-inst/lib sta -exit x.tcl` |
| CUDD（OpenSTA 依赖） | `/tmp/babel-pdk/cudd-inst` | 同上 `LD_LIBRARY_PATH` |
| KLayout 0.30.12（conda-forge） | `/tmp/babel-pdk/klayout/bin/klayout` | GDS 查看/DRC |
| micromamba | `/tmp/babel-pdk/bin/micromamba` | `MAMBA_ROOT_PREFIX=/tmp/babel-pdk/mamba` |

缺失：OpenROAD（conda litex-hub 构建依赖 libboost 1.73，已从 conda-forge 下架，装不上）、
Magic / Netgen / QRouter。因此 PD 段（place/route/DRC/LVS）仍不可跑。

STA 版本门禁已放宽为 ≥2.5 并支持 `STA_BIN` 覆盖；`eda_env.sh` 不存在时回退当前环境（要求 `sta` 在 PATH）。

## run_orfs_pd.sh（PD 段，实测可用）

```bash
# 目录布局：config.mk 与 RTL/SDC 同层，路径按 /work 引用
#   /tmp/babel-orfs/M13/{config.mk, constraint.sdc, M13_ISADecoder.sv}
utils/run_orfs_pd.sh /tmp/babel-orfs/M13/config.mk
```

产物：`results/6_final.gds`、`reports/6_finish.rpt`（WNS/TNS）、`logs/6_report.log`（area）。
镜像 `docker.io/openroad/orfs:latest`（4.4 GB，podman rootless 已拉取），内含 OpenROAD + yosys + KLayout。

实测 M13（asap7, 3.0 ns 时钟, 40% utilization）：全流程 79 s，
`6_final.gds` 1.8 MB，area 164 µm²，`wns max -214.59`（功能性打通，时序未收敛，属 RTL/SDC 迭代项）。
