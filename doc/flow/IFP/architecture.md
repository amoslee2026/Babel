# IFP 系统架构详解

本文档详细解析IC Flow Platform的系统架构、核心组件、数据流和模块交互。

---

## 1. 分层架构设计

IFP采用五层架构，每层职责清晰，便于扩展和维护。

### 1.1 架构总览

```
┌─────────────────────────────────────────────────────────────────────┐
│                         IFP System Architecture                      │
│                         Version 1.4.3                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Layer 1: GUI Presentation Layer                              │   │
│  │ Technology: PyQt5 5.15.9                                     │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ MainWindow (QMainWindow)                            │    │   │
│  │  │ - 尺寸: 根据screeninfo自动适配                        │    │   │
│  │  │ - 主题: 支持自定义                                   │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │   MenuBar    │  │   Toolbar    │  │  StatusBar   │       │   │
│  │  │ 文件/编辑    │  │ Build/Run    │  │ 状态信息     │       │   │
│  │  │ 视图/工具    │  │ Check/Sum    │  │ 进度显示     │       │   │
│  │  │ 帮助菜单    │  │ Release      │  │              │       │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ TabWidget                                           │    │   │
│  │  │                                                     │    │   │
│  │  │ ┌─────────┐ ┌─────────┐ ┌─────────┐                │    │   │
│  │  │ │  MAIN   │ │ CONFIG  │ │FlowChart│                │    │   │
│  │  │ │ 任务表  │ │ 配置界面│ │ 流程图  │                │    │   │
│  │  │ │ 状态监控│ │5个子Tab │ │ Graphviz│                │    │   │
│  │  │ │ 日志窗口│ │         │ │         │                │    │   │
│  │  │ └─────────┘ └─────────┘ └─────────┘                │    │   │
│  │  │                                                     │    │   │
│  │  │ CONFIG Tab子界面:                                   │    │   │
│  │  │ - Setting:  项目/用户组选择                         │    │   │
│  │  │ - Task:     任务创建/编辑/删除                      │    │   │
│  │  │ - Order:    执行顺序拖拽调整                        │    │   │
│  │  │ - Variable: 全局变量编辑                            │    │   │
│  │  │ - API:      API功能开关                             │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↑↓ 信号/槽连接                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Layer 2: Core Engine Layer                                   │   │
│  │ 主要文件: bin/*.py                                           │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ ifp.py - 主程序入口 (~4000行)                        │    │   │
│  │  │                                                     │    │   │
│  │  │ 主要职责:                                          │    │   │
│  │  │ 1. argparse参数解析                                │    │   │
│  │  │    -config_file: 配置文件路径                      │    │   │
│  │  │    -d/--debug: 调试模式                            │    │   │
│  │  │    -r/--read: 只读模式                              │    │   │
│  │  │    -a/--action: 启动后动作                         │    │   │
│  │  │    -t/--title: 窗口标题                            │    │   │
│  │  │                                                     │    │   │
│  │  │ 2. 环境检查                                        │    │   │
│  │  │    - XDG_RUNTIME_DIR设置                           │    │   │
│  │  │    - IFP_INSTALL_PATH验证                          │    │   │
│  │  │                                                     │    │   │
│  │  │ 3. 配置文件处理                                    │    │   │
│  │  │    - 加载ifp.cfg.yaml                              │    │   │
│  │  │    - 生成状态文件                                  │    │   │
│  │  │    - 创建缓存目录                                  │    │   │
│  │  │                                                     │    │   │
│  │  │ 4. MainWindow初始化                                │    │   │
│  │  │    - 界面组件创建                                  │    │   │
│  │  │    - Tab页面设置                                   │    │   │
│  │  │    - 信号槽连接                                    │    │   │
│  │  │                                                     │    │   │
│  │  │ 5. PyQt事件循环                                    │    │   │
│  │  │    - QApplication.exec_()                          │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ user_config.py - 用户配置处理 (~3000行)              │    │   │
│  │  │                                                     │    │   │
│  │  │ 主要类:                                            │    │   │
│  │  │ - UserConfig: CONFIG Tab主界面                      │    │   │
│  │  │ - WindowForTaskInformation: 任务详情弹窗           │    │   │
│  │  │ - WindowForDependency: 依赖配置弹窗                 │    │   │
│  │  │ - WindowForToolGlobalEnv: 环境变量编辑              │    │   │
│  │  │ - WindowForAPI: API功能配置                         │    │   │
│  │  │ - TaskJobCheckWorker: 任务检查工作线程             │    │   │
│  │  │                                                     │    │   │
│  │  │ 功能实现:                                          │    │   │
│  │  │ - Setting界面: 项目/组下拉选择                      │    │   │
│  │  │ - Task界面: 任务树形列表，增删改                   │    │   │
│  │  │ - Order界面: 拖拽排序，依赖可视化                  │    │   │
│  │  │ - Variable界面: 表格编辑变量                       │    │   │
│  │  │ - API界面: 复选框开关控制                          │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ job_manager.py - 任务调度管理 (~2000行)              │    │   │
│  │  │                                                     │    │   │
│  │  │ 主要类:                                            │    │   │
│  │  │ - JobManager: 任务管理器核心                        │    │   │
│  │  │ - AutoVivification: 嵌套字典结构                   │    │   │
│  │  │                                                     │    │   │
│  │  │ 核心功能:                                          │    │   │
│  │  │ 1. 任务状态管理                                    │    │   │
│  │  │    pending → running → pass/fail                   │    │   │
│  │  │                                                     │    │   │
│  │  │ 2. 任务队列维护                                    │    │   │
│  │  │    - pending_queue: 待执行列表                     │    │   │
│  │  │    - running_list: 正执行列表                      │    │   │
│  │  │    - completed_dict: 完成结果                       │    │   │
│  │  │                                                     │    │   │
│  │  │ 3. 并行控制                                        │    │   │
│  │  │    - MAX_RUNNING_JOBS: 最大并发数                  │    │   │
│  │  │    - threading.BoundedSemaphore(50)                │    │   │
│  │  │                                                     │    │   │
│  │  │ 4. 许可资源管理                                    │    │   │
│  │  │    - LICENSE依赖检查                               │    │   │
│  │  │    - 资源预留和释放                                │    │   │
│  │  │                                                     │    │   │
│  │  │ 5. 数据库持久化                                    │    │   │
│  │  │    - SQLite存储任务状态                            │    │   │
│  │  │    - SQLAlchemy ORM                                │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │parse_config  │  │job_dispatcher│  │ job_watcher  │       │   │
│  │  │ YAML解析     │  │ 任务分发     │  │ 状态监控     │       │   │
│  │  │ 变量替换     │  │ bsub/local   │  │ 日志收集     │       │   │
│  │  │ ~500行       │  │ ~300行       │  │ ~200行       │       │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↑↓ API调用                            │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Layer 3: Common Modules Layer                                │   │
│  │ 主要文件: common/*.py                                        │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ common.py - 核心函数库 (~800行)                       │    │   │
│  │  │                                                     │    │   │
│  │  │ 主要函数:                                          │    │   │
│  │  │ - readArgs(): 参数解析                              │    │   │
│  │  │ - gen_config_file(): 配置生成                       │    │   │
│  │  │ - gen_cache_file_name(): 缓存命名                   │    │   │
│  │  │ - run_command(): 命令执行                           │    │   │
│  │  │ - check_license(): 许可检查                         │    │   │
│  │  │ - check_file_dependency(): 文件依赖                 │    │   │
│  │  │ - get_process_status(): 进程状态                    │    │   │
│  │  │ - convert_ansi_to_html(): ANSI转HTML                │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │ common_db    │  │ common_lsf   │  │common_pyqt5  │       │   │
│  │  │ SQLAlchemy   │  │ bsub封装     │  │ PyQt组件     │       │   │
│  │  │ SQLite操作   │  │ bjobs/bkill  │  │ 封装函数     │       │   │
│  │  │ 会话管理     │  │ 队列管理     │  │ 颜色/字体    │       │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │common_license│  │common_predict│  │common_file  │       │   │
│  │  │ 许可检查     │  │ 内存预测ML   │  │ 文件检查     │       │   │
│  │  │ 资源计数     │  │ XGBoost      │  │ 存在性验证   │       │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↑↓ 数据读取                           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Layer 4: Configuration Layer                                 │   │
│  │ 文件: config/*.yaml + config.py                              │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │                                                              │   │
│  │  config.py - Python配置常量                                  │   │
│  │  default.yaml - 流程/任务定义                                │   │
│  │  api.yaml - API扩展定义                                       │   │
│  │  ifp.cfg.yaml - 用户运行时配置                               │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↑↓ 脚本执行                           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Layer 5: Action Execution Layer                              │   │
│  │ 目录: action/*                                               │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │                                                              │   │
│  │  action/build/   - BUILD阶段脚本                             │   │
│  │  action/run/     - RUN阶段脚本                               │   │
│  │  action/check/   - CHECK阶段脚本                             │   │
│  │    └── scripts/                                             │   │
│  │        ├── ic_check.py          - 检查执行入口               │   │
│  │        ├── gen_checklist_scripts.py - 生成检查脚本           │   │
│  │        ├── gen_checklist_summary.py - 生成检查汇总           │   │
│  │        └────────── view_checklist_report.py - 查看报告       │   │
│  │  action/summarize/ - SUMMARIZE阶段脚本                       │   │
│  │  action/release/  - RELEASE阶段脚本                          │   │
│  │  action/post_run/ - 后处理脚本                               │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              ↑↓ 外部系统                           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Layer 6: External Integration                                │   │
│  ├─────────────────────────────────────────────────────────────┤   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │  │ LSF Cluster  │  │License Server│  │   SQLite     │       │   │
│  │  │ bsub提交     │  │ EDA许可      │  │ 任务状态DB   │       │   │
│  │  │ bjobs监控    │  │ DC/PT/FM     │  │ 操作日志     │       │   │
│  │  │ 资源调度     │  │ 许可计数     │  │ 配置缓存     │       │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │   │
│  │                                                              │   │
│  │  ┌──────────────┐                                            │   │
│  │  │ File System  │                                            │   │
│  │  │ 设计数据     │                                            │   │
│  │  │ 日志文件     │                                            │   │
│  │  │ 报告文件     │                                            │   │
│  │  └──────────────┘                                            │   │
│  │                                                              │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 核心组件详解

### 2.1 ifp.py 主程序入口

**文件位置**: `bin/ifp.py`
**代码规模**: ~4000行
**核心职责**: 程序入口、GUI初始化、事件循环

```python
# ifp.py 关键代码结构

