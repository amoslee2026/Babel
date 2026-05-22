# IFP 配置文件详解

本文档详细解析IFP的配置文件结构、YAML语法、变量系统和配置加载机制。

---

## 1. 配置文件体系

### 1.1 配置文件层次结构

IFP采用多层次的配置体系，支持灵活的配置继承和覆盖。

```
配置层次（从低到高优先级递增）:

┌────────────────────────────────────────────────────────────┐
│ Level 1: 系统配置 (config.py)                              │
│ 位置: $IFP_INSTALL_PATH/config/config.py                  │
│ 类型: Python常量定义                                       │
│ 内容: 安装路径、默认值、系统常量                           │
│ 优先级: 最低                                               │
└────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────┐
│ Level 2: 全局流程定义 (default.yaml)                       │
│ 位置: $IFP_INSTALL_PATH/config/default.yaml               │
│ 类型: YAML流程定义                                         │
│ 内容: VAR变量、TASK定义、FLOW定义                          │
│ 优先级: 中等                                               │
└────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────┐
│ Level 3: 项目组专属配置                                    │
│ 位置: $IFP_INSTALL_PATH/config/default.{project}.{group}.yaml│
│ 类型: YAML覆盖配置                                         │
│ 内容: 项目组特定的VAR、TASK、FLOW                          │
│ 优先级: 高                                                 │
└────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────┐
│ Level 4: API扩展配置 (api.yaml)                            │
│ 位置: $IFP_INSTALL_PATH/config/api.yaml                   │
│ 类型: YAML扩展定义                                         │
│ 内容: PRE_CFG、PRE_IFP、TABLE_RIGHT_KEY_MENU              │
│ 优先级: 与default.yaml同级                                 │
└────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────┐
│ Level 5: 用户运行时配置 (ifp.cfg.yaml)                     │
│ 位置: <工作目录>/ifp.cfg.yaml                              │
│ 类型: YAML用户配置                                         │
│ 内容: project、group、block、version、flow选择             │
│ 优先级: 最高（用户可编辑）                                 │
└────────────────────────────────────────────────────────────┘
```

### 1.2 配置文件清单

| 文件名 | 位置 | 作用 | 编辑频率 |
|--------|------|------|----------|
| config.py | config/ | Python系统常量 | 极少 |
| default.yaml | config/ | 流程模板定义 | 常用 |
| default.{p}.{g}.yaml | config/ | 项目组专属定义 | 项目级 |
| api.yaml | config/ | API扩展定义 | 常用 |
| ifp.cfg.yaml | 工作目录/ | 用户选择配置 | 频繁 |
| .ifp.status.yaml | 工作目录/ | 状态缓存 | 自动生成 |

---

## 2. config.py 系统配置

### 2.1 文件结构

```python
# config/config.py 源码结构

import os
import sys

# IFP安装路径
IFP_INSTALL_PATH = os.environ.get('IFP_INSTALL_PATH', '')

# Python解释器路径
PYTHON_PATH = sys.executable

# 版本信息
IFP_VERSION = 'V1.4.3'
IFP_RELEASE_DATE = '2025.12.10'

# 目录结构
BIN_PATH = os.path.join(IFP_INSTALL_PATH, 'bin')
COMMON_PATH = os.path.join(IFP_INSTALL_PATH, 'common')
CONFIG_PATH = os.path.join(IFP_INSTALL_PATH, 'config')
ACTION_PATH = os.path.join(IFP_INSTALL_PATH, 'action')
TOOLS_PATH = os.path.join(IFP_INSTALL_PATH, 'tools')

# 配置文件名
DEFAULT_CONFIG_FILE = 'default.yaml'
API_CONFIG_FILE = 'api.yaml'
USER_CONFIG_FILE = 'ifp.cfg.yaml'
STATUS_FILE = '.ifp.status.yaml'

# 任务状态定义
STATUS_PENDING = 'pending'
STATUS_RUNNING = 'running'
STATUS_PASS = 'pass'
STATUS_FAIL = 'fail'

# 动作类型定义
ACTION_BUILD = 'build'
ACTION_RUN = 'run'
ACTION_CHECK = 'check'
ACTION_SUMMARIZE = 'summarize'
ACTION_RELEASE = 'release'

# 默认变量
DEFAULT_MAX_RUNNING_JOBS = 10
DEFAULT_RUN_METHOD = 'local'

# GUI配置
WINDOW_WIDTH = 1200
WINDOW_HEIGHT = 800
TABLE_ROW_HEIGHT = 30

# 日志配置
LOG_LEVEL = 'INFO'
LOG_FORMAT = '%(asctime)s - %(levelname)s - %(message)s'

# 数据库配置
DB_TYPE = 'sqlite'
DB_NAME = 'ifp_status.db'

# LSF配置
LSF_CHECK_INTERVAL = 30  # 秒
LSF_MAX_RETRY = 3
```

### 2.2 使用方式

