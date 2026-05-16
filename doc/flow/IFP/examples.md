# IFP 示例与最佳实践

本文档提供完整的 IFP 配置示例、脚本模板和最佳实践指南，帮助用户快速搭建 IC 设计流程。

---

## 1. 项目目录结构推荐

### 1.1 标准项目布局

```
project/
├── README.md                    # 项目说明
├── CLAUDE.md                    # Claude Code 项目指导 (可选)
├── ifp/                         # IFP 配置目录
│   ├── default.yaml             # 主配置文件
│   ├── api.yaml                 # API 扩展配置
│   ├── ifp.cfg.yaml             # IFP 元配置
│   └── scripts/                 # 自定义脚本
│       ├── setup_env.py         # 环境初始化
│       ├── check_license.py     # License 检查
│       ├── pre_build.py         # BUILD 前处理
│       ├── post_release.py      # RELEASE 后处理
│       └── ic_check/            # Checklist 脚本
│           ├── check_timing.py
│           ├── check_area.py
│           ├── check_power.py
│           └── gen_report.py
│
├── design/                      # 设计源文件
│   ├── rtl/                     # RTL 代码
│   │   ├── top.v
│   │   ├── sub_module_a.v
│   │   └── sub_module_b.v
│   │   └── lib/                 # IP 库
│   │       └── ip_xxx.v
│   ├── constraints/             # 约束文件
│   │   ├── top.sdc              # 时序约束
│   │   ├── top.constraints      # 物理约束
│   │   └── modes/               # 多模式约束
│   │       ├── func.sdc
│   │       ├── test.sdc
│   └── lib/                     # 库文件
│       ├── stdcell/             # 标准单元库
│       │   ├── slow.lib
│       │   ├── typical.lib
│       │   ├── fast.lib
│       ├── macro/               # 宏单元库
│       │   ├── ram.lib
│       │   ├── rom.lib
│       └── io/                  # IO 库
│           ├── io.lib
│
├── flow/                        # 流程工作目录
│   ├── syn/                     # 综合流程
│   │   ├── scripts/
│   │   │   ├── syn.tcl          # 综合脚本
│   │   │   ├── constraints.tcl
│   │   │   └── report.tcl
│   │   ├── outputs/             # 输出文件
│   │   │   ├── top.v            # 综合网表
│   │   │   ├── top.sdc          # 输出约束
│   │   │   ├── reports/
│   │   │   │   ├── timing.rpt
│   │   │   │   ├── area.rpt
│   │   │   │   ├── power.rpt
│   │   │   │   ├── qor.rpt
│   │   ├── logs/                # 日志文件
│   │   │   ├── syn.log
│   │   │   ├── error.log
│   │   ├── makefile             # Makefile
│   │   ├── run.sh               # 运行脚本
│   │
│   ├── dv/                      # 设计验证流程
│   │   ├── scripts/
│   │   │   ├── compile.tcl      # 编译脚本
│   │   │   ├── run_sim.tcl      # 仿真脚本
│   │   │   ├── coverage.tcl     # 覆盖率脚本
│   │   ├── tb/                  # Testbench
│   │   │   ├── tb_top.sv
│   │   │   ├── testcases/
│   │   │   │   ├── test_basic.sv
│   │   │   │   ├── test_corner.sv
│   │   │   │   ├── test_regression.sv
│   │   │   ├── waves/           # 波形文件
│   │   │   ├── coverage/        # 覆盖率数据
│   │   │   ├── logs/
│   │   │
│   ├── apr/                     # 自动布局布线流程
│   │   ├── scripts/
│   │   │   ├── init.tcl         # 初始化
│   │   │   ├── floorplan.tcl    # 布图规划
│   │   │   ├── placement.tcl    # 布局
│   │   │   ├── cts.tcl          # 时钟树综合
│   │   │   ├── routing.tcl      # 布线
│   │   │   ├── export.tcl       # 输出
│   │   ├── outputs/
│   │   │   ├── top.gds          # GDS 文件
│   │   │   ├── top.sdf          # SDF 文件
│   │   │   ├── top.spef         # SPEF 文件
│   │   │   ├── top.v            # APR 网表
│   │   ├── reports/
│   │   │   ├── timing.rpt
│   │   │   ├── area.rpt
│   │   │   ├── power.rpt
│   │   │   ├── drc.rpt
│   │   │   ├── lvs.rpt
│   │
│   ├── formal/                  # 形式验证流程
│   │   ├── scripts/
│   │   │   ├── setup.tcl
│   │   │   ├── compare.tcl
│   │   ├── logs/
│   │   ├── reports/
│   │
│   ├── sta/                     # 静态时序分析流程
│   │   ├── scripts/
│   │   │   ├── setup.tcl
│   │   │   ├── timing.tcl
│   │   ├── reports/
│   │
│   ├── power/                   # 功率分析流程
│   │   ├── scripts/
│   │   │   ├── setup.tcl
│   │   │   ├── power.tcl
│   │   ├── reports/
│
├── output/                      # 最终输出
│   ├── release_v1.0/            # 发布版本
│   │   ├── gds/
│   │   ├── netlist/
│   │   ├── sdc/
│   │   ├── lib/
│   │   ├── docs/
│   │
├── docs/                        # 项目文档
│   ├── spec.md                  # 规范文档
│   ├── flow.md                  # 流程文档
│   ├── checklist.xlsx           # Checklist 表格
│
└── workspace/                   # IFP 工作空间
    ├── .ifp/                    # IFP 数据目录
    │   ├── db/                  # SQLite 数据库
    │   │   ├── tasks.db
    │   │   ├── history.db
    │   ├── logs/                # IFP 日志
    │   │   ├── ifp.log
    │   │   ├── monitor.log
    │   ├── cache/               # 缓存数据
    │   │   ├── predictions/
    │   │   ├── reports/
    │   ├── temp/                # 临时文件
    │   ├── pid/                 # PID 文件
    │   │   ├── monitor.pid
    │
```

### 1.2 IFP 配置文件位置

IFP 支持多种配置文件查找路径，按优先级排序：

| 路径类型 | 查找顺序 | 说明 |
|---------|---------|------|
| 当前工作目录 | `./default.yaml` | 最高优先级 |
| IFP 配置目录 | `./ifp/default.yaml` | 推荐位置 |
| 用户目录 | `~/.ifp/default.yaml` | 用户级配置 |
| IFP 安装目录 | `<IFP_ROOT>/config/default.yaml` | 默认配置 |

---

## 2. 综合流程完整配置示例

### 2.1 default.yaml - Syn Flow

