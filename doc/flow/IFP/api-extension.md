# IFP API扩展开发

本文档详细解析IC Flow Platform的API扩展系统，包括PRE_CFG、PRE_IFP和右键菜单API。

---

## 1. API扩展系统概述

### 1.1 三类API扩展

IFP提供三类API扩展点，允许用户自定义功能。

```
API扩展类型:

┌─────────────────────────────────────────────────────────────────────┐
│                     API Extension Types                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Type 1: PRE_CFG                                                   │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 执行时机: 配置文件加载前                                         │ │
│  │                                                                 │ │
│  │ 目的:                                                           │ │
│  │ - 环境设置（设置环境变量）                                       │ │
│  │ - 许可检查（验证许可可用性）                                     │ │
│  │ - 配置同步（从远程服务器同步配置）                               │ │
│  │ - 目录准备（创建必要目录）                                       │ │
│  │                                                                 │ │
│  │ 执行方式:                                                       │ │
│  │ - 按api.yaml定义顺序执行                                         │ │
│  │ - 串行执行                                                       │ │
│  │ - 失败可阻止IFP启动                                             │ │
│  │                                                                 │ │
│  │ 配置位置: api.yaml PRE_CFG部分                                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  Type 2: PRE_IFP                                                   │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 执行时机: IFP启动后，GUI初始化前                                  │ │
│  │                                                                 │ │
│  │ 目的:                                                           │ │
│  │ - 工作区初始化                                                   │ │
│  │ - 自动启动监控服务                                               │ │
│  │ - 加载用户偏好                                                   │ │
│  │ - 连接外部系统                                                   │ │
│  │                                                                 │ │
│  │ 执行方式:                                                       │ │
│  │ - 按api.yaml定义顺序执行                                         │ │
│  │ - 串行执行                                                       │ │
│  │ - 失败仅警告，不影响启动                                         │ │
│  │                                                                 │ │
│  │ 配置位置: api.yaml PRE_IFP部分                                  │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  Type 3: TABLE_RIGHT_KEY_MENU                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 执行时机: 用户右键点击任务表                                      │ │
│  │                                                                 │ │
│  │ 目的:                                                           │ │
│  │ - 快捷操作（查看日志、打开目录）                                  │ │
│  │ - 自定义功能（发送邮件、生成报告）                                │ │
│  │ - 数据导出（导出数据、备份数据）                                  │ │
│  │                                                                 │ │
│  │ 执行方式:                                                       │ │
│  │ - 用户点击菜单项触发                                             │ │
│  │ - 支持二级菜单                                                   │ │
│  │ - 可访问选中任务信息                                             │ │
│  │                                                                 │ │
│  │ 配置位置: api.yaml TABLE_RIGHT_KEY_MENU部分                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 api.yaml文件结构

```yaml
# api.yaml完整结构示例

# ========== PRE_CFG配置加载前执行 ==========
PRE_CFG:
  # 扩展1: 环境设置
  setup_environment:
    LABEL: Setup Environment           # 显示名称
    PROJECT: all                       # 适用项目（all表示所有）
    GROUP: all                         # 适用组（all表示所有）
    TAB: all                           # 适用Tab（all表示所有）
    COLUMN: all                        # 适用列（all表示所有）
    ENABLE: true                       # 是否启用
    PATH: ${IFP_INSTALL_PATH}/tools/api/setup_environment.py
    COMMAND: python3 ${PATH}
    TIMEOUT: 30                        # 超时时间（秒）
    FAIL_ACTION: stop                  # 失败动作（stop继续启动）
  
  # 扩展2: 许可检查
  check_license:
    LABEL: Check License
    PROJECT: all
    GROUP: all
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/check_license.py
    COMMAND: python3 ${PATH} --project ${PROJECT}
    TIMEOUT: 60
    FAIL_ACTION: warn                  # 失败动作：仅警告
  
  # 扩展3: 配置同步
  sync_config:
    LABEL: Sync Config from Server
    PROJECT: mychip                    # 仅mychip项目
    GROUP: syn                         # 仅syn组
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/sync_config.py
    COMMAND: python3 ${PATH} --server config_server --project ${PROJECT}
    TIMEOUT: 120
    FAIL_ACTION: continue              # 失败动作：继续执行