import sys
import os
import argparse
import signal
from PyQt5.QtWidgets import QMainWindow, QApplication, QTabWidget
from PyQt5.QtCore import Qt, QTimer

# 导入内部模块
import parse_config
from user_config import UserConfig
from job_manager import JobManager

# 导入公共模块
sys.path.append(os.environ['IFP_INSTALL_PATH'] + '/common')
import common, common_db, common_pyqt5

# 导入配置
sys.path.append(os.environ['IFP_INSTALL_PATH'] + '/config')
import config as install_config

class MainWindow(QMainWindow):
    """主窗口类"""
    
    def __init__(self, config_file, read_only, debug, action, title):
        super().__init__()
        
        # 1. 环境检查
        self.check_environment()
        
        # 2. 加载配置
        self.load_config(config_file)
        
        # 3. 创建界面组件
        self.setup_ui()
        
        # 4. 连接信号槽
        self.connect_signals()
        
        # 5. 启动后动作
        if action:
            self.execute_action(action)
    
    def setup_ui(self):
        """创建界面"""
        # MenuBar
        self.menu_bar = self.menuBar()
        self.setup_menu_bar()
        
        # Toolbar
        self.toolbar = QToolBar()
        self.setup_toolbar()
        
        # TabWidget
        self.tab_widget = QTabWidget()
        self.main_tab = self.create_main_tab()
        self.config_tab = self.create_config_tab()
        self.flowchart_tab = self.create_flowchart_tab()
        self.tab_widget.addTab(self.main_tab, "MAIN")
        self.tab_widget.addTab(self.config_tab, "CONFIG")
        self.tab_widget.addTab(self.flowchart_tab, "FlowChart")
        
        # StatusBar
        self.status_bar = self.statusBar()
        
        self.setCentralWidget(self.tab_widget)
    
    def create_config_tab(self):
        """创建CONFIG Tab"""
        config_widget = UserConfig(self)
        return config_widget