```python
# 在其他模块中导入
import sys
sys.path.append(os.environ['IFP_INSTALL_PATH'] + '/config')
import config as install_config

# 使用配置常量
print(install_config.IFP_VERSION)
# V1.4.3

default_yaml = os.path.join(install_config.CONFIG_PATH, install_config.DEFAULT_CONFIG_FILE)
# /path/to/ic_flow_platform/config/default.yaml
```

---

## 3. default.yaml 流程定义

### 3.1 整体结构

default.yaml是IFP的核心配置文件，定义了整个流程的框架。

```yaml
# default.yaml 整体结构

# ========== VAR部分：变量定义 ==========
VAR:
  # 全局变量
  BSUB_QUEUE: normal
  DEFAULT_PATH: ${CWD}/${BLOCK}/${VERSION}
  ...
  
  # 任务相关变量
  SYN_RUN: RUN
  MAX_RUNNING_JOBS: ''
  ...

# ========== TASK部分：任务定义 ==========
TASK:
  # 任务1：综合
  syn_dc:
    BUILD: {...}
    RUN: {...}
    CHECK: {...}
    SUMMARIZE: {...}
    RELEASE: {...}
  
  # 任务2：形式验证
  fm_rtl2gate:
    ...
  
  # 任务3：布局前STA
  presta:
    ...
  
  # 更多任务...

# ========== FLOW部分：流程定义 ==========
FLOW:
  # 流程1：综合流程
  syn:
    - syn_dc
    - fm_rtl2gate
  
  # 流程2：验证流程
  dv:
    - sim_compile
    - sim_run
    - sim_check
  
  # 更多流程...
```

### 3.2 VAR变量定义详解

VAR部分定义全局变量，用于PATH、COMMAND等字段中的变量替换。

```yaml
VAR:
  # ========== LSF集群配置 ==========
  BSUB_QUEUE: ai_syn           # 默认LSF队列
  BSUB_CORES: 4                # 默认CPU核心数
  BSUB_MEMORY: 8000            # 默认内存（MB）
  BSUB_RUN_METHOD: 'bsub -q ${BSUB_QUEUE} -n ${BSUB_CORES} -R "rusage[mem=${BSUB_MEMORY}]"'
  
  # ========== 目录路径配置 ==========
  DEFAULT_PATH: ${CWD}/${BLOCK}/${VERSION}/${FLOW}  # 默认工作路径模板
  LOG_PATH: ${DEFAULT_PATH}/log                     # 日志路径
  REPORT_PATH: ${DEFAULT_PATH}/report               # 报告路径
  
  # ========== 设计数据配置 ==========
  DESIGN_PATH: ${CWD}/design                       # 设计文件路径
  RTL_FILES: ${DESIGN_PATH}/rtl/*.v                # RTL文件列表
  LIB_PATH: ${IFP_INSTALL_PATH}/lib                # 库文件路径
  
  # ========== 工具配置 ==========
  SYN_TOOL: DC                                    # 综合工具（Synopsys Design Compiler）
  FM_TOOL: FM                                     # 形式验证工具（Formality）
  STA_TOOL: PT                                    # 静态时序分析（PrimeTime）
  
  # ========== 执行配置 ==========
  MAX_RUNNING_JOBS: 10                            # 最大并行任务数
  SYN_RUN: RUN                                    # 默认RUN_MODE
  SYN_RUN_DBG: RUN.DBG                            # 调试模式
  
  # ========== 许可配置 ==========
  DC_LICENSE: 5                                   # DC许可数量
  FM_LICENSE: 2                                   # FM许可数量
  PT_LICENSE: 3                                   # PT许可数量
  
  # ========== CHECK配置 ==========
  CHECK_SCRIPT: ${IFP_INSTALL_PATH}/action/check/scripts/ic_check.py
  VIEWER_TOOL: firefox                            # 报告查看器
  
  # ========== 时间戳格式 ==========
  TIMESTAMP_FORMAT: '%Y%m%d_%H%M%S'
```

**变量命名规范**：

| 类型 | 前缀 | 示例 |
|------|------|------|
| 路径类 | `_PATH` | `DEFAULT_PATH`, `LOG_PATH` |
| 文件类 | `_FILES` | `RTL_FILES`, `LIB_FILES` |
| 工具类 | `_TOOL` | `SYN_TOOL`, `FM_TOOL` |
| 许可类 | `_LICENSE` | `DC_LICENSE`, `FM_LICENSE` |
| LSF类 | `BSUB_` | `BSUB_QUEUE`, `BSUB_CORES` |
| 执行类 | 无前缀 | `MAX_RUNNING_JOBS`, `SYN_RUN` |

### 3.3 TASK任务定义详解

每个TASK包含5个阶段的配置：BUILD、RUN、CHECK、SUMMARIZE、RELEASE。

