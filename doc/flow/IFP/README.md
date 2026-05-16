# IC Flow Platform (IFP) 详细文档

字节跳动开源集成电路设计流程管理平台 V1.4.3

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [architecture.md](./architecture.md) | 系统架构详解 - 分层设计、核心组件、数据流 |
| [installation.md](./installation.md) | 安装配置指南 - 系统要求、安装步骤、环境配置 |
| [configuration.md](./configuration.md) | 配置文件详解 - YAML结构、变量系统、任务定义 |
| [user-guide.md](./user-guide.md) | 用户操作指南 - GUI操作、完整工作流程 |
| [task-management.md](./task-management.md) | 任务管理机制 - 生命周期、依赖、并行控制 |
| [api-extension.md](./api-extension.md) | API扩展开发 - PRE_CFG、右键菜单、二级菜单 |
| [checklist.md](./checklist.md) | Checklist检查机制 - 检查脚本、报告生成 |
| [lsf-integration.md](./lsf-integration.md) | LSF集群集成 - 任务提交、监控、内存预测 |
| [examples.md](./examples.md) | 示例与最佳实践 - 完整流程配置示例 |

---

## IFP 简介

**IC Flow Platform (IFP)** 是字节跳动开源的集成电路设计流程管理平台，主要用于：

- **流程规范化管理** - 定义标准化设计流程
- **任务调度执行** - 自动化任务依赖和执行
- **数据流控制** - 设计数据的追踪和管理
- **Checklist质量检查** - 自动化结果验证
- **多项目支持** - 项目/用户组级别配置

### 核心价值

1. **提高效率** - 自动化重复性工作
2. **保证质量** - 强制Checklist检查
3. **规范流程** - 统一设计流程定义
4. **可追溯** - 完整的操作日志和状态记录

---

## 版本历史

| 版本 | 日期 | 主要更新 |
|------|------|----------|
| V1.4.3 | 2025.12.10 | 任务管理机制优化、GUI执行分离、配置加载加速、用户操作日志、内存管理优化 |
| V1.4.2 | 2025.05.25 | IN_PROCESS_CHECK运行时检查、过滤器功能、MAX_RUNNING_JOBS并行限制、IFP数据导出 |
| V1.4.1 | 2025.02.28 | RUN_MODE模式切换、Menubar/Toolbar API、-t标题参数、-r只读模式 |
| V1.4 | 2024.11.30 | 移除vendor/branch列、新default.yaml格式、详细任务信息界面 |
| V1.3.1 | 2024.09.04 | GUI编辑导出default.yaml/api.yaml、用户指南syn示例 |
| V1.3 | 2024.07.15 | 用户配置界面、API功能支持日常工作场景 |
| V1.2 | 2023.12.31 | 复杂逻辑控制、集中用户设置管理 |
| V1.1.1 | 2023.08.31 | 菜单栏功能优化、界面操作改进 |
| V1.1 | 2023.07.14 | Bug修复、CONFIG Tab操作优化 |
| V1.0 | 2023.02.02 | 正式开源发布 |

---

## 核心特性详解

### 1. 图形化界面 (PyQt5)

```
主窗口结构:
├── MenuBar          文件/编辑/视图/工具/帮助
├── Toolbar          快捷操作按钮区
├── TabWidget        主要功能区
│   ├── MAIN         任务执行与监控
│   ├── CONFIG       配置管理界面
│   │   ├── Setting  项目/用户组设置
│   │   ├── Task     任务创建编辑
│   │   ├── Order    执行顺序调整
│   │   ├── Variable 变量设置
│   │   ├── API      API功能开关
│   ├── FlowChart    流程可视化
├── StatusBar        状态信息显示
```

### 2. 任务调度系统

- **依赖管理** - 任务前置依赖、文件依赖、许可依赖
- **并行控制** - MAX_RUNNING_JOBS限制并发数
- **状态追踪** - pending/running/pass/fail四态
- **实时监控** - JobWatcher持续监控执行状态
- **日志收集** - 实时日志显示和保存

### 3. Checklist机制

- **自动检查** - RUN完成后自动执行CHECK
- **报告生成** - Excel格式检查报告
- **结果判定** - PASS/FAIL自动标记
- **可视化** - VIEWER查看器支持

