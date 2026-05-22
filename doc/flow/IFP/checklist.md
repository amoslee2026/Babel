# IFP Checklist检查机制

本文档详细解析IC Flow Platform的自动化质量检查机制，包括检查脚本、报告生成和结果判定。

---

## 1. CHECK机制概述

### 1.1 CHECK流程

CHECK阶段是IFP质量保证的核心，在RUN完成后自动执行。

```
CHECK执行流程:

┌─────────────────────────────────────────────────────────────────────┐
│                     CHECK Execution Flow                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  RUN完成 (status=pass)                                             │
│      │                                                              │
│      ↓                                                              │
│  自动触发CHECK                                                      │
│      │                                                              │
│      │  if RUN.status == 'pass' and CHECK defined:                │
│      │      auto_execute(CHECK)                                   │
│      │                                                              │
│      ↓                                                              │
│  检查CHECK配置                                                      │
│      │                                                              │
│      │  config = task_config['CHECK']                              │
│      │  PATH = config['PATH']                                      │
│      │  COMMAND = config['COMMAND']                                │
│      │  REPORT_FILE = config['REPORT_FILE']                        │
│      │  VIEWER = config['VIEWER']                                  │
│      │                                                              │
│      ↓                                                              │
│  变量替换                                                           │
│      │                                                              │
│      │  PATH = substitute(PATH, vars)                              │
│      │  COMMAND = substitute(COMMAND, vars)                        │
│      │                                                              │
│      ↓                                                              │
│  执行CHECK命令                                                      │
│      │                                                              │
│      │  cd PATH                                                    │
│      │  subprocess.run(COMMAND)                                    │
│      │                                                              │
│      │  COMMAND示例:                                               │
│      │  python3 ic_check.py -d ${PATH} -f syn -b ${BLOCK}          │
│      │                                                              │
│      ↓                                                              │
│  检查脚本执行                                                       │
│      │                                                              │
│      │  ic_check.py执行流程:                                       │
│      │  1. 解析检查参数                                            │
│      │  2. 加载检查定义                                             │
│      │  3. 执行各项检查                                             │
│      │  4. 生成Excel报告                                            │
│      │  5. 判定PASS/FAIL                                            │
│      │  6. 写入标记文件                                             │
│      │                                                              │
│      ↓                                                              │
│  报告生成                                                           │
│      │                                                              │
│      │  REPORT_FILE = ${PATH}/file_check.rpt                       │
│      │  Excel格式，包含所有检查项结果                               │
│      │                                                              │
│      ↓                                                              │
│  结果判定                                                           │
│      │                                                              │
│      │  if all checks pass:                                        │
│      │      write PASS file                                        │
│      │      CHECK.status = 'pass'                                  │
│      │  else:                                                       │
│      │      write FAIL file                                        │
│      │      CHECK.status = 'fail'                                  │
│      │                                                              │
│      ↓                                                              │
│  用户查看报告                                                       │
│      │                                                              │
│      │  点击[View]按钮                                             │
│      │  执行VIEWER命令                                             │
│      │  firefox ${REPORT_FILE}                                     │
│      │                                                              │
│      ↓                                                              │
│  CHECK完成                                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 CHECK配置详解

```yaml
# CHECK配置示例

TASK:
  syn_dc:
    RUN:
      COMMAND: dc_shell -f syn.tcl
      ...
    
    # CHECK配置
    CHECK:
      # 工作目录
      PATH: ${DEFAULT_PATH}/syn_dc/check
      
      # 检查命令
      COMMAND: python3 ${IFP_INSTALL_PATH}/action/check/scripts/ic_check.py -d ${PATH} -f syn -b ${BLOCK}
      
      # 日志文件
      LOG: ${PATH}/log/check.log
      
      # 报告文件
      REPORT_FILE: ${PATH}/file_check.rpt
      
      # 报告查看器
      VIEWER: firefox ${REPORT_FILE}
      
      # 执行方式（默认local）
      RUN_METHOD: local
      
      # 检查定义文件（可选）
      CHECK_DEF: ${IFP_INSTALL_PATH}/action/check/demo_excel/check_syn.xlsx

