# IC Flow Platform (IFP) - Architecture & User Guide

字节跳动开源集成电路设计流程管理平台。

---

## 1. 架构概述

### 1.1 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      IC Flow Platform                            │
├─────────────────────────────────────────────────────────────────┤
│  GUI Layer (PyQt5)                                               │
│  ├── MAIN Tab      - 任务执行与监控                               │
│  ├── CONFIG Tab    - 配置管理                                     │
│  ├── FlowChart     - 流程可视化                                   │
│  └────────────────────────────────────────────────────────────── │
│  Core Engine                                                     │
│  ├── ifp.py        - 主程序入口                                   │
│  ├── job_manager   - 任务调度管理                                 │
│  ├── user_config   - 用户配置处理                                 │
│  ├── parse_config  - YAML配置解析                                 │
│  └────────────────────────────────────────────────────────────── │
│  Common Modules                                                  │
│  ├── common.py     - 公共函数库                                   │
│  ├── common_db     - 数据库操作                                   │
│  ├── common_lsf    - LSF集群支持                                  │
│  ├── common_pyqt5  - PyQt5封装                                    │
│  └────────────────────────────────────────────────────────────── │
│  Configuration                                                   │
│  ├── default.yaml  - 流程/任务定义                                │
│  ├── api.yaml      - API扩展定义                                  │
│  ├── config.py     - 系统配置                                     │
│  └────────────────────────────────────────────────────────────── │
│  Action Layer                                                    │
│  ├── build/        - 构建动作                                     │
│  ├── run/          - 执行动作                                     │
│  ├── check/        - 检查动作                                     │
│  ├── summarize/    - 总结动作                                     │
│  ├── release/      - 发布动作                                     │
│  └────────────────────────────────────────────────────────────── │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 核心组件

| 组件 | 文件 | 功能 |
|------|------|------|
| 主入口 | `bin/ifp.py` | GUI启动、参数解析、界面渲染 |
| 任务管理 | `bin/job_manager.py` | 任务调度、状态跟踪、资源管理 |
| 用户配置 | `bin/user_config.py` | 配置界面、任务设置、依赖管理 |
| 配置解析 | `bin/parse_config.py` | YAML解析、变量替换、任务生成 |
| 任务分发 | `bin/job_dispatcher.py` | 任务分发、并行控制 |
| 任务监控 | `bin/job_watcher.py` | 实时监控、日志收集 |

---

## 2. 目录结构

### 2.1 完整目录树

```
ic_flow_platform/
├── bin/                    # 核心程序
│   ├── ifp.py             # 主程序入口
│   ├── function.py        # 功能函数
│   ├── job_dispatcher.py  # 任务分发
│   ├── job_manager.py     # 任务管理
│   ├── job_watcher.py     # 任务监控
│   ├── parse_config.py    # 配置解析
│   ├── user_config.py     # 用户配置
│
├── common/                 # 公共模块
│   ├── common.py          # 通用函数
│   ├── common_db.py       # 数据库操作
│   ├── common_file_check.py
│   ├── common_license.py  # 许可管理
│   ├── common_lsf.py      # LSF集群
│   ├── common_nosql_db.py
│   ├── common_prediction.py
│   ├── common_pyqt5.py    # PyQt封装
│
├── config/                 # 配置文件
│   ├── config.py          # 系统配置
│   ├── default.yaml       # 默认流程定义 ★
│   ├── default.demo.syn.yaml
│   ├── default.demo.dv.yaml
│   ├── api.yaml           # API扩展定义 ★
│   ├── api.demo.syn.yaml
│   ├── api.demo.dv.yaml
│   ├── env.*              # 环境变量模板
│
├── action/                 # 动作脚本
│   ├── build/             # 构建目录准备
│   ├── run/               # 任务执行
│   ├── check/             # 结果检查
│   │   ├── scripts/       # 检查脚本
│   │   │   ├── ic_check.py
│   │   │   ├── gen_checklist_scripts.py
│   │   │   ├── gen_checklist_summary.py
│   │   │   └── view_checklist_report.py
│   │   └── demo_excel/    # 检查报告模板
│   ├── summarize/         # 结果总结
│   ├── release/           # 数据发布
│   ├── post_run/          # 后处理
│   └── summary/           # 综合总结
│
├── tools/                  # 工具脚本
│   ├── ifp_demo_wrapper.py
│   ├── ifp_pre_cfg.py     # 预配置工具
│   ├── in_process_check.py
│   ├── patch.py           # 补丁管理
│   ├── waiting_window.py
│   ├── lsfMonitor/        # LSF监控 ★
│   │   ├── monitor/       # 监控模块
│   │   ├── memPrediction/ # 内存预测
│   │   ├── db/            # 数据库
│   │   └── lib/           # 库文件
│
├── demo/                   # 示例项目
│   ├── SYN/               # 综合示例
│   └── DV/                # 验证示例
│       ├── design/        # 设计文件
│       ├── verif/         # 验证环境
│       │   ├── sim/       # 仿真脚本
│       │   └── tb/        # 测试平台
│
├── data/                   # 数据资源
│   └── pictures/          # 图片资源
│
├── docs/                   # 文档
│   ├── IFP_user_manual.pdf
│   └── IFP_admin_manual.pdf
│
├── third_part/             # 第三方组件
│
├── patch/                  # 补丁目录
│
├── install.py              # 安装脚本 ★
├── requirements.txt        # Python依赖 ★
├── README.md               # 说明文档
└── LICENSE                 # Apache 2.0
```