def read_args():
    """参数解析"""
    parser = argparse.ArgumentParser()
    parser.add_argument('-config_file', default='ifp.cfg.yaml')
    parser.add_argument('-d', '--debug', action='store_true')
    parser.add_argument('-r', '--read', action='store_true')
    parser.add_argument('-a', '--action', choices=['build','run','check','summarize'])
    parser.add_argument('-t', '--title', default='IC Flow Platform')
    return parser.parse_args()

def main():
    """主入口"""
    # 1. 解析参数
    args = read_args()
    
    # 2. 设置环境
    if 'XDG_RUNTIME_DIR' not in os.environ:
        os.environ['XDG_RUNTIME_DIR'] = '/tmp/runtime-' + USER
    
    # 3. 创建应用
    app = QApplication(sys.argv)
    
    # 4. 创建主窗口
    window = MainWindow(args.config_file, args.read, args.debug, args.action, args.title)
    window.setWindowTitle(args.title)
    window.show()
    
    # 5. 事件循环
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
```

### 2.2 user_config.py 用户配置处理

**文件位置**: `bin/user_config.py`
**代码规模**: ~3000行
**核心职责**: CONFIG Tab界面实现

```python
# user_config.py 关键类结构

class UserConfig(QWidget):
    """CONFIG Tab主界面"""
    
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        self.setup_ui()
    
    def setup_ui(self):
        """创建子Tab"""
        self.tab_widget = QTabWidget()
        
        # 5个子Tab
        self.setting_tab = self.create_setting_tab()
        self.task_tab = self.create_task_tab()
        self.order_tab = self.create_order_tab()
        self.variable_tab = self.create_variable_tab()
        self.api_tab = self.create_api_tab()
        
        self.tab_widget.addTab(self.setting_tab, "Setting")
        self.tab_widget.addTab(self.task_tab, "Task")
        self.tab_widget.addTab(self.order_tab, "Order")
        self.tab_widget.addTab(self.variable_tab, "Variable")
        self.tab_widget.addTab(self.api_tab, "API")
    
    def create_setting_tab(self):
        """Setting界面"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Project下拉框
        self.project_combo = QComboBox()
        self.project_combo.addItems(self.get_projects())
        
        # Group下拉框
        self.group_combo = QComboBox()
        self.group_combo.addItems(self.get_groups())
        
        # Block输入框
        self.block_edit = QLineEdit()
        
        # Version输入框
        self.version_edit = QLineEdit()
        
        layout.addWidget(QLabel("Project:"))
        layout.addWidget(self.project_combo)
        layout.addWidget(QLabel("Group:"))
        layout.addWidget(self.group_combo)
        layout.addWidget(QLabel("Block:"))
        layout.addWidget(self.block_edit)
        layout.addWidget(QLabel("Version:"))
        layout.addWidget(self.version_edit)
        
        widget.setLayout(layout)
        return widget
    
    def create_task_tab(self):
        """Task界面"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # 任务树
        self.task_tree = QTreeWidget()
        self.task_tree.setHeaderLabels(["Task", "Status"])
        
        # 按钮
        self.add_btn = QPushButton("Add")
        self.del_btn = QPushButton("Delete")
        self.edit_btn = QPushButton("Edit")
        
        self.add_btn.clicked.connect(self.add_task)
        self.del_btn.clicked.connect(self.del_task)
        self.edit_btn.clicked.connect(self.edit_task)
        
        layout.addWidget(self.task_tree)
        layout.addWidget(self.add_btn)
        layout.addWidget(self.del_btn)
        layout.addWidget(self.edit_btn)
        
        widget.setLayout(layout)
        return widget

