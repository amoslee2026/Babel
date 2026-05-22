# IFP 用户操作指南

本文档详细说明IC Flow Platform的GUI操作流程、界面功能和使用方法。

---

## 1. IFP启动与参数

### 1.1 启动方式

```bash
# 基本启动（在工作目录中）
cd ~/project/mychip
ifp

# 启动后自动创建:
# - ifp.cfg.yaml      用户配置
# - .ifp.status.yaml  状态缓存
# - .ifp.cache/       缓存目录

# 查看启动日志
ifp -d     # Debug模式，打印详细日志

# 日志输出示例:
# IFP V1.4.3 starting...
# Loading config from: ifp.cfg.yaml
# Checking environment: OK
# Initializing GUI...
# MainWindow created
# CONFIG Tab loaded
# MAIN Tab loaded
# FlowChart Tab initialized
# Ready.
```

### 1.2 命令行参数详解

```bash
ifp [options]

选项说明:
-config_file FILE    配置文件路径
                     默认: <CWD>/ifp.cfg.yaml
                     示例: ifp -config_file custom.yaml

-d, --debug          调试模式
                     - 打印详细启动日志
                     - 显示配置加载过程
                     - 开启Python异常traceback
                     示例: ifp -d

-r, --read           只读模式
                     - 无法执行Build/Run/Check等动作
                     - 只能查看状态
                     - 适用于无写权限场景
                     示例: ifp -r

-a ACTION            启动后自动执行动作
                     可选: build/run/check/summarize/release
                     - 自动执行选中的任务
                     - 执行后GUI保持打开
                     示例: ifp -a run    # 自动执行RUN

-t TITLE             自定义窗口标题
                     - 替换默认标题"IC Flow Platform"
                     - 用于多项目区分
                     示例: ifp -t "MyChip Synthesis"

组合使用示例:
ifp -d -a run -t "Debug Run"            # 调试模式+自动run+自定义标题
ifp -config_file my.yaml -r             # 自定义配置+只读模式
ifp -a build -a run -a check            # 连续执行多个动作

参数解析代码:
# bin/ifp.py 参数解析部分

import argparse

def read_args():
    parser = argparse.ArgumentParser(
        description='IC Flow Platform - IC Design Flow Management'
    )
    parser.add_argument(
        '-config_file',
        default='ifp.cfg.yaml',
        help='Configuration file path'
    )
    parser.add_argument(
        '-d', '--debug',
        action='store_true',
        help='Enable debug mode'
    )
    parser.add_argument(
        '-r', '--read',
        action='store_true',
        help='Enable read-only mode'
    )
    parser.add_argument(
        '-a', '--action',
        choices=['build', 'run', 'check', 'summarize', 'release'],
        help='Action to execute after startup'
    )
    parser.add_argument(
        '-t', '--title',
        default='IC Flow Platform',
        help='Window title'
    )
    return parser.parse_args()
```

### 1.3 Demo模式

```bash
# 启用Demo模式
export IFP_DEMO_MODE=TRUE

# 创建测试目录
mkdir /tmp/ifp_demo && cd /tmp/ifp_demo

# 启动IFP
ifp

# Demo模式特点:
# 1. 使用预制配置文件（config/default.demo.*.yaml）
# 2. 模拟任务执行结果
# 3. 生成示例报告
# 4. 适合学习和测试
# 5. 不需要真实EDA工具

# Demo配置查看
ls $IFP_INSTALL_PATH/config/
# default.demo.DV.yaml       DV演示配置
# api.demo.DV.yaml           DV演示API
# default.demo.syn.yaml      综合演示配置

# 关闭Demo模式
unset IFP_DEMO_MODE
```

---

## 2. 主窗口界面

### 2.1 界面结构总览

```
IFP主窗口布局:

┌─────────────────────────────────────────────────────────────────────┐
│ MenuBar                                                              │
│ ┌─────────┬─────────┬─────────┬─────────┬─────────┐                 │
│ │ File    │ Edit    │ View    │ Tools   │ Help    │                 │
│ └─┬───────┴─┬───────┴─┬───────┴─┬───────┴─┬───────┘                 │
│   │ New     │ Undo    │ Refresh │ LSF Mon │ About                   │
│   │ Open    │ Redo    │ Settings│ Mem Pred│ Doc                      │
│   │ Save    │ Copy    │         │         │                          │
│   │ Export  │ Paste   │         │         │                          │
│   │ Quit    │ Delete  │         │         │                          │
└─────────────────────────────────────────────────────────────────────┘
│ Toolbar                                                              │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Build] [Run] [Check] [Summarize] [Release] [Refresh] [Help]    │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│ TabWidget                                                            │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [MAIN] [CONFIG] [FlowChart]                                      │ │
│ ├─────────────────────────────────────────────────────────────────┤ │
│ │                                                                   │ │
│ │  Tab内容区                                                        │ │
│ │                                                                   │ │
│ │                                                                   │ │
│ │                                                                   │ │
│ │                                                                   │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│ StatusBar                                                            │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Status: Ready | Running: 3 | Pending: 5 | Completed: 12          │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│ LogWindow (可隐藏)                                                   │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [2026-05-13 14:30:01] Starting syn_dc...                         │ │
│ │ [2026-05-13 14:30:15] Job submitted: Job<12345>                  │ │
│ │ [2026-05-13 14:35:22] syn_dc completed: PASS                     │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 MenuBar菜单详解

```
File菜单:
├── New Project         创建新项目
│   → 输入项目名/路径
│
├── Open Project        打开已有项目
│   → 选择ifp.cfg.yaml文件
│
├── Save Config         保存当前配置
│   → 写入ifp.cfg.yaml
│
├── Export Config       导出配置
│   → 导出为YAML/JSON
│
├── Export FlowChart    导出流程图
│   → 导出为PNG/SVG/PDF
│
├── Export Report       导出报告
│   → 导出检查报告Excel
│
└── Quit                退出IFP
    → 确认保存后退出

Edit菜单:
├── Undo               撤销操作
├── Redo               重做操作
├── Copy               复制选中任务
├── Paste              粘贴任务
├── Delete             删除选中任务
├── Select All         全选任务
└── Find Task          查找任务

View菜单:
├── Refresh            刷新界面
│   → 更新任务状态
│   → 重载配置
│
├── Toggle Log Window   显示/隐藏日志窗口
├── Toggle Toolbar      显示/隐藏工具栏
├── Full Screen         全屏模式
└── Settings            打开设置界面
│   → 界面主题
│   → 字体大小
│   → 日志级别

Tools菜单:
├── LSF Monitor         打开LSF监控界面
│   → Web界面端口5000
│   → 任务状态监控
│
├── Memory Predictor    打开内存预测工具
│   → ML模型预测
│   → 历史数据分析
│
├── Generate FlowChart  生成流程图
│   → Graphviz生成
│
├── Validate Config     验证配置文件
│   → YAML语法检查
│   → 变量检查
│   → 依赖检查
│
└── Clear Cache         清理缓存
    → 清理.ifp.cache/