# ========== PRE_IFP IFP启动后执行 ==========
PRE_IFP:
  # 扩展1: 工作区初始化
  init_workspace:
    LABEL: Initialize Workspace
    PROJECT: all
    GROUP: all
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/init_workspace.py
    COMMAND: python3 ${PATH} --cwd ${CWD}
    TIMEOUT: 30
    FAIL_ACTION: continue
  
  # 扩展2: 启动LSF监控
  start_lsf_monitor:
    LABEL: Start LSF Monitor
    PROJECT: all
    GROUP: all
    ENABLE: false                      # 默认关闭
    PATH: ${IFP_INSTALL_PATH}/tools/api/start_lsf_monitor.py
    COMMAND: python3 ${PATH} --port 5000
    TIMEOUT: 10
    FAIL_ACTION: warn
  
  # 扩展3: 加载用户偏好
  load_user_prefs:
    LABEL: Load User Preferences
    PROJECT: all
    GROUP: all
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/load_user_prefs.py
    COMMAND: python3 ${PATH} --user ${USER}
    TIMEOUT: 10
    FAIL_ACTION: continue

# ========== TABLE_RIGHT_KEY_MENU右键菜单 ==========
TABLE_RIGHT_KEY_MENU:
  # 菜单项1: 查看日志
  view_log:
    LABEL: View Log
    PROJECT: all
    GROUP: all
    TAB: MAIN                          # 仅MAIN Tab
    COLUMN: all                        # 所有列
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/view_log.py
    COMMAND: python3 ${PATH} --task ${TASK} --log ${LOG_PATH}
    # 可用变量:
    # ${TASK}: 选中任务名
    # ${BLOCK}: Block名
    # ${VERSION}: Version名
    # ${FLOW}: Flow名
    # ${PATH}: 任务路径
    # ${LOG_PATH}: 日志路径
  
  # 菜单项2: 打开目录
  open_directory:
    LABEL: Open Directory
    PROJECT: all
    GROUP: all
    TAB: MAIN
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/open_directory.py
    COMMAND: python3 ${PATH} --path ${PATH}
  
  # 菜单项3: 生成报告（二级菜单）
  generate_report:
    LABEL: Generate Report
    PROJECT: all
    GROUP: all
    TAB: MAIN
    ENABLE: true
    # 二级菜单定义
    MENU_TYPE: cascade                 # 级联菜单类型
    SUB_MENU:
      # 子菜单1: 生成Timing报告
      timing_report:
        LABEL: Timing Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_timing_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK}
      
      # 子菜单2: 生成Area报告
      area_report:
        LABEL: Area Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_area_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK}
      
      # 子菜单3: 生成完整报告
      full_report:
        LABEL: Full Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_full_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK} --version ${VERSION}
  
  # 菜单项4: 发送邮件
  send_email:
    LABEL: Send Email Notification
    PROJECT: mychip
    GROUP: dv
    TAB: MAIN
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/send_email.py
    COMMAND: python3 ${PATH} --task ${TASK} --status ${STATUS} --user ${USER}
  
  # 菜单项5: 备份数据
  backup_data:
    LABEL: Backup Task Data
    PROJECT: all
    GROUP: all
    TAB: MAIN
    ENABLE: true
    PATH: ${IFP_INSTALL_PATH}/tools/api/backup_data.py
    COMMAND: python3 ${PATH} --task ${TASK} --path ${PATH} --dest ${BACKUP_PATH}
```

---

## 2. PRE_CFG详解

### 2.1 PRE_CFG执行流程

```
PRE_CFG执行流程:

┌─────────────────────────────────────────────────────────────────────┐
│                     PRE_CFG Execution Flow                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  IFP启动                                                            │
│      │                                                              │
│      ↓                                                              │
│  读取ifp.cfg.yaml                                                   │
│      │                                                              │
│      ↓                                                              │
│  获取project/group                                                  │
│      │                                                              │
│      ↓                                                              │
│  加载api.yaml                                                       │
│      │                                                              │
│      ↓                                                              │
│  解析PRE_CFG配置                                                    │
│      │                                                              │
│      │                                                              │
│      ├─ 遍历PRE_CFG列表                                              │
│      │                                                              │
│      │  for each extension in PRE_CFG:                              │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  检查PROJECT/GROUP匹配                                        │
│      │      │                                                       │
│      │      │ if extension.PROJECT != 'all' and                     │
│      │      │    extension.PROJECT != user_project:                  │
│      │      │    skip this extension                                 │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  检查ENABLE状态                                               │
│      │      │                                                       │
│      │      │ if extension.ENABLE == false:                          │
│      │      │    skip this extension                                 │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  变量替换                                                     │
│      │      │                                                       │
│      │      │ PATH = substitute(extension.PATH, vars)                │
│      │      │ COMMAND = substitute(extension.COMMAND, vars)          │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  执行扩展脚本                                                 │
│      │      │                                                       │
│      │      │ subprocess.run(COMMAND, timeout=TIMEOUT)               │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  检查执行结果                                                 │
│      │      │                                                       │
│      │      │ if returncode != 0:                                    │
│      │      │    handle_failure(extension.FAIL_ACTION)               │
│      │      │                                                       │
│      │      │ FAIL_ACTION:                                          │
│      │      │ - stop: 停止IFP启动                                    │
│      │      │ - warn: 显示警告，继续启动                              │
│      │      │ - continue: 忽略错误，继续启动                          │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  下一个扩展                                                   │
│      │                                                              │
│      ↓                                                              │
│  PRE_CFG执行完成                                                    │
│      │                                                              │
│      ↓                                                              │
│  加载default.yaml                                                   │
│      │                                                              │
│      ↓                                                              │
│  初始化GUI                                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 PRE_CFG示例脚本