class WindowForTaskInformation(QDialog):
    """任务详情弹窗"""
    
    def __init__(self, task_name, task_config):
        super().__init__()
        self.task_name = task_name
        self.task_config = task_config
        self.setup_ui()
    
    def setup_ui(self):
        """创建详情表"""
        layout = QVBoxLayout()
        
        # 任务名
        self.name_edit = QLineEdit(self.task_name)
        
        # BUILD配置
        self.build_path = QLineEdit(self.task_config.get('BUILD', {}).get('PATH', ''))
        self.build_cmd = QLineEdit(self.task_config.get('BUILD', {}).get('COMMAND', ''))
        
        # RUN配置
        self.run_path = QLineEdit(self.task_config.get('RUN', {}).get('PATH', ''))
        self.run_cmd = QLineEdit(self.task_config.get('RUN', {}).get('COMMAND', ''))
        self.run_method = QLineEdit(self.task_config.get('RUN', {}).get('RUN_METHOD', ''))
        self.run_log = QLineEdit(self.task_config.get('RUN', {}).get('LOG', ''))
        
        # CHECK配置
        self.check_path = QLineEdit(self.task_config.get('CHECK', {}).get('PATH', ''))
        self.check_cmd = QLineEdit(self.task_config.get('CHECK', {}).get('COMMAND', ''))
        self.check_viewer = QLineEdit(self.task_config.get('CHECK', {}).get('VIEWER', ''))
        self.check_report = QLineEdit(self.task_config.get('CHECK', {}).get('REPORT_FILE', ''))
        
        # ...更多配置
        
        layout.addWidget(QLabel("Task Name:"))
        layout.addWidget(self.name_edit)
        layout.addWidget(QLabel("BUILD Path:"))
        layout.addWidget(self.build_path)
        # ...
        
        self.setLayout(layout)

class WindowForDependency(QDialog):
    """依赖配置弹窗"""
    pass

class WindowForAPI(QWidget):
    """API功能配置"""
    pass
```

### 2.3 job_manager.py 任务调度管理

**文件位置**: `bin/job_manager.py`
**代码规模**: ~2000行
**核心职责**: 任务状态管理、并行控制

```python
# job_manager.py 关键结构

import threading
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# 并行控制信号量
sem = threading.BoundedSemaphore(50)