CHECK配置属性详解:

| 属性 | 必需 | 说明 | 示例 |
|------|------|------|------|
| PATH | ✓ | CHECK工作目录 | ${PATH}/check |
| COMMAND | ✓ | 检查执行命令 | python3 ic_check.py |
| LOG | 推荐 | CHECK日志路径 | ${PATH}/log/check.log |
| REPORT_FILE | ✓ | 报告输出路径 | ${PATH}/file_check.rpt |
| VIEWER | ✓ | 报告查看命令 | firefox ${REPORT_FILE} |
| RUN_METHOD | 可选 | 执行方式 | local |
| CHECK_DEF | 可选 | 检查定义文件 | check_syn.xlsx |
```

---

## 2. ic_check.py检查脚本

### 2.1 脚本架构

```python
# action/check/scripts/ic_check.py 检查脚本架构

"""
ic_check.py - IFP检查执行脚本

功能:
1. 解析检查参数
2. 加载检查定义
3. 执行各项检查
4. 生成Excel报告
5. 判定PASS/FAIL
6. 写入标记文件

使用:
python3 ic_check.py -d ${PATH} -f syn -b ${BLOCK}

参数:
-d PATH       检查目录
-f FLOW       流程类型
-b BLOCK      模块名
-v VENDOR     供应商（可选）
-e EXCEL      检查定义Excel（可选）
"""

import os
import sys
import argparse
import yaml
import pandas as pd
import xlwt
from datetime import datetime

def main():
    """主函数"""
    # 解析参数
    args = parse_args()
    
    # 加载检查定义
    check_items = load_check_definition(args)
    
    # 执行检查
    check_results = execute_checks(args, check_items)
    
    # 生成报告
    report_file = generate_report(args, check_results)
    
    # 判定结果
    final_result = determine_result(check_results)
    
    # 写入标记文件
    write_marker_file(args, final_result)
    
    # 返回结果
    if final_result == 'PASS':
        return 0
    else:
        return 1

def parse_args():
    """解析参数"""
    parser = argparse.ArgumentParser(
        description='IFP Check Script'
    )
    parser.add_argument('-d', '--path', required=True, help='Check directory')
    parser.add_argument('-f', '--flow', required=True, help='Flow type')
    parser.add_argument('-b', '--block', required=True, help='Block name')
    parser.add_argument('-v', '--vendor', default='', help='Vendor')
    parser.add_argument('-e', '--excel', default='', help='Check definition Excel')
    
    return parser.parse_args()

def load_check_definition(args):
    """加载检查定义"""
    check_items = []
    
    # 方式1: 从Excel加载
    if args.excel and os.path.exists(args.excel):
        check_items = load_from_excel(args.excel)
    
    # 方式2: 从YAML加载
    yaml_file = f"{args.path}/check_definition.yaml"
    if os.path.exists(yaml_file):
        check_items = load_from_yaml(yaml_file)
    
    # 方式3: 根据flow类型加载默认定义
    if not check_items:
        check_items = load_default_definition(args.flow)
    
    return check_items

def execute_checks(args, check_items):
    """执行检查"""
    results = []
    
    for item in check_items:
        print(f"Executing check: {item['name']}")
        
        # 执行检查脚本
        check_script = item.get('script')
        if check_script:
            result = execute_check_script(args, check_script, item)
        else:
            # 内置检查
            result = execute_builtin_check(args, item)
        
        results.append(result)
        
        # 打印结果
        status = result['status']
        message = result['message']
        print(f"  Result: {status} - {message}")
    
    return results

def execute_check_script(args, script, item):
    """执行检查脚本"""
    import subprocess
    
    # 组装命令
    cmd = f"python3 {script} --path {args.path} --item {item['name']}"
    
    # 执行
    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True
    )
    
    # 解析结果
    if result.returncode == 0:
        return {
            'name': item['name'],
            'status': 'PASS',
            'message': result.stdout.strip(),
            'value': item.get('value', '')
        }
    else:
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': result.stderr.strip(),
            'value': item.get('value', '')
        }