#### setup_environment.py

```python
#!/usr/bin/env python3
# tools/api/setup_environment.py
# PRE_CFG示例：环境设置脚本

import os
import sys
import subprocess

def setup_environment():
    """设置IFP运行环境"""
    
    print("=== Setting up IFP environment ===")
    
    # 1. 检查必要环境变量
    required_vars = ['IFP_INSTALL_PATH', 'USER', 'HOME']
    for var in required_vars:
        if var not in os.environ:
            print(f"ERROR: Missing environment variable: {var}")
            return False
    
    print(f"IFP_INSTALL_PATH: {os.environ['IFP_INSTALL_PATH']}")
    print(f"USER: {os.environ['USER']}")
    
    # 2. 设置XDG_RUNTIME_DIR（Qt需要）
    if 'XDG_RUNTIME_DIR' not in os.environ:
        xdg_path = f"/tmp/runtime-{os.environ['USER']}"
        os.makedirs(xdg_path, mode=0o700, exist_ok=True)
        os.environ['XDG_RUNTIME_DIR'] = xdg_path
        print(f"Set XDG_RUNTIME_DIR: {xdg_path}")
    
    # 3. 检查Python版本
    python_version = sys.version_info
    if python_version < (3, 8):
        print(f"ERROR: Python 3.8+ required, found {python_version}")
        return False
    print(f"Python version: {python_version}")
    
    # 4. 检查必要Python模块
    required_modules = ['PyQt5', 'yaml', 'graphviz', 'pandas']
    for module in required_modules:
        try:
            __import__(module)
            print(f"Module {module}: OK")
        except ImportError:
            print(f"ERROR: Missing module: {module}")
            return False
    
    # 5. 检查系统命令
    required_commands = ['dot']  # graphviz
    for cmd in required_commands:
        result = subprocess.run(['which', cmd], capture_output=True)
        if result.returncode != 0:
            print(f"ERROR: Missing command: {cmd}")
            return False
        print(f"Command {cmd}: OK")
    
    # 6. 创建必要目录
    install_path = os.environ['IFP_INSTALL_PATH']
    dirs_to_create = [
        f"{install_path}/.cache",
        f"{install_path}/logs"
    ]
    for dir_path in dirs_to_create:
        os.makedirs(dir_path, exist_ok=True)
        print(f"Directory {dir_path}: OK")
    
    print("=== Environment setup complete ===")
    return True

if __name__ == '__main__':
    if setup_environment():
        sys.exit(0)
    else:
        sys.exit(1)
```

#### check_license.py

```python
#!/usr/bin/env python3
# tools/api/check_license.py
# PRE_CFG示例：许可检查脚本

import os
import sys
import subprocess
import re

def check_synopsys_license():
    """检查Synopsys许可可用性"""
    
    print("=== Checking Synopsys licenses ===")
    
    # 获取许可服务器地址
    license_server = os.environ.get('SNPSLMD_LICENSE_FILE', '')
    if not license_server:
        print("WARNING: SNPSLMD_LICENSE_FILE not set")
        return True  # 不阻止启动
    
    print(f"License server: {license_server}")
    
    # 使用lmstat检查许可
    try:
        result = subprocess.run(
            ['lmstat', '-a', '-c', license_server],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # 解析许可信息
        output = result.stdout
        
        # 检查Design Compiler
        dc_pattern = r'Users of DesignCompiler:.*Total of (\d+) licenses issued.*Total of (\d+) licenses in use'
        dc_match = re.search(dc_pattern, output)
        if dc_match:
            issued = int(dc_match.group(1))
            in_use = int(dc_match.group(2))
            available = issued - in_use
            print(f"Design Compiler: {available}/{issued} available")
        
        # 检查Formality
        fm_pattern = r'Users of Formality:.*Total of (\d+) licenses issued.*Total of (\d+) licenses in use'
        fm_match = re.search(fm_pattern, output)
        if fm_match:
            issued = int(fm_match.group(1))
            in_use = int(fm_match.group(2))
            available = issued - in_use
            print(f"Formality: {available}/{issued} available")
        
        # 检查PrimeTime
        pt_pattern = r'Users of PrimeTime:.*Total of (\d+) licenses issued.*Total of (\d+) licenses in use'
        pt_match = re.search(pt_pattern, output)
        if pt_match:
            issued = int(pt_match.group(1))
            in_use = int(pt_match.group(2))
            available = issued - in_use
            print(f"PrimeTime: {available}/{issued} available")
        
        print("=== License check complete ===")
        return True
        
    except subprocess.TimeoutExpired:
        print("WARNING: License check timeout")
        return True
    except Exception as e:
        print(f"WARNING: License check error: {e}")
        return True

if __name__ == '__main__':
    project = sys.argv[1] if len(sys.argv) > 1 else 'all'
    print(f"Project: {project}")
    
    if check_synopsys_license():
        sys.exit(0)
    else:
        sys.exit(1)
```