class AutoVivification(dict):
    """自动嵌套字典"""
    def __getitem__(self, item):
        try:
            return dict.__getitem__(self, item)
        except KeyError:
            value = self[item] = type(self)()
            return value

class JobManager:
    """任务管理器"""
    
    def __init__(self, max_running_jobs=None):
        self.max_running_jobs = max_running_jobs or 10
        self.pending_queue = []
        self.running_list = []
        self.completed_dict = AutoVivification()
        
        # 数据库连接
        self.engine = create_engine('sqlite:///ifp_status.db')
        self.session = sessionmaker(bind=self.engine)()
    
    def add_task(self, block, version, flow, task, config):
        """添加任务到队列"""
        task_info = {
            'block': block,
            'version': version,
            'flow': flow,
            'task': task,
            'status': 'pending',
            'config': config
        }
        self.pending_queue.append(task_info)
        self.save_to_db(task_info)
    
    def check_dependency(self, task_info):
        """检查依赖"""
        config = task_info['config']
        
        # 1. 文件依赖
        if 'DEPENDENCY' in config and 'FILE' in config['DEPENDENCY']:
            for file_path in config['DEPENDENCY']['FILE']:
                if not os.path.exists(file_path):
                    return False, f"File dependency missing: {file_path}"
        
        # 2. 许可依赖
        if 'DEPENDENCY' in config and 'LICENSE' in config['DEPENDENCY']:
            for license_req in config['DEPENDENCY']['LICENSE']:
                tool, count = license_req.split()
                if not common_license.check_license(tool, int(count)):
                    return False, f"License insufficient: {tool}"
        
        # 3. 任务依赖
        if 'RUN_AFTER' in config and 'TASK' in config['RUN_AFTER']:
            pre_task = config['RUN_AFTER']['TASK']
            if pre_task not in self.completed_dict:
                return False, f"Pre-task not completed: {pre_task}"
        
        return True, "OK"
    
    def dispatch_task(self, task_info):
        """分发任务"""
        # 检查并行限制
        if len(self.running_list) >= self.max_running_jobs:
            return False
        
        # 检查依赖
        ok, msg = self.check_dependency(task_info)
        if not ok:
            return False
        
        # 获取信号量
        sem.acquire()
        
        # 更新状态
        task_info['status'] = 'running'
        task_info['start_time'] = datetime.now()
        self.running_list.append(task_info)
        
        # 执行命令
        config = task_info['config']
        path = config['RUN']['PATH']
        cmd = config['RUN']['COMMAND']
        method = config['RUN'].get('RUN_METHOD', 'local')
        
        if method.startswith('bsub'):
            # LSF提交
            full_cmd = f"{method} {cmd}"
            subprocess.run(full_cmd, cwd=path, shell=True)
        else:
            # 本地执行
            subprocess.run(cmd, cwd=path, shell=True)
        
        return True
    
    def update_status(self, task_info, status, result):
        """更新任务状态"""
        task_info['status'] = status
        task_info['end_time'] = datetime.now()
        task_info['result'] = result
        
        # 从运行列表移除
        if task_info in self.running_list:
            self.running_list.remove(task_info)
        
        # 添加到完成字典
        key = f"{task_info['block']}.{task_info['version']}.{task_info['flow']}.{task_info['task']}"
        self.completed_dict[key] = task_info
        
        # 释放信号量
        sem.release()
        
        # 保存到数据库
        self.save_to_db(task_info)
    
    def save_to_db(self, task_info):
        """持久化到数据库"""
        # SQLAlchemy ORM操作
        pass
    
    def get_task_status(self, block, version, flow, task):
        """获取任务状态"""
        key = f"{block}.{version}.{flow}.{task}"
        if key in self.completed_dict:
            return self.completed_dict[key]['status']
        for t in self.running_list:
            if f"{t['block']}.{t['version']}.{t['flow']}.{t['task']}" == key:
                return 'running'
        return 'pending'
```

### 2.4 parse_config.py 配置解析

```python
# parse_config.py 关键函数

import yaml
import os
import re
from string import Template

def parse_yaml(yaml_file):
    """解析YAML文件"""
    with open(yaml_file) as f:
        config = yaml.safe_load(f)
    return config