```yaml
TASK:
  # ========== 综合任务示例 ==========
  syn_dc:
    # ===== BUILD阶段：创建工作目录 =====
    BUILD:
      PATH: ${DEFAULT_PATH}/syn_dc         # 工作目录路径
      COMMAND: mkdir -p ${PATH}/run ${PATH}/check ${PATH}/log
      # COMMAND详解：
      #   mkdir -p 创建目录（含父目录）
      #   ${PATH}/run     - RUN阶段输出目录
      #   ${PATH}/check   - CHECK阶段输出目录
      #   ${PATH}/log     - 日志目录
      LOG: ${PATH}/log/build.log           # BUILD日志
      RUN_METHOD: local                     # 本地执行（不提交LSF）
    
    # ===== RUN阶段：执行综合 =====
    RUN:
      PATH: ${DEFAULT_PATH}/syn_dc         # 执行目录
      COMMAND: dc_shell -f syn.tcl         # 综合命令
      # COMMAND详解：
      #   dc_shell   - Synopsys DC工具
      #   -f syn.tcl - 执行TCL脚本
      
      RUN_METHOD: ${BSUB_RUN_METHOD}       # 使用LSF提交
      # RUN_METHOD详解：
      #   local         - 本地直接执行
      #   bsub -q queue  - 提交到指定队列
      #   bsub -q queue -n cores -R "rusage" - 完整LSF命令
      
      LOG: ${PATH}/log/run.log             # RUN日志
      RUN_MODE: ${SYN_RUN}                 # 默认RUN_MODE
      
      # RUN_MODE变体（可选）
      RUN.DBG:
        COMMAND: dc_shell -f syn_dbg.tcl   # 调试版本
        LOG: ${PATH}/log/run_dbg.log
      
      RUN.option1:
        COMMAND: dc_shell -f syn_opt1.tcl  # 选项1版本
        RUN_METHOD: local                  # 本地执行
      
      # 任务依赖（可选）
      RUN_AFTER:
        TASK: initial                      # 前置任务名
      
      # 其他依赖（可选）
      DEPENDENCY:
        FILE:                              # 文件依赖
          - ${DESIGN_PATH}/rtl/top.v       # 必须存在的设计文件
          - ${CWD}/setup.txt               # 必须存在的配置文件
        LICENSE:                           # 许可依赖
          - DC 5                           # 需要5个DC许可
    
    # ===== CHECK阶段：质量检查 =====
    CHECK:
      PATH: ${DEFAULT_PATH}/syn_dc/check   # CHECK目录
      COMMAND: python3 ${CHECK_SCRIPT} -d ${PATH} -f syn -b ${BLOCK}
      # CHECK命令详解：
      #   ic_check.py  - IFP检查脚本
      #   -d ${PATH}   - 检查目录
      #   -f syn       - 流程类型
      #   -b ${BLOCK}  - 模块名
      
      LOG: ${PATH}/log/check.log           # CHECK日志
      REPORT_FILE: ${PATH}/file_check.rpt  # 检查报告
      VIEWER: ${VIEWER_TOOL} ${REPORT_FILE} # 报告查看命令
      RUN_METHOD: local                     # 本地执行
    
    # ===== SUMMARIZE阶段：数据汇总 =====
    SUMMARIZE:
      PATH: ${DEFAULT_PATH}/syn_dc         # 汇总目录
      COMMAND: python3 ${IFP_INSTALL_PATH}/action/summarize/scripts/gen_summary.py
      LOG: ${PATH}/log/summarize.log
      RUN_METHOD: local
    
    # ===== RELEASE阶段：数据发布 =====
    RELEASE:
      PATH: ${DEFAULT_PATH}/syn_dc
      COMMAND: cp -r ${PATH}/run/* ${RELEASE_PATH}/
      LOG: ${PATH}/log/release.log
      RUN_METHOD: local
  
  # ========== 形式验证任务示例 ==========
  fm_rtl2gate:
    BUILD:
      PATH: ${DEFAULT_PATH}/fm_rtl2gate
      COMMAND: mkdir -p ${PATH}/run ${PATH}/check ${PATH}/log
      LOG: ${PATH}/log/build.log
    
    RUN:
      PATH: ${DEFAULT_PATH}/fm_rtl2gate
      COMMAND: fm_shell -f fm_rtl2gate.tcl
      RUN_METHOD: ${BSUB_RUN_METHOD}
      LOG: ${PATH}/log/run.log
      
      DEPENDENCY:
        FILE:
          - ${DEFAULT_PATH}/syn_dc/run/output/netlist.v  # 综合输出
        LICENSE:
          - FM 2
      
      RUN_AFTER:
        TASK: syn_dc                       # 必须等syn_dc完成
    
    CHECK:
      PATH: ${DEFAULT_PATH}/fm_rtl2gate/check
      COMMAND: python3 ${CHECK_SCRIPT} -d ${PATH} -f fm -b ${BLOCK}
      REPORT_FILE: ${PATH}/file_check.rpt
      VIEWER: ${VIEWER_TOOL} ${REPORT_FILE}
  
  # ========== 验证任务示例 ==========
  sim_compile:
    BUILD:
      PATH: ${DEFAULT_PATH}/sim_compile
      COMMAND: mkdir -p ${PATH}/run ${PATH}/log
    
    RUN:
      PATH: ${DEFAULT_PATH}/sim_compile
      COMMAND: make compile                 # Makefile编译
      RUN_METHOD: local
      LOG: ${PATH}/log/run.log
      
      DEPENDENCY:
        FILE:
          - ${DESIGN_PATH}/rtl/*.v
          - ${CWD}/verif/sim/Makefile
  
  sim_run:
    BUILD:
      PATH: ${DEFAULT_PATH}/sim_run
      COMMAND: mkdir -p ${PATH}/run ${PATH}/log
    
    RUN:
      PATH: ${DEFAULT_PATH}/sim_run
      COMMAND: make run TEST=${TEST_NAME}
      RUN_METHOD: ${BSUB_RUN_METHOD}
      LOG: ${PATH}/log/run.log
      
      RUN_AFTER:
        TASK: sim_compile                   # 依赖编译
      
      # 变量注入
      VAR:
        TEST_NAME: basic_test               # 默认测试名
  
  # ========== 更多任务示例 ==========
  presta:
    BUILD:
      PATH: ${DEFAULT_PATH}/presta
      COMMAND: mkdir -p ${PATH}/run ${PATH}/check ${PATH}/log
    
    RUN:
      PATH: ${DEFAULT_PATH}/presta
      COMMAND: pt_shell -f sta.tcl
      RUN_METHOD: ${BSUB_RUN_METHOD}
      LOG: ${PATH}/log/run.log
      
      DEPENDENCY:
        FILE:
          - ${DEFAULT_PATH}/syn_dc/run/output/netlist.v
          - ${DESIGN_PATH}/lib/*.lib
        LICENSE:
          - PT 3
      
      RUN_AFTER:
        TASK: fm_rtl2gate
```