```yaml
# /home/user/project/ifp/default.yaml
# IFP 综合流程配置示例

VAR:
  # ========== 项目变量 ==========
  PROJECT_NAME: "chiplet_top"
  PROJECT_ROOT: "/home/user/project"
  DESIGN_TOP: "top"
  
  # ========== 库文件路径 ==========
  LIB_ROOT: "${PROJECT_ROOT}/design/lib"
  STDCELL_LIB: "${LIB_ROOT}/stdcell/typical.lib"
  STDCELL_slow: "${LIB_ROOT}/stdcell/slow.lib"
  STDCELL_fast: "${LIB_ROOT}/stdcell/fast.lib"
  
  MACRO_LIB: "${LIB_ROOT}/macro/ram.lib"
  IO_LIB: "${LIB_ROOT}/io/io.lib"
  
  # ========== 设计文件 ==========
  RTL_ROOT: "${PROJECT_ROOT}/design/rtl"
  RTL_FILES:
    - "${RTL_ROOT}/top.v"
    - "${RTL_ROOT}/sub_module_a.v"
    - "${RTL_ROOT}/sub_module_b.v"
    - "${RTL_ROOT}/lib/ip_xxx.v"
  
  CONSTRAINT_FILE: "${PROJECT_ROOT}/design/constraints/top.sdc"
  
  # ========== 流程路径 ==========
  FLOW_ROOT: "${PROJECT_ROOT}/flow"
  SYN_ROOT: "${FLOW_ROOT}/syn"
  SYN_SCRIPT: "${SYN_ROOT}/scripts/syn.tcl"
  SYN_OUTPUT: "${SYN_ROOT}/outputs"
  
  # ========== 工具配置 ==========
  SYN_TOOL: "DesignCompiler"  # 或 "Genus"
  LICENSE_SERVER: "192.168.1.100:27000"
  MAX_RUNTIME: "12h"          # 最大运行时间
  
  # ========== 综合参数 ==========
  TARGET_FREQUENCY: 500       # MHz
  EFFORT_LEVEL: "high"        # low/medium/high
  OPTIMIZATION_FOCUS: "timing"  # timing/area/power/balanced
  
  # ========== 并行控制 ==========
  MAX_RUNNING_JOBS: 8
  
  # ========== LSF 配置 ==========
  LSF_QUEUE: "ic_normal"
  LSF_PROJECT: "ic_design"
  LSF_MEMORY_MIN: "8G"
  LSF_MEMORY_MAX: "64G"
  LSF_CORES: 8

TASK:
  # ========== 综合主任务 ==========
  syn_main:
    DESCRIPTION: "RTL 综合主流程"
    RUN_METHOD: bsub            # 使用 LSF 集群
    RUN_MODE: RUN               # 正常执行模式
    RUN_CMD: "cd ${SYN_ROOT} && make syn"
    
    DEPENDENCY:
      FILE:
        - "${RTL_ROOT}/top.v"
        - "${STDCELL_LIB}"
        - "${SYN_SCRIPT}"
      LICENSE:
        tool: "${SYN_TOOL}"
        count: 1
      TASK: []
    
    OUTPUT:
      - "${SYN_OUTPUT}/${DESIGN_TOP}.v"
      - "${SYN_OUTPUT}/${DESIGN_TOP}.sdc"
      - "${SYN_OUTPUT}/reports/timing.rpt"
    
    CHECK:
      check_timing:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_timing.py"
        threshold:
          slack_min: -0.0       # 无负 Slack
          timing_violation: 0
        report: "${SYN_OUTPUT}/reports/check_timing.xlsx"
      
      check_area:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_area.py"
        threshold:
          total_area_max: 100000  # um²
          utilization_max: 70     # %
        report: "${SYN_OUTPUT}/reports/check_area.xlsx"
      
      check_power:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_power.py"
        threshold:
          total_power_max: 100   # mW
          leakage_ratio_max: 10  # %
        report: "${SYN_OUTPUT}/reports/check_power.xlsx"
    
    TIMEOUT: "12h"
    RETRY: 0
    
    ENV:
      SYNOPSYS_LICENSE_FILE: "${LICENSE_SERVER}"
      DC_HOME: "/opt/synopsys/dc"
      PATH: "${DC_HOME}/bin:$PATH"
    
    PRE_TASK:
      - pre_check_license
      - pre_setup_env
    
    POST_TASK:
      - post_backup_results

  # ========== License 检查任务 ==========
  pre_check_license:
    DESCRIPTION: "检查综合工具 License"
    RUN_METHOD: local
    RUN_MODE: RUN
    RUN_CMD: "python ${PROJECT_ROOT}/ifp/scripts/check_license.py"
    TIMEOUT: "5m"
    CHECK:
      check_pass:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_license_available.py"

  # ========== 环境设置任务 ==========
  pre_setup_env:
    DESCRIPTION: "初始化综合环境"
    RUN_METHOD: local
    RUN_MODE: RUN
    RUN_CMD: "python ${PROJECT_ROOT}/ifp/scripts/setup_env.py --flow syn"
    TIMEOUT: "10m"

  # ========== 结果备份任务 ==========
  post_backup_results:
    DESCRIPTION: "备份综合结果"
    RUN_METHOD: local
    RUN_MODE: RUN
    RUN_CMD: "cp -r ${SYN_OUTPUT} ${PROJECT_ROOT}/output/syn_backup_$(date +%Y%m%d)"
    TIMEOUT: "5m"

  # ========== 综合增量优化 ==========
  syn_incremental:
    DESCRIPTION: "增量综合优化"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${SYN_ROOT} && make incremental_opt"
    DEPENDENCY:
      TASK:
        - syn_main
    CHECK:
      check_timing_improved:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_timing.py"
        threshold:
          slack_improvement_min: 0.1  # 至少改善 0.1ns
    TIMEOUT: "4h"

  # ========== 综合探索 (多Corner) ==========
  syn_mc:
    DESCRIPTION: "多 Corner 综合分析"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${SYN_ROOT} && make mc_analysis"
    DEPENDENCY:
      TASK:
        - syn_main
    ENV:
      LIB_SET: "slow,typical,fast"
      MODE_SET: "func,test"
    TIMEOUT: "8h"
    CHECK:
      check_all_corners:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_mc.py"

FLOW:
  # ========== 综合主流程 ==========
  syn_flow:
    DESCRIPTION: "完整综合流程"
    TASKS:
      - pre_check_license
      - pre_setup_env
      - syn_main
      - syn_incremental
      - post_backup_results
    SEQUENCE: true              # 顺序执行
    
  # ========== 快速综合流程 ==========
  syn_quick_flow:
    DESCRIPTION: "快速综合 (用于验证)"
    TASKS:
      - syn_main
    TASK_VARS:
      syn_main:
        EFFORT_LEVEL: "low"
        RUN_MODE: RUN.fast
    
  # ========== 调试综合流程 ==========
  syn_debug_flow:
    DESCRIPTION: "调试综合流程"
    TASKS:
      - syn_main
    TASK_VARS:
      syn_main:
        RUN_MODE: RUN.DBG

```