def substitute_variables(config, system_vars):
    """变量替换"""
    # 递归处理所有字符串值
    def substitute(value):
        if isinstance(value, str):
            # 使用Template进行替换
            template = Template(value)
            return template.safe_substitute(system_vars)
        elif isinstance(value, dict):
            return {k: substitute(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [substitute(v) for v in value]
        return value
    
    return substitute(config)

def extract_tasks(config):
    """提取任务列表"""
    return config.get('TASK', {})

def extract_flows(config):
    """提取流程列表"""
    return config.get('FLOW', {})

def get_system_vars(cwd, install_path, user, block, version, flow, task):
    """获取系统变量"""
    return {
        'CWD': cwd,
        'IFP_INSTALL_PATH': install_path,
        'USER': user,
        'BLOCK': block,
        'VERSION': version,
        'FLOW': flow,
        'TASK': task
    }

def load_full_config(config_file, project, group):
    """加载完整配置"""
    # 1. 加载default.yaml
    default_path = f"{os.environ['IFP_INSTALL_PATH']}/config/default.yaml"
    if project and group:
        specific_path = f"{os.environ['IFP_INSTALL_PATH']}/config/default.{project}.{group}.yaml"
        if os.path.exists(specific_path):
            default_path = specific_path
    
    config = parse_yaml(default_path)
    
    # 2. 加载用户配置
    if os.path.exists(config_file):
        user_config = parse_yaml(config_file)
        # 合并配置
        config = merge_config(config, user_config)
    
    return config
```

---

## 3. 数据流详解

### 3.1 配置加载流程

```
ifp启动
    │
    ├── 1. 参数解析
    │   - config_file: 配置路径
    │   - project/group: 项目组
    │
    ├── 2. 环境检查
    │   - IFP_INSTALL_PATH验证
    │   - XDG_RUNTIME_DIR设置
    │   - 写权限检查
    │
    ├── 3. 配置文件加载
    │   │
    │   ├── 3.1 default.yaml加载
    │   │   - 查找default.{project}.{group}.yaml
    │   │   - 若无则使用default.yaml
    │   │   - YAML解析成Python dict
    │   │
    │   ├── 3.2 api.yaml加载
    │   │   - PRE_CFG配置
    │   │   - PRE_IFP配置
    │   │   - TABLE_RIGHT_KEY_MENU配置
    │   │
    │   ├── 3.3 ifp.cfg.yaml加载
    │   │   - 用户运行时配置
    │   │   - 覆盖default.yaml
    │   │
    │   ├── 3.4 变量合并
    │   │   VAR定义 + 系统变量 → 最终变量字典
    │   │
    │   └── 3.5 变量替换
    │       - 递归替换所有${VAR}
    │       - PATH/COMMAND/RUN_METHOD等
    │
    ├── 4. 配置解析
    │   - 提取TASK定义
    │   - 提取FLOW定义
    │   - 构建任务依赖图
    │
    ├── 5. GUI初始化
    │   - 创建MainWindow
    │   - 创建CONFIG Tab（UserConfig）
    │   - 创建MAIN Tab（任务表）
    │   - 创建FlowChart Tab
    │   - 连接信号槽
    │
    └── 6. 状态恢复
        - 从SQLite读取上次状态
        - 从.ifp.status.yaml读取缓存
        - 渲染任务状态
```

### 3.2 任务执行流程

```
用户点击动作按钮（Build/Run/Check等）
    │
    ├── 1. 任务选择
    │   - 从任务表获取选中任务
    │   - 获取Block/Version/Flow/Task
    │
    ├── 2. 配置获取
    │   - 从config['TASK'][task_name]获取配置
    │   - 获取PATH/COMMAND/RUN_METHOD等
    │
    ├── 3. 依赖检查
    │   │
    │   ├── 3.1 文件依赖
    │   │   for file in DEPENDENCY.FILE:
    │   │       check os.path.exists(file)
    │   │
    │   ├── 3.2 许可依赖
    │   │   for license in DEPENDENCY.LICENSE:
    │   │       check_license(tool, count)
    │   │
    │   ├── 3.3 任务依赖
    │   │   pre_task = RUN_AFTER.TASK
    │   │       check completed_dict[pre_task]['status'] == 'pass'
    │   │
    │   └── 依赖失败 → 状态pending，等待
    │
    ├── 4. 并行检查
    │   if len(running_list) >= MAX_RUNNING_JOBS:
    │       wait...
    │   sem.acquire()
    │
    ├── 5. 命令生成
    │   │
    │   ├── 5.1 变量替换
    │   │   PATH = substitute(PATH, vars)
    │   │   COMMAND = substitute(COMMAND, vars)
    │   │   RUN_METHOD = substitute(RUN_METHOD, vars)
    │   │
    │   ├── 5.2 RUN_MODE选择
    │   │   if RUN_MODE == 'RUN.option1':
    │   │       use RUN.option1 config
    │   │
    │   └── 5.3 命令组装
    │       if RUN_METHOD.startswith('bsub'):
    │           full_cmd = RUN_METHOD + " " + COMMAND
    │       else:
    │           full_cmd = COMMAND
    │
    ├── 6. 任务分发
    │   │
    │   ├── 6.1 JobDispatcher.dispatch()
    │   │   - 创建执行线程
    │   │   - 设置工作目录
    │   │   - 启动subprocess
    │   │
    │   ├── 6.2 执行方式
    │   │   │
    │   │   ├── Local执行
    │   │   │   subprocess.run(cmd, cwd=path, shell=True)
    │   │   │   - 实时stdout捕获
    │   │   │   - 实时stderr捕获
    │   │   │
    │   │   └── LSF执行
    │   │       bsub -q queue -n cores -R "rusage" cmd
    │   │       - 提交到集群
    │   │       - 获取job_id
    │   │       - JobWatcher监控job状态
    │   │
    │   └── 6.3 状态更新
    │       status = 'running'
    │       start_time = now
    │       add to running_list
    │
    ├── 7. 状态监控
    │   │
    │   ├── 7.1 JobWatcher.watch()
    │   │   - 定时轮询（QTimer）
    │   │   - 检查进程状态
    │   │   - 检查LSF bjobs状态
    │   │
    │   ├── 7.2 日志收集
    │   │   - 实时读取stdout
    │   │   - 发送到GUI日志窗口
    │   │   - 保存到LOG文件
    │   │
    │   └── 7.3 进度显示
    │       - 更新StatusBar
    │       - 更新任务表状态列
    │
    ├── 8. 执行完成
    │   │
    │   ├── 8.1 状态判定
    │   │   if returncode == 0:
    │   │       status = 'pass'
    │   │   else:
    │   │       status = 'fail'
    │   │
    │   ├── 8.2 资源释放
    │   │   - sem.release()
    │   │   - 许可释放
    │   │   - 从running_list移除
    │   │
    │   └── 8.3 持久化
    │       - 保存到SQLite
    │       - 更新completed_dict
    │       - end_time = now
    │
    ├── 9. CHECK阶段（自动）
    │   │
    │   ├── 9.1 CHECK脚本执行
    │   │   python3 ic_check.py -d path -f flow -v vendor -b block
    │   │
    │   ├── 9.2 报告生成
    │   │   file_check/file_check.rpt
    │   │   Excel格式报告
    │   │
    │   ├── 9.3 结果判定
    │   │   if report exists and check_pass:
    │   │       write PASS file
    │   │   else:
    │   │       write FAIL file
    │   │
    │   └── 9.4 VIEWER调用
    │       if user clicks view:
    │           VIEWER REPORT_FILE
    │
    └── 10. SUMMARIZE阶段
        - 收集数据
        - 生成Excel汇总报告
        - VIEWER查看
```

---

## 4. 状态管理机制

### 4.1 SQLite数据库结构

```sql
-- 任务状态表
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block TEXT NOT NULL,
    version TEXT NOT NULL,
    flow TEXT NOT NULL,
    task TEXT NOT NULL,
    status TEXT NOT NULL,      -- pending/running/pass/fail
    start_time DATETIME,
    end_time DATETIME,
    log_path TEXT,
    result TEXT,
    config_json TEXT           -- JSON存储完整配置
);

-- 用户操作日志表
CREATE TABLE operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    user TEXT NOT NULL,
    action TEXT NOT NULL,      -- build/run/check/summarize/release
    block TEXT,
    version TEXT,
    flow TEXT,
    task TEXT,
    details TEXT
);