def execute_builtin_check(args, item):
    """执行内置检查"""
    check_type = item['type']
    
    if check_type == 'file_exists':
        return check_file_exists(args.path, item)
    
    elif check_type == 'file_size':
        return check_file_size(args.path, item)
    
    elif check_type == 'file_content':
        return check_file_content(args.path, item)
    
    elif check_type == 'timing':
        return check_timing(args.path, item)
    
    elif check_type == 'area':
        return check_area(args.path, item)
    
    elif check_type == 'power':
        return check_power(args.path, item)
    
    elif check_type == 'formal':
        return check_formal(args.path, item)
    
    else:
        return {
            'name': item['name'],
            'status': 'UNKNOWN',
            'message': f"Unknown check type: {check_type}",
            'value': ''
        }

def check_file_exists(path, item):
    """检查文件是否存在"""
    file_pattern = item['file']
    
    # 处理通配符
    import glob
    files = glob.glob(os.path.join(path, file_pattern))
    
    if files:
        return {
            'name': item['name'],
            'status': 'PASS',
            'message': f"Found {len(files)} files",
            'value': ', '.join([os.path.basename(f) for f in files])
        }
    else:
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': f"File not found: {file_pattern}",
            'value': ''
        }

def check_timing(path, item):
    """检查Timing结果"""
    # 查找timing报告
    timing_file = find_timing_report(path)
    
    if not timing_file:
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': "Timing report not found",
            'value': ''
        }
    
    # 解析timing报告
    slack = parse_timing_slack(timing_file)
    
    # 判断是否满足
    threshold = item.get('threshold', 0)
    
    if slack >= threshold:
        return {
            'name': item['name'],
            'status': 'PASS',
            'message': f"Timing met: slack = {slack}",
            'value': str(slack)
        }
    else:
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': f"Timing violation: slack = {slack}",
            'value': str(slack)
        }

def generate_report(args, check_results):
    """生成Excel报告"""
    report_file = args.path + '/file_check.rpt'
    
    # 创建Excel
    workbook = xlwt.Workbook()
    sheet = workbook.add_sheet('Check Results')
    
    # 写入标题
    headers = ['Check Item', 'Status', 'Value', 'Message', 'Timestamp']
    for col, header in enumerate(headers):
        sheet.write(0, col, header)
    
    # 写入结果
    for row, result in enumerate(check_results, start=1):
        sheet.write(row, 0, result['name'])
        sheet.write(row, 1, result['status'])
        sheet.write(row, 2, result['value'])
        sheet.write(row, 3, result['message'])
        sheet.write(row, 4, datetime.now().isoformat())
    
    # 写入汇总
    summary_row = len(check_results) + 1
    pass_count = sum(1 for r in check_results if r['status'] == 'PASS')
    fail_count = sum(1 for r in check_results if r['status'] == 'FAIL')
    
    sheet.write(summary_row, 0, 'Summary')
    sheet.write(summary_row, 1, f"PASS: {pass_count}, FAIL: {fail_count}")
    
    # 保存
    workbook.save(report_file)
    
    print(f"Report generated: {report_file}")
    return report_file

def determine_result(check_results):
    """判定最终结果"""
    for result in check_results:
        if result['status'] == 'FAIL':
            return 'FAIL'
    
    return 'PASS'

def write_marker_file(args, result):
    """写入标记文件"""
    marker_file = os.path.join(args.path, result)
    
    with open(marker_file, 'w') as f:
        f.write(f"{result}\n")
        f.write(f"Timestamp: {datetime.now().isoformat()}\n")
        f.write(f"Block: {args.block}\n")
        f.write(f"Flow: {args.flow}\n")
    
    print(f"Marker file written: {marker_file}")