### 2.2 syn.tcl 脚本示例

```tcl
# /home/user/project/flow/syn/scripts/syn.tcl
# Design Compiler 综合脚本

# ========== 环境设置 ==========
set PROJECT_ROOT [ getenv PROJECT_ROOT ]
set DESIGN_TOP   [ getenv DESIGN_TOP ]
set TARGET_FREQ  [ getenv TARGET_FREQUENCY ]

# ========== 库设置 ==========
set STDCELL_LIB  [ getenv STDCELL_LIB ]
set MACRO_LIB    [ getenv MACRO_LIB ]
set IO_LIB       [ getenv IO_LIB ]

# 读取库文件
read_lib "${STDCELL_LIB}"
read_lib "${MACRO_LIB}"
read_lib "${IO_LIB}"

# 设置目标库
set target_library "${STDCELL_LIB}"
set link_library   "${STDCELL_LIB} ${MACRO_LIB} ${IO_LIB}"

# ========== 设计读取 ==========
set RTL_FILES [ getenv RTL_FILES ]
foreach file $RTL_FILES {
    analyze -format verilog $file
}
elaborate $DESIGN_TOP
current_design $DESIGN_TOP

# ========== 约束设置 ==========
set CONSTRAINT_FILE [ getenv CONSTRAINT_FILE ]
read_sdc $CONSTRAINT_FILE

# 设置时钟
set CLK_PERIOD [ expr 1000.0 / $TARGET_FREQ ]  # ns
create_clock -name clk -period $CLK_PERIOD [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_latency 0.5 [get_clocks clk]
set_input_delay 0.3 -clock clk [all_inputs]
set_output_delay 0.3 -clock clk [all_outputs]

# 设置负载和驱动
set_driving_cell -lib_cell BUF_X4 [all_inputs]
set_load 0.1 [all_outputs]

# ========== 综合优化 ==========
set EFFORT [ getenv EFFORT_LEVEL ]
set FOCUS   [ getenv OPTIMIZATION_FOCUS ]

# 综合约束
set_max_area 0
set_max_fanout 20
set_max_transition 0.5

# 优化设置
set optimization_effort $EFFORT
if { $FOCUS == "timing" } {
    set_optimize_effort high
    set_critical_range 0.1
} elseif { $FOCUS == "area" } {
    set_max_area 100000
    set_optimize_effort medium
} elseif { $FOCUS == "power" } {
    set_dynamic_power_optimization true
    set_leakage_power_optimization true
}

# 编译
compile -effort $EFFORT -map_effort high

# ========== 输出报告 ==========
set OUTPUT_DIR [ getenv SYN_OUTPUT ]
set REPORT_DIR "${OUTPUT_DIR}/reports"

# 时序报告
report_timing -max_paths 10 -slack_lesser_than 0 > ${REPORT_DIR}/timing.rpt
report_timing -max_paths 100 > ${REPORT_DIR}/timing_full.rpt

# 面积报告
report_area -hierarchy > ${REPORT_DIR}/area.rpt
report_reference -hierarchy > ${REPORT_DIR}/reference.rpt

# 功率报告
report_power -hierarchy > ${REPORT_DIR}/power.rpt

# QoR 报告
report_qor > ${REPORT_DIR}/qor.rpt

# ========== 输出文件 ==========
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output ${OUTPUT_DIR}/${DESIGN_TOP}.v
write_sdc -nosplit ${OUTPUT_DIR}/${DESIGN_TOP}.sdc
write_script ${OUTPUT_DIR}/${DESIGN_TOP}.scr

# ========== 结束 ==========
exit

```

### 2.3 Makefile 示例

```makefile
# /home/user/project/flow/syn/Makefile
# 综合流程 Makefile

# ========== 变量定义 ==========
PROJECT_ROOT ?= /home/user/project
SYN_ROOT     := $(PROJECT_ROOT)/flow/syn
SCRIPT_DIR   := $(SYN_ROOT)/scripts
OUTPUT_DIR   := $(SYN_ROOT)/outputs
LOG_DIR      := $(SYN_ROOT)/logs

DESIGN_TOP   ?= top
SYN_TOOL     ?= dc_shell

# ========== 目标定义 ==========
.PHONY: syn clean clean_logs report check

# 主综合目标
syn: setup_dir
	@echo "========== 开始综合 =========="
	$(SYN_TOOL) -f $(SCRIPT_DIR)/syn.tcl | tee $(LOG_DIR)/syn.log
	@echo "========== 综合完成 =========="

# 增量优化
incremental_opt: syn
	@echo "========== 增量优化 =========="
	$(SYN_TOOL) -f $(SCRIPT_DIR)/incremental.tcl | tee $(LOG_DIR)/incremental.log
	@echo "========== 增量优化完成 =========="

# 多 Corner 分析
mc_analysis: syn
	@echo "========== 多 Corner 分析 =========="
	for corner in slow typical fast; do \
		for mode in func test; do \
			$(SYN_TOOL) -f $(SCRIPT_DIR)/mc.tcl \
				-corner $corner -mode $mode \
				| tee $(LOG_DIR)/mc_${corner}_${mode}.log; \
		done \
	done
	@echo "========== 多 Corner 分析完成 =========="

# 创建目录
setup_dir:
	mkdir -p $(OUTPUT_DIR) $(OUTPUT_DIR)/reports $(LOG_DIR)

# 生成报告汇总
report:
	@echo "========== 生成报告汇总 =========="
	python $(PROJECT_ROOT)/ifp/scripts/ic_check/gen_report.py \
		--syn-dir $(SYN_ROOT) \
		--output $(OUTPUT_DIR)/reports/summary.xlsx

# 检查结果
check: syn report
	@echo "========== 检查综合结果 =========="
	python $(PROJECT_ROOT)/ifp/scripts/ic_check/check_timing.py \
		--report $(OUTPUT_DIR)/reports/timing.rpt \
		--threshold -0.0
	python $(PROJECT_ROOT)/ifp/scripts/ic_check/check_area.py \
		--report $(OUTPUT_DIR)/reports/area.rpt \
		--threshold 100000

# 清理输出
clean:
	rm -rf $(OUTPUT_DIR)/*

# 清理日志
clean_logs:
	rm -rf $(LOG_DIR)/*

# 调试运行
debug:
	$(SYN_TOOL) -gui -f $(SCRIPT_DIR)/syn.tcl

```

---

## 3. 设计验证流程完整配置示例

### 3.1 default.yaml - DV Flow