Help菜单:
├── About               关于IFP
│   → 版本信息
│   → 许可证
│
├── Documentation       打开文档
│   → PDF用户手册
│   → PDF管理员手册
│
├── API Reference       API参考
│   → PRE_CFG用法
│   → PRE_IFP用法
│   → 右键菜单API
│
└── GitHub              打开GitHub仓库
```

### 2.3 Toolbar工具栏详解

```
Toolbar按钮:

┌────────┬────────┬────────┬────────┬────────┬────────┬────────┐
│ Build  │  Run   │ Check  │ Summary│ Release│ Refresh│ Help   │
└────────┴────────┴────────┴────────┴────────┴────────┴────────┘

按钮功能:

Build按钮:
- 功能: 执行BUILD阶段
- 作用: 创建工作目录
- 快捷键: Ctrl+B
- 点击后弹出确认框，确认后执行
- 执行目录: config['TASK'][task]['BUILD']['PATH']

Run按钮:
- 功能: 执行RUN阶段
- 作用: 运行任务命令
- 快捷键: Ctrl+R
- 支持RUN_MODE选择（下拉菜单）
- 支持LSF提交或本地执行

Check按钮:
- 功能: 执行CHECK阶段
- 作用: 运行检查脚本
- 快捷键: Ctrl+C
- 自动生成检查报告
- 显示PASS/FAIL结果

Summarize按钮:
- 功能: 执行SUMMARIZE阶段
- 作用: 收集汇总数据
- 快捷键: Ctrl+S
- 生成Excel汇总报告

Release按钮:
- 功能: 执行RELEASE阶段
- 作用: 发布最终数据
- 快捷键: Ctrl+L
- 复制数据到发布目录

Refresh按钮:
- 功能: 刷新界面
- 作用: 更新任务状态
- 快捷键: F5
- 重新加载配置
- 检查LSF任务状态

Help按钮:
- 功能: 打开帮助文档
- 快捷键: Ctrl+H
- 跳转到Help菜单

按钮状态:

按钮根据任务状态显示不同颜色:
- 灰色: 不可执行（依赖未满足）
- 绿色: 可执行
- 黄色: 正执行中
- 蓝色: 已完成
```

### 2.4 StatusBar状态栏

```
StatusBar显示信息:

┌──────────────────────────────────────────────────────────────────────┐
│ Status: Ready | Running: 3 | Pending: 5 | Pass: 12 | Fail: 2        │
└──────────────────────────────────────────────────────────────────────┘

状态字段:
- Status:     当前状态（Ready/Working/Error）
- Running:    正执行任务数
- Pending:    待执行任务数
- Pass:       成功完成数
- Fail:       失败数

进度显示（任务执行时）:
┌──────────────────────────────────────────────────────────────────────┐
│ Running syn_dc... [████████░░░░░░░░] 50% | ETA: 5min                 │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. CONFIG Tab配置界面

### 3.1 CONFIG Tab结构

CONFIG Tab包含5个子Tab，用于配置流程。

```
CONFIG Tab布局:

┌─────────────────────────────────────────────────────────────────────┐
│ [Setting] [Task] [Order] [Variable] [API]                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  子Tab内容区                                                        │
│                                                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Setting界面详解

```
Setting界面布局:

┌─────────────────────────────────────────────────────────────────────┐
│ Project Configuration                                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Project: [ mychip        ▼ ]                                       │
│          选择或输入项目名                                            │
│          配置加载: default.{project}.{group}.yaml                   │
│                                                                     │
│ Group:   [ dv            ▼ ]                                       │
│          选择用户组                                                  │
│          决定使用哪套项目组配置                                       │
│                                                                     │
│ Block:   [ cpu_core       ]                                        │
│          输入模块名                                                  │
│          用于${BLOCK}变量                                           │
│                                                                     │
│ Version: [ v1.0           ]                                        │
│          输入版本名                                                  │
│          用于${VERSION}变量                                          │
│                                                                     │
│ Flow:    [ syn          ▼ ]                                        │
│          选择流程                                                    │
│          可选值来自config['FLOW']                                   │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Apply] [Reset]                                                 │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

操作步骤:

1. 选择Project:
   - 下拉列表显示可用项目
   - 可直接输入新项目名
   - 选择后自动加载对应配置

2. 选择Group:
   - 下拉列表显示可用组
   - 组名对应配置文件后缀
   - mychip.dv → default.mychip.dv.yaml

3. 输入Block:
   - 输入模块名（如cpu_core, alu, cache）
   - 用于目录命名
   - ${CWD}/${BLOCK}/${VERSION}

4. 输入Version:
   - 输入版本名（如v1.0, v2.0, rev1）
   - 用于版本管理
   - ${CWD}/${BLOCK}/${VERSION}

5. 选择Flow:
   - 下拉列表显示可用流程
   - 来自config['FLOW']定义
   - 选择后更新任务列表

6. 点击Apply:
   - 保存配置到ifp.cfg.yaml
   - 更新MAIN Tab任务列表
   - 更新FlowChart流程图

代码实现:

# user_config.py Setting界面

class SettingTab(QWidget):
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Project下拉
        self.project_combo = QComboBox()
        self.project_combo.setEditable(True)  # 允许输入
        self.project_combo.addItems(self.get_available_projects())
        self.project_combo.currentTextChanged.connect(self.on_project_changed)
        
        # Group下拉
        self.group_combo = QComboBox()
        self.group_combo.setEditable(True)
        self.group_combo.addItems(self.get_available_groups())
        
        # Block输入
        self.block_edit = QLineEdit()
        self.block_edit.setPlaceholderText("Enter block name")
        
        # Version输入
        self.version_edit = QLineEdit()
        self.version_edit.setPlaceholderText("Enter version")
        
        # Flow下拉
        self.flow_combo = QComboBox()
        self.flow_combo.addItems(self.get_available_flows())
        self.flow_combo.currentTextChanged.connect(self.on_flow_changed)
        
        # 按钮
        self.apply_btn = QPushButton("Apply")
        self.apply_btn.clicked.connect(self.apply_config)
        
        self.reset_btn = QPushButton("Reset")
        self.reset_btn.clicked.connect(self.reset_config)
        
        # 布局
        layout.addWidget(QLabel("Project:"))
        layout.addWidget(self.project_combo)
        layout.addWidget(QLabel("Group:"))
        layout.addWidget(self.group_combo)
        layout.addWidget(QLabel("Block:"))
        layout.addWidget(self.block_edit)
        layout.addWidget(QLabel("Version:"))
        layout.addWidget(self.version_edit)
        layout.addWidget(QLabel("Flow:"))
        layout.addWidget(self.flow_combo)
        
        btn_layout = QHBoxLayout()
        btn_layout.addWidget(self.apply_btn)
        btn_layout.addWidget(self.reset_btn)
        layout.addLayout(btn_layout)
        
        self.setLayout(layout)
    
    def apply_config(self):
        """应用配置"""
        config_data = {
            'project': self.project_combo.currentText(),
            'group': self.group_combo.currentText(),
            'block': self.block_edit.text(),
            'version': self.version_edit.text(),
            'flow': self.flow_combo.currentText()
        }
        
        # 保存配置
        self.main_window.save_config(config_data)
        
        # 更新其他Tab
        self.main_window.update_task_list()
        self.main_window.update_flowchart()
        
        QMessageBox.information(self, "Success", "Configuration applied!")