def load_default_definition(flow):
    """加载默认检查定义"""
    # 综合流程默认检查
    if flow == 'syn':
        return [
            {
                'name': 'Netlist Exists',
                'type': 'file_exists',
                'file': 'run/output/*.v'
            },
            {
                'name': 'Timing Met',
                'type': 'timing',
                'threshold': 0
            },
            {
                'name': 'Area Within Budget',
                'type': 'area',
                'max_area': 100000
            },
            {
                'name': 'No Unconnected Ports',
                'type': 'file_content',
                'file': 'run/log/run.log',
                'pattern': 'Unconnected',
                'expected': 'not found'
            }
        ]
    
    # 形式验证默认检查
    elif flow == 'fm':
        return [
            {
                'name': 'Verification Pass',
                'type': 'formal',
                'threshold': 100  # 100% match
            },
            {
                'name': 'No Compare Points Failing',
                'type': 'file_content',
                'file': 'run/reports/fm_report.rpt',
                'pattern': 'Failing',
                'expected': '0'
            }
        ]
    
    # 验证默认检查
    elif flow == 'dv':
        return [
            {
                'name': 'Test Passed',
                'type': 'file_content',
                'file': 'run/sim.log',
                'pattern': 'PASS',
                'expected': 'found'
            },
            {
                'name': 'Coverage Met',
                'type': 'coverage',
                'threshold': 80
            }
        ]
    
    return []

if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)
```

### 2.2 检查类型详解

```python
# 内置检查类型

"""
IFP支持的检查类型:

1. file_exists - 文件存在检查
   {
       'name': 'Netlist Exists',
       'type': 'file_exists',
       'file': 'run/output/*.v'
   }

2. file_size - 文件大小检查
   {
       'name': 'Log Size Check',
       'type': 'file_size',
       'file': 'run/log/run.log',
       'max_size': 100000000  # 100MB
   }

3. file_content - 文件内容检查
   {
       'name': 'No Errors in Log',
       'type': 'file_content',
       'file': 'run/log/run.log',
       'pattern': 'ERROR',
       'expected': 'not found'
   }

4. timing - Timing检查
   {
       'name': 'Timing Met',
       'type': 'timing',
       'threshold': 0  # slack >= 0
   }

5. area - Area检查
   {
       'name': 'Area Within Budget',
       'type': 'area',
       'max_area': 100000
   }

6. power - Power检查
   {
       'name': 'Power Within Budget',
       'type': 'power',
       'max_power': 1000  # mW
   }

7. formal - 形式验证检查
   {
       'name': 'Formal Verification Pass',
       'type': 'formal',
       'threshold': 100  # 100% match
   }

8. coverage - 覆盖率检查
   {
       'name': 'Coverage Met',
       'type': 'coverage',
       'threshold': 80  # 80%
   }

9. drc - DRC检查
   {
       'name': 'DRC Clean',
       'type': 'drc',
       'expected': 0  # 0 violations
   }

10. lvs - LVS检查
    {
        'name': 'LVS Match',
        'type': 'lvs',
        'expected': 'MATCH'
    }
"""

def check_file_size(path, item):
    """检查文件大小"""
    file_path = os.path.join(path, item['file'])
    
    if not os.path.exists(file_path):
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': f"File not found: {item['file']}",
            'value': ''
        }
    
    file_size = os.path.getsize(file_path)
    max_size = item.get('max_size', float('inf'))
    
    if file_size <= max_size:
        return {
            'name': item['name'],
            'status': 'PASS',
            'message': f"File size: {file_size} bytes",
            'value': str(file_size)
        }
    else:
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': f"File size exceeded: {file_size} > {max_size}",
            'value': str(file_size)
        }