```yaml
# /home/user/project/ifp/default.yaml
# IFP 设计验证流程配置示例

VAR:
  PROJECT_NAME: "chiplet_top"
  PROJECT_ROOT: "/home/user/project"
  DESIGN_TOP: "top"
  
  # ========== RTL 文件 ==========
  RTL_ROOT: "${PROJECT_ROOT}/design/rtl"
  RTL_FILES:
    - "${RTL_ROOT}/top.v"
    - "${RTL_ROOT}/sub_module_a.v"
    - "${RTL_ROOT}/sub_module_b.v"
  
  # ========== Testbench 文件 ==========
  DV_ROOT: "${PROJECT_ROOT}/flow/dv"
  TB_ROOT: "${DV_ROOT}/tb"
  TB_FILES:
    - "${TB_ROOT}/tb_top.sv"
  TESTCASE_ROOT: "${TB_ROOT}/testcases"
  
  # ========== 验证工具 ==========
  SIM_TOOL: "VCS"              # 或 "Verilator", "Icarus"
  COVERAGE_ENABLE: true
  WAVE_ENABLE: false
  
  # ========== 验证参数 ==========
  SIM_TIME: "10ms"
  TEST_LEVEL: "regression"     # basic/corner/regression
  
  # ========== LSF 配置 ==========
  LSF_QUEUE: "ic_verify"
  LSF_MEMORY: "16G"
  LSF_CORES: 4

TASK:
  # ========== 编译任务 ==========
  dv_compile:
    DESCRIPTION: "编译 RTL 和 Testbench"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${DV_ROOT} && make compile"
    
    DEPENDENCY:
      FILE:
        - "${RTL_ROOT}/top.v"
        - "${TB_ROOT}/tb_top.sv"
      LICENSE:
        tool: "${SIM_TOOL}"
        count: 1
    
    OUTPUT:
      - "${DV_ROOT}/simv"
    
    TIMEOUT: "2h"

  # ========== 基本仿真任务 ==========
  dv_sim_basic:
    DESCRIPTION: "基本功能仿真"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${DV_ROOT} && make sim_basic"
    
    DEPENDENCY:
      TASK:
        - dv_compile
    
    CHECK:
      check_pass:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_sim_pass.py"
        pattern: "PASS"
      check_coverage:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_coverage.py"
        threshold:
          line_coverage_min: 80
          functional_coverage_min: 70
    
    TIMEOUT: "4h"

  # ========== Corner Case 仿真 ==========
  dv_sim_corner:
    DESCRIPTION: "Corner Case 仿真"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${DV_ROOT} && make sim_corner"
    
    DEPENDENCY:
      TASK:
        - dv_compile
    
    CHECK:
      check_all_pass:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_all_corners_pass.py"
    
    TIMEOUT: "8h"

  # ========== 回归测试 ==========
  dv_regression:
    DESCRIPTION: "回归测试套件"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${DV_ROOT} && make regression"
    
    DEPENDENCY:
      TASK:
        - dv_compile
    
    CHECK:
      check_regression:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_regression.py"
        threshold:
          pass_rate_min: 95      # %
    
    TIMEOUT: "24h"

  # ========== 波形生成 ==========
  dv_wave:
    DESCRIPTION: "生成波形文件"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${DV_ROOT} && make wave"
    
    DEPENDENCY:
      TASK:
        - dv_sim_basic
    
    ENV:
      WAVE_ENABLE: "true"
    
    TIMEOUT: "2h"

FLOW:
  # ========== 基本验证流程 ==========
  dv_basic_flow:
    DESCRIPTION: "基本验证流程"
    TASKS:
      - dv_compile
      - dv_sim_basic
    
  # ========== 完整验证流程 ==========
  dv_full_flow:
    DESCRIPTION: "完整验证流程"
    TASKS:
      - dv_compile
      - dv_sim_basic
      - dv_sim_corner
      - dv_regression
      - dv_wave
    SEQUENCE: true

  # ========== 快速验证流程 ==========
  dv_quick_flow:
    DESCRIPTION: "快速验证"
    TASKS:
      - dv_compile
      - dv_sim_basic
    TASK_VARS:
      dv_compile:
        COVERAGE_ENABLE: false
      dv_sim_basic:
        TEST_LEVEL: basic

```

### 3.2 run_sim.tcl 脚本示例

```tcl
# /home/user/project/flow/dv/scripts/run_sim.tcl
# VCS 仿真脚本

# ========== 参数获取 ==========
set PROJECT_ROOT [ getenv PROJECT_ROOT ]
set DV_ROOT      [ getenv DV_ROOT ]
set DESIGN_TOP   [ getenv DESIGN_TOP ]
set SIM_TIME     [ getenv SIM_TIME ]
set COVERAGE     [ getenv COVERAGE_ENABLE ]
set WAVE         [ getenv WAVE_ENABLE ]

# ========== 编译选项 ==========
# RTL 文件
set RTL_FILES [ getenv RTL_FILES ]
set rtl_list ""
foreach file $RTL_FILES {
    append rtl_list $file " "
}

# Testbench 文件
set TB_FILES [ getenv TB_FILES ]
set tb_list ""
foreach file $TB_FILES {
    append tb_list $file " "
}

# ========== VCS 编译 ==========
set vcs_opts "-full64 -sverilog +v2k -debug_access+all"
if { $COVERAGE == "true" } {
    append vcs_opts " -cm line+cond+fsm+tgl+path"
    append vcs_opts " -cm_dir ${DV_ROOT}/coverage/test.vdb"
}
if { $WAVE == "true" } {
    append vcs_opts " -kdb -lca -debug_access+all"
}

# 运行编译
eval "vcs $vcs_opts $rtl_list $tb_list -top $DESIGN_TOP -o ${DV_ROOT}/simv"

# ========== 仿真运行 ==========
set sim_opts ""
if { $COVERAGE == "true" } {
    append sim_opts " -cm line+cond+fsm+tgl+path"
    append sim_opts " -cm_dir ${DV_ROOT}/coverage/test.vdb"
}

# 运行仿真
eval "${DV_ROOT}/simv $sim_opts -l ${DV_ROOT}/logs/sim.log +TEST_TIME=${SIM_TIME}"

# ========== 检查结果 ==========
set log_file "${DV_ROOT}/logs/sim.log"
set result [ exec grep -c "PASS" $log_file ]
if { $result > 0 } {
    puts "========== 仿真通过 =========="
    exit 0
} else {
    puts "========== 仿真失败 =========="
    exit 1
}

```

---

## 4. 自动布局布线流程配置示例

### 4.1 default.yaml - APR Flow