### 4. LSF集群集成

- **任务提交** - bsub命令封装
- **资源管理** - CPU/内存/许可管理
- **内存预测** - ML模型预测资源需求
- **状态监控** - 实时任务状态同步

### 5. API扩展系统

- **PRE_CFG** - 配置加载前执行脚本
- **PRE_IFP** - IFP启动后执行脚本
- **TABLE_RIGHT_KEY_MENU** - 右键菜单扩展
- **二级菜单** - API-2支持多级菜单

### 6. 流程可视化

- **Graphviz生成** - 自动生成流程图
- **依赖关系** - 显示任务依赖链
- **状态标记** - 颜色标识任务状态

---

## 技术栈详解

### Python依赖 (requirements.txt)

```
# GUI框架
PyQt5==5.15.9           # 主GUI框架
screeninfo==0.8.1       # 屏幕信息获取

# 配置处理
PyYAML==6.0             # YAML文件解析

# 流程图
graphviz==0.20.1        # 流程图生成

# 数据处理
pandas==1.5.3           # 数据表格处理
numpy==1.24.2           # 数值计算

# 系统监控
psutil==5.9.4           # 进程/系统监控

# 图表
matplotlib==3.7.1       # 绑制图表

# Excel处理
xlrd==2.0.1             # Excel读取
xlwt==1.3.0             # Excel写入

# LSF监控扩展
Flask==2.3.3            # Web框架
flask_restful==0.3.10   # REST API
gensim==4.3.2           # NLP库
gevent==23.9.1          # 异步库
xgboost==2.0.0          # ML模型
scikit_learn==1.3.0     # ML库
imblearn==0.0           # 数据平衡
tabulate==0.9.4         # 表格格式化
tqdm==4.66.1            # 进度条
glove==1.0.2            # 词向量
```

### 源码结构

```
ic_flow_platform-main/
├── bin/                    # 核心程序 (Python)
│   ├── ifp.py             # 主入口，~4000行
│   ├── user_config.py     # 配置界面，~3000行
│   ├── job_manager.py     # 任务管理，~2000行
│   ├── parse_config.py    # 配置解析，~500行
│   ├── job_dispatcher.py  # 任务分发，~300行
│   ├── job_watcher.py     # 状态监控，~200行
│   ├── function.py        # 功能函数，~100行
│
├── common/                 # 公共模块 (~2000行)
│   ├── common.py          # 核心函数库
│   ├── common_db.py       # SQLAlchemy封装
│   ├── common_lsf.py      # LSF命令封装
│   ├── common_pyqt5.py    # PyQt组件封装
│   ├── common_license.py  # 许可检查
│   ├── common_prediction.py # 内存预测
│   ├── common_file_check.py # 文件检查
│   ├── common_nosql_db.py  # NoSQL操作
│
├── config/                 # 配置文件
│   ├── config.py          # Python配置常量
│   ├── default.yaml       # 主流程定义
│   ├── api.yaml           # API扩展定义
│   ├── default.demo.*.yaml # Demo配置
│   ├── api.demo.*.yaml    # Demo API
│
├── action/                 # 动作脚本
│   ├── build/             # 构建阶段
│   ├── run/               # 执行阶段
│   ├── check/             # 检查阶段
│   │   ├── scripts/       # Python检查脚本
│   │   │   ├── ic_check.py
│   │   │   ├── gen_checklist_scripts.py
│   │   │   ├── gen_checklist_summary.py
│   │   │   ├── view_checklist_report.py
│   │   ├── demo_excel/    # Excel模板
│   ├── summarize/         # 总结阶段
│   ├── release/           # 发布阶段
│   ├── post_run/          # 后处理
│
├── tools/                  # 工具脚本
│   ├── ifp_pre_cfg.py     # 预配置工具
│   ├── ifp_demo_wrapper.py # Demo包装
│   ├── in_process_check.py # 运行时检查
│   ├── patch.py           # 补丁管理
│   ├── waiting_window.py  # 等待窗口
│   ├── lsfMonitor/        # LSF监控子系统
│   │   ├── monitor/       # 监控模块
│   │   ├── memPrediction/ # 内存预测ML
│   │   ├── db/            # 数据库
│   │   ├── lib/           # 库文件
│   │   ├── install.py     # LSF监控安装
│
├── demo/                   # 示例项目
│   ├── DV/                # 验证示例
│   │   ├── design/        # 设计文件 .v .f
│   │   ├── verif/         # 验证环境
│   │   │   ├── sim/       # 仿真脚本 Makefile
│   │   │   ├── tb/        # 测试平台 .sv
│
├── docs/                   # PDF文档
│   ├── IFP_user_manual.pdf
│   ├── IFP_admin_manual.pdf
│
├── install.py              # 安装脚本
├── requirements.txt        # 依赖列表
├── LICENSE                 # Apache 2.0
└── README.md               # 项目说明
```