def check_file_content(path, item):
    """检查文件内容"""
    file_path = os.path.join(path, item['file'])
    
    if not os.path.exists(file_path):
        return {
            'name': item['name'],
            'status': 'FAIL',
            'message': f"File not found: {item['file']}",
            'value': ''
        }
    
    with open(file_path) as f:
        content = f.read()
    
    pattern = item['pattern']
    expected = item['expected']
    
    import re
    match = re.search(pattern, content, re.IGNORECASE)
    
    if expected == 'found':
        if match:
            return {
                'name': item['name'],
                'status': 'PASS',
                'message': f"Pattern found: {pattern}",
                'value': match.group()
            }
        else:
            return {
                'name': item['name'],
                'status': 'FAIL',
                'message': f"Pattern not found: {pattern}",
                'value': ''
            }
    
    elif expected == 'not found':
        if match:
            return {
                'name': item['name'],
                'status': 'FAIL',
                'message': f"Pattern found (unexpected): {pattern}",
                'value': match.group()
            }
        else:
            return {
                'name': item['name'],
                'status': 'PASS',
                'message': f"Pattern not found: {pattern}",
                'value': ''
            }
    
    else:
        # 检查数值
        if match:
            value = match.group(1) if match.groups() else match.group()
            try:
                num_value = float(value)
                expected_value = float(expected)
                
                if num_value == expected_value:
                    return {
                        'name': item['name'],
                        'status': 'PASS',
                        'message': f"Value matches: {value}",
                        'value': str(value)
                    }
                else:
                    return {
                        'name': item['name'],
                        'status': 'FAIL',
                        'message': f"Value mismatch: {value} != {expected}",
                        'value': str(value)
                    }
            except ValueError:
                return {
                    'name': item['name'],
                    'status': 'FAIL',
                    'message': f"Cannot parse value: {value}",
                    'value': str(value)
                }
        else:
            return {
                'name': item['name'],
                'status': 'FAIL',
                'message': f"Pattern not found: {pattern}",
                'value': ''
            }
```

---

## 3. 检查定义文件

### 3.1 Excel定义格式

```
检查定义Excel格式:

check_syn.xlsx:

┌─────────────────────────────────────────────────────────────────────┐
│ Sheet: CheckDefinition                                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ | Check Item        | Type     | File              | Threshold |   │
│ |-------------------|----------|--------------------|-----------|   │
│ | Netlist Exists    |file_exist| run/output/*.v    | -         |   │
│ | Timing Met        | timing   | run/reports/*.rpt | 0         |   │
│ | Area Within Budget| area     | run/reports/*.rpt | 100000    |   │
│ | Power Within Budget| power   | run/reports/*.rpt | 1000      |   │
│ | No Errors in Log  | content  | run/log/run.log   | ERROR:not │   │
│ | Constraints Valid | file_exist| run/output/*.sdc | -         |   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

Excel列说明:

| 列名 | 说明 | 示例 |
|------|------|------|
| Check Item | 检查项名称 | Timing Met |
| Type | 检查类型 | timing/area/file_exists |
| File | 文件路径（相对） | run/reports/timing.rpt |
| Threshold | 阈值/期望值 | 0 (timing slack) |
| Script | 自定义脚本路径（可选） | /path/to/check_timing.py |
| Description | 检查项描述（可选） | Check timing slack >= 0 |

自定义检查脚本格式:

check_timing.py:
#!/usr/bin/env python3

import argparse
import re

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', required=True)
    parser.add_argument('--item', required=True)
    args = parser.parse_args()
    
    # 查找timing报告
    timing_file = find_timing_file(args.path)
    
    # 解析slack
    slack = parse_timing_slack(timing_file)
    
    # 输出结果
    if slack >= 0:
        print(f"PASS: Timing slack = {slack}")
        return 0
    else:
        print(f"FAIL: Timing violation, slack = {slack}")
        return 1

def parse_timing_slack(file):
    """解析timing报告中的slack"""
    with open(file) as f:
        content = f.read()
    
    # 匹配slack值
    # 格式: Slack: -0.123
    match = re.search(r'Slack:\s+([\d.-]+)', content)
    if match:
        return float(match.group(1))
    return None

if __name__ == '__main__':
    exit(main())
```

### 3.2 YAML定义格式

```yaml
# check_definition.yaml - YAML格式检查定义

# 检查定义
checks:
  # 检查项1: 网表存在
  - name: Netlist Exists
    type: file_exists
    file: run/output/*.v
    description: Check synthesized netlist exists
    
  # 检查项2: Timing满足
  - name: Timing Met
    type: timing
    threshold: 0
    file: run/reports/timing_max.rpt
    description: Check timing slack >= 0
    
  # 检查项3: Area在预算内
  - name: Area Within Budget
    type: area
    max_area: 100000
    file: run/reports/area.rpt
    description: Check total area <= 100000 um2
    
  # 检查项4: Power在预算内
  - name: Power Within Budget
    type: power
    max_power: 1000
    file: run/reports/power.rpt
    description: Check total power <= 1000 mW
    
  # 检查项5: 日志无错误
  - name: No Errors in Log
    type: file_content
    file: run/log/run.log
    pattern: ERROR
    expected: not found
    description: Check no ERROR in run log
    
  # 检查项6: 约束文件有效
  - name: Constraints Valid
    type: file_exists
    file: run/output/*.sdc
    description: Check SDC constraints exist
    
  # 检查项7: 自定义脚本检查
  - name: Custom Check
    script: ${IFP_INSTALL_PATH}/action/check/scripts/custom_check.py
    description: Custom check using external script

# 检查配置
config:
  # 失败处理
  fail_action: continue    # continue/stop
  
  # 报告格式
  report_format: excel     # excel/html/json
  
  # 通知配置
  notification:
    email: true
    recipients: [user@company.com]
```

---

## 4. 报告生成机制

### 4.1 Excel报告格式

```
Excel报告结构:

file_check.rpt:

┌─────────────────────────────────────────────────────────────────────┐
│ Sheet: CheckResults                                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ | Check Item        | Status | Value     | Message       | Timestamp│
│ |-------------------|--------|-----------|---------------|----------│
│ | Netlist Exists    | PASS   | netlist.v | Found 1 file  | 14:30:01 │
│ | Timing Met        | PASS   | 0.5       | Slack = 0.5ns | 14:30:02 │
│ | Area Within Budget| PASS   | 85000     | Area = 85000  | 14:30:03 │
│ | Power Within Budget| PASS  | 800       | Power = 800mW | 14:30:04 │
│ | No Errors in Log  | PASS   | -         | No ERROR found| 14:30:05 │
│ | Constraints Valid | PASS   | top.sdc   | Found 1 file  | 14:30:06 │
│ |-------------------|--------|-----------|---------------|----------│
│ | Summary           | PASS   | -         | 6 PASS, 0 FAIL| -        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Sheet: Metadata                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ | Field    | Value                  │                              │
│ |----------|-------------------------│                              │
│ | Block    | cpu_core               │                              │
│ | Flow     | syn                    │                              │
│ | Task     | syn_dc                 │                              │
│ | Date     | 2026-05-13             │                              │
│ | User     | zhangsan               │                              │
│ | IFP Ver  | V1.4.3                 │                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 报告生成代码

```python
# gen_checklist_report.py 报告生成

import xlwt
import pandas as pd
from datetime import datetime

def generate_check_report(results, metadata, output_file):
    """生成检查报告"""
    
    workbook = xlwt.Workbook()
    
    # Sheet 1: 检查结果
    results_sheet = workbook.add_sheet('CheckResults')
    
    # 标题行
    headers = ['Check Item', 'Status', 'Value', 'Message', 'Timestamp']
    header_style = xlwt.easyxf('font: bold on')
    
    for col, header in enumerate(headers):
        results_sheet.write(0, col, header, header_style)
    
    # 结果行
    pass_style = xlwt.easyxf('pattern: pattern solid, fore_colour green')
    fail_style = xlwt.easyxf('pattern: pattern solid, fore_colour red')
    
    for row, result in enumerate(results, start=1):
        results_sheet.write(row, 0, result['name'])
        
        status = result['status']
        style = pass_style if status == 'PASS' else fail_style
        results_sheet.write(row, 1, status, style)
        
        results_sheet.write(row, 2, result.get('value', ''))
        results_sheet.write(row, 3, result.get('message', ''))
        results_sheet.write(row, 4, result.get('timestamp', ''))
    
    # 汇总行
    summary_row = len(results) + 1
    pass_count = sum(1 for r in results if r['status'] == 'PASS')
    fail_count = sum(1 for r in results if r['status'] == 'FAIL')
    
    final_status = 'PASS' if fail_count == 0 else 'FAIL'
    final_style = pass_style if final_status == 'PASS' else fail_style
    
    results_sheet.write(summary_row, 0, 'Summary', header_style)
    results_sheet.write(summary_row, 1, final_status, final_style)
    results_sheet.write(summary_row, 3, f"{pass_count} PASS, {fail_count} FAIL")
    
    # Sheet 2: 元数据
    meta_sheet = workbook.add_sheet('Metadata')
    
    for row, (key, value) in enumerate(metadata.items()):
        meta_sheet.write(row, 0, key)
        meta_sheet.write(row, 1, value)
    
    # 保存
    workbook.save(output_file)
    
    return output_file
```

---

## 5. 结果判定与标记文件

### 5.1 PASS/FAIL判定

```
结果判定逻辑:

┌─────────────────────────────────────────────────────────────────────┐
│                     Result Determination                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  判定规则:                                                          │
│                                                                     │
│  1. 严格模式 (strict):                                             │
│     - 任一检查项FAIL → 整体FAIL                                     │
│     - 所有检查项PASS → 整体PASS                                     │
│                                                                     │
│  2. 宽松模式 (relaxed):                                            │
│     - 关键检查项FAIL → 整体FAIL                                     │
│     - 非关键检查项FAIL → 整体PASS (with warning)                    │
│                                                                     │
│  3. 自定义模式 (custom):                                           │
│     - 根据权重计算总分                                              │
│     - 总分 >= threshold → PASS                                     │
│                                                                     │
│  IFP默认使用严格模式                                                │
│                                                                     │
│  代码实现:                                                          │
│                                                                     │
│  def determine_result(results, mode='strict'):                     │
│      """判定最终结果"""                                              │
│      if mode == 'strict':                                          │
│          for result in results:                                    │
│              if result['status'] == 'FAIL':                        │
│                  return 'FAIL'                                      │
│          return 'PASS'                                             │
│                                                                     │
│      elif mode == 'relaxed':                                       │
│          for result in results:                                    │
│              if result['status'] == 'FAIL' and                     │
│                 result.get('critical', True):                      │
│                  return 'FAIL'                                      │
│          return 'PASS'                                             │
│                                                                     │
│      elif mode == 'custom':                                        │
│          total_score = 0                                           │
│          for result in results:                                    │
│              weight = result.get('weight', 1)                      │
│              if result['status'] == 'PASS':                        │
│                  total_score += weight                             │
│          threshold = config.get('threshold', 0)                    │
│          if total_score >= threshold:                              │
│              return 'PASS'                                         │
│          return 'FAIL'                                             │
│                                                                     │
│      return 'PASS'                                                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 标记文件写入

```python
# 标记文件写入

def write_marker_file(check_path, result, metadata):
    """
    写入标记文件
    
    Args:
        check_path: CHECK目录
        result: 最终结果（PASS/FAIL）
        metadata: 元数据字典
    """
    
    # 创建标记文件
    marker_file = os.path.join(check_path, result)
    
    with open(marker_file, 'w') as f:
        # 写入结果
        f.write(f"Result: {result}\n")
        
        # 写入时间戳
        f.write(f"Timestamp: {datetime.now().isoformat()}\n")
        
        # 写入元数据
        for key, value in metadata.items():
            f.write(f"{key}: {value}\n")
        
        # 写入检查项汇总
        f.write("\nCheck Items:\n")
        for item in metadata.get('check_results', []):
            f.write(f"  - {item['name']}: {item['status']}\n")
    
    # 创建详细报告文件
    detail_file = os.path.join(check_path, f"{result}_details.txt")
    
    with open(detail_file, 'w') as f:
        f.write(f"Check Report Details\n")
        f.write(f"=" * 50 + "\n\n")
        
        for item in metadata.get('check_results', []):
            f.write(f"Check: {item['name']}\n")
            f.write(f"  Status: {item['status']}\n")
            f.write(f"  Value: {item.get('value', '')}\n")
            f.write(f"  Message: {item.get('message', '')}\n")
            f.write(f"  Timestamp: {item.get('timestamp', '')}\n")
            f.write("\n")

# 标记文件示例内容:

# PASS文件:
Result: PASS
Timestamp: 2026-05-13T14:30:01
Block: cpu_core
Flow: syn
Task: syn_dc
User: zhangsan

Check Items:
  - Netlist Exists: PASS
  - Timing Met: PASS
  - Area Within Budget: PASS
  - Power Within Budget: PASS
  - No Errors in Log: PASS
  - Constraints Valid: PASS

# FAIL文件:
Result: FAIL
Timestamp: 2026-05-13T14:30:01
Block: cpu_core
Flow: syn
Task: syn_dc
User: zhangsan

Check Items:
  - Netlist Exists: PASS
  - Timing Met: FAIL
  - Area Within Budget: PASS
  - Power Within Budget: PASS
  - No Errors in Log: PASS
  - Constraints Valid: PASS
```

---

## 6. VIEWER查看器

### 6.1 VIEWER配置

```yaml
# VIEWER配置示例

CHECK:
  # 报告文件路径
  REPORT_FILE: ${PATH}/file_check.rpt
  
  # 查看器命令
  VIEWER: firefox ${REPORT_FILE}
  
  # 或使用其他查看器:
  # VIEWER: libreoffice ${REPORT_FILE}     # LibreOffice
  # VIEWER: excel ${REPORT_FILE}           # Microsoft Excel
  # VIEWER: less ${REPORT_FILE}.txt        # 文本查看
  # VIEWER: custom_viewer.py ${REPORT_FILE} # 自定义脚本

# VIEWER调用时机:
# 1. 用户点击[View]按钮
# 2. CHECK完成后自动显示（可选配置）
```

### 6.2 自定义VIEWER脚本

```python
#!/usr/bin/env python3
# tools/custom_viewer.py
# 自定义报告查看器

import sys
import os
import subprocess

def view_report(report_file):
    """查看检查报告"""
    
    if not os.path.exists(report_file):
        print(f"Report not found: {report_file}")
        return False
    
    # 检测文件类型
    if report_file.endswith('.xlsx') or report_file.endswith('.xls'):
        # Excel文件
        if os.name == 'posix':
            # Linux
            subprocess.run(['libreoffice', report_file])
        elif os.name == 'darwin':
            # macOS
            subprocess.run(['open', '-a', 'Numbers', report_file])
        elif os.name == 'nt':
            # Windows
            subprocess.run(['excel', report_file])
    
    elif report_file.endswith('.html'):
        # HTML文件
        subprocess.run(['firefox', report_file])
    
    elif report_file.endswith('.txt'):
        # 文本文件
        subprocess.run(['less', report_file])
    
    else:
        # 默认使用文本查看器
        subprocess.run(['cat', report_file])
    
    return True

if __name__ == '__main__':
    if len(sys.argv) > 1:
        report_file = sys.argv[1]
        view_report(report_file)
```

---

## 7. 检查脚本目录结构

```
action/check/目录结构:

action/check/
├── scripts/                    # Python检查脚本
│   ├── ic_check.py             # 主检查脚本
│   ├── gen_checklist_scripts.py # 生成检查脚本
│   ├── gen_checklist_summary.py # 生成检查汇总
│   ├── view_checklist_report.py # 查看报告脚本
│   ├── check_timing.py         # Timing检查
│   ├── check_area.py           # Area检查
│   ├── check_power.py          # Power检查
│   ├── check_formal.py         # 形式验证检查
│   ├── check_coverage.py       # 覆盖率检查
│   ├── check_drc.py            # DRC检查
│   ├── check_lvs.py            # LVS检查
│   └── custom_check.py         # 自定义检查模板
│
├── demo_excel/                 # 检查定义Excel模板
│   ├── check_syn.xlsx          # 综合检查定义
│   ├── check_fm.xlsx           # 形式验证检查定义
│   ├── check_sta.xlsx          # STA检查定义
│   ├── check_dv.xlsx           # 验证检查定义
│   ├── check_apr.xlsx          # APR检查定义
│   └── template.xlsx           # 空白模板
│
├── demo_yaml/                  # YAML定义模板
│   ├── check_syn.yaml
│   ├── check_fm.yaml
│   └── template.yaml
│
├── reports/                    # 报告模板
│   ├── report_template.xlsx    # Excel报告模板
│   └── report_template.html    # HTML报告模板
│
└── docs/                       # 检查文档
    ├── check_guide.md          # 检查指南
    └── check_types.md          # 检查类型说明
```

---

*Chiplet Design Practice*
*文档生成: 2026-05-13*