### 3.4 TASK属性详解

#### BUILD阶段属性

| 属性 | 必需 | 说明 | 示例 |
|------|------|------|------|
| PATH | ✓ | 工作目录路径 | `${DEFAULT_PATH}/syn_dc` |
| COMMAND | ✓ | 创建目录命令 | `mkdir -p ${PATH}/run` |
| LOG | 可选 | 日志文件路径 | `${PATH}/log/build.log` |
| RUN_METHOD | 可选 | 执行方式 | `local`（默认） |

#### RUN阶段属性

| 属性 | 必需 | 说明 | 示例 |
|------|------|------|------|
| PATH | ✓ | 执行目录 | `${DEFAULT_PATH}/syn_dc` |
| COMMAND | ✓ | 执行命令 | `dc_shell -f syn.tcl` |
| RUN_METHOD | ✓ | 执行方式 | `bsub -q ai_syn` |
| LOG | 推荐 | 日志路径 | `${PATH}/log/run.log` |
| RUN_MODE | 可选 | 默认模式 | `RUN` |
| RUN.xxx | 可选 | 模式变体 | `RUN.DBG: {...}` |
| RUN_AFTER | 可选 | 任务依赖 | `TASK: initial` |
| DEPENDENCY.FILE | 可选 | 文件依赖 | `[file1, file2]` |
| DEPENDENCY.LICENSE | 可选 | 许可依赖 | `[DC 5]` |
| VAR | 可选 | 任务级变量 | `TEST_NAME: basic` |

#### CHECK阶段属性

| 属性 | 必需 | 说明 | 示例 |
|------|------|------|------|
| PATH | ✓ | 检查目录 | `${PATH}/check` |
| COMMAND | ✓ | 检查命令 | `python3 ic_check.py` |
| LOG | 推荐 | 日志路径 | `${PATH}/log/check.log` |
| REPORT_FILE | ✓ | 报告路径 | `${PATH}/file_check.rpt` |
| VIEWER | ✓ | 查看命令 | `firefox ${REPORT_FILE}` |
| RUN_METHOD | 可选 | 执行方式 | `local`（默认） |

#### SUMMARIZE阶段属性

| 属性 | 必需 | 说明 | 示例 |
|------|------|------|------|
| PATH | ✓ | 汇总目录 | `${DEFAULT_PATH}/syn_dc` |
| COMMAND | ✓ | 汇总命令 | `python3 gen_summary.py` |
| LOG | 可选 | 日志路径 | `${PATH}/log/summarize.log` |
| RUN_METHOD | 可选 | 执行方式 | `local`（默认） |

#### RELEASE阶段属性

| 属性 | 必需 | 说明 | 示例 |
|------|------|------|------|
| PATH | ✓ | 发布目录 | `${DEFAULT_PATH}/syn_dc` |
| COMMAND | ✓ | 发布命令 | `cp -r output/* release/` |
| LOG | 可选 | 日志路径 | `${PATH}/log/release.log` |
| RUN_METHOD | 可选 | 执行方式 | `local`（默认） |

#### RUN_METHOD详解

RUN_METHOD决定任务执行方式，直接影响资源分配和调度策略。