```yaml
# /home/user/project/ifp/default.yaml
# IFP APR 流程配置示例

VAR:
  PROJECT_NAME: "chiplet_top"
  PROJECT_ROOT: "/home/user/project"
  DESIGN_TOP: "top"
  
  # ========== 输入文件 ==========
  SYN_OUTPUT: "${PROJECT_ROOT}/flow/syn/outputs"
  NETLIST_FILE: "${SYN_OUTPUT}/${DESIGN_TOP}.v"
  SDC_FILE: "${SYN_OUTPUT}/${DESIGN_TOP}.sdc"
  
  # ========== 库文件 ==========
  LIB_ROOT: "${PROJECT_ROOT}/design/lib"
  TECH_FILE: "${LIB_ROOT}/tech/tech.tf"
  LEF_FILES:
    - "${LIB_ROOT}/stdcell/stdcell.lef"
    - "${LIB_ROOT}/macro/macro.lef"
    - "${LIB_ROOT}/io/io.lef"
  
  # ========== APR 路径 ==========
  APR_ROOT: "${PROJECT_ROOT}/flow/apr"
  APR_SCRIPT: "${APR_ROOT}/scripts"
  APR_OUTPUT: "${APR_ROOT}/outputs"
  
  # ========== APR 参数 ==========
  CORE_UTILIZATION: 70          # %
  CORE_TO_IO_DISTANCE: 50       # um
  TARGET_FREQUENCY: 500         # MHz
  POWER_NETS: "VDD, VSS"
  
  # ========== APR 工具 ==========
  APR_TOOL: "Innovus"           # 或 "ICC2"

TASK:
  # ========== APR 初始化 ==========
  apr_init:
    DESCRIPTION: "APR 初始化"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${APR_ROOT} && make init"
    
    DEPENDENCY:
      FILE:
        - "${NETLIST_FILE}"
        - "${SDC_FILE}"
        - "${TECH_FILE}"
      LICENSE:
        tool: "${APR_TOOL}"
        count: 1
    
    OUTPUT:
      - "${APR_ROOT}/work/init_setup"
    
    TIMEOUT: "2h"

  # ========== 布图规划 ==========
  apr_floorplan:
    DESCRIPTION: "布图规划"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${APR_ROOT} && make floorplan"
    
    DEPENDENCY:
      TASK:
        - apr_init
    
    OUTPUT:
      - "${APR_ROOT}/work/floorplan.def"
    
    CHECK:
      check_area:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_floorplan.py"
        threshold:
          utilization_max: 80
          aspect_ratio_range: "0.5-2.0"
    
    TIMEOUT: "4h"

  # ========== 布局 ==========
  apr_placement:
    DESCRIPTION: "布局优化"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${APR_ROOT} && make placement"
    
    DEPENDENCY:
      TASK:
        - apr_floorplan
    
    OUTPUT:
      - "${APR_ROOT}/work/placement.def"
    
    CHECK:
      check_congestion:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_congestion.py"
        threshold:
          congestion_max: 5      # %
    
    TIMEOUT: "8h"

  # ========== 时钟树综合 ==========
  apr_cts:
    DESCRIPTION: "时钟树综合"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${APR_ROOT} && make cts"
    
    DEPENDENCY:
      TASK:
        - apr_placement
    
    OUTPUT:
      - "${APR_ROOT}/work/cts.def"
    
    CHECK:
      check_clock_tree:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_cts.py"
        threshold:
          skew_max: 0.1          # ns
          insertion_delay_max: 1.0  # ns
    
    TIMEOUT: "6h"

  # ========== 布线 ==========
  apr_routing:
    DESCRIPTION: "布线"
    RUN_METHOD: bsub
    RUN_MODE: RUN
    RUN_CMD: "cd ${APR_ROOT} && make routing"
    
    DEPENDENCY:
      TASK:
        - apr_cts
    
    OUTPUT:
      - "${APR_OUTPUT}/${DESIGN_TOP}.gds"
      - "${APR_OUTPUT}/${DESIGN_TOP}.v"
      - "${APR_OUTPUT}/${DESIGN_TOP}.sdf"
    
    CHECK:
      check_timing:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_timing.py"
      check_drc:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_drc.py"
        threshold:
          violation_max: 0
      check_lvs:
        script: "${PROJECT_ROOT}/ifp/scripts/ic_check/check_lvs.py"
        threshold:
          mismatch_max: 0
    
    TIMEOUT: "12h"

  # ========== 输出 ==========
  apr_export:
    DESCRIPTION: "导出最终文件"
    RUN_METHOD: local
    RUN_MODE: RUN
    RUN_CMD: "cd ${APR_ROOT} && make export"
    
    DEPENDENCY:
      TASK:
        - apr_routing
    
    TIMEOUT: "2h"

FLOW:
  # ========== APR 主流程 ==========
  apr_flow:
    DESCRIPTION: "完整 APR 流程"
    TASKS:
      - apr_init
      - apr_floorplan
      - apr_placement
      - apr_cts
      - apr_routing
      - apr_export
    SEQUENCE: true

```

---

## 5. API 扩展配置示例

### 5.1 api.yaml 完整示例