#### sync_config.py

```python
#!/usr/bin/env python3
# tools/api/sync_config.py
# PRE_CFG示例：配置同步脚本

import os
import sys
import subprocess
import json

def sync_config_from_server(server_url, project):
    """从远程服务器同步配置"""
    
    print("=== Syncing config from server ===")
    print(f"Server: {server_url}")
    print(f"Project: {project}")
    
    install_path = os.environ['IFP_INSTALL_PATH']
    config_dir = f"{install_path}/config"
    
    # 使用curl下载配置
    try:
        # 下载default.yaml
        default_url = f"{server_url}/api/config/{project}/default.yaml"
        result = subprocess.run(
            ['curl', '-s', '-o', f"{config_dir}/default.{project}.yaml", default_url],
            timeout=60
        )
        
        if result.returncode == 0:
            print(f"Synced: default.{project}.yaml")
        else:
            print(f"WARNING: Failed to sync default.{project}.yaml")
        
        # 下载api.yaml
        api_url = f"{server_url}/api/config/{project}/api.yaml"
        result = subprocess.run(
            ['curl', '-s', '-o', f"{config_dir}/api.{project}.yaml", api_url],
            timeout=60
        )
        
        if result.returncode == 0:
            print(f"Synced: api.{project}.yaml")
        else:
            print(f"WARNING: Failed to sync api.{project}.yaml")
        
        print("=== Config sync complete ===")
        return True
        
    except subprocess.TimeoutExpired:
        print("WARNING: Config sync timeout")
        return False
    except Exception as e:
        print(f"WARNING: Config sync error: {e}")
        return False

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--server', required=True)
    parser.add_argument('--project', required=True)
    args = parser.parse_args()
    
    if sync_config_from_server(args.server, args.project):
        sys.exit(0)
    else:
        sys.exit(1)
```

---

## 3. PRE_IFP详解

### 3.1 PRE_IFP执行流程

```
PRE_IFP执行流程:

┌─────────────────────────────────────────────────────────────────────┐
│                     PRE_IFP Execution Flow                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  PRE_CFG完成                                                        │
│      │                                                              │
│      ↓                                                              │
│  加载default.yaml                                                   │
│      │                                                              │
│      ↓                                                              │
│  解析VAR/TASK/FLOW                                                  │
│      │                                                              │
│      ↓                                                              │
│  加载api.yaml PRE_IFP部分                                           │
│      │                                                              │
│      │                                                              │
│      ├─ 遍历PRE_IFP列表                                              │
│      │                                                              │
│      │  for each extension in PRE_IFP:                              │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  检查PROJECT/GROUP匹配                                        │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  检查ENABLE状态                                               │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  变量替换                                                     │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  执行扩展脚本                                                 │
│      │      │                                                       │
│      │      │ subprocess.run(COMMAND, timeout=TIMEOUT)               │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  检查执行结果                                                 │
│      │      │                                                       │
│      │      │ if returncode != 0:                                    │
│      │      │    if FAIL_ACTION == 'warn':                           │
│      │      │        show_warning()                                  │
│      │      │    elif FAIL_ACTION == 'continue':                     │
│      │      │        pass                                            │
│      │      │    # PRE_IFP失败不阻止启动                              │
│      │      │                                                       │
│      │      ↓                                                       │
│      │  下一个扩展                                                   │
│      │                                                              │
│      ↓                                                              │
│  PRE_IFP执行完成                                                    │
│      │                                                              │
│      ↓                                                              │
│  创建MainWindow                                                     │
│      │                                                              │
│      ↓                                                              │
│  GUI显示                                                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 PRE_IFP示例脚本

#### init_workspace.py

```python
#!/usr/bin/env python3
# tools/api/init_workspace.py
# PRE_IFP示例：工作区初始化脚本