```
执行方式分类:

┌─────────────────────────────────────────────────────────────┐
│ Local执行                                                   │
│ RUN_METHOD: local（或不设置）                               │
│                                                             │
│ 特点:                                                       │
│ - 在本地机器直接执行                                         │
│ - subprocess.run(cmd, cwd=path, shell=True)                 │
│ - 实时stdout/stderr捕获                                     │
│ - 进程状态直接监控                                           │
│                                                             │
│ 适用场景:                                                    │
│ - BUILD阶段（创建目录）                                      │
│ - CHECK阶段（检查脚本）                                      │
│ - SUMMARIZE/RELEASE阶段                                     │
│ - 小型任务                                                   │
│                                                             │
│ 示例:                                                       │
│ RUN_METHOD: local                                           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ LSF执行                                                     │
│ RUN_METHOD: bsub命令                                        │
│                                                             │
│ 特点:                                                       │
│ - 提交到LSF集群                                              │
│ - 分布式执行                                                 │
│ - bjobs监控状态                                              │
│ - 资源预留                                                   │
│                                                             │
│ bsub命令组成:                                               │
│ bsub -q <queue> -n <cores> -R "rusage[mem=<MB>]" <command> │
│                                                             │
│ 参数详解:                                                    │
│ -q queue     指定队列（normal/ai_syn等）                     │
│ -n cores     CPU核心数                                       │
│ -R rusage    资源使用                                        │
│   mem=MB     内存需求（MB）                                  │
│   span[hosts=1]  单主机                                     │
│ -o file      输出文件                                        │
│ -e file      错误文件                                        │
│ -J job_name  任务名                                          │
│ -P project   项目名                                          │
│                                                             │
│ 适用场景:                                                    │
│ - RUN阶段（综合、验证、STA）                                 │
│ - 资源密集型任务                                             │
│ - 长时间运行任务                                             │
│                                                             │
│ 示例:                                                       │
│ RUN_METHOD: bsub -q ai_syn -n 4 -R "rusage[mem=8000]"       │
│                                                             │
│ 使用变量:                                                    │
│ RUN_METHOD: ${BSUB_RUN_METHOD}                              │
│ BSUB_RUN_METHOD: bsub -q ${BSUB_QUEUE} -n ${BSUB_CORES}...  │
└─────────────────────────────────────────────────────────────┘
```

#### RUN_MODE详解

RUN_MODE允许定义任务的不同执行模式。

```yaml
RUN:
  # 默认模式
  RUN_MODE: ${SYN_RUN}         # 取值: RUN
  
  # 调试模式
  RUN.DBG:
    COMMAND: dc_shell -f syn_dbg.tcl
    LOG: ${PATH}/log/run_dbg.log
    # 切换方式: 在GUI中选择RUN.DBG
  
  # 快速模式
  RUN.fast:
    COMMAND: dc_shell -f syn_fast.tcl
    RUN_METHOD: local          # 本地执行，更快但精度低
  
  # 详尽模式
  RUN.full:
    COMMAND: dc_shell -f syn_full.tcl
    RUN_METHOD: bsub -q high_perf -n 8 -R "rusage[mem=16000]"
    # 更多资源，更高质量
```

### 3.5 FLOW流程定义

FLOW定义任务序列，决定执行顺序。

```yaml
FLOW:
  # ========== 综合流程 ==========
  syn:
    - initial        # 初始化任务
    - syn_dc         # 综合任务
    - fm_rtl2gate    # RTL到门级形式验证
    - presta         # 布局前STA
  
  # ========== 验证流程 ==========
  dv:
    - sim_compile    # 编译仿真环境
    - sim_run        # 运行仿真
    - sim_check      # 检查仿真结果
  
  # ========== 回归验证流程 ==========
  dv_regression:
    - sim_compile
    - sim_run.regression   # 回归测试模式
    - sim_check
    - gen_report
  
  # ========== 全流程 ==========
  full_flow:
    - initial
    - syn_dc
    - fm_rtl2gate
    - presta
    - apr           # 自动布局布线
    - poststa       # 布局后STA
    - drc           # 设计规则检查
    - lvs           # 版图与原理图验证
    - release       # 最终发布
```

**流程依赖自动推导**:

```python
# IFP自动从FLOW推导任务顺序
flow_tasks = config['FLOW']['syn']  # ['initial', 'syn_dc', 'fm_rtl2gate', 'presta']

# 自动添加RUN_AFTER依赖
for i, task in enumerate(flow_tasks):
    if i > 0:
        # syn_dc 自动依赖 initial
        # fm_rtl2gate 自动依赖 syn_dc
        # presta 自动依赖 fm_rtl2gate
        config['TASK'][task]['RUN']['RUN_AFTER'] = {'TASK': flow_tasks[i-1]}
```

---

## 4. 系统变量详解

### 4.1 内置系统变量

IFP提供一组内置系统变量，无需定义，直接可用。