---

## 快速开始完整流程

### 步骤1: 安装

```bash
# 1.1 克隆仓库
cd ~/wrk
git clone https://github.com/bytedance/ic_flow_platform.git
cd ic_flow_platform

# 1.2 安装Python依赖（推荐使用conda）
conda create -n ifp python=3.8 -y
conda activate ifp
pip install -r requirements.txt

# 1.3 运行安装脚本
python3 install.py

# 1.4 设置环境变量（永久）
echo 'export IFP_INSTALL_PATH=~/wrk/ic_flow_platform-main' >> ~/.bashrc
source ~/.bashrc
```

### 步骤2: 创建工作目录

```bash
# 2.1 创建项目目录
mkdir -p ~/project/mychip
cd ~/project/mychip

# 2.2 准备设计文件（示例）
mkdir -p design rtl
# 放入RTL设计文件...
```

### 步骤3: 启动IFP

```bash
# 3.1 GUI模式
ifp

# 3.2 首次启动会生成 ifp.cfg.yaml
# 3.3 界面打开后进入CONFIG Tab
```

### 步骤4: 配置项目

```
CONFIG Tab操作:
1. Setting界面:
   - Project Name: mychip
   - User Group: dv_team
   
2. Task界面:
   - 添加syn_dc任务
   - 添加fm_rtl2gate任务
   - 添加presta任务
   
3. Order界面:
   - 调整执行顺序
   
4. Variable界面:
   - BSUB_QUEUE: normal
   - SYN_RUN: RUN
```

### 步骤5: 执行流程

```
MAIN Tab操作:
1. 选择Block/Version/Flow/Task
2. 点击Build → 创建目录
3. 点击Run → 执行综合
4. 点击Check → 质量检查
5. 点击Summarize → 收集报告
```

### 步骤6: 查看结果

```
FlowChart Tab: 查看流程图
日志窗口: 实时日志
报告: Excel检查报告
```

---

## Demo模式体验

```bash
# 启用Demo模式
export IFP_DEMO_MODE=TRUE

# 创建临时目录测试
mkdir /tmp/ifp_demo && cd /tmp/ifp_demo
ifp

# Demo模式提供:
# - 示例配置
# - 模拟任务
# - 学习界面
```

---

## 命令行参数详解

```bash
ifp [options]

选项:
-config_file FILE    配置文件路径，默认 <CWD>/ifp.cfg.yaml
-d, --debug          调试模式，打印详细信息
-r, --read           只读模式，无写权限时使用
-a ACTION            启动后执行动作: build/run/check/summarize
-t TITLE             自定义窗口标题

示例:
ifp                               # 正常启动
ifp -r                            # 只读模式
ifp -d                            # 调试模式
ifp -a run                        # 启动后执行run
ifp -config_file custom.yaml      # 自定义配置
ifp -t "MyChip Project"           # 自定义标题
```

---

## 相关资源

| 资源 | 链接 |
|------|------|
| GitHub仓库 | https://github.com/bytedance/ic_flow_platform |
| 用户手册PDF | docs/IFP_user_manual.pdf |
| 管理手册PDF | docs/IFP_admin_manual.pdf |
| License | Apache 2.0 |
| 源码位置 | ~/wrk/ic_flow_platform-main/ |

---

*清华大学集成电路学院 - 芯粒设计实践课*
*文档生成: 2026-05-13*