-- 配置变更记录表
CREATE TABLE config_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    user TEXT NOT NULL,
    config_file TEXT NOT NULL,
    change_type TEXT,          -- add/modify/delete
    key_path TEXT,
    old_value TEXT,
    new_value TEXT
);
```

### 4.2 状态文件

```
.ifp.status.yaml    - YAML格式状态缓存
.ifp.cache/         - 缓存目录
├── logs/           - 任务日志缓存
│   └── {task}.log
├── reports/        - 报告缓存
│   └── file_check.rpt
├── temp/           - 临时文件
└── db/             - SQLite数据库文件
    └── ifp_status.db
```

---

## 5. 模块交互图

```
┌─────────────────────────────────────────────────────────────────┐
│                     模块交互关系                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ifp.py                                                         │
│    ├── imports: parse_config, user_config, job_manager          │
│    ├── imports: common, common_db, common_pyqt5                 │
│    ├── imports: config                                           │
│    │                                                             │
│    ├── creates: MainWindow                                       │
│    │       ├── contains: UserConfig (CONFIG Tab)                │
│    │       │       ├── uses: job_manager                         │
│    │       │       ├── uses: parse_config                        │
│    │       │       └── uses: common_pyqt5                       │
│    │       │                                                     │
│    │       ├── contains: MAIN Tab                                │
│    │       │       ├── uses: job_manager                         │
│    │       │       ├── uses: common_db                           │
│    │       │                                                     │
│    │       ├── contains: FlowChart Tab                           │
│    │       │       ├── uses: graphviz                            │
│    │                                                             │
│    ├── calls: parse_config.load_full_config()                   │
│    │       ├── reads: config/default.yaml                        │
│    │       ├── reads: config/api.yaml                            │
│    │       └───────────────────────────────────────────────      │
│    │                                                             │
│    ├── calls: job_manager.add_task()                            │
│    │       ├── calls: common.check_file_dependency()            │
│    │       ├── calls: common_license.check_license()            │
│    │       ├── calls: common_db.save()                          │
│    │                                                             │
│    └── calls: job_dispatcher.dispatch()                         │
│            ├── calls: common.run_command()                      │
│            ├── calls: common_lsf.submit_job()                   │
│            └───────────────────────────────────────────────      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. 执行方式详解