| 变量 | 说明 | 值示例 |
|------|------|--------|
| `CWD` | 当前工作目录 | `/home/user/project/mychip` |
| `IFP_INSTALL_PATH` | IFP安装路径 | `/opt/ifp/current` |
| `USER` | 当前用户名 | `zhangsan` |
| `BLOCK` | 用户选择的模块名 | `cpu_core` |
| `VERSION` | 用户选择的版本名 | `v1.0` |
| `FLOW` | 用户选择的流程名 | `syn` |
| `TASK` | 当前任务名 | `syn_dc` |
| `DATE` | 当前日期 | `20260513` |
| `TIME` | 当前时间 | `143052` |

### 4.2 变量替换规则

变量替换遵循严格的顺序和规则。

```
变量替换流程:

┌─────────────────────────────────────────────────────────────┐
│ Step 1: 收集系统变量                                        │
│                                                             │
│ CWD = os.getcwd()                                          │
│ IFP_INSTALL_PATH = os.environ['IFP_INSTALL_PATH']          │
│ USER = os.environ['USER']                                   │
│ BLOCK = user_config.block                                   │
│ VERSION = user_config.version                               │
│ FLOW = user_config.flow                                     │
│ TASK = current_task_name                                    │
│                                                             │
│ 系统变量字典:                                               │
│ system_vars = {                                            │
│     'CWD': '/home/user/project',                           │
│     'IFP_INSTALL_PATH': '/opt/ifp',                        │
│     'USER': 'zhangsan',                                    │
│     'BLOCK': 'cpu_core',                                   │
│     'VERSION': 'v1.0',                                     │
│     'FLOW': 'syn',                                         │
│     'TASK': 'syn_dc'                                       │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: 收集VAR变量                                         │
│                                                             │
│ 从default.yaml VAR部分读取                                  │
│ var_dict = config['VAR']                                   │
│                                                             │
│ VAR变量字典:                                                │
│ var_dict = {                                               │
│     'BSUB_QUEUE': 'ai_syn',                                │
│     'DEFAULT_PATH': '${CWD}/${BLOCK}/${VERSION}/${FLOW}',  │
│     'SYN_RUN': 'RUN',                                      │
│     ...                                                    │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: 合并变量字典                                         │
│                                                             │
│ final_vars = {**system_vars, **var_dict}                   │
│                                                             │
│ 注意顺序: VAR变量可覆盖系统变量（除了内置的）                 │
│ 但系统变量优先级更高                                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: 递归变量替换                                         │
│                                                             │
│ 使用Template.safe_substitute()                              │
│                                                             │
│ 递归替换所有字符串值中的${VAR}                               │
│                                                             │
│ 示例:                                                       │
│ DEFAULT_PATH = '${CWD}/${BLOCK}/${VERSION}/${FLOW}'        │
│                                                             │
│ 第一次替换:                                                  │
│ DEFAULT_PATH = '/home/user/project/${BLOCK}/${VERSION}/${FLOW}'│
│                                                             │
│ 第二次替换:                                                  │
│ DEFAULT_PATH = '/home/user/project/cpu_core/${VERSION}/${FLOW}'│
│                                                             │
│ 第三次替换:                                                  │
│ DEFAULT_PATH = '/home/user/project/cpu_core/v1.0/${FLOW}'  │
│                                                             │
│ 第四次替换:                                                  │
│ DEFAULT_PATH = '/home/user/project/cpu_core/v1.0/syn'      │
│                                                             │
│ 最终结果:                                                   │
│ DEFAULT_PATH = '/home/user/project/cpu_core/v1.0/syn'      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: 任务级变量注入                                       │
│                                                             │
│ 若TASK定义了VAR，注入到任务执行环境                          │
│                                                             │
│ TASK:                                                       │
│   sim_run:                                                 │
│     RUN:                                                   │
│       VAR:                                                 │
│         TEST_NAME: basic_test                              │
│                                                             │
│ 执行时:                                                     │
│ TEST_NAME = 'basic_test'                                   │
│ COMMAND = 'make run TEST=${TEST_NAME}'                     │
│ 替换后:                                                     │
│ COMMAND = 'make run TEST=basic_test'                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 变量替换代码实现

```python
# parse_config.py 变量替换实现

from string import Template
import re

def substitute_variables(value, var_dict, max_depth=10):
    """
    递归变量替换
    
    Args:
        value: 待替换的值（可以是字符串、字典、列表）
        var_dict: 变量字典
        max_depth: 最大递归深度（防止循环引用）
    
    Returns:
        替换后的值
    """
    if max_depth <= 0:
        raise ValueError("Maximum substitution depth exceeded - possible circular reference")
    
    if isinstance(value, str):
        # 使用Template进行安全替换
        # safe_substitute不会抛出异常，未找到的变量保持原样
        template = Template(value)
        result = template.safe_substitute(var_dict)
        
        # 检查是否还有未替换的变量
        if '${' in result:
            # 继续递归替换
            return substitute_variables(result, var_dict, max_depth - 1)
        return result
    
    elif isinstance(value, dict):
        # 递归处理字典
        return {k: substitute_variables(v, var_dict, max_depth) for k, v in value.items()}
    
    elif isinstance(value, list):
        # 递归处理列表
        return [substitute_variables(v, var_dict, max_depth) for v in value]
    
    else:
        # 其他类型保持原样
        return value