```

### 3.3 Task界面详解

```
Task界面布局:

┌─────────────────────────────────────────────────────────────────────┐
│ Task Configuration                                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Task Tree                                                       │ │
│ │ ┌─────────────────────────────────────────────────────────────┐ │ │
│ │ │ Task Name        │ BUILD │ RUN │ CHECK │ Status │           │ │ │
│ │ ├──────────────────┼───────┼─────┼───────┼────────┤           │ │ │
│ │ │ syn              │       │     │       │        │ (展开)    │ │ │
│ │ │ ├ syn_dc         │ ✓     │ ✓   │ ✓     │ pass   │           │ │ │
│ │ │ ├ fm_rtl2gate    │ ✓     │ ✓   │ ✓     │ pass   │           │ │ │
│ │ │ └ presta         │ ✓     │ ✓   │ ✓     │ pending│           │ │ │
│ │ │ dv               │       │     │       │        │ (折叠)    │ │ │
│ │ │ apr              │       │     │       │        │           │ │ │
│ │ └─────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Add Task] [Edit Task] [Delete Task] [Copy Task] [Check All]    │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ Task Details (点击Edit后显示)                                       │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Task Name: [ syn_dc          ]                                  │ │
│ │                                                                 │ │
│ │ BUILD:                                                          │ │
│ │   PATH:   [ ${DEFAULT_PATH}/syn_dc ]                            │ │
│ │   COMMAND: [ mkdir -p ${PATH}/run... ]                          │ │
│ │                                                                 │ │
│ │ RUN:                                                            │ │
│ │   PATH:   [ ${DEFAULT_PATH}/syn_dc ]                            │ │
│ │   COMMAND: [ dc_shell -f syn.tcl ]                              │ │
│ │   RUN_METHOD: [ bsub -q ai_syn... ]                             │ │
│ │   RUN_MODE: [ RUN           ▼ ]                                 │ │
│ │                                                                 │ │
│ │ CHECK:                                                          │ │
│ │   COMMAND: [ python3 ic_check.py... ]                           │ │
│ │   REPORT_FILE: [ ${PATH}/file_check.rpt ]                       │ │
│ │   VIEWER: [ firefox ${REPORT_FILE} ]                            │ │
│ │                                                                 │ │
│ │ DEPENDENCY:                                                     │ │
│ │   FILE: [ file1.v, file2.v, ... ]                               │ │
│ │   LICENSE: [ DC 5 ]                                             │ │
│ │   RUN_AFTER: [ initial ]                                        │ │
│ │                                                                 │ │
│ │ [Save] [Cancel]                                                 │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

操作步骤:

1. 查看任务列表:
   - 树形结构显示任务
   - Flow作为父节点
   - Task作为子节点
   - 显示各阶段状态

2. 添加新任务:
   - 点击"Add Task"
   - 输入任务名
   - 配置BUILD/RUN/CHECK等
   - 点击"Save"

3. 编辑任务:
   - 选中任务
   - 点击"Edit Task"
   - 弹出详情对话框
   - 修改配置
   - 点击"Save"

4. 删除任务:
   - 选中任务
   - 点击"Delete Task"
   - 确认删除

5. 复制任务:
   - 选中任务
   - 点击"Copy Task"
   - 输入新任务名
   - 自动复制配置

任务详情对话框字段:

| 字段 | 说明 | 示例 |
|------|------|------|
| Task Name | 任务名 | syn_dc |
| BUILD.PATH | BUILD目录 | ${DEFAULT_PATH}/syn_dc |
| BUILD.COMMAND | BUILD命令 | mkdir -p ${PATH}/run |
| RUN.PATH | RUN目录 | ${DEFAULT_PATH}/syn_dc |
| RUN.COMMAND | RUN命令 | dc_shell -f syn.tcl |
| RUN.RUN_METHOD | 执行方式 | bsub -q ai_syn |
| RUN.RUN_MODE | 默认模式 | RUN |
| RUN.LOG | 日志路径 | ${PATH}/log/run.log |
| CHECK.COMMAND | CHECK命令 | python3 ic_check.py |
| CHECK.REPORT_FILE | 报告路径 | ${PATH}/file_check.rpt |
| CHECK.VIEWER | 查看命令 | firefox ${REPORT_FILE} |
| DEPENDENCY.FILE | 文件依赖 | [file1.v, file2.v] |
| DEPENDENCY.LICENSE | 许可依赖 | [DC 5] |
| RUN_AFTER.TASK | 前置任务 | initial |

代码实现:

# user_config.py Task界面

class TaskTab(QWidget):
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # 任务树
        self.task_tree = QTreeWidget()
        self.task_tree.setHeaderLabels(
            ['Task', 'BUILD', 'RUN', 'CHECK', 'Status']
        )
        self.task_tree.setColumnWidth(0, 200)
        
        # 加载任务
        self.load_tasks()
        
        # 按钮
        self.add_btn = QPushButton("Add Task")
        self.add_btn.clicked.connect(self.add_task)
        
        self.edit_btn = QPushButton("Edit Task")
        self.edit_btn.clicked.connect(self.edit_task)
        
        self.del_btn = QPushButton("Delete Task")
        self.del_btn.clicked.connect(self.delete_task)
        
        self.copy_btn = QPushButton("Copy Task")
        self.copy_btn.clicked.connect(self.copy_task)
        
        btn_layout = QHBoxLayout()
        btn_layout.addWidget(self.add_btn)
        btn_layout.addWidget(self.edit_btn)
        btn_layout.addWidget(self.del_btn)
        btn_layout.addWidget(self.copy_btn)
        
        layout.addWidget(self.task_tree)
        layout.addLayout(btn_layout)
        
        self.setLayout(layout)
    
    def load_tasks(self):
        """加载任务树"""
        config = self.main_window.config
        
        # 清空树
        self.task_tree.clear()
        
        # 添加Flow节点
        for flow_name, tasks in config['FLOW'].items():
            flow_item = QTreeWidgetItem([flow_name, '', '', '', ''])
            flow_item.setExpanded(True)
            
            # 添加Task节点
            for task_name in tasks:
                task_item = QTreeWidgetItem([
                    task_name,
                    '✓' if 'BUILD' in config['TASK'][task_name] else '',
                    '✓' if 'RUN' in config['TASK'][task_name] else '',
                    '✓' if 'CHECK' in config['TASK'][task_name] else '',
                    self.get_task_status(task_name)
                ])
                flow_item.addChild(task_item)
            
            self.task_tree.addTopLevelItem(flow_item)
    
    def edit_task(self):
        """编辑任务"""
        selected = self.task_tree.currentItem()
        if selected:
            task_name = selected.text(0)
            
            # 打开编辑对话框
            dialog = TaskEditDialog(task_name, self.main_window.config)
            if dialog.exec_() == QDialog.Accepted:
                # 保存修改
                self.save_task_config(task_name, dialog.get_config())
                self.load_tasks()