```yaml
# /home/user/project/ifp/api.yaml
# IFP API 扩展配置

# ========== PRE_CFG 扩展 ==========
PRE_CFG:
  # 环境检查
  env_check:
    script: "${PROJECT_ROOT}/ifp/scripts/check_environment.py"
    description: "检查项目环境和依赖"
    timeout: "5m"
    required: true             # 必须通过才能继续
  
  # 工具版本检查
  tool_version:
    script: "${PROJECT_ROOT}/ifp/scripts/check_tool_version.py"
    description: "检查 EDA 工具版本"
    timeout: "2m"
    required: true
  
  # Git 状态检查
  git_status:
    script: "${PROJECT_ROOT}/ifp/scripts/check_git_status.py"
    description: "检查 Git 工作区状态"
    timeout: "1m"
    required: false           # 可选检查

# ========== PRE_IFP 扩展 ==========
PRE_IFP:
  # 项目初始化
  project_init:
    script: "${PROJECT_ROOT}/ifp/scripts/init_project.py"
    description: "初始化项目工作空间"
    timeout: "10m"
    
  # License 预分配
  license_preallocate:
    script: "${PROJECT_ROOT}/ifp/scripts/preallocate_license.py"
    description: "预分配 EDA 工具 License"
    timeout: "5m"
    
  # 历史数据加载
  load_history:
    script: "${PROJECT_ROOT}/ifp/scripts/load_history.py"
    description: "加载历史运行数据"
    timeout: "5m"

# ========== 右键菜单扩展 ==========
TABLE_RIGHT_KEY_MENU:
  # 任务菜单
  task_menu:
    label: "任务操作"
    cascade:
      - label: "查看日志"
        command: "${PROJECT_ROOT}/ifp/scripts/view_log.py"
        shortcut: "Ctrl+L"
      
      - label: "重新运行"
        command: "${PROJECT_ROOT}/ifp/scripts/rerun_task.py"
        shortcut: "Ctrl+R"
      
      - label: "查看报告"
        command: "${PROJECT_ROOT}/ifp/scripts/view_report.py"
        shortcut: "Ctrl+E"
      
      - label: "生成对比报告"
        command: "${PROJECT_ROOT}/ifp/scripts/gen_comparison.py"
        shortcut: "Ctrl+C"
      
      - separator: true
      
      - label: "导出任务配置"
        command: "${PROJECT_ROOT}/ifp/scripts/export_task_config.py"
      
      - label: "复制任务"
        command: "${PROJECT_ROOT}/ifp/scripts/copy_task.py"
      
      - label: "删除任务"
        command: "${PROJECT_ROOT}/ifp/scripts/delete_task.py"
        shortcut: "Delete"

  # 流程菜单
  flow_menu:
    label: "流程操作"
    cascade:
      - label: "运行整个流程"
        command: "${PROJECT_ROOT}/ifp/scripts/run_flow.py"
        shortcut: "F5"
      
      - label: "暂停流程"
        command: "${PROJECT_ROOT}/ifp/scripts/pause_flow.py"
        shortcut: "F6"
      
      - label: "恢复流程"
        command: "${PROJECT_ROOT}/ifp/scripts/resume_flow.py"
        shortcut: "F7"
      
      - label: "停止流程"
        command: "${PROJECT_ROOT}/ifp/scripts/stop_flow.py"
        shortcut: "F8"

  # 工具菜单
  tool_menu:
    label: "工具"
    cascade:
      - label: "时序分析"
        command: "${PROJECT_ROOT}/ifp/scripts/run_sta.py"
      
      - label: "功耗分析"
        command: "${PROJECT_ROOT}/ifp/scripts/run_power.py"
      
      - label: "形式验证"
        command: "${PROJECT_ROOT}/ifp/scripts/run_formal.py"
      
      - separator: true
      
      - label: "生成统计报告"
        command: "${PROJECT_ROOT}/ifp/scripts/gen_stats.py"

# ========== 自定义命令 ==========
CUSTOM_COMMANDS:
  # 快速检查
  quick_check:
    shortcut: "Ctrl+Q"
    script: "${PROJECT_ROOT}/ifp/scripts/quick_check.py"
    description: "快速质量检查"
  
  # 全量检查
  full_check:
    shortcut: "Ctrl+F"
    script: "${PROJECT_ROOT}/ifp/scripts/full_check.py"
    description: "全量质量检查"

# ========== 监控扩展 ==========
MONITOR:
  # 自定义监控指标
  custom_metrics:
    - name: "timing_slack"
      script: "${PROJECT_ROOT}/ifp/scripts/monitor_timing.py"
      interval: 300           # 5分钟
      
    - name: "area_utilization"
      script: "${PROJECT_ROOT}/ifp/scripts/monitor_area.py"
      interval: 600           # 10分钟
  
  # 告警配置
  alerts:
    - name: "timing_violation"
      condition: "slack < 0"
      action: "${PROJECT_ROOT}/ifp/scripts/alert_timing.py"
      level: "high"
    
    - name: "area_overflow"
      condition: "utilization > 85"
      action: "${PROJECT_ROOT}/ifp/scripts/alert_area.py"
      level: "medium"

```

### 5.2 常用扩展脚本示例

#### 5.2.1 check_environment.py

```python
#!/usr/bin/env python3
# /home/user/project/ifp/scripts/check_environment.py
# 环境检查脚本

import os
import sys
import yaml
import subprocess
from pathlib import Path

def check_environment():
    """检查项目环境配置"""
    
    # 获取项目根目录
    project_root = os.environ.get('PROJECT_ROOT')
    if not project_root:
        print("错误: PROJECT_ROOT 环境变量未设置")
        return False
    
    # 检查必需目录
    required_dirs = [
        'design/rtl',
        'design/lib',
        'flow',
        'ifp'
    ]
    
    for dir_path in required_dirs:
        full_path = os.path.join(project_root, dir_path)
        if not os.path.exists(full_path):
            print(f"错误: 目录不存在 {full_path}")
            return False
        print(f"✓ 目录检查通过: {dir_path}")
    
    # 检查配置文件
    config_files = [
        'ifp/default.yaml',
        'ifp/ifp.cfg.yaml'
    ]
    
    for file_path in config_files:
        full_path = os.path.join(project_root, file_path)
        if not os.path.exists(full_path):
            print(f"错误: 配置文件不存在 {full_path}")
            return False
        print(f"✓ 配置文件检查通过: {file_path}")
    
    # 检查环境变量
    required_vars = [
        'SYNOPSYS_LICENSE_FILE',
        'DC_HOME'
    ]
    
    for var in required_vars:
        if not os.environ.get(var):
            print(f"警告: 环境变量未设置 {var}")
        else:
            print(f"✓ 环境变量设置: {var}")
    
    # 检查工具可用性
    tools = ['dc_shell', 'innovus', 'vcs']
    for tool in tools:
        try:
            subprocess.run([tool, '-version'], 
                          capture_output=True, timeout=5)
            print(f"✓ 工具可用: {tool}")
        except:
            print(f"警告: 工具不可用 {tool}")
    
    print("\n========== 环境检查完成 ==========")
    return True

if __name__ == '__main__':
    success = check_environment()
    sys.exit(0 if success else 1)

```

#### 5.2.2 init_project.py

```python
#!/usr/bin/env python3
# /home/user/project/ifp/scripts/init_project.py
# 项目初始化脚本

import os
import sys
import json
import sqlite3
from pathlib import Path
from datetime import datetime

def init_project():
    """初始化项目工作空间"""
    
    project_root = os.environ.get('PROJECT_ROOT')
    if not project_root:
        print("错误: PROJECT_ROOT 未设置")
        return False
    
    workspace = os.path.join(project_root, 'workspace', '.ifp')
    
    # 创建目录结构
    dirs_to_create = [
        workspace,
        os.path.join(workspace, 'db'),
        os.path.join(workspace, 'logs'),
        os.path.join(workspace, 'cache'),
        os.path.join(workspace, 'cache', 'predictions'),
        os.path.join(workspace, 'cache', 'reports'),
        os.path.join(workspace, 'temp'),
        os.path.join(workspace, 'pid'),
    ]
    
    for dir_path in dirs_to_create:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
        print(f"✓ 创建目录: {dir_path}")
    
    # 初始化数据库
    db_path = os.path.join(workspace, 'db', 'tasks.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 创建任务表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            status TEXT DEFAULT 'pending',
            run_method TEXT,
            run_cmd TEXT,
            start_time TEXT,
            end_time TEXT,
            duration REAL,
            lsf_job_id TEXT,
            retry_count INTEGER DEFAULT 0,
            output TEXT,
            error TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    ''')
    
    # 创建历史表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_name TEXT,
            flow_name TEXT,
            status TEXT,
            start_time TEXT,
            end_time TEXT,
            duration REAL,
            lsf_job_id TEXT,
            memory_used REAL,
            cpu_usage REAL,
            checkpoint TEXT,
            created_at TEXT
        )
    ''')
    
    conn.commit()
    conn.close()
    print(f"✓ 初始化数据库: {db_path}")
    
    # 创建项目元数据
    metadata = {
        'project_name': os.environ.get('PROJECT_NAME', 'unknown'),
        'project_root': project_root,
        'design_top': os.environ.get('DESIGN_TOP', 'top'),
        'created_at': datetime.now().isoformat(),
        'ifp_version': '1.4.3',
        'workspace': workspace
    }
    
    metadata_path = os.path.join(workspace, 'project_meta.json')
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"✓ 创建元数据: {metadata_path}")
    
    print("\n========== 项目初始化完成 ==========")
    return True

if __name__ == '__main__':
    success = init_project()
    sys.exit(0 if success else 1)

```