import os
import sys
import yaml

def init_workspace(cwd):
    """初始化工作区"""
    
    print("=== Initializing workspace ===")
    print(f"Working directory: {cwd}")
    
    # 1. 创建必要目录结构
    dirs_to_create = [
        f"{cwd}/.ifp.cache",
        f"{cwd}/.ifp.cache/logs",
        f"{cwd}/.ifp.cache/reports",
        f"{cwd}/.ifp.cache/db",
        f"{cwd}/.ifp.cache/temp",
        f"{cwd}/design",
        f"{cwd}/design/rtl",
        f"{cwd}/verif",
        f"{cwd}/verif/sim",
        f"{cwd}/verif/tb"
    ]
    
    for dir_path in dirs_to_create:
        os.makedirs(dir_path, exist_ok=True)
        print(f"Created: {dir_path}")
    
    # 2. 创建ifp.cfg.yaml（如果不存在）
    config_file = f"{cwd}/ifp.cfg.yaml"
    if not os.path.exists(config_file):
        default_config = {
            'project': '',
            'group': '',
            'block': '',
            'version': '',
            'flow': '',
            'VAR': {},
            'selected_tasks': []
        }
        
        with open(config_file, 'w') as f:
            yaml.dump(default_config, f, default_flow_style=False)
        print(f"Created: {config_file}")
    
    # 3. 创建README（如果不存在）
    readme_file = f"{cwd}/README.md"
    if not os.path.exists(readme_file):
        readme_content = """# IFP Workspace

This is an IFP workspace for IC design flow management.

## Directory Structure

- design/         Design files (RTL, constraints)
- verif/          Verification environment
- .ifp.cache/     IFP cache directory

## Usage

1. Start IFP: `ifp`
2. Configure in CONFIG Tab
3. Execute tasks in MAIN Tab
"""
        with open(readme_file, 'w') as f:
            f.write(readme_content)
        print(f"Created: {readme_file}")
    
    print("=== Workspace initialization complete ===")
    return True

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--cwd', required=True)
    args = parser.parse_args()
    
    if init_workspace(args.cwd):
        sys.exit(0)
    else:
        sys.exit(1)
```

#### start_lsf_monitor.py

```python
#!/usr/bin/env python3
# tools/api/start_lsf_monitor.py
# PRE_IFP示例：启动LSF监控

import os
import sys
import subprocess
import time