```

### 3.4 Order界面详解

```
Order界面布局:

┌─────────────────────────────────────────────────────────────────────┐
│ Task Order Configuration                                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Task Order List (拖拽调整顺序)                                  │ │
│ │                                                                 │ │
│ │ ┌─────────────────────────────────────────────────────────────┐ │ │
│ │ │ 1. initial                                                   │ │ │
│ │ │    ↓                                                         │ │ │
│ │ │ 2. syn_dc                                                    │ │ │
│ │ │    ↓                                                         │ │ │
│ │ │ 3. fm_rtl2gate                                               │ │ │
│ │ │    ↓                                                         │ │ │
│ │ │ 4. presta                                                     │ │ │
│ │ └─────────────────────────────────────────────────────────────┘ │ │
│ │                                                                 │ │
│ │ 依赖关系可视化:                                                 │ │
│ │  initial → syn_dc → fm_rtl2gate → presta                       │ │
│ │                                                                 │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Move Up] [Move Down] [Add Dependency] [Remove Dependency]      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

操作步骤:

1. 查看执行顺序:
   - 列表显示任务顺序
   - 序号表示执行先后
   - 箭头表示依赖关系

2. 调整顺序:
   - 拖拽任务项
   - 或使用"Move Up/Down"按钮
   - 自动更新RUN_AFTER依赖

3. 添加依赖:
   - 选中任务
   - 点击"Add Dependency"
   - 选择前置任务

4. 移除依赖:
   - 选中任务
   - 点击"Remove Dependency"
   - 移除RUN_AFTER

代码实现:

# user_config.py Order界面

class OrderTab(QWidget):
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # 任务列表（可拖拽）
        self.order_list = QListWidget()
        self.order_list.setDragEnabled(True)
        self.order_list.setAcceptDrops(True)
        self.order_list.setDropIndicatorShown(True)
        self.order_list.setDragDropMode(QAbstractItemView.InternalMove)
        
        self.load_order()
        
        self.order_list.model().rowsMoved.connect(self.on_order_changed)
        
        # 按钮
        self.up_btn = QPushButton("Move Up")
        self.up_btn.clicked.connect(self.move_up)
        
        self.down_btn = QPushButton("Move Down")
        self.down_btn.clicked.connect(self.move_down)
        
        self.add_dep_btn = QPushButton("Add Dependency")
        self.add_dep_btn.clicked.connect(self.add_dependency)
        
        self.del_dep_btn = QPushButton("Remove Dependency")
        self.del_dep_btn.clicked.connect(self.remove_dependency)
        
        btn_layout = QHBoxLayout()
        btn_layout.addWidget(self.up_btn)
        btn_layout.addWidget(self.down_btn)
        btn_layout.addWidget(self.add_dep_btn)
        btn_layout.addWidget(self.del_dep_btn)
        
        layout.addWidget(QLabel("Task Order (drag to reorder):"))
        layout.addWidget(self.order_list)
        layout.addLayout(btn_layout)
        
        self.setLayout(layout)
    
    def on_order_changed(self):
        """顺序改变后更新依赖"""
        items = []
        for i in range(self.order_list.count()):
            items.append(self.order_list.item(i).text())
        
        # 更新RUN_AFTER
        config = self.main_window.config
        for i, task_name in enumerate(items):
            if i > 0:
                config['TASK'][task_name]['RUN']['RUN_AFTER'] = {
                    'TASK': items[i-1]
                }
        
        self.main_window.update_flowchart()
```

### 3.5 Variable界面详解

```
Variable界面布局:

┌─────────────────────────────────────────────────────────────────────┐
│ Variable Configuration                                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Variable Table                                                  │ │
│ │ ┌─────────────────────────────────────────────────────────────┐ │ │
│ │ │ Variable Name        │ Value            │ Source            │ │ │
│ │ ├──────────────────────┼──────────────────┼───────────────────┤ │ │
│ │ │ CWD                  │ /home/user/proj  │ System            │ │ │
│ │ │ IFP_INSTALL_PATH     │ /opt/ifp         │ System            │ │ │
│ │ │ USER                 │ zhangsan         │ System            │ │ │
│ │ │ BLOCK                │ cpu_core         │ User              │ │ │
│ │ │ VERSION              │ v1.0             │ User              │ │ │
│ │ │ FLOW                 │ syn              │ User              │ │ │
│ │ │ BSUB_QUEUE           │ ai_syn           │ VAR               │ │ │
│ │ │ DEFAULT_PATH         │ ${CWD}/${BLOCK}  │ VAR               │ │ │
│ │ │ SYN_RUN              │ RUN              │ VAR               │ │ │
│ │ │ MAX_RUNNING_JOBS     │ 10               │ VAR               │ │ │
│ │ │ (Editable)           │                  │                   │ │ │
│ │ └─────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Add Variable] [Edit Variable] [Delete Variable] [Refresh]      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ Note: System variables cannot be edited. VAR variables can be     │
│       overridden in ifp.cfg.yaml.                                  │
└─────────────────────────────────────────────────────────────────────┘

操作步骤:

1. 查看变量:
   - 表格显示所有变量
   - 显示值和来源
   - 系统变量灰色（不可编辑）
   - VAR变量白色（可编辑）

2. 添加变量:
   - 点击"Add Variable"
   - 输入变量名和值
   - 保存到ifp.cfg.yaml VAR部分

3. 编辑变量:
   - 双击表格单元格
   - 或选中后点击"Edit"
   - 修改值

4. 删除变量:
   - 选中用户自定义变量
   - 点击"Delete Variable"
   - 从ifp.cfg.yaml移除

代码实现:

# user_config.py Variable界面