---

## 6. Checklist 脚本示例

### 6.1 check_timing.py

```python
#!/usr/bin/env python3
# /home/user/project/ifp/scripts/ic_check/check_timing.py
# 时序检查脚本

import os
import sys
import re
import argparse
import pandas as pd
from openpyxl import Workbook
from pathlib import Path

def parse_timing_report(report_path):
    """解析时序报告"""
    
    results = {
        'slack_min': None,
        'slack_max': None,
        'timing_violations': 0,
        'critical_paths': [],
        'summary': {}
    }
    
    with open(report_path, 'r') as f:
        content = f.read()
    
    # 提取 Slack 信息
    slack_pattern = r'slack\s+([\d.-]+)'
    slacks = re.findall(slack_pattern, content)
    if slacks:
        slacks_float = [float(s) for s in slacks]
        results['slack_min'] = min(slacks_float)
        results['slack_max'] = max(slacks_float)
        results['timing_violations'] = len([s for s in slacks_float if s < 0])
    
    # 提取关键路径信息
    path_pattern = r'Path\s+(\d+):\s+.*?slack\s+([\d.-]+)'
    paths = re.findall(path_pattern, content)
    for path_id, slack in paths[:10]:  # 取前10条路径
        results['critical_paths'].append({
            'path_id': int(path_id),
            'slack': float(slack)
        })
    
    # 提取总结信息
    if 'Timing Summary' in content:
        summary_section = content.split('Timing Summary')[1].split('\n\n')[0]
        results['summary']['raw'] = summary_section
    
    return results

def check_timing(report_path, threshold_slack=0.0):
    """执行时序检查"""
    
    print(f"========== 时序检查 ========== ")
    print(f"报告文件: {report_path}")
    print(f"Slack 阈值: {threshold_slack} ns")
    
    # 解析报告
    results = parse_timing_report(report_path)
    
    # 输出结果
    print(f"\n时序分析结果:")
    print(f"  最小 Slack: {results['slack_min']} ns")
    print(f"  最大 Slack: {results['slack_max']} ns")
    print(f"  时序违例数: {results['timing_violations']}")
    
    # 判断结果
    pass_status = True
    if results['slack_min'] is not None and results['slack_min'] < threshold_slack:
        pass_status = False
        print(f"\n❌ 时序检查失败: Slack {results['slack_min']} < 阈值 {threshold_slack}")
    else:
        print(f"\n✓ 时序检查通过")
    
    # 生成详细报告
    wb = Workbook()
    ws = wb.active
    ws.title = "Timing Check"
    
    # 写入检查结果
    ws.append(['检查项', '值', '阈值', '状态'])
    ws.append(['最小 Slack', results['slack_min'], threshold_slack, 'PASS' if results['slack_min'] >= threshold_slack else 'FAIL'])
    ws.append(['时序违例数', results['timing_violations'], 0, 'PASS' if results['timing_violations'] == 0 else 'FAIL'])
    ws.append([''])
    
    # 写入关键路径
    ws.append(['关键路径分析'])
    ws.append(['路径ID', 'Slack (ns)', '状态'])
    for path in results['critical_paths']:
        ws.append([path['path_id'], path['slack'], 'VIOLATION' if path['slack'] < 0 else 'MET'])
    
    # 保存报告
    report_output = Path(report_path).parent / 'check_timing.xlsx'
    wb.save(report_output)
    print(f"\n详细报告: {report_output}")
    
    return pass_status

def main():
    parser = argparse.ArgumentParser(description='时序检查脚本')
    parser.add_argument('--report', required=True, help='时序报告文件路径')
    parser.add_argument('--threshold', type=float, default=0.0, help='Slack 阈值')
    
    args = parser.parse_args()
    
    success = check_timing(args.report, args.threshold)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()

```

### 6.2 check_area.py

```python
#!/usr/bin/env python3
# /home/user/project/ifp/scripts/ic_check/check_area.py
# 面积检查脚本

import os
import sys
import re
import argparse
from openpyxl import Workbook

def parse_area_report(report_path):
    """解析面积报告"""
    
    results = {
        'total_area': 0,
        'module_areas': {},
        'cell_count': 0,
        'cell_types': {}
    }
    
    with open(report_path, 'r') as f:
        content = f.read()
    
    # 提取总面积
    total_pattern = r'Total cell area:\s+([\d.]+)'
    match = re.search(total_pattern, content)
    if match:
        results['total_area'] = float(match.group(1))
    
    # 提取模块面积
    module_pattern = r'(\w+)\s+([\d.]+)\s+([\d.]+)'
    modules = re.findall(module_pattern, content)
    for module_name, area, count in modules:
        results['module_areas'][module_name] = {
            'area': float(area),
            'count': int(count)
        }
    
    # 提取单元类型统计
    cell_type_pattern = r'(\w+)\s+(\d+)\s+([\d.]+)'
    cell_types = re.findall(cell_type_pattern, content)
    for cell_type, count, area in cell_types:
        results['cell_types'][cell_type] = {
            'count': int(count),
            'area': float(area)
        }
        results['cell_count'] += int(count)
    
    return results

def check_area(report_path, threshold_area=None, threshold_utilization=None):
    """执行面积检查"""
    
    print(f"========== 面积检查 ========== ")
    print(f"报告文件: {report_path}")
    
    # 解析报告
    results = parse_area_report(report_path)
    
    # 输出结果
    print(f"\n面积分析结果:")
    print(f"  总面积: {results['total_area']} um²")
    print(f"  单元数: {results['cell_count']}")
    
    if threshold_area:
        print(f"  面积阈值: {threshold_area} um²")
    if threshold_utilization:
        print(f"  利用率阈值: {threshold_utilization} %")
    
    # 判断结果
    pass_status = True
    
    if threshold_area and results['total_area'] > threshold_area:
        pass_status = False
        print(f"\n❌ 面积检查失败: {results['total_area']} > 阈值 {threshold_area}")
    
    if threshold_utilization:
        # 计算利用率 (需要 Core Area 信息)
        core_area = os.environ.get('CORE_AREA', 100000)
        utilization = results['total_area'] / float(core_area) * 100
        print(f"  计算利用率: {utilization:.2f} %")
        
        if utilization > threshold_utilization:
            pass_status = False
            print(f"❌ 利用率检查失败: {utilization:.2f} > 阈值 {threshold_utilization}")
    
    if pass_status:
        print(f"\n✓ 面积检查通过")
    
    # 生成报告
    wb = Workbook()
    ws = wb.active
    ws.title = "Area Check"
    
    ws.append(['检查项', '值', '阈值', '状态'])
    ws.append(['总面积', results['total_area'], threshold_area or 'N/A', 
               'PASS' if not threshold_area or results['total_area'] <= threshold_area else 'FAIL'])
    ws.append(['单元数', results['cell_count'], 'N/A', 'INFO'])
    ws.append([''])
    
    ws.append(['模块面积分布'])
    ws.append(['模块名', '面积', '数量'])
    for module, data in results['module_areas'].items():
        ws.append([module, data['area'], data['count']])
    
    report_output = Path(report_path).parent / 'check_area.xlsx'
    wb.save(report_output)
    print(f"\n详细报告: {report_output}")
    
    return pass_status

def main():
    parser = argparse.ArgumentParser(description='面积检查脚本')
    parser.add_argument('--report', required=True, help='面积报告文件路径')
    parser.add_argument('--threshold', type=float, default=None, help='面积阈值')
    parser.add_argument('--utilization', type=float, default=None, help='利用率阈值')
    
    args = parser.parse_args()
    
    success = check_area(args.report, args.threshold, args.utilization)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()

```