### 6.1 Local执行

```python
# 本地直接执行
def run_local(path, command, log_file=None):
    """本地执行命令"""
    import subprocess
    
    # 创建进程
    process = subprocess.Popen(
        command,
        cwd=path,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1  # 行缓冲
    )
    
    # 实时读取输出
    while True:
        line = process.stdout.readline()
        if not line and process.poll() is not None:
            break
        if line:
            # 发送到GUI
            emit_log_signal(line)
            # 写入日志文件
            if log_file:
                with open(log_file, 'a') as f:
                    f.write(line)
    
    return process.returncode
```

### 6.2 LSF执行

```python
# LSF集群提交
def run_lsf(path, run_method, command):
    """LSF集群执行"""
    import subprocess
    import re
    
    # 组装bsub命令
    bsub_cmd = f"{run_method} {command}"
    
    # 提交任务
    result = subprocess.run(
        bsub_cmd,
        cwd=path,
        shell=True,
        capture_output=True,
        text=True
    )
    
    # 解析job_id
    # Job <12345> is submitted to queue <normal>.
    match = re.search(r'Job <(\d+)>', result.stdout)
    if match:
        job_id = match.group(1)
        
        # 监控job状态
        while True:
            status = check_lsf_job(job_id)
            if status in ['DONE', 'EXIT']:
                break
            time.sleep(30)  # 30秒轮询
        
        return status == 'DONE'
    
    return False

def check_lsf_job(job_id):
    """检查LSF任务状态"""
    result = subprocess.run(
        f"bjobs {job_id}",
        shell=True,
        capture_output=True,
        text=True
    )
    # 解析状态
    # JOBID USER STAT QUEUE ...
    lines = result.stdout.strip().split('\n')
    if len(lines) > 1:
        fields = lines[1].split()
        return fields[2]  # STAT字段
    
    return 'UNKNOWN'
```

---

## 7. 性能优化机制（V1.4.3）

### 7.1 配置加载优化

```python
# 缓存机制
config_cache = {}

def load_config_cached(config_file):
    """带缓存的配置加载"""
    mtime = os.path.getmtime(config_file)
    cache_key = f"{config_file}:{mtime}"
    
    if cache_key in config_cache:
        return config_cache[cache_key]
    
    config = parse_yaml(config_file)
    config_cache[cache_key] = config
    return config

# 异步渲染
def render_ui_async():
    """异步界面渲染"""
    from PyQt5.QtCore import QThread
    
    class RenderThread(QThread):
        def run(self):
            # 准备数据
            data = prepare_table_data()
            # 发送信号
            self.emit_data_signal(data)
    
    thread = RenderThread()
    thread.data_signal.connect(update_table)
    thread.start()
```

### 7.2 任务调度优化

```python
# 许可预检查
def precheck_licenses(tasks):
    """批量许可检查"""
    total_required = {}
    for task in tasks:
        if 'LICENSE' in task.config.get('DEPENDENCY', {}):
            for lic in task.config['DEPENDENCY']['LICENSE']:
                tool, count = lic.split()
                total_required[tool] = total_required.get(tool, 0) + int(count)
    
    # 检查总量
    for tool, count in total_required.items():
        if not check_license_total(tool, count):
            return False, f"Insufficient {tool}"
    
    return True, "OK"

# 内存预测
def predict_memory(task):
    """预测任务内存需求"""
    from sklearn.externals import joblib
    
    model = joblib.load('memory_predictor.pkl')
    features = extract_features(task)
    predicted = model.predict([features])
    
    return predicted[0]
```

---

*Chiplet Design Practice*