class VariableTab(QWidget):
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # 变量表格
        self.var_table = QTableWidget()
        self.var_table.setColumnCount(3)
        self.var_table.setHorizontalHeaderLabels(
            ['Variable', 'Value', 'Source']
        )
        self.var_table.setRowCount(0)
        
        # 加载变量
        self.load_variables()
        
        # 双击编辑
        self.var_table.cellDoubleClicked.connect(self.edit_cell)
        
        # 按钮
        self.add_btn = QPushButton("Add Variable")
        self.add_btn.clicked.connect(self.add_variable)
        
        self.del_btn = QPushButton("Delete Variable")
        self.del_btn.clicked.connect(self.del_variable)
        
        self.refresh_btn = QPushButton("Refresh")
        self.refresh_btn.clicked.connect(self.load_variables)
        
        btn_layout = QHBoxLayout()
        btn_layout.addWidget(self.add_btn)
        btn_layout.addWidget(self.del_btn)
        btn_layout.addWidget(self.refresh_btn)
        
        layout.addWidget(self.var_table)
        layout.addLayout(btn_layout)
        
        # 说明
        note = QLabel(
            "Note: System variables cannot be edited.\n"
            "VAR variables can be overridden in ifp.cfg.yaml."
        )
        layout.addWidget(note)
        
        self.setLayout(layout)
    
    def load_variables(self):
        """加载变量表格"""
        config = self.main_window.config
        system_vars = self.main_window.system_vars
        
        # 清空表格
        self.var_table.setRowCount(0)
        
        row = 0
        
        # 添加系统变量
        for name, value in system_vars.items():
            self.var_table.insertRow(row)
            self.var_table.setItem(row, 0, QTableWidgetItem(name))
            self.var_table.setItem(row, 1, QTableWidgetItem(value))
            self.var_table.setItem(row, 2, QTableWidgetItem("System"))
            
            # 系统变量不可编辑
            for col in range(3):
                item = self.var_table.item(row, col)
                item.setFlags(item.flags() & ~Qt.ItemIsEditable)
                item.setBackground(QColor(200, 200, 200))
            
            row += 1
        
        # 添加VAR变量
        if 'VAR' in config:
            for name, value in config['VAR'].items():
                self.var_table.insertRow(row)
                self.var_table.setItem(row, 0, QTableWidgetItem(name))
                self.var_table.setItem(row, 1, QTableWidgetItem(str(value)))
                self.var_table.setItem(row, 2, QTableWidgetItem("VAR"))
                row += 1
```

### 3.6 API界面详解

```
API界面布局:

┌─────────────────────────────────────────────────────────────────────┐
│ API Configuration                                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ PRE_CFG (配置加载前执行):                                           │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [✓] Execute PRE_CFG scripts                                    │ │
│ │                                                                 │ │
│ │ Enabled scripts:                                                │ │
│ │ [✓] setup_environment.py                                       │ │
│ │ [✓] check_license.py                                           │ │
│ │ [ ] sync_config.py                                              │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ PRE_IFP (IFP启动后执行):                                            │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [✓] Execute PRE_IFP scripts                                    │ │
│ │                                                                 │ │
│ │ Enabled scripts:                                                │ │
│ │ [✓] init_workspace.py                                          │ │
│ │ [ ] auto_start_monitor.py                                      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ TABLE_RIGHT_KEY_MENU (右键菜单):                                    │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [✓] Enable right-key menu extensions                           │ │
│ │                                                                 │ │
│ │ Menu items:                                                     │ │
│ │ [✓] View Log                                                   │ │
│ │ [✓] Open Directory                                             │ │
│ │ [✓] Generate Report                                            │ │
│ │ [ ] Send Email                                                  │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Save API Config] [Refresh API List]                           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

API功能说明:

PRE_CFG:
- 执行时机: 配置文件加载前
- 执行顺序: 按api.yaml定义顺序
- 用途: 环境设置、许可检查、配置同步
- 示例脚本: setup_environment.py

PRE_IFP:
- 执行时机: IFP启动后，GUI初始化前
- 执行顺序: 按api.yaml定义顺序
- 用途: 工作区初始化、自动启动监控
- 示例脚本: init_workspace.py

TABLE_RIGHT_KEY_MENU:
- 执行时机: 用户右键点击任务表
- 用途: 快捷操作、自定义功能
- 示例: View Log、Open Directory

代码实现:

# user_config.py API界面

class APITab(QWidget):
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # PRE_CFG
        pre_cfg_group = QGroupBox("PRE_CFG (Execute before config load)")
        pre_cfg_layout = QVBoxLayout()
        
        self.pre_cfg_enabled = QCheckBox("Execute PRE_CFG scripts")
        self.pre_cfg_enabled.setChecked(True)
        pre_cfg_layout.addWidget(self.pre_cfg_enabled)
        
        self.pre_cfg_list = QListWidget()
        self.load_pre_cfg_scripts()
        pre_cfg_layout.addWidget(QLabel("Enabled scripts:"))
        pre_cfg_layout.addWidget(self.pre_cfg_list)
        
        pre_cfg_group.setLayout(pre_cfg_layout)
        layout.addWidget(pre_cfg_group)
        
        # PRE_IFP
        pre_ifp_group = QGroupBox("PRE_IFP (Execute after IFP startup)")
        pre_ifp_layout = QVBoxLayout()
        
        self.pre_ifp_enabled = QCheckBox("Execute PRE_IFP scripts")
        self.pre_ifp_layout.setChecked(True)
        pre_ifp_layout.addWidget(self.pre_ifp_enabled)
        
        self.pre_ifp_list = QListWidget()
        self.load_pre_ifp_scripts()
        pre_ifp_layout.addWidget(QLabel("Enabled scripts:"))
        pre_ifp_layout.addWidget(self.pre_ifp_list)
        
        pre_ifp_group.setLayout(pre_ifp_layout)
        layout.addWidget(pre_ifp_group)
        
        # 右键菜单
        menu_group = QGroupBox("TABLE_RIGHT_KEY_MENU (Right-click menu)")
        menu_layout = QVBoxLayout()
        
        self.menu_enabled = QCheckBox("Enable right-key menu extensions")
        self.menu_enabled.setChecked(True)
        menu_layout.addWidget(self.menu_enabled)
        
        self.menu_list = QListWidget()
        self.load_menu_items()
        menu_layout.addWidget(QLabel("Menu items:"))
        menu_layout.addWidget(self.menu_list)
        
        menu_group.setLayout(menu_layout)
        layout.addWidget(menu_group)
        
        # 按钮
        btn_layout = QHBoxLayout()
        self.save_btn = QPushButton("Save API Config")
        self.save_btn.clicked.connect(self.save_api_config)
        
        self.refresh_btn = QPushButton("Refresh API List")
        self.refresh_btn.clicked.connect(self.refresh_api_list)
        
        btn_layout.addWidget(self.save_btn)
        btn_layout.addWidget(self.refresh_btn)
        layout.addLayout(btn_layout)
        
        self.setLayout(layout)
```

---

## 4. MAIN Tab任务执行

### 4.1 MAIN Tab结构

```
MAIN Tab布局:

┌─────────────────────────────────────────────────────────────────────┐
│ Task Selection                                                      │
├─────────────────────────────────────────────────────────────────────┤
│ Block:   [ cpu_core       ] Version: [ v1.0      ]                 │
│ Flow:    [ syn          ▼ ] Run Mode: [ RUN       ▼ ]               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Task Table                                                          │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Task      │ Status │ Start Time  │ End Time │ Log │ Action      │ │
│ ├───────────┼────────┼─────────────┼──────────┼─────┼─────────────┤ │
│ │ initial   │ pass   │ 14:00:01    │ 14:00:05 │ [ ] │ [View]      │ │
│ │ syn_dc    │ pass   │ 14:00:05    │ 14:35:22 │ [ ] │ [View]      │ │
│ │ fm_rtl2gt │ pass   │ 14:35:22    │ 14:40:00 │ [ ] │ [View]      │ │
│ │ presta    │ pending│ -           │ -        │ [ ] │ [View]      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Build] [Run] [Check] [Summarize] [Release] [Refresh]           │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ Log Window                                                          │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Filter: All ▼] [Clear] [Export Log]                            │ │
│ ├─────────────────────────────────────────────────────────────────┤ │
│ │ [2026-05-13 14:00:01] Starting initial...                       │ │
│ │ [2026-05-13 14:00:05] initial completed: PASS                   │ │
│ │ [2026-05-13 14:00:05] Starting syn_dc...                        │ │
│ │ [2026-05-13 14:00:10] Job submitted: Job<12345>                 │ │
│ │ [2026-05-13 14:05:00] syn_dc: Compiling...                      │ │
│ │ [2026-05-13 14:10:00] syn_dc: Optimizing...                     │ │
│ │ [2026-05-13 14:35:22] syn_dc completed: PASS                    │ │
│ │ ...                                                             │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 任务表详解

```
任务表列说明:

| 列名 | 说明 | 内容示例 |
|------|------|----------|
| Task | 任务名 | syn_dc |
| Status | 任务状态 | pending/running/pass/fail |
| Start Time | 开始时间 | 2026-05-13 14:00:01 |
| End Time | 结束时间 | 2026-05-13 14:35:22 |
| Log | 日志按钮 | 点击打开日志文件 |
| Action | 操作按钮 | View/Retry/Delete等 |

状态颜色:
- pending: 灰色（等待执行）
- running: 黄色（正执行中）
- pass: 绿色（成功完成）
- fail: 红色（执行失败）

任务选择:
- 单选: 点击任务行
- 多选: Ctrl+点击
- 全选: Ctrl+A

右键菜单:
- View Log: 查看日志文件
- Open Directory: 打开工作目录
- Generate Report: 生成检查报告
- Retry: 重试失败任务
- Mark Pass: 手动标记成功
- Mark Fail: 手动标记失败
```

### 4.3 执行流程详解

```
完整执行流程:

Step 1: 选择Block/Version
┌─────────────────────────────────────────────────────────────────────┐
│ Block: [ cpu_core       ] Version: [ v1.0      ]                   │
│                                                                     │
│ 这两个值用于变量替换:                                                │
│ ${BLOCK} = cpu_core                                                │
│ ${VERSION} = v1.0                                                  │
│                                                                     │
│ 最终路径:                                                           │
│ ${CWD}/${BLOCK}/${VERSION}/${FLOW}                                 │
│ = /home/user/project/mychip/cpu_core/v1.0/syn                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 2: 选择Flow
┌─────────────────────────────────────────────────────────────────────┐
│ Flow: [ syn          ▼ ]                                           │
│                                                                     │
│ 可选值来自config['FLOW']:                                          │
│ syn: [initial, syn_dc, fm_rtl2gate, presta]                        │
│ dv: [sim_compile, sim_run, sim_check]                              │
│ full_flow: [initial, syn_dc, ..., release]                        │
│                                                                     │
│ 选择syn后，任务表显示:                                              │
│ - initial                                                          │
│ - syn_dc                                                           │
│ - fm_rtl2gate                                                      │
│ - presta                                                           │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 3: 选择Run Mode
┌─────────────────────────────────────────────────────────────────────┐
│ Run Mode: [ RUN       ▼ ]                                          │
│                                                                     │
│ 可选值来自任务定义的RUN_MODE和RUN.xxx:                              │
│ RUN         - 默认模式                                              │
│ RUN.DBG     - 调试模式                                              │
│ RUN.fast    - 快速模式                                              │
│ RUN.full    - 详尽模式                                              │
│                                                                     │
│ 选择不同模式影响:                                                   │
│ - COMMAND内容                                                       │
│ - RUN_METHOD                                                       │
│ - LOG路径                                                          │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 4: 选择任务
┌─────────────────────────────────────────────────────────────────────┐
│ 点击任务表中的任务行                                                │
│                                                                     │
│ 单选: 执行一个任务                                                  │
│ 多选: Ctrl+点击选择多个任务                                         │
│ 全选: Ctrl+A选择所有任务                                            │
│                                                                     │
│ 选中任务高亮显示                                                    │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 5: 执行Build
┌─────────────────────────────────────────────────────────────────────┐
│ 点击[Build]按钮                                                    │
│                                                                     │
│ 执行内容:                                                           │
│ 1. 检查依赖                                                         │
│    - FILE依赖: 文件是否存在                                         │
│    - LICENSE依赖: 许可是否可用                                      │
│    - TASK依赖: 前置任务是否完成                                      │
│                                                                     │
│ 2. 创建目录                                                         │
│    PATH = ${DEFAULT_PATH}/syn_dc                                   │
│    mkdir -p ${PATH}/run ${PATH}/check ${PATH}/log                  │
│                                                                     │
│ 3. 执行BUILD.COMMAND                                                │
│    cd ${PATH}                                                       │
│    mkdir -p ${PATH}/run ${PATH}/check ${PATH}/log                  │
│                                                                     │
│ 4. 写入日志                                                         │
│    ${PATH}/log/build.log                                           │
│                                                                     │
│ 5. 更新状态                                                         │
│    status = 'pass' 或 'fail'                                        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 6: 执行Run
┌─────────────────────────────────────────────────────────────────────┐
│ 点击[Run]按钮                                                      │
│                                                                     │
│ 执行内容:                                                           │
│ 1. 检查BUILD状态                                                    │
│    if BUILD != 'pass':                                             │
│        error: "BUILD not completed"                                │
│                                                                     │
│ 2. 检查依赖                                                         │
│    - FILE: ${DESIGN_PATH}/rtl/*.v                                  │
│    - LICENSE: DC 5                                                 │
│    - RUN_AFTER.TASK: initial                                       │
│                                                                     │
│ 3. 变量替换                                                         │
│    PATH = substitute(PATH, vars)                                   │
│    COMMAND = substitute(COMMAND, vars)                             │
│    RUN_METHOD = substitute(RUN_METHOD, vars)                       │
│                                                                     │
│ 4. 组装命令                                                         │
│    if RUN_METHOD.startswith('bsub'):                              │
│        full_cmd = RUN_METHOD + " " + COMMAND                       │
│    else:                                                            │
│        full_cmd = COMMAND                                          │
│                                                                     │
│ 5. 执行命令                                                         │
│    cd ${PATH}                                                       │
│    subprocess.run(full_cmd, cwd=PATH, shell=True)                  │
│                                                                     │
│    或LSF提交:                                                       │
│    bsub -q ai_syn -n 4 -R "rusage[mem=8000]" dc_shell -f syn.tcl   │
│                                                                     │
│ 6. 实时日志输出                                                     │
│    stdout/stderr → GUI Log Window                                  │
│    stdout/stderr → ${PATH}/log/run.log                             │
│                                                                     │
│ 7. 状态监控                                                         │
│    JobWatcher定时检查进程状态                                       │
│    或LSF bjobs检查任务状态                                          │
│                                                                     │
│ 8. 执行完成                                                         │
│    if returncode == 0:                                             │
│        status = 'pass'                                             │
│    else:                                                            │
│        status = 'fail'                                             │
│                                                                     │
│ 9. 自动触发CHECK                                                    │
│    if RUN.pass and CHECK defined:                                  │
│        auto_execute(CHECK)                                         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 7: 执行Check
┌─────────────────────────────────────────────────────────────────────┐
│ 点击[Check]按钮 或 RUN完成后自动触发                                │
│                                                                     │
│ 执行内容:                                                           │
│ 1. 检查RUN状态                                                      │
│    if RUN != 'pass':                                               │
│        error: "RUN not passed"                                     │
│                                                                     │
│ 2. 执行CHECK.COMMAND                                                │
│    python3 ${CHECK_SCRIPT} -d ${PATH} -f syn -b ${BLOCK}           │
│                                                                     │
│ 3. 检查脚本内容                                                     │
│    ic_check.py执行:                                                │
│    - 读取检查项定义                                                 │
│    - 执行各项检查                                                   │
│    - 生成Excel报告                                                  │
│    - 写入PASS/FAIL标记                                              │
│                                                                     │
│ 4. 报告生成                                                         │
│    REPORT_FILE = ${PATH}/file_check.rpt                            │
│    Excel格式报告                                                    │
│                                                                     │
│ 5. 结果判定                                                         │
│    if report.check_all_pass:                                       │
│        status = 'pass'                                             │
│        write ${PATH}/PASS                                          │
│    else:                                                            │
│        status = 'fail'                                             │
│        write ${PATH}/FAIL                                          │
│                                                                     │
│ 6. VIEWER查看                                                       │
│    点击[View]按钮:                                                  │
│    firefox ${REPORT_FILE}                                          │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 8: 执行Summarize
┌─────────────────────────────────────────────────────────────────────┐
│ 点击[Summarize]按钮                                                │
│                                                                     │
│ 执行内容:                                                           │
│ 1. 检查CHECK状态                                                    │
│    if CHECK != 'pass':                                             │
│        warn: "CHECK not passed, continue?"                         │
│                                                                     │
│ 2. 收集数据                                                         │
│    - syn_dc/run/output/*.v                                         │
│    - syn_dc/run/output/*.sdc                                       │
│    - syn_dc/check/file_check.rpt                                   │
│    - fm_rtl2gate/run/output/*.log                                  │
│                                                                     │
│ 3. 执行SUMMARIZE.COMMAND                                           │
│    python3 gen_summary.py                                          │
│                                                                     │
│ 4. 生成汇总报告                                                     │
│    Excel格式                                                        │
│    包含所有任务关键结果                                             │
│                                                                     │
│ 5. VIEWER查看                                                       │
│    firefox summary.xlsx                                            │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
Step 9: 执行Release
┌─────────────────────────────────────────────────────────────────────┐
│ 点击[Release]按钮                                                  │
│                                                                     │
│ 执行内容:                                                           │
│ 1. 检查SUMMARIZE状态                                                │
│    if SUMMARIZE != 'pass':                                         │
│        warn: "SUMMARIZE not passed"                                │
│                                                                     │
│ 2. 复制数据                                                         │
│    RELEASE_PATH = ${CWD}/release/${BLOCK}/${VERSION}               │
│    cp -r ${PATH}/run/output/* ${RELEASE_PATH}/                     │
│    cp -r ${PATH}/check/*.rpt ${RELEASE_PATH}/                      │
│                                                                     │
│ 3. 更新发布记录                                                     │
│    write release_manifest.yaml                                     │
│                                                                     │
│ 4. 完成流程                                                         │
│    status = 'released'                                             │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.4 日志窗口详解

```
日志窗口功能:

┌─────────────────────────────────────────────────────────────────────┐
│ Log Window                                                          │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Filter: All ▼] [Level: INFO ▼] [Clear] [Export Log] [Auto ▼] │ │
│ ├─────────────────────────────────────────────────────────────────┤ │
│ │ [2026-05-13 14:00:01] INFO Starting initial...                  │ │
│ │ [2026-05-13 14:00:02] INFO mkdir -p /project/cpu_core/v1.0/syn │ │
│ │ [2026-05-13 14:00:05] INFO initial completed: PASS              │ │
│ │ [2026-05-13 14:00:05] INFO Starting syn_dc...                   │ │
│ │ [2026-05-13 14:00:10] INFO Job submitted: Job<12345>            │ │
│ │ [2026-05-13 14:05:00] DEBUG syn_dc: Compiling rtl files...      │ │
│ │ [2026-05-13 14:10:00] DEBUG syn_dc: Applying constraints...     │ │
│ │ [2026-05-13 14:15:00] WARNING syn_dc: Timing not met for path X │ │
│ │ [2026-05-13 14:35:22] INFO syn_dc completed: PASS               │ │
│ │ [2026-05-13 14:35:25] INFO Starting CHECK for syn_dc...         │ │
│ │ [2026-05-13 14:36:00] INFO CHECK completed: PASS                │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

日志级别:
- DEBUG: 详细调试信息
- INFO: 正常执行信息
- WARNING: 警告信息
- ERROR: 错误信息
- CRITICAL: 严重错误

日志过滤:
- Filter: All/syn_dc/fm_rtl2gate/...
- Level: DEBUG/INFO/WARNING/ERROR

日志操作:
- Clear: 清空日志窗口
- Export Log: 导出日志文件
- Auto Scroll: 自动滚动到最新

ANSI颜色支持:
- 红色: ERROR
- 黄色: WARNING
- 绿色: INFO/PASS
- 灰色: DEBUG
```

---

## 5. FlowChart Tab流程可视化

### 5.1 FlowChart界面

```
FlowChart Tab布局:

┌─────────────────────────────────────────────────────────────────────┐
│ Flow Visualization                                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Flow: [ syn          ▼ ]                                           │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Graphviz生成的流程图                                            │ │
│ │                                                                 │ │
│ │    ┌─────────┐                                                 │ │
│ │    │ initial │ (绿色/pass)                                     │ │
│ │    └─────────┘                                                 │ │
│ │         │                                                       │ │
│ │         ↓                                                       │ │
│ │    ┌─────────┐                                                 │ │
│ │    │ syn_dc  │ (绿色/pass)                                     │ │
│ │    └─────────┘                                                 │ │
│ │         │                                                       │ │
│ │         ↓                                                       │ │
│ │    ┌───────────┐                                               │ │
│ │    │ fm_rtl2gt │ (绿色/pass)                                   │ │
│ │    └───────────┘                                               │ │
│ │         │                                                       │ │
│ │         ↓                                                       │ │
│ │    ┌─────────┐                                                 │ │
│ │    │ presta  │ (灰色/pending)                                  │ │
│ │    └─────────┘                                                 │ │
│ │                                                                 │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ [Generate] [Export PNG] [Export SVG] [Export PDF]              │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘

节点颜色含义:
- 绿色: pass（成功完成）
- 黄色: running（正在执行）
- 红色: fail（执行失败）
- 灰色: pending（待执行）
- 白色: 未定义状态

箭头含义:
- 直线箭头: 顺序依赖
- 虚线箭头: 可选依赖
```

### 5.2 Graphviz生成代码

```python
# FlowChart生成代码

import graphviz

def generate_flowchart(flow_name, tasks, status_dict):
    """生成流程图"""
    
    # 创建digraph
    dot = graphviz.Digraph(comment=f'Flow: {flow_name}')
    dot.attr(rankdir='TB')  # 从上到下布局
    
    # 添加节点
    for task_name in tasks:
        status = status_dict.get(task_name, 'pending')
        
        # 根据状态设置颜色
        if status == 'pass':
            color = 'green'
        elif status == 'running':
            color = 'yellow'
        elif status == 'fail':
            color = 'red'
        else:
            color = 'gray'
        
        dot.node(
            task_name,
            task_name,
            shape='box',
            style='filled',
            fillcolor=color
        )
    
    # 添加边（依赖关系）
    for i in range(len(tasks) - 1):
        dot.edge(tasks[i], tasks[i+1])
    
    # 渲染
    output_path = f'/tmp/flowchart_{flow_name}'
    dot.render(output_path, format='png', cleanup=True)
    
    return output_path + '.png'
```

---

## 6. 完整工作流程示例

### 6.1 综合流程完整操作

```
完整综合流程操作步骤:

===== 1. 启动IFP =====
$ cd ~/project/mychip
$ ifp

===== 2. CONFIG Tab设置 =====
进入CONFIG Tab:

Step 2.1: Setting界面
- Project: mychip
- Group: syn
- Block: cpu_core
- Version: v1.0
- Flow: syn
点击Apply

Step 2.2: Task界面
- 查看任务列表: initial, syn_dc, fm_rtl2gate, presta
- 检查任务配置是否正确
- 如需修改，点击Edit Task

Step 2.3: Order界面
- 查看执行顺序: initial → syn_dc → fm_rtl2gate → presta
- 如需调整，拖拽任务

Step 2.4: Variable界面
- 查看变量值
- 如需修改BSUB_QUEUE等，双击编辑

Step 2.5: API界面
- 检查PRE_CFG是否启用
- 检查右键菜单是否启用

===== 3. 返回MAIN Tab =====
进入MAIN Tab:

- Block: cpu_core
- Version: v1.0
- Flow: syn
- Run Mode: RUN

===== 4. 执行任务 =====

Step 4.1: 选择initial任务
点击initial行
点击[Build]
等待完成（通常几秒）

Step 4.2: 执行综合
选择syn_dc任务
点击[Build] → 创建目录
点击[Run] → 执行综合
查看日志窗口:
- Job submitted: Job<12345>
- Compiling...
- Optimizing...
- syn_dc completed: PASS

点击[Check] → 质量检查
查看检查报告:
- Timing check: PASS
- Area check: PASS
- Power check: PASS

Step 4.3: 执行形式验证
选择fm_rtl2gate任务
点击[Build]
点击[Run] → 验证RTL与门级一致性
点击[Check]

Step 4.4: 执行STA
选择presta任务
点击[Build]
点击[Run] → 静态时序分析
点击[Check]

===== 5. 汇总与发布 =====

Step 5.1: 汇总数据
点击[Summarize]
生成汇总报告Excel

Step 5.2: 发布数据
点击[Release]
复制到发布目录

===== 6. 查看结果 =====

进入FlowChart Tab:
- 查看流程图，所有节点绿色

点击日志窗口[Export Log]:
- 保存完整日志

查看发布目录:
$ ls ~/project/mychip/release/cpu_core/v1.0/
- netlist.v
- constraints.sdc
- file_check.rpt
- summary.xlsx
```

### 6.2 验证流程完整操作

```
完整验证流程操作步骤:

===== 1. 配置DV组 =====
进入CONFIG Tab → Setting:
- Project: mychip
- Group: dv
- Block: cpu_core
- Version: v1.0
- Flow: dv

===== 2. 执行仿真 =====
进入MAIN Tab:

Step 2.1: 编译
选择sim_compile任务
点击[Build]
点击[Run] → 编译仿真环境
- vcs -full64 -f file_list.f -top top_tb

Step 2.2: 运行仿真
选择sim_run任务
Run Mode: RUN.basic_test
点击[Build]
点击[Run] → 运行仿真
- ./simv +TEST=basic_test +TIME=10000

查看波形:
点击[View] → 打开波形文件

Step 2.3: 检查结果
点击[Check]
检查仿真结果:
- Test passed: PASS
- Coverage: 85%

===== 3. 回归测试 =====
Run Mode: RUN.regression
点击[Run] → 运行回归测试
等待所有测试完成

===== 4. 生成覆盖率报告 =====
点击[Summarize]
生成覆盖率报告
```

---

## 7. 快捷键与技巧

### 7.1 快捷键列表

```
全局快捷键:
Ctrl+O      打开项目
Ctrl+S      保存配置
Ctrl+Q      退出IFP
F5          刷新界面
Ctrl+H      打开帮助

MAIN Tab快捷键:
Ctrl+B      执行Build
Ctrl+R      执行Run
Ctrl+C      执行Check
Ctrl+G      执行Summarize
Ctrl+L      执行Release
Ctrl+A      全选任务
Ctrl+Click  多选任务
Right Click 打开右键菜单

CONFIG Tab快捷键:
Ctrl+N      添加新任务
Ctrl+E      编辑选中任务
Ctrl+D      删除选中任务
Ctrl+Z      撤销操作
Ctrl+Y      重做操作

日志窗口快捷键:
Ctrl+F      搜索日志
Ctrl+L      清空日志
Ctrl+E      导出日志
```

### 7.2 使用技巧

```
技巧1: 批量执行
- 全选任务（Ctrl+A）
- 点击[Build] → 所有任务创建目录
- 点击[Run] → 按依赖顺序执行

技巧2: 调试模式
- Run Mode选择RUN.DBG
- 命令使用调试脚本
- 日志更详细

技巧3: 快速检查
- RUN完成后自动CHECK
- 无需手动点击[Check]

技巧4: 日志过滤
- Filter选择特定任务
- 只查看该任务日志

技巧5: 状态恢复
- IFP自动保存状态到.ifp.status.yaml
- 关闭后重新打开，状态恢复
- 不需要重新执行已完成任务

技巧6: 多版本管理
- 同一Block创建多个Version
- v1.0, v1.1, v2.0
- 选择不同Version执行

技巧7: 多Block管理
- 同一项目多个Block
- cpu_core, cache, alu
- 选择不同Block执行

技巧8: 配置导出
- File → Export Config
- 导出为YAML
- 分享给团队使用
```

---

*Chiplet Design Practice*
*文档生成: 2026-05-13*