---

## 7. 最佳实践总结

### 7.1 配置管理最佳实践

| 实践项 | 建议 | 原因 |
|-------|------|------|
| 配置文件版本控制 | 将 `default.yaml` 纳入 Git 管理 | 便于追溯和团队协作 |
| 使用变量替换 | 优先使用 `${VAR}` 而非硬编码路径 | 提高配置可移植性 |
| 分离敏感信息 | License/密码等放入 `ifp.cfg.yaml` (不入库) | 安全性考量 |
| 模块化配置 | 按 Flow 类型拆分配置文件 | 减少配置复杂度 |
| 配置模板复用 | 创建模板库供新项目使用 | 提高效率 |

### 7.2 任务设计最佳实践

| 实践项 | 建议 | 原因 |
|-------|------|------|
| 单一职责 | 每个 TASK 只做一件事 | 易于调试和维护 |
| 合理依赖 | 最小化 DEPENDENCY 依赖链 | 减少等待时间 |
| 明确输出 | 明确声明 OUTPUT 文件 | IFP 可自动检查产出 |
| 设置超时 | 为所有 TASK 设置 TIMEOUT | 防止任务无限挂起 |
| 错误处理 | 使用 RETRY + CHECK 组合 | 提高可靠性 |

### 7.3 Checklist 最佳实践

| 实践项 | 建议 | 原因 |
|-------|------|------|
| 阈值合理 | 设置实际可达的阈值 | 避免 false positive/negative |
| 报告格式 | 使用 Excel 格式输出报告 | 便于审查和归档 |
| 分层检查 | 分 quick/full 两级检查 | 平衡速度和质量 |
| 持续优化 | 根据历史数据调整阈值 | 适应项目演进 |

### 7.4 LSF 使用最佳实践

| 实践项 | 建议 | 原因 |
|-------|------|------|
| 资源预估 | 使用 ML 预测内存需求 | 减少资源浪费 |
| 合理队列 | 根据任务类型选择队列 | 提高调度效率 |
| 监控集成 | 启用 LSF Monitor 服务 | 实时跟踪任务状态 |
| Job Group | 使用 `-JG` 组织相关任务 | 管理便捷 |

### 7.5 团队协作最佳实践

| 实践项 | 建议 | 原因 |
|-------|------|------|
| 统一环境 | 团队统一 IFP 版本和环境 | 避免兼容问题 |
| 配置共享 | 共享模板配置库 | 提高效率 |
| 文档先行 | 新流程先写文档再配置 | 减少沟通成本 |
| 定期复盘 | 定期审查历史数据和报告 | 持续改进 |

---

## 8. 常见问题与解决方案

### 8.1 配置问题

| 问题 | 原因 | 解决方案 |
|-----|------|---------|
| 变量未替换 | `${VAR}` 引用未定义变量 | 检查 VAR 段定义 |
| 路径不存在 | 环境变量路径错误 | 使用绝对路径或验证变量 |
| 依赖死循环 | TASK 相互依赖 | 检查依赖图，移除循环 |
| License 检查失败 | License Server 不可用 | 检查网络和 License 配置 |

### 8.2 任务执行问题

| 问题 | 原因 | 解决方案 |
|-----|------|---------|
| 任务一直 pending | 依赖任务未完成 | 检查上游任务状态 |
| LSF Job 失败 | 资源不足/配置错误 | 检查 bsub 参数 |
| 超时触发 | TIMEOUT 设置过短 | 根据实际需求调整 |
| CHECK 误报 | 阈值设置不合理 | 调整阈值或检查脚本 |

### 8.3 工具集成问题

| 问题 | 原因 | 解决方案 |
|-----|------|---------|
| 工具启动失败 | 环境变量未设置 | 检查 ENV 配置 |
| License 冲突 | 多任务竞争 License | 使用 DEPENDENCY 控制 |
| 输出路径错误 | 工具输出到默认位置 | 明确指定输出路径 |

---

## 附录 A: 命令速查表

### IFP CLI 常用命令

| 命令 | 说明 |
|-----|------|
| `ifp` | 启动 IFP GUI |
| `ifp --config ./ifp/default.yaml` | 指定配置文件 |
| `ifp --debug` | 启动调试模式 |
| `ifp --no-monitor` | 禁用 LSF Monitor |
| `ifp --task syn_main` | 直接运行指定任务 |
| `ifp --flow syn_flow` | 运行指定流程 |

### IFP GUI 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+S` | 保存配置 |
| `Ctrl+R` | 刷新任务列表 |
| `Ctrl+L` | 查看日志 |
| `Ctrl+E` | 查看报告 |
| `F5` | 运行选中任务 |
| `F6` | 暂停任务 |
| `F7` | 恢复任务 |
| `F8` | 停止任务 |

---

## 附录 B: 参考资源

| 资源 | 链接 |
|-----|------|
| IFP GitHub | https://github.com/bytedance/ic_flow_platform |
| IFP 文档 | https://github.com/bytedance/ic_flow_platform/tree/main/docs |
| Design Compiler 用户手册 | Synopsys SolvNet |
| Innovus 用户手册 | Cadence Documentation |
| VCS 用户手册 | Synopsys SolvNet |
| LSF 文档 | IBM Platform LSF Documentation |

---

**文档版本**: 1.0
**最后更新**: 2026-05-13
**适用 IFP 版本**: V1.4.3