def build_var_dict(config, system_vars):
    """
    构建完整变量字典
    
    Args:
        config: 配置字典（default.yaml解析结果）
        system_vars: 系统变量字典
    
    Returns:
        合并后的变量字典
    """
    # 合并变量
    var_dict = {**system_vars}
    
    # 添加VAR定义的变量
    if 'VAR' in config:
        var_dict.update(config['VAR'])
    
    return var_dict

def process_task_config(task_config, var_dict):
    """
    处理单个任务配置
    
    Args:
        task_config: 任务配置字典
        var_dict: 变量字典
    
    Returns:
        替换后的任务配置
    """
    return substitute_variables(task_config, var_dict)

# 使用示例
config = yaml.safe_load(open('default.yaml'))
system_vars = {
    'CWD': '/home/user/project',
    'BLOCK': 'cpu_core',
    'VERSION': 'v1.0',
    'FLOW': 'syn',
    'TASK': 'syn_dc'
}

var_dict = build_var_dict(config, system_vars)
task_config = config['TASK']['syn_dc']
processed_config = process_task_config(task_config, var_dict)

# processed_config['RUN']['PATH'] = '/home/user/project/cpu_core/v1.0/syn/syn_dc'
```

---

## 5. 项目组专属配置

### 5.1 配置文件命名规则

```
命名格式: default.{project}.{group}.yaml

project: 项目名（用户定义）
group:   用户组名（用户定义）

示例:
default.yaml                  # 默认配置（通用）
default.mychip.dv.yaml        # mychip项目dv组专属
default.mychip.syn.yaml       # mychip项目syn组专属
default.bigchip.all.yaml      # bigchip项目通用
```

### 5.2 配置匹配逻辑

```python
# 配置匹配代码

def find_config_file(project, group):
    """
    根据project和group查找配置文件
    
    Args:
        project: 项目名
        group: 用户组名
    
    Returns:
        配置文件路径
    """
    config_dir = os.environ['IFP_INSTALL_PATH'] + '/config'
    
    # 优先查找项目组专属配置
    if project and group:
        specific_file = f"{config_dir}/default.{project}.{group}.yaml"
        if os.path.exists(specific_file):
            return specific_file
    
    # 其次查找项目通用配置
    if project:
        project_file = f"{config_dir}/default.{project}.yaml"
        if os.path.exists(project_file):
            return project_file
    
    # 最后使用默认配置
    default_file = f"{config_dir}/default.yaml"
    return default_file

def merge_config(base_config, override_config):
    """
    合并配置（override覆盖base）
    
    Args:
        base_config: 基础配置
        override_config: 覆盖配置
    
    Returns:
        合合后的配置
    """
    result = base_config.copy()
    
    for key, value in override_config.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            # 深度合并字典
            result[key] = merge_config(result[key], value)
        else:
            # 直接覆盖
            result[key] = value
    
    return result
```

### 5.3 项目组配置示例

```yaml
# default.mychip.dv.yaml - DV组专属配置

VAR:
  # DV组特定变量
  BSUB_QUEUE: dv_queue            # DV专用队列
  SIM_TOOL: VCS                   # 使用VCS仿真器
  SIM_RUN_TIME: 10000             # 默认仿真时间
  
  # DV目录结构
  VERIF_PATH: ${CWD}/verif
  TB_PATH: ${VERIF_PATH}/tb
  SIM_PATH: ${DEFAULT_PATH}/sim

TASK:
  # DV组特定任务
  sim_compile:
    BUILD:
      PATH: ${SIM_PATH}/sim_compile
      COMMAND: mkdir -p ${PATH}/run ${PATH}/log
    
    RUN:
      PATH: ${SIM_PATH}/sim_compile
      COMMAND: vcs -full64 -f file_list.f -top top_tb
      RUN_METHOD: local
      LOG: ${PATH}/log/run.log
      
      DEPENDENCY:
        FILE:
          - ${TB_PATH}/top_tb.sv
          - ${VERIF_PATH}/sim/file_list.f
  
  sim_run:
    BUILD:
      PATH: ${SIM_PATH}/sim_run
      COMMAND: mkdir -p ${PATH}/run ${PATH}/log
    
    RUN:
      PATH: ${SIM_PATH}/sim_run
      COMMAND: ./simv +TEST=${TEST_NAME} +TIME=${SIM_RUN_TIME}
      RUN_METHOD: bsub -q ${BSUB_QUEUE} -n 4 -R "rusage[mem=4000]"
      LOG: ${PATH}/log/run.log
      
      RUN_AFTER:
        TASK: sim_compile
      
      VAR:
        TEST_NAME: basic_test

FLOW:
  # DV流程
  dv:
    - sim_compile
    - sim_run
    - sim_check
  
  dv_regression:
    - sim_compile
    - sim_run.regression
    - sim_check
    - gen_cov_report
```

---

## 6. ifp.cfg.yaml 用户配置

### 6.1 文件作用

ifp.cfg.yaml是用户在工作目录中的运行时配置，记录用户的选择。

### 6.2 文件结构

```yaml
# ifp.cfg.yaml 自动生成或用户编辑

