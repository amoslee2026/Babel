# IFP 任务管理机制

本文档详细解析IC Flow Platform的任务生命周期、状态管理、依赖处理和并行控制机制。

---

## 1. 任务生命周期

### 1.1 五阶段模型

IFP任务执行遵循严格的五阶段模型。

```
任务执行阶段:

┌─────────────────────────────────────────────────────────────────────┐
│                     Task Lifecycle                                  │
│                     Five-Phase Model                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Phase 1: BUILD                                                    │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 目的: 创建工作目录和初始化环境                                   │ │
│  │                                                                 │ │
│  │ 执行内容:                                                       │ │
│  │ - 创建PATH目录                                                  │ │
│  │ - 创建子目录: run/, check/, log/                               │ │
│  │ - 执行BUILD.COMMAND                                            │ │
│  │ - 生成BUILD日志                                                 │ │
│  │                                                                 │ │
│  │ 特点:                                                           │ │
│  │ - 本地执行（RUN_METHOD: local）                                │ │
│  │ - 执行速度快（通常几秒）                                         │ │
│  │ - 不消耗许可                                                     │ │
│  │ - 不依赖文件                                                     │ │
│  │                                                                 │ │
│  │ 输出:                                                           │ │
│  │ - 目录结构创建                                                   │ │
│  │ - build.log                                                     │ │
│  │                                                                 │ │
│  │ 状态变化:                                                       │ │
│  │ pending → running → pass/fail                                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│                                                                     │
│  Phase 2: RUN                                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 目的: 执行核心任务命令                                           │ │
│  │                                                                 │ │
│  │ 执行内容:                                                       │ │
│  │ - 检查BUILD状态（必须pass）                                     │ │
│  │ - 检查所有依赖                                                   │ │
│  │ - 变量替换PATH/COMMAND                                          │ │
│  │ - 组装完整命令                                                   │ │
│  │ - 执行RUN.COMMAND                                               │ │
│  │ - 实时日志输出                                                   │ │
│  │ - 状态监控                                                       │ │
│  │                                                                 │ │
│  │ 特点:                                                           │ │
│  │ - 支持LSF提交或本地执行                                          │ │
│  │ - 执行时间较长（几分钟到几小时）                                   │ │
│  │ - 消耗许可（LICENSE依赖）                                        │ │
│  │ - 依赖文件/任务                                                   │ │
│  │                                                                 │ │
│  │ 执行方式:                                                       │ │
│  │ - local: subprocess.run()                                       │ │
│  │ - bsub: bsub -q queue -n cores COMMAND                         │ │
│  │                                                                 │ │
│  │ 输出:                                                           │ │
│  │ - run.log                                                       │ │
│  │ - 设计数据（netlist.v, reports等）                               │ │
│  │                                                                 │ │
│  │ 状态变化:                                                       │ │
│  │ pending → running → pass/fail                                  │ │
│  │                                                                 │ │
│  │ RUN成功后自动触发CHECK                                           │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│                                                                     │
│  Phase 3: CHECK                                                    │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 目的: 自动化质量检查                                             │ │
│  │                                                                 │ │
│  │ 执行内容:                                                       │ │
│  │ - 检查RUN状态（必须pass）                                       │ │
│  │ - 执行CHECK.COMMAND                                             │ │
│  │ - 运行检查脚本                                                   │ │
│  │ - 生成Excel报告                                                  │ │
│  │ - 判定PASS/FAIL                                                 │ │
│  │ - 写入标记文件                                                   │ │
│  │                                                                 │ │
│  │ 特点:                                                           │ │
│  │ - 本地执行                                                       │ │
│  │ - 使用Python检查脚本                                             │ │
│  │ - 生成结构化报告                                                 │ │
│  │ - 支持VIEWER查看                                                 │ │
│  │                                                                 │ │
│  │ 检查内容:                                                       │ │
│  │ - Timing检查                                                     │ │
│  │ - Area检查                                                       │ │
│  │ - Power检查                                                      │ │
│  │ - DRC检查                                                        │ │
│  │ - 结果一致性检查                                                  │ │
│  │                                                                 │ │
│  │ 输出:                                                           │ │
│  │ - file_check.rpt（Excel）                                       │ │
│  │ - PASS或FAIL文件                                                 │ │
│  │                                                                 │ │
│  │ 状态变化:                                                       │ │
│  │ pending → running → pass/fail                                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│                                                                     │
│  Phase 4: SUMMARIZE                                                │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 目的: 数据收集与汇总                                             │ │
│  │                                                                 │ │
│  │ 执行内容:                                                       │ │
│  │ - 检查CHECK状态                                                 │ │
│  │ - 收集各阶段数据                                                 │ │
│  │ - 执行SUMMARIZE.COMMAND                                         │ │
│  │ - 生成汇总报告                                                   │ │
│  │                                                                 │ │
│  │ 特点:                                                           │ │
│  │ - 本地执行                                                       │ │
│  │ - 收集多任务数据                                                 │ │
│  │ - 生成Excel汇总                                                  │ │
│  │                                                                 │ │
│  │ 收集内容:                                                       │ │
│  │ - 综合结果                                                       │ │
│  │ - 验证结果                                                       │ │
│  │ - STA结果                                                        │ │
│  │ - 检查报告                                                       │ │
│  │                                                                 │ │
│  │ 输出:                                                           │ │
│  │ - summary.xlsx                                                  │ │
│  │                                                                 │ │
│  │ 状态变化:                                                       │ │
│  │ pending → running → pass/fail                                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│                                                                     │
│  Phase 5: RELEASE                                                  │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 目的: 数据发布                                                   │ │
│  │                                                                 │ │
│  │ 执行内容:                                                       │ │
│  │ - 检查SUMMARIZE状态                                             │ │
│  │ - 复制数据到发布目录                                             │ │
│  │ - 执行RELEASE.COMMAND                                           │ │
│  │ - 更新发布记录                                                   │ │
│  │                                                                 │ │
│  │ 特点:                                                           │ │
│  │ - 本地执行                                                       │ │
│  │ - 复制操作                                                       │ │
│  │ - 生成发布清单                                                   │ │
│  │                                                                 │ │
│  │ 发布内容:                                                       │ │
│  │ - 最终网表                                                       │ │
│  │ - 约束文件                                                       │ │
│  │ - 检查报告                                                       │ │
│  │ - 汇总报告                                                       │ │
│  │                                                                 │ │
│  │ 输出:                                                           │ │
│  │ - release目录内容                                               │ │
│  │ - release_manifest.yaml                                         │ │
│  │                                                                 │ │
│  │ 状态变化:                                                       │ │
│  │ pending → running → pass → released                            │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 阶段配置详解

每个阶段在YAML中有独立配置块。

```yaml
TASK:
  syn_dc:
    # Phase 1: BUILD配置
    BUILD:
      PATH: ${DEFAULT_PATH}/syn_dc
      COMMAND: mkdir -p ${PATH}/run ${PATH}/check ${PATH}/log
      LOG: ${PATH}/log/build.log
      RUN_METHOD: local
    
    # Phase 2: RUN配置
    RUN:
      PATH: ${DEFAULT_PATH}/syn_dc
      COMMAND: dc_shell -f syn.tcl
      RUN_METHOD: bsub -q ai_syn -n 4 -R "rusage[mem=8000]"
      LOG: ${PATH}/log/run.log
      RUN_MODE: ${SYN_RUN}
      
      # RUN模式变体
      RUN.DBG:
        COMMAND: dc_shell -f syn_dbg.tcl
        LOG: ${PATH}/log/run_dbg.log
      
      # 依赖配置
      RUN_AFTER:
        TASK: initial
      DEPENDENCY:
        FILE: [${DESIGN_PATH}/rtl/*.v]
        LICENSE: [DC 5]
    
    # Phase 3: CHECK配置
    CHECK:
      PATH: ${DEFAULT_PATH}/syn_dc/check
      COMMAND: python3 ${CHECK_SCRIPT} -d ${PATH} -f syn -b ${BLOCK}
      LOG: ${PATH}/log/check.log
      REPORT_FILE: ${PATH}/file_check.rpt
      VIEWER: firefox ${REPORT_FILE}
      RUN_METHOD: local
    
    # Phase 4: SUMMARIZE配置
    SUMMARIZE:
      PATH: ${DEFAULT_PATH}/syn_dc
      COMMAND: python3 gen_summary.py
      LOG: ${PATH}/log/summarize.log
      RUN_METHOD: local
    
    # Phase 5: RELEASE配置
    RELEASE:
      PATH: ${DEFAULT_PATH}/syn_dc
      COMMAND: cp -r ${PATH}/run/output/* ${RELEASE_PATH}/
      LOG: ${PATH}/log/release.log
      RUN_METHOD: local
```

### 1.3 阶段状态依赖

各阶段存在严格的状态依赖关系。

```
阶段依赖关系:

┌─────────────────────────────────────────────────────────────────────┐
│                     Phase Dependency                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  BUILD → RUN → CHECK → SUMMARIZE → RELEASE                         │
│                                                                     │
│  依赖规则:                                                          │
│                                                                     │
│  RUN依赖:                                                           │
│  - BUILD必须pass                                                   │
│  - 所有DEPENDENCY必须满足                                           │
│  - RUN_AFTER.TASK必须pass                                          │
│                                                                     │
│  CHECK依赖:                                                         │
│  - RUN必须pass                                                     │
│  - RUN完成后自动触发CHECK                                           │
│                                                                     │
│  SUMMARIZE依赖:                                                     │
│  - CHECK建议pass（警告级别）                                        │
│  - CHECK失败可继续SUMMARIZE                                         │
│                                                                     │
│  RELEASE依赖:                                                       │
│  - SUMMARIZE建议pass                                               │
│  - 所有关键数据必须存在                                              │
│                                                                     │
│  错误处理:                                                          │
│  - BUILD失败: RUN无法执行                                           │
│  - RUN失败: CHECK不执行                                             │
│  - CHECK失败: 继续后续阶段但标记                                     │
│  - SUMMARIZE失败: RELEASE可执行                                     │
│  - RELEASE失败: 流程标记为部分成功                                    │
│                                                                     │
│  代码实现:                                                          │
│                                                                     │
│  def check_phase_dependency(phase, task_info):                     │
│      """检查阶段依赖"""                                              │
│      if phase == 'RUN':                                            │
│          # BUILD必须完成                                            │
│          if task_info['BUILD']['status'] != 'pass':               │
│              return False, "BUILD not passed"                      │
│                                                                     │
│          # 文件依赖                                                 │
│          for file in task_info['RUN']['DEPENDENCY']['FILE']:      │
│              if not os.path.exists(file):                         │
│                  return False, f"File missing: {file}"            │
│                                                                     │
│          # 许可依赖                                                 │
│          for lic in task_info['RUN']['DEPENDENCY']['LICENSE']:   │
│              tool, count = lic.split()                            │
│              if not check_license(tool, int(count)):              │
│                  return False, f"License unavailable: {tool}"     │
│                                                                     │
│          # 任务依赖                                                 │
│          pre_task = task_info['RUN']['RUN_AFTER']['TASK']         │
│          if pre_task and get_task_status(pre_task) != 'pass':    │
│              return False, f"Pre-task not passed: {pre_task}"    │
│                                                                     │
│      elif phase == 'CHECK':                                       │
│          if task_info['RUN']['status'] != 'pass':                │
│              return False, "RUN not passed"                       │
│                                                                     │
│      return True, "OK"                                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 任务状态管理

### 2.1 四状态模型

任务状态采用四状态模型。

```
任务状态:

┌─────────────────────────────────────────────────────────────────────┐
│                     Task Status Model                               │
│                     Four-State Model                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐                                                   │
│  │   pending   │                                                   │
│  │   (等待)    │                                                   │
│  └─────────────┘                                                   │
│        │                                                            │
│        │ 检查依赖通过                                                │
│        │ 开始执行                                                   │
│        ↓                                                            │
│  ┌─────────────┐                                                   │
│  │   running   │                                                   │
│  │   (执行中)  │                                                   │
│  └─────────────┘                                                   │
│        │                                                            │
│        ├─────────── 执行成功 ───────────┐                          │
│        │                                │                          │
│        ↓                                ↓                          │
│  ┌─────────────┐               ┌─────────────┐                    │
│  │    pass     │               │    fail     │                    │
│  │   (成功)    │               │   (失败)    │                    │
│  └─────────────┘               └─────────────┘                    │
│                                     │                              │
│                                     │ 用户手动重试                  │
│                                     ↓                              │
│                              ┌─────────────┐                      │
│                              │   pending   │                      │
│                              │   (重新等待) │                      │
│                              └─────────────┘                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

状态定义:

pending:
- 含义: 任务待执行
- 条件: 任务已添加但未开始
- 阻塞因素:
  - BUILD未完成
  - 文件依赖不满足
  - 许可依赖不满足
  - 前置任务未完成
  - 并行数已达上限
- GUI显示: 灰色
- 可执行操作: Build, Run（条件满足后）

running:
- 含义: 任务正执行
- 条件: 命令已提交，进程/LSF job活跃
- 监控方式:
  - local: subprocess.poll()
  - bsub: bjobs查询
- GUI显示: 黄色
- 可执行操作: 查看日志，等待完成

pass:
- 含义: 任务成功完成
- 条件: 命令执行成功，returncode=0
- 后续动作:
  - 自动触发下一阶段
  - 释放许可资源
  - 更新依赖状态
- GUI显示: 绿色
- 可执行操作: Check, Summarize, Release, View

fail:
- 含义: 任务执行失败
- 条件: 命令执行失败，returncode≠0
- 原因:
  - 命令错误
  - 超时
  - 资源不足
  - 被手动终止
- GUI显示: 红色
- 可执行操作: Retry, View Log, Mark Pass
```

### 2.2 状态存储机制

任务状态持久化存储，支持断点恢复。

```python
# 状态存储代码

import sqlite3
import yaml
import json

# SQLite数据库存储
def init_db(db_path):
    """初始化数据库"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 创建任务状态表
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS task_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        block TEXT NOT NULL,
        version TEXT NOT NULL,
        flow TEXT NOT NULL,
        task TEXT NOT NULL,
        phase TEXT NOT NULL,
        status TEXT NOT NULL,
        start_time DATETIME,
        end_time DATETIME,
        log_path TEXT,
        returncode INTEGER,
        details TEXT
    )
    ''')
    
    # 创建索引
    cursor.execute('''
    CREATE INDEX IF NOT EXISTS idx_task 
    ON task_status(block, version, flow, task, phase)
    ''')
    
    conn.commit()
    conn.close()

def save_task_status(db_path, block, version, flow, task, phase, status, 
                     start_time=None, end_time=None, log_path=None, 
                     returncode=None, details=None):
    """保存任务状态"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 查找现有记录
    cursor.execute('''
    SELECT id FROM task_status 
    WHERE block=? AND version=? AND flow=? AND task=? AND phase=?
    ''', (block, version, flow, task, phase))
    
    existing = cursor.fetchone()
    
    if existing:
        # 更新现有记录
        cursor.execute('''
        UPDATE task_status 
        SET status=?, start_time=?, end_time=?, log_path=?, returncode=?, details=?
        WHERE id=?
        ''', (status, start_time, end_time, log_path, returncode, 
              json.dumps(details) if details else None, existing[0]))
    else:
        # 插入新记录
        cursor.execute('''
        INSERT INTO task_status 
        (block, version, flow, task, phase, status, start_time, end_time, 
         log_path, returncode, details)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (block, version, flow, task, phase, status, start_time, end_time,
              log_path, returncode, json.dumps(details) if details else None))
    
    conn.commit()
    conn.close()

def load_task_status(db_path, block, version, flow, task):
    """加载任务状态"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute('''
    SELECT phase, status, start_time, end_time, log_path, returncode, details
    FROM task_status 
    WHERE block=? AND version=? AND flow=? AND task=?
    ORDER BY phase
    ''', (block, version, flow, task))
    
    results = cursor.fetchall()
    conn.close()
    
    status_dict = {}
    for row in results:
        phase, status, start_time, end_time, log_path, returncode, details = row
        status_dict[phase] = {
            'status': status,
            'start_time': start_time,
            'end_time': end_time,
            'log_path': log_path,
            'returncode': returncode,
            'details': json.loads(details) if details else None
        }
    
    return status_dict

# YAML状态文件（备份）
def save_status_yaml(status_file, status_dict):
    """保存YAML状态文件"""
    with open(status_file, 'w') as f:
        yaml.dump(status_dict, f, default_flow_style=False)

def load_status_yaml(status_file):
    """加载YAML状态文件"""
    if os.path.exists(status_file):
        with open(status_file) as f:
            return yaml.safe_load(f)
    return {}

# 状态恢复
def restore_status_on_startup(db_path, status_file):
    """启动时恢复状态"""
    # 优先从SQLite加载
    if os.path.exists(db_path):
        return load_all_status_from_db(db_path)
    
    # 备用从YAML加载
    if os.path.exists(status_file):
        return load_status_yaml(status_file)
    
    return {}
```

### 2.3 状态更新时机

```
状态更新时机:

┌─────────────────────────────────────────────────────────────────────┐
│                     Status Update Timing                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  BUILD阶段:                                                         │
│  - 开始: pending → running                                         │
│    - 时机: 点击[Build]按钮                                          │
│    - 动作: 写入DB，记录start_time                                   │
│                                                                     │
│  - 完成: running → pass/fail                                       │
│    - 时机: mkdir命令返回                                             │
│    - 动作: 写入DB，记录end_time, returncode                         │
│                                                                     │
│  RUN阶段:                                                           │
│  - 开始: pending → running                                         │
│    - 时机: 命令提交（bsub或subprocess）                              │
│    - 动作: 写入DB，记录start_time, job_id                           │
│                                                                     │
│  - 执行中: running → running（状态不变）                            │
│    - 时机: JobWatcher轮询                                           │
│    - 动作: 更新日志，检查进程状态                                     │
│                                                                     │
│  - 完成: running → pass/fail                                       │
│    - 时机: 进程结束或bjobs显示DONE/EXIT                              │
│    - 动作: 写入DB，记录end_time, returncode                         │
│    - 自动: 触发CHECK阶段                                             │
│                                                                     │
│  CHECK阶段:                                                         │
│  - 开始: pending → running                                         │
│    - 时机: RUN完成后自动触发                                         │
│    - 动作: 写入DB，记录start_time                                    │
│                                                                     │
│  - 完成: running → pass/fail                                       │
│    - 时机: ic_check.py返回                                          │
│    - 动作: 写入DB，记录end_time, report_path                        │
│                                                                     │
│  SUMMARIZE阶段:                                                     │
│  - 开始: pending → running                                         │
│    - 时机: 点击[Summarize]按钮                                       │
│    - 动作: 写入DB，记录start_time                                    │
│                                                                     │
│  - 完成: running → pass/fail                                       │
│    - 时机: gen_summary.py返回                                       │
│    - 动作: 写入DB，记录end_time, summary_path                       │
│                                                                     │
│  RELEASE阶段:                                                       │
│  - 开始: pending → running                                         │
│    - 时机: 点击[Release]按钮                                         │
│    - 动作: 写入DB，记录start_time                                    │
│                                                                     │
│  - 完成: running → pass → released                                 │
│    - 时机: cp命令完成                                                │
│    - 动作: 写入DB，记录end_time, release_path                       │
│                                                                     │
│  用户操作:                                                          │
│  - Retry: fail → pending                                           │
│    - 时机: 点击[Retry]按钮                                           │
│    - 动作: 更新DB，清除旧状态                                         │
│                                                                     │
│  - Mark Pass: fail → pass                                          │
│    - 时机: 点击[Mark Pass]按钮                                       │
│    - 动作: 更新DB，手动标记                                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 依赖管理

### 3.1 三类依赖

IFP支持三种依赖类型：文件依赖、许可依赖、任务依赖。

```yaml
# 依赖配置示例

RUN:
  # 任务依赖
  RUN_AFTER:
    TASK: initial                    # 单任务依赖
    # TASKS: [task1, task2]          # 多任务依赖（可选）
  
  # 依赖配置块
  DEPENDENCY:
    # 文件依赖
    FILE:
      - ${DESIGN_PATH}/rtl/top.v     # 设计文件必须存在
      - ${DESIGN_PATH}/lib/*.lib     # 库文件必须存在
      - ${CWD}/setup.txt             # 配置文件必须存在
    
    # 许可依赖
    LICENSE:
      - DC 5                         # 需要5个DC许可
      - FM 2                         # 需要2个FM许可
      - PT 3                         # 需要3个PT许可
```

### 3.2 文件依赖检查

```python
# 文件依赖检查代码

import os
import glob

def check_file_dependency(file_list):
    """
    检查文件依赖
    
    Args:
        file_list: 文件路径列表（可含通配符）
    
    Returns:
        (bool, str): (是否满足, 错误消息)
    """
    missing_files = []
    
    for file_pattern in file_list:
        # 处理通配符
        if '*' in file_pattern or '?' in file_pattern:
            # 使用glob匹配
            matched_files = glob.glob(file_pattern)
            if not matched_files:
                missing_files.append(file_pattern)
        else:
            # 直接检查存在性
            if not os.path.exists(file_pattern):
                missing_files.append(file_pattern)
    
    if missing_files:
        return False, f"Missing files: {missing_files}"
    
    return True, "OK"

# 使用示例
file_deps = [
    '/project/design/rtl/top.v',
    '/project/design/rtl/*.v',        # 通配符
    '/project/design/lib/*.lib'
]

ok, msg = check_file_dependency(file_deps)
if not ok:
    print(f"Dependency check failed: {msg}")
else:
    print("All files exist, proceeding...")
```

### 3.3 许可依赖检查

```python
# 许可依赖检查代码

import subprocess
import re

def check_license(tool, required_count):
    """
    检查许可可用性
    
    Args:
        tool: 工具名（DC, FM, PT等）
        required_count: 需求数量
    
    Returns:
        (bool, int): (是否满足, 可用数量)
    """
    # 方式1: 使用lmstat查询（Synopsys许可）
    # lmstat -a -c license_file
    
    # 方式2: 使用内部许可检查工具
    result = subprocess.run(
        ['lmstat', '-a'],
        capture_output=True,
        text=True
    )
    
    # 解析输出
    # Users of DesignCompiler:  (Total of 10 licenses issued;  Total of 3 licenses in use)
    pattern = f'Users of {tool}:.*Total of (\d+) licenses issued.*Total of (\d+) licenses in use'
    match = re.search(pattern, result.stdout)
    
    if match:
        issued = int(match.group(1))
        in_use = int(match.group(2))
        available = issued - in_use
        
        return available >= required_count, available
    
    # 许可信息无法解析
    return False, 0

def check_license_dependency(license_list):
    """
    检查许可依赖
    
    Args:
        license_list: 许需列表 ['DC 5', 'FM 2']
    
    Returns:
        (bool, str): (是否满足, 错误消息)
    """
    insufficient = []
    
    for license_req in license_list:
        parts = license_req.split()
        if len(parts) == 2:
            tool = parts[0]
            count = int(parts[1])
            
            ok, available = check_license(tool, count)
            if not ok:
                insufficient.append(f"{tool}: need {count}, have {available}")
    
    if insufficient:
        return False, f"Insufficient licenses: {insufficient}"
    
    return True, "OK"

# 许可资源管理
license_pool = {}

def acquire_license(tool, count):
    """获取许可"""
    if tool not in license_pool:
        license_pool[tool] = {'available': 0, 'allocated': {}}
    
    if license_pool[tool]['available'] >= count:
        license_pool[tool]['available'] -= count
        return True
    return False

def release_license(tool, count):
    """释放许可"""
    if tool in license_pool:
        license_pool[tool]['available'] += count
```

### 3.4 任务依赖检查

```python
# 任务依赖检查代码

def check_task_dependency(pre_task_name, status_dict):
    """
    检查任务依赖
    
    Args:
        pre_task_name: 前置任务名
        status_dict: 状态字典
    
    Returns:
        (bool, str): (是否满足, 错误消息)
    """
    # 检查前置任务是否存在
    if pre_task_name not in status_dict:
        return False, f"Pre-task '{pre_task_name}' not found"
    
    # 检查RUN状态
    if 'RUN' in status_dict[pre_task_name]:
        status = status_dict[pre_task_name]['RUN']['status']
        if status != 'pass':
            return False, f"Pre-task '{pre_task_name}' RUN status: {status}"
    else:
        return False, f"Pre-task '{pre_task_name}' RUN not completed"
    
    return True, "OK"

def check_all_dependencies(task_config, status_dict):
    """
    检查所有依赖
    
    Args:
        task_config: 任务配置
        status_dict: 状态字典
    
    Returns:
        (bool, str): (是否满足, 错误消息)
    """
    # 1. BUILD状态检查
    if 'BUILD' in task_config and task_config['BUILD']['status'] != 'pass':
        return False, "BUILD not passed"
    
    # 2. 文件依赖
    if 'DEPENDENCY' in task_config and 'FILE' in task_config['DEPENDENCY']:
        ok, msg = check_file_dependency(task_config['DEPENDENCY']['FILE'])
        if not ok:
            return False, msg
    
    # 3. 许可依赖
    if 'DEPENDENCY' in task_config and 'LICENSE' in task_config['DEPENDENCY']:
        ok, msg = check_license_dependency(task_config['DEPENDENCY']['LICENSE'])
        if not ok:
            return False, msg
    
    # 4. 任务依赖
    if 'RUN_AFTER' in task_config and 'TASK' in task_config['RUN_AFTER']:
        pre_task = task_config['RUN_AFTER']['TASK']
        ok, msg = check_task_dependency(pre_task, status_dict)
        if not ok:
            return False, msg
    
    return True, "OK"
```

---

## 4. 并行控制

### 4.1 MAX_RUNNING_JOBS机制

IFP使用MAX_RUNNING_JOBS控制最大并行任务数。

```yaml
# VAR中定义最大并行数
VAR:
  MAX_RUNNING_JOBS: 10               # 最大10个任务并行

# 或在任务配置中覆盖
TASK:
  syn_dc:
    RUN:
      MAX_RUNNING_JOBS: 5            # syn_dc最多5个并行实例
```

### 4.2 并行控制代码实现

```python
# 并行控制代码

import threading
from collections import deque

# 全局信号量
semaphore = threading.BoundedSemaphore(50)

class JobManager:
    """任务管理器"""
    
    def __init__(self, max_running_jobs=10):
        self.max_running_jobs = max_running_jobs
        
        # 任务队列
        self.pending_queue = deque()      # 待执行队列
        self.running_list = []            # 正执行列表
        self.completed_dict = {}          # 完成字典
        
        # 锁
        self.lock = threading.Lock()
    
    def add_task(self, task_info):
        """添加任务到队列"""
        with self.lock:
            self.pending_queue.append(task_info)
        
        # 尝试调度
        self.try_schedule()
    
    def try_schedule(self):
        """尝试调度任务"""
        with self.lock:
            # 检查并行限制
            while len(self.running_list) < self.max_running_jobs and self.pending_queue:
                task_info = self.pending_queue.popleft()
                
                # 检查依赖
                ok, msg = check_all_dependencies(task_info, self.completed_dict)
                if not ok:
                    # 依赖不满足，放回队列末尾
                    self.pending_queue.append(task_info)
                    continue
                
                # 执行任务
                self.execute_task(task_info)
    
    def execute_task(self, task_info):
        """执行任务"""
        # 更新状态
        task_info['status'] = 'running'
        task_info['start_time'] = datetime.now()
        
        with self.lock:
            self.running_list.append(task_info)
        
        # 创建执行线程
        thread = threading.Thread(
            target=self.run_task,
            args=(task_info,)
        )
        thread.start()
    
    def run_task(self, task_info):
        """任务执行线程"""
        # 获取信号量
        semaphore.acquire()
        
        try:
            # 执行命令
            config = task_info['config']
            path = config['PATH']
            command = config['COMMAND']
            
            result = subprocess.run(
                command,
                cwd=path,
                shell=True,
                capture_output=True,
                text=True
            )
            
            # 更新状态
            if result.returncode == 0:
                status = 'pass'
            else:
                status = 'fail'
            
            task_info['status'] = status
            task_info['end_time'] = datetime.now()
            task_info['returncode'] = result.returncode
            
            # 保存到完成字典
            with self.lock:
                key = task_info['key']
                self.completed_dict[key] = task_info
                self.running_list.remove(task_info)
            
            # 触发CHECK
            if status == 'pass' and 'CHECK' in config:
                self.auto_trigger_check(task_info)
            
        finally:
            # 释放信号量
            semaphore.release()
            
            # 尝试调度下一个
            self.try_schedule()
    
    def auto_trigger_check(self, task_info):
        """自动触发CHECK"""
        check_task_info = {
            'key': task_info['key'] + '_check',
            'task': task_info['task'] + '_check',
            'config': task_info['config']['CHECK'],
            'status': 'pending'
        }
        self.add_task(check_task_info)
    
    def get_status_summary(self):
        """获取状态汇总"""
        with self.lock:
            return {
                'pending': len(self.pending_queue),
                'running': len(self.running_list),
                'pass': sum(1 for t in self.completed_dict.values() if t['status'] == 'pass'),
                'fail': sum(1 for t in self.completed_dict.values() if t['status'] == 'fail')
            }
```

### 4.3 并行调度策略

```
并行调度策略:

┌─────────────────────────────────────────────────────────────────────┐
│                     Parallel Scheduling                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  策略1: FIFO（先进先出）                                            │
│  - 任务按添加顺序排队                                               │
│  - 依赖满足时立即调度                                               │
│  - 简单但可能不够高效                                               │
│                                                                     │
│  策略2: 优先级调度                                                  │
│  - 任务可设置优先级                                                 │
│  - 高优先级任务优先调度                                             │
│  - 适用场景: 关键路径任务                                            │
│                                                                     │
│  策略3: 依赖优先调度                                                │
│  - 自动识别依赖链                                                   │
│  - 阻塞其他任务的任务优先                                             │
│  - 适用场景: 复杂依赖网络                                            │
│                                                                     │
│  策略4: 资源感知调度                                                │
│  - 考虑许可资源可用性                                               │
│  - 考虑内存资源                                                     │
│  - 适用场景: 许可受限环境                                            │
│                                                                     │
│  IFP默认使用FIFO + 依赖检查:                                        │
│                                                                     │
│  1. 任务添加到pending_queue                                         │
│  2. 调度器检查running_list长度                                       │
│  3. 若未达上限，取出队首任务                                          │
│  4. 检查依赖是否满足                                                 │
│  5. 满足则执行，不满足则放回队尾                                       │
│  6. 任务完成后释放资源                                               │
│  7. 重新触发调度                                                     │
│                                                                     │
│  队列状态示例:                                                      │
│                                                                     │
│  pending_queue: [task4, task5, task6]                              │
│  running_list: [task1, task2, task3]                               │
│  completed_dict: {task0: pass}                                     │
│                                                                     │
│  MAX_RUNNING_JOBS: 10                                              │
│  current_running: 3                                                │
│  可调度: 7                                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. RUN_MODE模式系统

### 5.1 RUN_MODE定义

RUN_MODE允许定义任务的不同执行模式。

```yaml
TASK:
  syn_dc:
    RUN:
      # 默认模式
      RUN_MODE: ${SYN_RUN}           # 通常值为 RUN
      
      # 正常模式
      RUN:
        COMMAND: dc_shell -f syn.tcl
        LOG: ${PATH}/log/run.log
        RUN_METHOD: ${BSUB_RUN_METHOD}
      
      # 调试模式
      RUN.DBG:
        COMMAND: dc_shell -f syn_dbg.tcl
        LOG: ${PATH}/log/run_dbg.log
        RUN_METHOD: local             # 本地执行
      
      # 快速模式
      RUN.fast:
        COMMAND: dc_shell -f syn_fast.tcl
        LOG: ${PATH}/log/run_fast.log
        RUN_METHOD: local
        # 简化约束，快速执行
      
      # 详尽模式
      RUN.full:
        COMMAND: dc_shell -f syn_full.tcl
        LOG: ${PATH}/log/run_full.log
        RUN_METHOD: bsub -q high_perf -n 8 -R "rusage[mem=16000]"
        # 更多资源，更高质量
      
      # 特定配置模式
      RUN.option1:
        COMMAND: dc_shell -f syn_opt1.tcl
        VAR:
          OPT_LEVEL: 1                # 模式级变量
```

### 5.2 RUN_MODE选择

```python
# RUN_MODE选择代码

def select_run_mode(config, run_mode):
    """
    选择RUN_MODE
    
    Args:
        config: 任务配置
        run_mode: 用户选择的模式名（RUN, RUN.DBG等）
    
    Returns:
        dict: 该模式的配置
    """
    run_config = config.get('RUN', {})
    
    # 检查是否是标准模式
    if run_mode in run_config:
        return run_config[run_mode]
    
    # 检查是否是变体模式
    mode_key = f'RUN.{run_mode}'
    if mode_key in run_config:
        # 合合默认配置和变体配置
        default_config = run_config.get('RUN', {})
        mode_config = run_config[mode_key]
        
        # 变体配置覆盖默认配置
        merged_config = {**default_config, **mode_config}
        return merged_config
    
    # 未找到，使用默认
    return run_config

# 使用示例
config = {
    'RUN': {
        'PATH': '/project/syn_dc',
        'COMMAND': 'dc_shell -f syn.tcl',
        'RUN': {
            'COMMAND': 'dc_shell -f syn.tcl',
            'LOG': 'run.log'
        },
        'RUN.DBG': {
            'COMMAND': 'dc_shell -f syn_dbg.tcl',
            'LOG': 'run_dbg.log',
            'RUN_METHOD': 'local'
        }
    }
}

# 选择RUN.DBG模式
dbg_config = select_run_mode(config, 'DBG')
# dbg_config = {
#     'PATH': '/project/syn_dc',         # 来自默认
#     'COMMAND': 'dc_shell -f syn_dbg.tcl', # 来自RUN.DBG
#     'LOG': 'run_dbg.log',              # 来自RUN.DBG
#     'RUN_METHOD': 'local'              # 来自RUN.DBG
# }
```

### 5.3 GUI RUN_MODE选择

```
GUI中RUN_MODE选择:

MAIN Tab中下拉菜单:

┌─────────────────────────────────────────────────────────────────────┐
│ Run Mode: [ RUN       ▼ ]                                          │
│           ┌─────────────────┐                                      │
│           │ RUN             │ ← 默认模式                            │
│           │ RUN.DBG         │ ← 调试模式                            │
│           │ RUN.fast        │ ← 快速模式                            │
│           │ RUN.full        │ ← 详尽模式                            │
│           │ RUN.option1     │ ← 特定配置                            │
│           └─────────────────┘                                      │
└─────────────────────────────────────────────────────────────────────┘

下拉菜单内容来源:
1. 默认RUN_MODE（config['RUN']['RUN_MODE']）
2. 所有RUN.xxx变体（扫描RUN配置键）

用户选择后:
1. 更新变量RUN_MODE
2. 切换到对应配置
3. 更新COMMAND/RUN_METHOD/LOG等
```

---

## 6. JobWatcher状态监控

### 6.1 监控机制

JobWatcher持续监控正在执行的任务状态。

```python
# JobWatcher监控代码

import threading
import time
import subprocess

class JobWatcher:
    """任务状态监控器"""
    
    def __init__(self, job_manager):
        self.job_manager = job_manager
        self.running = True
        self.thread = None
    
    def start(self):
        """启动监控"""
        self.thread = threading.Thread(target=self.watch_loop)
        self.thread.start()
    
    def stop(self):
        """停止监控"""
        self.running = False
        if self.thread:
            self.thread.join()
    
    def watch_loop(self):
        """监控循环"""
        while self.running:
            # 检查所有running任务
            for task_info in self.job_manager.running_list[:]:
                self.check_task_status(task_info)
            
            # 等待间隔
            time.sleep(30)  # 30秒轮询
    
    def check_task_status(self, task_info):
        """检查单个任务状态"""
        config = task_info['config']
        method = config.get('RUN_METHOD', 'local')
        
        if method.startswith('bsub'):
            # LSF任务
            self.check_lsf_job(task_info)
        else:
            # 本地任务
            self.check_local_job(task_info)
    
    def check_lsf_job(self, task_info):
        """检查LSF任务状态"""
        job_id = task_info.get('job_id')
        
        if not job_id:
            return
        
        # 执行bjobs查询
        result = subprocess.run(
            f'bjobs {job_id}',
            shell=True,
            capture_output=True,
            text=True
        )
        
        # 解析状态
        lines = result.stdout.strip().split('\n')
        if len(lines) > 1:
            fields = lines[1].split()
            status = fields[2]  # STAT字段
            
            # 状态映射
            if status == 'DONE':
                self.on_task_complete(task_info, 'pass')
            elif status == 'EXIT':
                self.on_task_complete(task_info, 'fail')
            elif status in ['RUN', 'PEND', 'PSUSP']:
                # 任务仍在运行
                pass
            else:
                # 未知状态
                pass
    
    def check_local_job(self, task_info):
        """检查本地任务状态"""
        process = task_info.get('process')
        
        if not process:
            return
        
        # 检查进程状态
        returncode = process.poll()
        
        if returncode is not None:
            # 进程已结束
            if returncode == 0:
                self.on_task_complete(task_info, 'pass')
            else:
                self.on_task_complete(task_info, 'fail')
    
    def on_task_complete(self, task_info, status):
        """任务完成回调"""
        # 更新任务状态
        self.job_manager.update_status(task_info, status)
        
        # 发送GUI信号
        self.emit_signal('task_complete', task_info)
```

### 6.2 LSF状态映射

```
LSF状态与IFP状态映射:

LSF bjobs状态输出格式:

JOBID  USER    STAT   QUEUE    FROM_HOST  EXEC_HOST  JOB_NAME  SUBMIT_TIME
12345  zhang   RUN    ai_syn   server1    node01     syn_dc    May 13 14:00
12346  zhang   PEND   ai_syn   server1    -          fm_rtl2g May 13 14:35
12347  zhang   DONE   ai_syn   server1    node02     sim_run   May 13 12:00
12348  zhang   EXIT   ai_syn   server1    node03     presta    May 13 10:00

STAT字段含义与IFP映射:

┌─────────────────────────────────────────────────────────────────────┐
│ LSF STAT │ 含义                │ IFP状态                           │
├──────────┼─────────────────────┼───────────────────────────────────┤
│ RUN      │ 正在执行            │ running                           │
│ PEND     │ 等待调度            │ running（已提交，等待集群调度）    │
│ PSUSP    │ 用户暂停            │ running（暂停状态）               │
│ SSUSP    │ 系统暂停            │ running（系统暂停）               │
│ USUSP    │ 用户暂停            │ running                           │
│ DONE     │ 正常完成            │ pass                              │
│ EXIT     │ 异常退出            │ fail                              │
│ ZOMBI    │僵尸进程            │ fail                              │
│ UNKNOWN  │ 未知                │ pending                           │
└─────────────────────────────────────────────────────────────────────┘

状态查询频率:
- 默认: 30秒轮询
- 可配置: LSF_CHECK_INTERVAL
- 高负载: 60秒轮询
- 低负载: 10秒轮询

查询命令:
bjobs {job_id}        # 单任务查询
bjobs -u {user}       # 用户所有任务
bjobs -q {queue}      # 队列所有任务
bjobs -a              # 所有任务
bhist {job_id}        # 任务历史
bpeek {job_id}        # 查看输出（实时）
```

---

## 7. IN_PROCESS_CHECK运行时检查

### 7.1 功能概述

V1.4.2引入IN_PROCESS_CHECK，允许在RUN执行过程中进行实时检查。

```yaml
# IN_PROCESS_CHECK配置

TASK:
  syn_dc:
    RUN:
      COMMAND: dc_shell -f syn.tcl
      RUN_METHOD: bsub -q ai_syn
      
      # 运行时检查配置
      IN_PROCESS_CHECK:
        # 检查脚本
        SCRIPT: ${IFP_INSTALL_PATH}/tools/in_process_check.py
        
        # 检查间隔（秒）
        INTERVAL: 60
        
        # 检查条件
        CONDITIONS:
          # 检查日志文件大小
          - TYPE: file_size
            PATH: ${PATH}/log/run.log
            MAX_SIZE: 100MB           # 日志不超过100MB
          
          # 检查进程内存
          - TYPE: memory_usage
            MAX_MEMORY: 8GB           # 内存不超过8GB
          
          # 检查运行时间
          - TYPE: elapsed_time
            MAX_TIME: 3600            # 运行不超过1小时
          
          # 检查日志关键字
          - TYPE: log_keyword
            PATH: ${PATH}/log/run.log
            KEYWORDS:
              - "ERROR"               # 出现ERROR则警告
              - "FATAL"               # 出现FATAL则终止
            ACTION: terminate         # 动作：终止任务
          
          # 检查输出文件
          - TYPE: output_check
            PATH: ${PATH}/run/output
            REQUIRED_FILES:
              - netlist.v             # 必须生成网表
            CHECK_INTERVAL: 300       # 每5分钟检查
```

### 7.2 检查脚本实现

```python
# tools/in_process_check.py

import os
import sys
import time
import psutil
import re

def check_file_size(path, max_size_mb):
    """检查文件大小"""
    if os.path.exists(path):
        size = os.path.getsize(path)
        size_mb = size / (1024 * 1024)
        return size_mb <= max_size_mb, size_mb
    return True, 0

def check_memory_usage(max_memory_gb):
    """检查内存使用"""
    process = psutil.Process()
    memory_info = process.memory_info()
    memory_gb = memory_info.rss / (1024 * 1024 * 1024)
    return memory_gb <= max_memory_gb, memory_gb

def check_elapsed_time(start_time, max_time_sec):
    """检查运行时间"""
    elapsed = time.time() - start_time
    return elapsed <= max_time_sec, elapsed

def check_log_keywords(path, keywords):
    """检查日志关键字"""
    if os.path.exists(path):
        with open(path) as f:
            content = f.read()
        
        found_keywords = []
        for kw in keywords:
            if re.search(kw, content, re.IGNORECASE):
                found_keywords.append(kw)
        
        return len(found_keywords) == 0, found_keywords
    return True, []

def check_output_files(path, required_files):
    """检查输出文件"""
    missing = []
    for file in required_files:
        full_path = os.path.join(path, file)
        if not os.path.exists(full_path):
            missing.append(file)
    
    return len(missing) == 0, missing

def run_in_process_check(config_file):
    """运行时检查主函数"""
    import yaml
    
    config = yaml.safe_load(open(config_file))
    
    start_time = time.time()
    interval = config.get('INTERVAL', 60)
    
    while True:
        # 执行各项检查
        checks_passed = True
        messages = []
        
        for condition in config.get('CONDITIONS', []):
            check_type = condition['TYPE']
            
            if check_type == 'file_size':
                ok, value = check_file_size(
                    condition['PATH'],
                    condition['MAX_SIZE']
                )
                if not ok:
                    checks_passed = False
                    messages.append(f"File size exceeded: {value}MB")
            
            elif check_type == 'memory_usage':
                ok, value = check_memory_usage(
                    condition['MAX_MEMORY']
                )
                if not ok:
                    checks_passed = False
                    messages.append(f"Memory exceeded: {value}GB")
            
            elif check_type == 'elapsed_time':
                ok, value = check_elapsed_time(
                    start_time,
                    condition['MAX_TIME']
                )
                if not ok:
                    checks_passed = False
                    messages.append(f"Time exceeded: {value}sec")
                    # 超时可能需要终止
                    if condition.get('ACTION') == 'terminate':
                        return 'terminate', messages
            
            elif check_type == 'log_keyword':
                ok, found = check_log_keywords(
                    condition['PATH'],
                    condition['KEYWORDS']
                )
                if not ok:
                    action = condition.get('ACTION', 'warn')
                    messages.append(f"Keywords found: {found}")
                    
                    if action == 'terminate':
                        return 'terminate', messages
            
            elif check_type == 'output_check':
                ok, missing = check_output_files(
                    condition['PATH'],
                    condition['REQUIRED_FILES']
                )
                if not ok:
                    messages.append(f"Files missing: {missing}")
        
        # 检查失败处理
        if not checks_passed:
            return 'warn', messages
        
        # 等待下次检查
        time.sleep(interval)

if __name__ == '__main__':
    config_file = sys.argv[1]
    status, messages = run_in_process_check(config_file)
    
    if status == 'terminate':
        print(f"TERMINATE: {messages}")
        sys.exit(1)
    elif status == 'warn':
        print(f"WARN: {messages}")
        sys.exit(0)
```

---

## 8. 错误处理与重试

### 8.1 错误分类

```
错误类型分类:

┌─────────────────────────────────────────────────────────────────────┐
│                     Error Classification                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  类型1: 配置错误                                                    │
│  - YAML语法错误                                                     │
│  - 变量未定义                                                       │
│  - 路径不存在                                                       │
│  - 处理: 启动时检查，阻止执行                                         │
│                                                                     │
│  类型2: 依赖错误                                                    │
│  - 文件依赖不满足                                                   │
│  - 许可依赖不满足                                                   │
│  - 任务依赖不满足                                                   │
│  - 处理: pending等待，满足后执行                                      │
│                                                                     │
│  类型3: 执行错误                                                    │
│  - 命令执行失败                                                     │
│  - 超时                                                            │
│  - 资源耗尽                                                         │
│  - 处理: 标记fail，用户决定重试                                       │
│                                                                     │
│  类型4: LSF错误                                                     │
│  - bsub提交失败                                                     │
│  - bjobs状态异常                                                    │
│  - 集群不可用                                                       │
│  - 处理: 标记fail，检查LSF环境                                        │
│                                                                     │
│  类型5: CHECK错误                                                   │
│  - 检查脚本失败                                                     │
│  - 检查项不通过                                                     │
│  - 报告生成失败                                                     │
│  - 处理: 标记fail，查看检查报告                                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 重试机制

```python
# 重试机制代码

class RetryManager:
    """重试管理器"""
    
    def __init__(self, max_retry=3):
        self.max_retry = max_retry
        self.retry_count = {}
    
    def can_retry(self, task_key):
        """检查是否可重试"""
        count = self.retry_count.get(task_key, 0)
        return count < self.max_retry
    
    def increment_retry(self, task_key):
        """增加重试计数"""
        self.retry_count[task_key] = self.retry_count.get(task_key, 0) + 1
    
    def reset_retry(self, task_key):
        """重置重试计数"""
        self.retry_count[task_key] = 0
    
    def retry_task(self, task_info):
        """重试任务"""
        task_key = task_info['key']
        
        if not self.can_retry(task_key):
            return False, "Max retry exceeded"
        
        # 增加计数
        self.increment_retry(task_key)
        
        # 重置状态
        task_info['status'] = 'pending'
        task_info['start_time'] = None
        task_info['end_time'] = None
        task_info['returncode'] = None
        
        # 重新添加到队列
        self.job_manager.add_task(task_info)
        
        return True, f"Retry #{self.retry_count[task_key]}"
```

---

*清华大学集成电路学院 - 芯粒设计实践课*
*文档生成: 2026-05-13*