def start_lsf_monitor(port):
    """启动LSF监控服务"""
    
    print("=== Starting LSF Monitor ===")
    print(f"Port: {port}")
    
    install_path = os.environ['IFP_INSTALL_PATH']
    monitor_script = f"{install_path}/tools/lsfMonitor/monitor/app.py"
    
    # 检查脚本是否存在
    if not os.path.exists(monitor_script):
        print("WARNING: LSF Monitor script not found")
        return True  # 不阻止启动
    
    # 检查LSF环境
    if 'LSF_ENVDIR' not in os.environ:
        print("WARNING: LSF environment not configured")
        return True
    
    # 启动Flask服务
    try:
        process = subprocess.Popen(
            ['python3', monitor_script, '--port', str(port)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        # 等待服务启动
        time.sleep(2)
        
        # 检查进程状态
        if process.poll() is None:
            print(f"LSF Monitor started on port {port}")
            print(f"Access: http://localhost:{port}")
            return True
        else:
            print("WARNING: LSF Monitor failed to start")
            return True
            
    except Exception as e:
        print(f"WARNING: Error starting LSF Monitor: {e}")
        return True

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5000)
    args = parser.parse_args()
    
    if start_lsf_monitor(args.port):
        sys.exit(0)
    else:
        sys.exit(1)
```

---

## 4. TABLE_RIGHT_KEY_MENU详解

### 4.1 右键菜单执行流程

```
右键菜单执行流程:

┌─────────────────────────────────────────────────────────────────────┐
│                     Right-Click Menu Flow                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  用户在MAIN Tab任务表右键点击                                        │
│      │                                                              │
│      ↓                                                              │
│  IFP捕获右键事件                                                    │
│      │                                                              │
│      ↓                                                              │
│  获取选中任务信息                                                   │
│      │                                                              │
│      │  selected_task = {                                          │
│      │      'task': 'syn_dc',                                      │
│      │      'block': 'cpu_core',                                   │
│      │      'version': 'v1.0',                                     │
│      │      'flow': 'syn',                                         │
│      │      'path': '/project/cpu_core/v1.0/syn/syn_dc',           │
│      │      'status': 'pass'                                       │
│      │  }                                                          │
│      │                                                              │
│      ↓                                                              │
│  加载api.yaml TABLE_RIGHT_KEY_MENU                                  │
│      │                                                              │
│      ↓                                                              │
│  筛选匹配的菜单项                                                   │
│      │                                                              │
│      │  for each menu_item in TABLE_RIGHT_KEY_MENU:                │
│      │      │                                                       │
│      │      │ if menu_item.PROJECT != 'all' and                     │
│      │      │    menu_item.PROJECT != current_project:               │
│      │      │    skip                                               │
│      │      │                                                       │
│      │      │ if menu_item.GROUP != 'all' and                        │
│      │      │    menu_item.GROUP != current_group:                   │
│      │      │    skip                                               │
│      │      │                                                       │
│      │      │ if menu_item.TAB != 'all' and                         │
│      │      │    menu_item.TAB != current_tab:                       │
│      │      │    skip                                               │
│      │      │                                                       │
│      │      │ if menu_item.ENABLE == false:                          │
│      │      │    skip                                               │
│      │      │                                                       │
│      │      │ add to available_menu_items                           │
│      │                                                              │
│      ↓                                                              │
│  构建菜单结构                                                       │
│      │                                                              │
│      │  if menu_item.MENU_TYPE == 'cascade':                       │
│      │      create_submenu(menu_item)                              │
│      │  else:                                                       │
│      │      create_menu_item(menu_item)                            │
│      │                                                              │
│      ↓                                                              │
│  显示右键菜单                                                       │
│      │                                                              │
│      ↓                                                              │
│  用户点击菜单项                                                     │
│      │                                                              │
│      ↓                                                              │
│  执行菜单命令                                                       │
│      │                                                              │
│      │  variables = {                                              │
│      │      'TASK': selected_task['task'],                         │
│      │      'BLOCK': selected_task['block'],                       │
│      │      'VERSION': selected_task['version'],                   │
│      │      'FLOW': selected_task['flow'],                         │
│      │      'PATH': selected_task['path'],                         │
│      │      'STATUS': selected_task['status'],                     │
│      │      'LOG_PATH': f"{selected_task['path']}/log/run.log",    │
│      │      'USER': os.environ['USER']                             │
│      │  }                                                          │
│      │                                                              │
│      │  COMMAND = substitute(menu_item.COMMAND, variables)         │
│      │                                                              │
│      │  subprocess.run(COMMAND, shell=True)                        │
│      │                                                              │
│      ↓                                                              │
│  完成                                                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 右键菜单示例脚本

#### view_log.py

```python
#!/usr/bin/env python3
# tools/api/view_log.py
# 右键菜单示例：查看日志

import os
import sys
import subprocess

def view_log(task, log_path):
    """查看任务日志"""
    
    print(f"=== Viewing log for task: {task} ===")
    print(f"Log path: {log_path}")
    
    # 检查日志文件是否存在
    if not os.path.exists(log_path):
        print(f"ERROR: Log file not found: {log_path}")
        return False
    
    # 使用系统查看器打开日志
    # 根据系统选择查看器
    if os.name == 'posix':
        # Linux: 使用less或gedit
        subprocess.run(['less', '-R', log_path])
    elif os.name == 'darwin':
        # macOS: 使用open
        subprocess.run(['open', '-a', 'TextEdit', log_path])
    elif os.name == 'nt':
        # Windows: 使用notepad
        subprocess.run(['notepad', log_path])
    
    return True

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--task', required=True)
    parser.add_argument('--log', required=True)
    args = parser.parse_args()
    
    if view_log(args.task, args.log):
        sys.exit(0)
    else:
        sys.exit(1)
```

#### open_directory.py

```python
#!/usr/bin/env python3
# tools/api/open_directory.py
# 右键菜单示例：打开目录

import os
import sys
import subprocess

def open_directory(path):
    """打开任务目录"""
    
    print(f"=== Opening directory: {path} ===")
    
    # 检查目录是否存在
    if not os.path.exists(path):
        print(f"ERROR: Directory not found: {path}")
        return False
    
    # 使用系统文件管理器打开
    if os.name == 'posix':
        # Linux: 使用xdg-open或nautilus
        subprocess.run(['xdg-open', path])
    elif os.name == 'darwin':
        # macOS: 使用open
        subprocess.run(['open', path])
    elif os.name == 'nt':
        # Windows: 使用explorer
        subprocess.run(['explorer', path])
    
    return True

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', required=True)
    args = parser.parse_args()
    
    if open_directory(args.path):
        sys.exit(0)
    else:
        sys.exit(1)
```

#### gen_timing_report.py

```python
#!/usr/bin/env python3
# tools/api/gen_timing_report.py
# 右键菜单示例：生成Timing报告

import os
import sys
import subprocess

def gen_timing_report(task, block):
    """生成Timing报告"""
    
    print(f"=== Generating Timing report ===")
    print(f"Task: {task}")
    print(f"Block: {block}")
    
    # 查找timing报告文件
    # 通常在run/output/或run/reports/目录
    timing_reports = [
        f"{path}/run/reports/timing.rpt",
        f"{path}/run/output/timing_summary.rpt",
        f"{path}/run/timing_max.rpt",
        f"{path}/run/timing_min.rpt"
    ]
    
    for rpt_file in timing_reports:
        if os.path.exists(rpt_file):
            print(f"Found: {rpt_file}")
            
            # 使用查看器打开
            subprocess.run(['firefox', rpt_file])
            return True
    
    print("WARNING: Timing report not found")
    return True  # 不报告错误

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--task', required=True)
    parser.add_argument('--block', required=True)
    args = parser.parse_args()
    
    if gen_timing_report(args.task, args.block):
        sys.exit(0)
    else:
        sys.exit(1)
```

#### send_email.py

```python
#!/usr/bin/env python3
# tools/api/send_email.py
# 右键菜单示例：发送邮件通知

import os
import sys
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email_notification(task, status, user):
    """发送邮件通知"""
    
    print(f"=== Sending email notification ===")
    print(f"Task: {task}")
    print(f"Status: {status}")
    print(f"User: {user}")
    
    # 配置邮件服务器
    smtp_server = os.environ.get('SMTP_SERVER', 'smtp.company.com')
    smtp_port = int(os.environ.get('SMTP_PORT', 25))
    
    # 创建邮件
    msg = MIMEMultipart()
    msg['From'] = 'ifp-notification@company.com'
    msg['To'] = f'{user}@company.com'
    msg['Subject'] = f'IFP Task Notification: {task} - {status}'
    
    # 邮件内容
    body = f"""
IFP Task Notification

Task: {task}
Status: {status}
User: {user}
Timestamp: {datetime.now().isoformat()}

This is an automated notification from IC Flow Platform.
"""
    
    msg.attach(MIMEText(body, 'plain'))
    
    # 发送邮件
    try:
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.send_message(msg)
        server.quit()
        
        print(f"Email sent to {user}@company.com")
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to send email: {e}")
        return False

if __name__ == '__main__':
    import argparse
    from datetime import datetime
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--task', required=True)
    parser.add_argument('--status', required=True)
    parser.add_argument('--user', required=True)
    args = parser.parse_args()
    
    if send_email_notification(args.task, args.status, args.user):
        sys.exit(0)
    else:
        sys.exit(1)
```

---

## 5. 二级菜单实现

### 5.1 二级菜单配置

```yaml
# 二级菜单配置示例

TABLE_RIGHT_KEY_MENU:
  generate_report:
    LABEL: Generate Report
    PROJECT: all
    GROUP: all
    TAB: MAIN
    ENABLE: true
    
    # 标识为级联菜单
    MENU_TYPE: cascade
    
    # 二级菜单定义
    SUB_MENU:
      # 子菜单项
      timing_report:
        LABEL: Timing Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_timing_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK}
      
      area_report:
        LABEL: Area Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_area_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK}
      
      power_report:
        LABEL: Power Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_power_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK}
      
      full_report:
        LABEL: Full Report
        ENABLE: true
        PATH: ${IFP_INSTALL_PATH}/tools/api/gen_full_report.py
        COMMAND: python3 ${PATH} --task ${TASK} --block ${BLOCK} --version ${VERSION}
```

### 5.2 二级菜单GUI实现

```python
# 右键菜单GUI实现

from PyQt5.QtWidgets import QMenu, QAction

def create_right_key_menu(main_window, selected_task):
    """创建右键菜单"""
    
    menu = QMenu(main_window)
    
    # 加载API配置
    api_config = main_window.api_config
    menu_items = api_config.get('TABLE_RIGHT_KEY_MENU', {})
    
    # 当前项目信息
    current_project = main_window.project
    current_group = main_window.group
    current_tab = main_window.current_tab
    
    # 变量字典
    variables = {
        'TASK': selected_task['task'],
        'BLOCK': selected_task['block'],
        'VERSION': selected_task['version'],
        'FLOW': selected_task['flow'],
        'PATH': selected_task['path'],
        'STATUS': selected_task['status'],
        'LOG_PATH': f"{selected_task['path']}/log/run.log",
        'USER': os.environ['USER'],
        'PROJECT': current_project,
        'GROUP': current_group
    }
    
    # 添加菜单项
    for item_name, item_config in menu_items.items():
        # 检查匹配条件
        if not is_menu_item_match(item_config, current_project, current_group, current_tab):
            continue
        
        if not item_config.get('ENABLE', True):
            continue
        
        # 处理级联菜单
        if item_config.get('MENU_TYPE') == 'cascade':
            # 创建子菜单
            submenu = menu.addMenu(item_config['LABEL'])
            
            # 添加子菜单项
            for sub_name, sub_config in item_config.get('SUB_MENU', {}).items():
                if not sub_config.get('ENABLE', True):
                    continue
                
                action = QAction(sub_config['LABEL'], submenu)
                action.triggered.connect(
                    lambda checked, c=sub_config, v=variables:
                        execute_menu_action(c, v)
                )
                submenu.addAction(action)
        
        else:
            # 添加普通菜单项
            action = QAction(item_config['LABEL'], menu)
            action.triggered.connect(
                lambda checked, c=item_config, v=variables:
                    execute_menu_action(c, v)
            )
            menu.addAction(action)
    
    return menu

def is_menu_item_match(config, project, group, tab):
    """检查菜单项是否匹配当前条件"""
    
    # PROJECT匹配
    item_project = config.get('PROJECT', 'all')
    if item_project != 'all' and item_project != project:
        return False
    
    # GROUP匹配
    item_group = config.get('GROUP', 'all')
    if item_group != 'all' and item_group != group:
        return False
    
    # TAB匹配
    item_tab = config.get('TAB', 'all')
    if item_tab != 'all' and item_tab != tab:
        return False
    
    return True

def execute_menu_action(config, variables):
    """执行菜单动作"""
    
    import subprocess
    
    # 变量替换
    command = substitute_variables(config['COMMAND'], variables)
    
    # 执行命令
    try:
        subprocess.run(command, shell=True)
    except Exception as e:
        print(f"Menu action failed: {e}")
```

---

## 6. API脚本开发指南

### 6.1 脚本规范

```python
# API脚本开发规范

"""
IFP API脚本开发规范:

1. 脚本位置
   - PRE_CFG/PRE_IFP脚本: $IFP_INSTALL_PATH/tools/api/
   - 右键菜单脚本: $IFP_INSTALL_PATH/tools/api/

2. 脚本命名
   - 使用snake_case命名
   - 例如: setup_environment.py, check_license.py

3. 脚本结构
   - 必须包含main函数
   - 必须有清晰的帮助信息
   - 必须返回正确的退出码

4. 参数处理
   - 使用argparse解析参数
   - 提供必要的参数说明

5. 输出格式
   - 使用print输出状态信息
   - 使用ERROR/WARNING/INFO标记
   - 避免过多输出

6. 错误处理
   - 捕获异常并返回错误信息
   - 返回正确的退出码:
     - 0: 成功
     - 1: 失败（PRE_CFG会阻止启动）
     - 0 (with warnings): 警告（PRE_CFG不会阻止）

7. 可用变量
   - ${IFP_INSTALL_PATH}: IFP安装路径
   - ${CWD}: 当前工作目录
   - ${USER}: 用户名
   - ${PROJECT}: 项目名
   - ${GROUP}: 用户组名
   - ${BLOCK}: Block名
   - ${VERSION}: Version名
   - ${FLOW}: Flow名
   - ${TASK}: 任务名
   - ${PATH}: 任务路径
   - ${STATUS}: 任务状态

8. 可用环境变量
   - os.environ['IFP_INSTALL_PATH']
   - os.environ['USER']
   - os.environ['HOME']
   - 其他系统环境变量
"""

#!/usr/bin/env python3
"""
API脚本模板

Purpose: [脚本用途说明]
Author: [作者]
Date: [日期]
"""

import os
import sys
import argparse
import subprocess

def main(args):
    """主函数"""
    
    # 1. 打印开始信息
    print(f"=== Starting {args.action} ===")
    
    # 2. 执行主要逻辑
    try:
        # [具体实现]
        result = do_something(args)
        
        if result:
            print(f"=== {args.action} complete ===")
            return 0
        else:
            print(f"ERROR: {args.action} failed")
            return 1
            
    except Exception as e:
        print(f"ERROR: {args.action} exception: {e}")
        return 1

def do_something(args):
    """具体实现"""
    # [实现代码]
    return True

if __name__ == '__main__':
    # 参数解析
    parser = argparse.ArgumentParser(
        description='API script description'
    )
    parser.add_argument('--action', required=True, help='Action to perform')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    # 执行
    exit_code = main(args)
    sys.exit(exit_code)
```

---

*Chiplet Design Practice*
*文档生成: 2026-05-13*