# ========== 项目选择 ==========
project: mychip                   # 项目名
group: dv                         # 用户组

# ========== 模块选择 ==========
block: cpu_core                   # 当前模块
version: v1.0                     # 当前版本

# ========== 流程选择 ==========
flow: syn                         # 当前流程

# ========== 变量覆盖 ==========
# 用户可覆盖VAR定义的变量
VAR:
  BSUB_QUEUE: high_perf           # 使用高性能队列
  MAX_RUNNING_JOBS: 20            # 增加并行数

# ========== 任务选择 ==========
# 可指定要执行的任务（覆盖FLOW）
selected_tasks:
  - syn_dc
  - fm_rtl2gate

# ========== GUI配置 ==========
gui:
  window_width: 1400
  window_height: 900
  theme: dark                     # 界面主题
```

### 6.3 自动生成逻辑

```python
# ifp.py中ifp.cfg.yaml生成代码

def gen_config_file(cwd):
    """
    自动生成ifp.cfg.yaml
    
    Args:
        cwd: 当前工作目录
    
    Returns:
        配置文件路径
    """
    config_file = os.path.join(cwd, 'ifp.cfg.yaml')
    
    if not os.path.exists(config_file):
        # 创建默认配置
        default_config = {
            'project': '',
            'group': '',
            'block': '',
            'version': '',
            'flow': '',
            'VAR': {},
            'selected_tasks': [],
            'gui': {
                'window_width': 1200,
                'window_height': 800,
                'theme': 'default'
            }
        }
        
        with open(config_file, 'w') as f:
            yaml.dump(default_config, f, default_flow_style=False)
        
        print(f"Generated default config: {config_file}")
    
    return config_file

# 用户在GUI中修改后保存
def save_user_config(config_file, config_data):
    """保存用户配置"""
    with open(config_file, 'w') as f:
        yaml.dump(config_data, f, default_flow_style=False)
    print(f"Saved config to: {config_file}")
```

---

## 7. 配置加载完整流程

```python
# parse_config.py 配置加载流程

def load_full_config(user_config_file, system_vars):
    """
    加载完整配置
    
    Args:
        user_config_file: 用户配置文件路径（ifp.cfg.yaml）
        system_vars: 系统变量字典
    
    Returns:
        完整配置字典（已进行变量替换）
    """
    # Step 1: 加载用户配置
    if os.path.exists(user_config_file):
        user_config = yaml.safe_load(open(user_config_file))
    else:
        user_config = {}
    
    project = user_config.get('project', '')
    group = user_config.get('group', '')
    
    # Step 2: 查找default.yaml
    default_file = find_config_file(project, group)
    default_config = yaml.safe_load(open(default_file))
    
    # Step 3: 合并配置
    merged_config = merge_config(default_config, user_config)
    
    # Step 4: 构建变量字典
    var_dict = build_var_dict(merged_config, system_vars)
    
    # Step 5: 递归变量替换
    final_config = substitute_variables(merged_config, var_dict)
    
    return final_config

# 完整调用示例
cwd = '/home/user/project/mychip'
system_vars = {
    'CWD': cwd,
    'IFP_INSTALL_PATH': '/opt/ifp',
    'USER': 'zhangsan',
    'BLOCK': 'cpu_core',
    'VERSION': 'v1.0',
    'FLOW': 'syn',
    'TASK': ''
}

config = load_full_config(os.path.join(cwd, 'ifp.cfg.yaml'), system_vars)

# config['TASK']['syn_dc']['RUN']['PATH'] 已替换为:
# '/home/user/project/mychip/cpu_core/v1.0/syn/syn_dc'
```

---

## 8. YAML语法要点

### 8.1 基本语法

```yaml
# 键值对
key: value

# 字符串（无需引号，除非包含特殊字符）
string1: hello
string2: "hello world"
string3: 'hello: world'

# 数字
integer: 123
float: 12.34

# 布尔
bool_true: true
bool_false: false

# 列表
list_inline: [item1, item2, item3]
list_block:
  - item1
  - item2
  - item3

# 字典
dict_inline: {key1: value1, key2: value2}
dict_block:
  key1: value1
  key2: value2

# 嵌套结构
nested:
  level1:
    level2:
      level3: value
```

### 8.2 IFP配置语法要点

```yaml
# 变量引用使用${VAR}
PATH: ${DEFAULT_PATH}/${TASK}

# 多行命令使用|保留换行
COMMAND: |
  echo "Step 1"
  echo "Step 2"
  make all

# 命令行参数保留引号
COMMAND: "make run TEST=\"${TEST_NAME}\""

# 列表依赖
DEPENDENCY:
  FILE:
    - file1.v
    - file2.v
    - file3.v

# 任务依赖字典
RUN_AFTER:
  TASK: previous_task
  # 或多任务
  TASKS:
    - task1
    - task2
```

---

*Chiplet Design Practice*
*文档生成: 2026-05-13*