### 2.2 关键目录说明

| 目录 | 作用 | 管理员/用户 |
|------|------|-------------|
| `config/` | 流程定义、API配置 | 管理员配置 |
| `action/` | 执行脚本模板 | 管理员配置 |
| `bin/` | 核心程序 | 系统固定 |
| `tools/` | 扩展工具 | 管理员配置 |
| `demo/` | 示例项目 | 学习参考 |

---

## 3. 工作流程

### 3.1 整体流程

```
┌──────────────────────────────────────────────────────────────┐
│                    IFP 工作流程                                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. 安装配置                                                  │
│     ├── pip install -r requirements.txt                      │
│     ├── python3 install.py                                   │
│     └── 配置 config/default.yaml                             │
│                                                              │
│  2. 启动IFP                                                   │
│     ├── cd <work_directory>                                  │
│     ├── ifp                                                   │
│     └── 生成 ifp.cfg.yaml                                     │
│                                                              │
│  3. 用户配置                                                   │
│     ├── CONFIG-Setting: 设置项目名、用户组                     │
│     ├── CONFIG-Task: 创建任务                                 │
│     ├── CONFIG-Order: 设置执行顺序                            │
│     ├── CONFIG-Variable: 设置变量                             │
│     ├── CONFIG-API: 启用API功能                               │
│                                                              │
│  4. 任务执行                                                   │
│     ├── BUILD: 创建目录结构                                   │
│     ├── RUN:   执行设计任务                                   │
│     ├── CHECK: 检查结果质量                                   │
│     ├── SUMMARIZE: 收集报告                                   │
│     ├── RELEASE: 发布数据                                     │
│                                                              │
│  5. 监控与管理                                                 │
│     ├── MAIN界面: 监控进度                                    │
│     ├── FlowChart: 查看流程图                                 │
│     ├── 日志查看: 实时日志                                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 任务生命周期

每个任务包含5个阶段：

```
BUILD → RUN → CHECK → SUMMARIZE → RELEASE
  │       │      │         │         │
  │       │      │         │         └── 数据发布
  │       │      │         └── 结果汇总报告
  │       │      └── Checklist质量检查
  │       └── 执行主任务（综合/验证/STA等）
  └── 创建工作目录、准备脚本
```

### 3.3 任务依赖关系

```yaml
TASK:
  syn_dc:
    RUN_AFTER:
      TASK: initial          # 必须在 initial 任务完成后执行
    DEPENDENCY:
      FILE:                  # 文件依赖
        - ${CWD}/initial_setup.txt
      LICENSE:               # 许可依赖
        - DC 5               # 需要5个DC许可
```

---

## 4. 配置详解

### 4.1 default.yaml 结构

```yaml
# 1. 变量定义
VAR:
  BSUB_QUEUE: ai_syn
  DEFAULT_PATH: ${CWD}/${BLOCK}/${VERSION}/${FLOW}

# 2. 任务定义
TASK:
  synthesis:
    BUILD:                    # 构建阶段
      PATH: $DEFAULT_PATH
      COMMAND: make build
    
    RUN:                      # 执行阶段
      PATH: ${DEFAULT_PATH}/dc
      COMMAND: make run_initopt
      RUN_METHOD: bsub -q $BSUB_QUEUE -n 8
      LOG: ${DEFAULT_PATH}/dc/logs/log.dc
    
    RUN.option1:              # 可选执行模式
      PATH: ${DEFAULT_PATH}/dc
      COMMAND: make run_initopt --option1
      RUN_METHOD: bsub -q $BSUB_QUEUE -n 8
    
    RUN_MODE: RUN.option1     # 默认执行模式
    
    CHECK:                    # 检查阶段
      PATH: ${DEFAULT_PATH}/dc
      COMMAND: python3 check_script.py -b ${BLOCK}
      VIEWER: view_report.py -i
      REPORT_FILE: file_check/file_check.rpt
    
    SUMMARIZE:                # 总结阶段
      PATH: ${DEFAULT_PATH}/dc
      COMMAND: python3 collect_qor.py
      VIEWER: /bin/soffice
      REPORT_FILE: syn_qor.xlsx
    
    RELEASE:                  # 发布阶段
      PATH: ${DEFAULT_PATH}/dc
      COMMAND: make release
    
    RUN_AFTER:                # 任务依赖
      TASK: initial
    
    DEPENDENCY:               # 资源依赖
      FILE:
        - ${CWD}/initial_setup.txt
      LICENSE:
        - DC 5

# 3. 流程定义
FLOW:
  initial: [setup]
  syn: [fusion_lib, synthesis, dataout]
  formal: [dftrtl2syn, syn2dft]
```

### 4.2 系统变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `CWD` | IFP启动目录 | `/project/work` |
| `IFP_INSTALL_PATH` | IFP安装路径 | `/tools/ifp` |
| `USER` | 当前用户 | `jingfuyi` |
| `BLOCK` | 模块名 | `cpu_core` |
| `VERSION` | 版本名 | `v1.0` |
| `FLOW` | 流程名 | `syn` |
| `TASK` | 任务名 | `syn_dc` |

### 4.3 任务属性

| 属性 | 说明 | 必需 |
|------|------|------|
| `PATH` | 工作目录 | ✓ |
| `COMMAND` | 执行命令 | ✓ |
| `RUN_METHOD` | 执行方式 (bsub/local) | 可选 |
| `LOG` | 日志文件路径 | 可选 |
| `VIEWER` | 报告查看器 | CHECK/SUMMARIZE |
| `REPORT_FILE` | 报告文件路径 | CHECK/SUMMARIZE |
| `RUN_MODE` | 默认RUN模式 | 可选 |
| `RUN_AFTER.TASK` | 前置任务 | 可选 |
| `DEPENDENCY.FILE` | 文件依赖 | 可选 |
| `DEPENDENCY.LICENSE` | 许可依赖 | 可选 |

---

## 5. API扩展

### 5.1 api.yaml 结构

```yaml
API:
  PRE_CFG:
    - LABEL: "pre_cfg"
      PATH: ${CWD}
      COMMAND: python3 ${IFP_INSTALL_PATH}/tools/ifp_pre_cfg.py
      ENABLE: True
  
  PRE_IFP:
    - LABEL: "pre_ifp_action"
      PROJECT: my_project
      GROUP: design_team
      PATH: ${CWD}
      COMMAND: echo 'test'
      ENABLE: True
  
  TABLE_RIGHT_KEY_MENU:
    - LABEL: "查看日志"
      TAB: MAIN
      COLUMN: TASK
      PATH: ${CWD}
      COMMAND: cat log.txt
      ENABLE: True
```

---

## 6. 安装与使用

### 6.1 安装步骤

```bash
pip install -r requirements.txt
python3 install.py
export IFP_INSTALL_PATH=/path/to/ic_flow_platform
```

### 6.2 启动命令

```bash
cd <work_directory>
ifp                        # GUI模式
ifp -a run                 # 启动后执行run
ifp -r                     # 只读模式
export IFP_DEMO_MODE=TRUE && ifp  # Demo模式
```

### 6.3 命令行参数

| 参数 | 说明 |
|------|------|
| `-config_file` | 指定配置文件 |
| `-d, --debug` | 调试模式 |
| `-r, --read` | 只读模式 |
| `-a, --action` | 启动后执行动作 |
| `-t, --title` | 自定义窗口标题 |

---

## 7. 界面操作

### 7.1 CONFIG Tab

- **Setting**: 设置项目名、用户组 → 匹配default.yaml
- **Task**: 创建任务，设置属性
- **Order**: 调整任务执行顺序
- **Variable**: 设置全局变量
- **API**: 启用所需API功能

### 7.2 MAIN Tab

- 显示 Block/Version/Flow/Task/Status 表格
- 动作按钮: [Build] [Run] [Check] [Summarize] [Release]
- 实时日志窗口

### 7.3 操作流程

1. CONFIG-Setting → 2. CONFIG-Task → 3. CONFIG-Order →
4. CONFIG-Variable → 5. CONFIG-API → 6. MAIN执行 →

---

## 8. Checklist机制

检查流程:
```
RUN完成 → CHECK脚本执行 → 生成报告 → PASS/FAIL判定
```

检查报告输出位置: `file_check/file_check.rpt`

---

## 9. LSF集成

RUN_METHOD配置示例:
```yaml
RUN:
  COMMAND: make synthesis
  RUN_METHOD: bsub -q ${BSUB_QUEUE} -n 8 -R "rusage[mem=50000]"
```

LSF监控工具位置: `tools/lsfMonitor/`

---

## 10. 参考资源

| 资源 | 位置 |
|------|------|
| 用户手册 | `docs/IFP_user_manual.pdf` |
| 管理手册 | `docs/IFP_admin_manual.pdf` |
| GitHub | https://github.com/bytedance/ic_flow_platform |

---
*Chiplet Design Practice - 2026-05-13*