# IFP LSF集群集成

本文档详细解析IC Flow Platform与LSF（Load Sharing Facility）集群的集成机制。

---

## 1. LSF概述

### 1.1 LSF架构

LSF是IBM开发的分布式计算管理系统，广泛应用于EDA计算集群。

```
LSF系统架构:

┌─────────────────────────────────────────────────────────────────────┐
│                     LSF System Architecture                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Master Host                                                       │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ LIM (Load Information Manager)                                 │ │
│  │ - 收集集群负载信息                                             │ │
│  │ - 管理主机状态                                                 │ │
│  │                                                               │ │
│  │ MBD (Master Batch Daemon)                                     │ │
│  │ - 接收任务提交                                                 │ │
│  │ - 任务调度决策                                                 │ │
│  │ - 任务队列管理                                                 │ │
│  │                                                               │ │
│  │ RES (Remote Execution Server)                                 │ │
│  │ - 执行任务                                                     │ │
│  │ - 返回结果                                                     │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↕                                      │
│                              网络                                   │
│                              ↕                                      │
│  Execution Hosts                                                   │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │ │
│  │ │ Slave LIM   │ │ Slave LIM   │ │ Slave LIM   │ │ Slave LIM │ │ │
│  │ │ RES         │ │ RES         │ │ RES         │ │ RES       │ │ │
│  │ │ node01      │ │ node02      │ │ node03      │ │ node04    │ │ │
│  │ │ 8 cores     │ │ 16 cores    │ │ 8 cores     │ │ 32 cores  │ │ │
│  │ │ 32GB RAM    │ │ 64GB RAM    │ │ 32GB RAM    │ │ 128GB RAM │ │ │
│  │ └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  用户提交任务流程:                                                  │
│  User → bsub → MBD → 调度 → RES → 执行 → 返回                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

LSF关键组件:

| 组件 | 说明 | 命令 |
|------|------|------|
| LIM | 负载信息管理器 | lsload, lshosts |
| MBD | 主批处理守护进程 | bsub, bjobs, bkill |
| RES | 远程执行服务器 | 运行任务 |
| SBD | 从批处理守护进程 | 任务执行管理 |

LSF核心命令:

| 命令 | 功能 | 示例 |
|------|------|------|
| bsub | 提交任务 | bsub -q queue -n 4 command |
| bjobs | 查看任务 | bjobs, bjobs -l job_id |
| bkill | 终止任务 | bkill job_id |
| bpeek | 查看输出 | bpeek job_id |
| bhist | 任务历史 | bhist job_id |
| bqueues | 查看队列 | bqueues, bqueues -l queue_name |
| bhosts | 查看主机 | bhosts, bhosts -l host_name |
| lsload | 查看负载 | lsload, lsload -l |
| lshosts | 查看主机 | lshosts, lshosts -l |
```

### 1.2 LSF环境配置

```bash
# LSF环境变量配置

# 通常在系统级profile中设置
# /opt/lsf/conf/profile.lsf

# 必要环境变量
export LSF_ENVDIR=/opt/lsf/conf       # LSF配置目录
export LSF_SERVERDIR=/opt/lsf/etc     # LSF服务器目录
export PATH=/opt/lsf/bin:$PATH        # LSF命令路径

# 许可环境变量
export LSF_LICENSE_FILE=/opt/lsf/license/license.dat

# 验证LSF环境
source /opt/lsf/conf/profile.lsf

which bsub
# /opt/lsf/bin/bsub

bsub -V
# LSF version 10.1.0.3

lsload
# HOST_NAME      STATUS  CPU    MEM    SWP    UT    PG    IO
# master         ok      1.0    64G    32G    10%   0.0   0.0
# node01         ok      8.0    32G    16G    50%   0.1   1.0
# node02         ok      16.0   64G    32G    80%   0.2   2.0

bqueues
# QUEUE_NAME     PRIO   NJOBS   PEND   RUN    SSUSP  USUSP  FINISHED
# normal         50     10      5      3      0      0      100
# ai_syn         60     20      10     5      0      0      200
# high_perf      70     5       2      1      0      0      50
```

---

## 2. RUN_METHOD详解

### 2.1 RUN_METHOD配置

RUN_METHOD定义任务执行方式，直接影响LSF提交参数。

```yaml
# RUN_METHOD配置示例

VAR:
  # LSF队列配置
  BSUB_QUEUE: ai_syn
  BSUB_CORES: 4
  BSUB_MEMORY: 8000    # MB
  BSUB_RUN_TIME: 3600  # 秒
  
  # 组合RUN_METHOD模板
  BSUB_RUN_METHOD: bsub -q ${BSUB_QUEUE} -n ${BSUB_CORES} -R "rusage[mem=${BSUB_MEMORY}]" -W ${BSUB_RUN_TIME}

TASK:
  syn_dc:
    RUN:
      # 方式1: 直接使用LSF命令
      RUN_METHOD: bsub -q ai_syn -n 4 -R "rusage[mem=8000]"
      
      # 方式2: 使用变量组合
      RUN_METHOD: ${BSUB_RUN_METHOD}
      
      # 方式3: 本地执行
      RUN_METHOD: local
      
      # 方式4: 详细LSF配置
      RUN_METHOD: bsub -q ai_syn -n 4 -R "rusage[mem=8000] span[hosts=1]" -W 3600 -J syn_dc_${BLOCK} -o ${PATH}/log/bsub.out -e ${PATH}/log/bsub.err

RUN_METHOD参数详解:

bsub基本参数:

bsub -q queue          指定队列名
bsub -n cores          CPU核心数
bsub -R "rusage"       资源使用声明
bsub -W time           运行时间限制（分钟）
bsub -J job_name       任务名
bsub -o output_file    输出文件
bsub -e error_file     错误文件
bsub -P project        项目名
bsub -u user           用户名
bsub -i input_file     输入文件
bsub -app application  应用类型

rusage资源声明:

rusage[mem=MB]         内存需求（MB）
rusage[mem=GB]         内存需求（GB，部分版本）
span[hosts=1]          单主机运行
span[ptile=cores]      每主机核心数
select[type==type]     选择主机类型

示例组合:

# 8核，16GB内存，单主机，2小时
bsub -q ai_syn -n 8 -R "rusage[mem=16000] span[hosts=1]" -W 120 command

# 32核，64GB内存，分布式，4小时
bsub -q high_perf -n 32 -R "rusage[mem=64GB]" -W 240 -J big_job command

# 交互式任务
bsub -q interactive -I command

# 数组任务
bsub -q normal -J "array[1-100]" command \$LSB_JOBINDEX
```

### 2.2 LSF提交代码实现

```python
# common_lsf.py LSF命令封装

import subprocess
import re
import os

class LSFClient:
    """LSF客户端"""
    
    def __init__(self):
        self.lsf_bin = '/opt/lsf/bin'
    
    def submit_job(self, queue, cores, memory, command, 
                   job_name=None, output_file=None, error_file=None,
                   run_time=None, project=None):
        """
        提交LSF任务
        
        Args:
            queue: 队列名
            cores: CPU核心数
            memory: 内存需求（MB）
            command: 执行命令
            job_name: 任务名（可选）
            output_file: 输出文件（可选）
            error_file: 错误文件（可选）
            run_time: 运行时间限制（分钟，可选）
            project: 项目名（可选）
        
        Returns:
            (bool, int/str): (是否成功, job_id或错误消息)
        """
        
        # 组装bsub命令
        bsub_cmd = f"{self.lsf_bin}/bsub -q {queue} -n {cores} -R \"rusage[mem={memory}]\""
        
        if job_name:
            bsub_cmd += f" -J {job_name}"
        
        if output_file:
            bsub_cmd += f" -o {output_file}"
        
        if error_file:
            bsub_cmd += f" -e {error_file}"
        
        if run_time:
            bsub_cmd += f" -W {run_time}"
        
        if project:
            bsub_cmd += f" -P {project}"
        
        bsub_cmd += f" {command}"
        
        # 执行bsub
        try:
            result = subprocess.run(
                bsub_cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            # 解析job_id
            # Job <12345> is submitted to queue <ai_syn>.
            pattern = r'Job <(\d+)>'
            match = re.search(pattern, result.stdout)
            
            if match:
                job_id = int(match.group(1))
                return True, job_id
            else:
                return False, result.stderr
            
        except subprocess.TimeoutExpired:
            return False, "bsub timeout"
        except Exception as e:
            return False, str(e)
    
    def check_job_status(self, job_id):
        """
        查询任务状态
        
        Args:
            job_id: 任务ID
        
        Returns:
            str: 任务状态（PEND/RUN/DONE/EXIT/UNKNOWN）
        """
        
        try:
            result = subprocess.run(
                f"{self.lsf_bin}/bjobs {job_id}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # 解析状态
            # JOBID USER STAT QUEUE FROM_HOST EXEC_HOST JOB_NAME SUBMIT_TIME
            # 12345 zhang RUN ai_syn server1 node01 syn_dc May 13 14:00
            
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                fields = lines[1].split()
                status = fields[2]  # STAT字段
                return status
            
            return 'UNKNOWN'
            
        except Exception as e:
            return 'UNKNOWN'
    
    def kill_job(self, job_id):
        """
        终止任务
        
        Args:
            job_id: 任务ID
        
        Returns:
            bool: 是否成功
        """
        
        try:
            result = subprocess.run(
                f"{self.lsf_bin}/bkill {job_id}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # Job <12345> is being terminated
            return result.returncode == 0
            
        except Exception as e:
            return False
    
    def peek_job_output(self, job_id):
        """
        查看任务输出
        
        Args:
            job_id: 任务ID
        
        Returns:
            str: 输出内容
        """
        
        try:
            result = subprocess.run(
                f"{self.lsf_bin}/bpeek {job_id}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            return result.stdout
            
        except Exception as e:
            return ""
    
    def get_job_history(self, job_id):
        """
        获取任务历史
        
        Args:
            job_id: 任务ID
        
        Returns:
            dict: 任务历史信息
        """
        
        try:
            result = subprocess.run(
                f"{self.lsf_bin}/bhist {job_id}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            # 解析历史
            # Summary of time in seconds spent in various states:
            # PEND     RUN     SSUSP   USUSP   FINISHED   EXIT
            # 10       1800    0       0       0          0
            
            history = {}
            lines = result.stdout.strip().split('\n')
            
            for line in lines:
                if 'PEND' in line:
                    values = line.split()
                    history = {
                        'pend': int(values[0]),
                        'run': int(values[1]),
                        'ssusp': int(values[2]),
                        'ususp': int(values[3]),
                        'finished': int(values[4]),
                        'exit': int(values[5])
                    }
            
            return history
            
        except Exception as e:
            return {}
    
    def get_queue_info(self, queue_name=None):
        """
        获取队列信息
        
        Args:
            queue_name: 队列名（可选，不指定返回所有）
        
        Returns:
            list: 队列信息列表
        """
        
        cmd = f"{self.lsf_bin}/bqueues"
        if queue_name:
            cmd += f" {queue_name}"
        
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            queues = []
            lines = result.stdout.strip().split('\n')
            
            for i, line in enumerate(lines):
                if i > 0:  # 跳过标题行
                    fields = line.split()
                    queues.append({
                        'name': fields[0],
                        'prio': fields[1],
                        'njobs': fields[2],
                        'pend': fields[3],
                        'run': fields[4]
                    })
            
            return queues
            
        except Exception as e:
            return []
    
    def get_host_info(self, host_name=None):
        """
        获取主机信息
        
        Args:
            host_name: 主机名（可选）
        
        Returns:
            list: 主机信息列表
        """
        
        cmd = f"{self.lsf_bin}/bhosts"
        if host_name:
            cmd += f" {host_name}"
        
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            hosts = []
            lines = result.stdout.strip().split('\n')
            
            for i, line in enumerate(lines):
                if i > 0:
                    fields = line.split()
                    hosts.append({
                        'name': fields[0],
                        'status': fields[1],
                        'njobs': fields[2],
                        'run': fields[3],
                        'ssusp': fields[4]
                    })
            
            return hosts
            
        except Exception as e:
            return []

# 使用示例
lsf = LSFClient()

# 提交任务
ok, job_id = lsf.submit_job(
    queue='ai_syn',
    cores=4,
    memory=8000,
    command='dc_shell -f syn.tcl',
    job_name='syn_dc_cpu_core',
    output_file='/project/syn_dc/log/bsub.out',
    run_time=60
)

if ok:
    print(f"Job submitted: {job_id}")
    
    # 监控状态
    while True:
        status = lsf.check_job_status(job_id)
        print(f"Job status: {status}")
        
        if status == 'DONE':
            print("Job completed successfully")
            break
        elif status == 'EXIT':
            print("Job failed")
            break
        
        time.sleep(30)
else:
    print(f"Submit failed: {job_id}")
```

---

## 3. LSF监控子系统

### 3.1 监控架构

```
LSF监控子系统架构:

┌─────────────────────────────────────────────────────────────────────┐
│                     LSF Monitor Architecture                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Web Interface                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ Flask REST API (Port 5000)                                    │ │
│  │                                                               │ │
│  │ Endpoints:                                                    │ │
│  │ /api/jobs           - 任务列表                                │ │
│  │ /api/jobs/<id>      - 任务详情                                │ │
│  │ /api/jobs/<id>/log  - 任务日志                                │ │
│  │ /api/queues         - 队列信息                                │ │
│  │ /api/hosts          - 主机信息                                │ │
│  │ /api/stats          - 统计信息                                │ │
│  │                                                               │ │
│  │ Web UI:                                                       │ │
│  │ /jobs               - 任务监控界面                            │ │
│  │ /queues             - 队列监控界面                            │ │
│  │ /hosts              - 主机监控界面                            │ │
│  │ /dashboard          - 综合仪表板                              │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↕                                      │
│  Data Collection                                                   │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ LSF Poller (Background Thread)                                │ │
│  │                                                               │ │
│  │ - 定时轮询bjobs/bqueues/bhosts                                │ │
│  │ - 收集任务状态                                                 │ │
│  │ - 收集队列负载                                                 │ │
│  │ - 收集主机状态                                                 │ │
│  │ - 存储到SQLite                                                │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↕                                      │
│  Memory Prediction                                                 │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ ML Memory Predictor (XGBoost)                                 │ │
│  │                                                               │ │
│  │ - 分析历史任务数据                                             │ │
│  │ - 预测任务内存需求                                             │ │
│  │ - 预测任务运行时间                                             │ │
│  │ - 提供资源配置建议                                             │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↕                                      │
│  Database                                                          │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ SQLite Database                                               │ │
│  │                                                               │ │
│  │ Tables:                                                       │ │
│  │ - jobs: 任务记录                                              │ │
│  │ - queues: 队列状态                                            │ │
│  │ - hosts: 主机状态                                             │ │
│  │ - predictions: 预测记录                                       │ │
│  │ - history: 历史数据                                           │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Flask监控服务

```python
# tools/lsfMonitor/monitor/app.py Flask监控服务

from flask import Flask, jsonify, request, render_template
from flask_restful import Api, Resource
import threading
import time
import sqlite3

app = Flask(__name__)
api = Api(app)

# 数据库路径
DB_PATH = '/opt/ifp/data/lsf_monitor.db'

# 任务列表API
class JobListResource(Resource):
    def get(self):
        """获取任务列表"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # 查询参数
        status = request.args.get('status', '')
        queue = request.args.get('queue', '')
        limit = int(request.args.get('limit', 100))
        
        # 构建SQL
        sql = "SELECT * FROM jobs"
        conditions = []
        
        if status:
            conditions.append(f"status='{status}'")
        if queue:
            conditions.append(f"queue='{queue}'")
        
        if conditions:
            sql += " WHERE " + " AND ".join(conditions)
        
        sql += f" ORDER BY submit_time DESC LIMIT {limit}"
        
        cursor.execute(sql)
        rows = cursor.fetchall()
        
        conn.close()
        
        jobs = []
        for row in rows:
            jobs.append({
                'job_id': row[0],
                'job_name': row[1],
                'user': row[2],
                'queue': row[3],
                'status': row[4],
                'submit_time': row[5],
                'start_time': row[6],
                'finish_time': row[7],
                'cores': row[8],
                'memory': row[9],
                'host': row[10]
            })
        
        return jsonify(jobs)

# 任务详情API
class JobDetailResource(Resource):
    def get(self, job_id):
        """获取任务详情"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(f"SELECT * FROM jobs WHERE job_id={job_id}")
        row = cursor.fetchone()
        
        conn.close()
        
        if row:
            return jsonify({
                'job_id': row[0],
                'job_name': row[1],
                'user': row[2],
                'queue': row[3],
                'status': row[4],
                'submit_time': row[5],
                'start_time': row[6],
                'finish_time': row[7],
                'cores': row[8],
                'memory': row[9],
                'host': row[10],
                'output_file': row[11],
                'error_file': row[12]
            })
        else:
            return jsonify({'error': 'Job not found'}), 404

# 队列信息API
class QueueListResource(Resource):
    def get(self):
        """获取队列信息"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM queues ORDER BY priority DESC")
        rows = cursor.fetchall()
        
        conn.close()
        
        queues = []
        for row in rows:
            queues.append({
                'name': row[0],
                'priority': row[1],
                'njobs': row[2],
                'pend': row[3],
                'run': row[4],
                'ssusp': row[5],
                'ususp': row[6],
                'finished': row[7]
            })
        
        return jsonify(queues)

# 统计信息API
class StatsResource(Resource):
    def get(self):
        """获取统计信息"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # 总任务数
        cursor.execute("SELECT COUNT(*) FROM jobs")
        total_jobs = cursor.fetchone()[0]
        
        # 各状态任务数
        cursor.execute("SELECT status, COUNT(*) FROM jobs GROUP BY status")
        status_counts = {}
        for row in cursor.fetchall():
            status_counts[row[0]] = row[1]
        
        # 队列负载
        cursor.execute("SELECT name, njobs, pend, run FROM queues")
        queue_load = []
        for row in cursor.fetchall():
            queue_load.append({
                'name': row[0],
                'njobs': row[1],
                'pend': row[2],
                'run': row[3]
            })
        
        conn.close()
        
        return jsonify({
            'total_jobs': total_jobs,
            'status_counts': status_counts,
            'queue_load': queue_load
        })

# 注册API资源
api.add_resource(JobListResource, '/api/jobs')
api.add_resource(JobDetailResource, '/api/jobs/<int:job_id>')
api.add_resource(QueueListResource, '/api/queues')
api.add_resource(StatsResource, '/api/stats')

# Web界面路由
@app.route('/')
def index():
    """首页"""
    return render_template('index.html')

@app.route('/jobs')
def jobs_page():
    """任务监控界面"""
    return render_template('jobs.html')

@app.route('/queues')
def queues_page():
    """队列监控界面"""
    return render_template('queues.html')

@app.route('/dashboard')
def dashboard():
    """综合仪表板"""
    return render_template('dashboard.html')

# LSF数据轮询线程
def lsf_poller():
    """LSF数据轮询"""
    import subprocess
    
    while True:
        # 收集任务数据
        collect_jobs()
        
        # 收集队列数据
        collect_queues()
        
        # 收集主机数据
        collect_hosts()
        
        # 等待下次轮询
        time.sleep(30)

def collect_jobs():
    """收集任务数据"""
    subprocess.run(['python3', 'collect_jobs.py'])

def collect_queues():
    """收集队列数据"""
    subprocess.run(['python3', 'collect_queues.py'])

def collect_hosts():
    """收集主机数据"""
    subprocess.run(['python3', 'collect_hosts.py'])

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5000)
    args = parser.parse_args()
    
    # 启动轮询线程
    poller_thread = threading.Thread(target=lsf_poller, daemon=True)
    poller_thread.start()
    
    # 启动Flask服务
    app.run(host='0.0.0.0', port=args.port, debug=False)
```

---

## 4. 内存预测ML模型

### 4.1 内存预测原理

```
内存预测流程:

┌─────────────────────────────────────────────────────────────────────┐
│                     Memory Prediction Flow                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  历史数据收集                                                       │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 从LSF bhist收集历史任务数据                                     │ │
│  │                                                               │ │
│  │ 数据字段:                                                      │ │
│  │ - job_name: 任务名                                             │ │
│  │ - cores: CPU核心数                                             │ │
│  │ - memory_used: 实际内存使用                                    │ │
│  │ - run_time: 运行时间                                           │ │
│  │ - design_size: 设计规模（门数）                                │ │
│  │ - flow_type: 流程类型                                          │ │
│  │ - block_name: 模块名                                           │ │
│  │                                                               │ │
│  │ 存储到SQLite history表                                         │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│  特征工程                                                           │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 提取预测特征                                                    │ │
│  │                                                               │ │
│  │ 特征列表:                                                      │ │
│  │ 1. design_gates: 设计门数                                      │ │
│  │ 2. design_ports: 端口数                                        │ │
│  │ 3. design_hierarchy: 层级深度                                  │ │
│  │ 4. cores_request: 申请核心数                                   │ │
│  │ 5. flow_type_encoded: 流程类型编码                             │ │
│  │ 6. block_complexity: 模块复杂度                                │ │
│  │ 7. historical_avg_mem: 历史平均内存                            │ │
│  │                                                               │ │
│  │ 特征处理:                                                      │ │
│  │ - 标准化                                                       │ │
│  │ - 编码                                                         │ │
│  │ - 缺失值填充                                                   │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│  模型训练                                                           │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ XGBoost回归模型                                                 │ │
│  │                                                               │ │
│  │ 目标变量:                                                      │ │
│  │ - memory_required: 内存需求（MB）                              │ │
│  │                                                               │ │
│  │ 模型配置:                                                      │ │
│  │ - n_estimators: 100                                            │ │
│  │ - max_depth: 6                                                 │ │
│  │ - learning_rate: 0.1                                           │ │
│  │                                                               │ │
│  │ 训练流程:                                                      │ │
│  │ 1. 加载历史数据                                                │ │
│  │ 2. 特征工程                                                    │ │
│  │ 3. 训练模型                                                    │ │
│  │ 4. 评估模型                                                    │ │
│  │ 5. 保存模型                                                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│  内存预测                                                           │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 预测新任务内存需求                                              │ │
│  │                                                               │ │
│  │ 输入:                                                          │ │
│  │ - 任务配置                                                     │ │
│  │ - 设计信息                                                     │ │
│  │                                                               │ │
│  │ 输出:                                                          │ │
│  │ - predicted_memory: 预测内存（MB）                             │ │
│  │ - confidence: 置信度                                           │ │
│  │ - recommendation: 配置建议                                     │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              ↓                                      │
│  配置建议                                                           │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ 根据预测生成LSF配置建议                                         │ │
│  │                                                               │ │
│  │ 建议:                                                          │ │
│  │ - 推荐内存配置: predicted_memory * 1.2                         │ │
│  │ - 推荐核心数: 根据设计规模                                     │ │
│  │ - 推荐队列: 根据任务类型                                       │ │
│  │ - 预估运行时间                                                 │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 XGBoost预测模型

```python
# tools/lsfMonitor/memPrediction/model.py

import xgboost as xgb
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import joblib
import sqlite3

class MemoryPredictor:
    """内存预测模型"""
    
    def __init__(self, db_path='/opt/ifp/data/lsf_monitor.db'):
        self.db_path = db_path
        self.model = None
        self.scaler = None
    
    def load_training_data(self):
        """加载训练数据"""
        conn = sqlite3.connect(self.db_path)
        
        # 查询历史任务
        df = pd.read_sql_query(
            "SELECT * FROM history WHERE memory_used > 0",
            conn
        )
        
        conn.close()
        
        return df
    
    def prepare_features(self, df):
        """准备特征"""
        # 特征列
        feature_cols = [
            'design_gates',
            'design_ports',
            'design_hierarchy',
            'cores_request',
            'flow_type_encoded',
            'block_complexity'
        ]
        
        # 目标列
        target_col = 'memory_used'
        
        # 提取特征
        X = df[feature_cols].values
        
        # 提取目标
        y = df[target_col].values
        
        # 标准化
        self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X)
        
        return X_scaled, y
    
    def train(self):
        """训练模型"""
        # 加载数据
        df = self.load_training_data()
        
        if len(df) < 50:
            print("Insufficient training data")
            return False
        
        # 准备特征
        X, y = self.prepare_features(df)
        
        # 分割数据
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # 创建模型
        self.model = xgb.XGBRegressor(
            n_estimators=100,
            max_depth=6,
            learning_rate=0.1,
            objective='reg:squarederror'
        )
        
        # 训练
        self.model.fit(X_train, y_train)
        
        # 评估
        from sklearn.metrics import mean_absolute_error, r2_score
        
        y_pred = self.model.predict(X_test)
        
        mae = mean_absolute_error(y_test, y_pred)
        r2 = r2_score(y_test, y_pred)
        
        print(f"Model trained:")
        print(f"  MAE: {mae:.2f} MB")
        print(f"  R²: {r2:.4f}")
        
        return True
    
    def save(self, model_path='memory_predictor.pkl'):
        """保存模型"""
        if self.model and self.scaler:
            joblib.dump({
                'model': self.model,
                'scaler': self.scaler
            }, model_path)
            print(f"Model saved: {model_path}")
    
    def load(self, model_path='memory_predictor.pkl'):
        """加载模型"""
        data = joblib.load(model_path)
        self.model = data['model']
        self.scaler = data['scaler']
    
    def predict(self, task_config):
        """
        预测内存需求
        
        Args:
            task_config: 任务配置字典
        
        Returns:
            dict: 预测结果
        """
        
        if not self.model:
            return None
        
        # 提取特征
        features = np.array([
            task_config.get('design_gates', 0),
            task_config.get('design_ports', 0),
            task_config.get('design_hierarchy', 0),
            task_config.get('cores_request', 4),
            self.encode_flow_type(task_config.get('flow_type', 'syn')),
            task_config.get('block_complexity', 1)
        ]).reshape(1, -1)
        
        # 标准化
        features_scaled = self.scaler.transform(features)
        
        # 预测
        predicted_memory = self.model.predict(features_scaled)[0]
        
        # 置信度（简化计算）
        confidence = 0.8  # 默认
        
        # 配置建议
        recommended_memory = predicted_memory * 1.2  # 20%余量
        
        return {
            'predicted_memory': int(predicted_memory),
            'confidence': confidence,
            'recommended_memory': int(recommended_memory),
            'recommendation': f"bsub -R \"rusage[mem={int(recommended_memory)}]\""
        }
    
    def encode_flow_type(self, flow_type):
        """编码流程类型"""
        flow_encoding = {
            'syn': 1,
            'fm': 2,
            'sta': 3,
            'dv': 4,
            'apr': 5,
            'drc': 6,
            'lvs': 7
        }
        return flow_encoding.get(flow_type, 0)

# 使用示例
predictor = MemoryPredictor()

# 训练模型
predictor.train()
predictor.save()

# 预测
task_config = {
    'design_gates': 50000,
    'design_ports': 100,
    'design_hierarchy': 5,
    'cores_request': 4,
    'flow_type': 'syn',
    'block_complexity': 2
}

result = predictor.predict(task_config)
print(f"Predicted memory: {result['predicted_memory']} MB")
print(f"Recommended: {result['recommended_memory']} MB")
print(f"Recommendation: {result['recommendation']}")
```

---

## 5. JobWatcher集成

### 5.1 LSF状态监控

```python
# IFP集成的LSF监控

class JobWatcher:
    """IFP任务状态监控"""
    
    def __init__(self, job_manager, lsf_client):
        self.job_manager = job_manager
        self.lsf = lsf_client
        self.running = True
    
    def watch_lsf_jobs(self):
        """监控LSF任务"""
        while self.running:
            # 检查所有running状态的LSF任务
            for task_info in self.job_manager.running_list:
                if task_info.get('lsf_job_id'):
                    self.check_lsf_job(task_info)
            
            time.sleep(30)
    
    def check_lsf_job(self, task_info):
        """检查单个LSF任务"""
        job_id = task_info['lsf_job_id']
        status = self.lsf.check_job_status(job_id)
        
        # 更新状态
        if status == 'DONE':
            self.on_job_complete(task_info, 'pass')
        
        elif status == 'EXIT':
            self.on_job_complete(task_info, 'fail')
        
        elif status == 'RUN':
            # 任务正在运行
            self.update_progress(task_info)
        
        elif status == 'PEND':
            # 任务等待调度
            task_info['pend_time'] += 30
    
    def on_job_complete(self, task_info, result):
        """任务完成回调"""
        # 获取任务历史
        history = self.lsf.get_job_history(task_info['lsf_job_id'])
        
        # 更新任务信息
        task_info['status'] = result
        task_info['end_time'] = datetime.now()
        task_info['run_time'] = history.get('run', 0)
        task_info['pend_time'] = history.get('pend', 0)
        
        # 更新job_manager
        self.job_manager.update_status(task_info, result)
        
        # 触发CHECK
        if result == 'pass':
            self.job_manager.auto_trigger_check(task_info)
    
    def update_progress(self, task_info):
        """更新任务进度"""
        # 查看输出
        output = self.lsf.peek_job_output(task_info['lsf_job_id'])
        
        # 发送到GUI
        self.emit_log_signal(output)
```

---

## 6. LSF最佳实践

### 6.1 队列选择策略

```
队列选择建议:

┌─────────────────────────────────────────────────────────────────────┐
│                     Queue Selection Guide                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  任务类型           推荐队列     核心数   内存       时间           │
│  ─────────────────────────────────────────────────────────────────│
│  DC综合             ai_syn      4-8      8-16GB     30-60min       │
│  FM形式验证         ai_syn      2-4      4-8GB      10-30min       │
│  PT STA             sta_queue   2-4      4-8GB      10-20min       │
│  VCS仿真            dv_queue    4-8      4-8GB      10-60min       │
│  APR布局布线        apr_queue   8-16     32-64GB    60-120min      │
│  Calibre DRC        drc_queue   4-8      16-32GB    30-60min       │
│  Calibre LVS        lvs_queue   2-4      8-16GB     10-20min       │
│                                                                     │
│  队列优先级:                                                        │
│  - interactive: 最高（交互式任务）                                  │
│  - high_perf: 高（高性能任务）                                      │
│  - ai_syn: 中（综合验证）                                           │
│  - normal: 低（普通任务）                                           │
│                                                                     │
│  选择原则:                                                          │
│  1. 根据任务类型选择对应队列                                        │
│  2. 根据设计规模调整资源                                            │
│  3. 根据优先级选择队列                                              │
│  4. 考虑集群负载情况                                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 资源配置建议

```yaml
# LSF资源配置建议

VAR:
  # 小型设计（<10K gates）
  SMALL_DESIGN:
    BSUB_QUEUE: normal
    BSUB_CORES: 2
    BSUB_MEMORY: 4000    # 4GB
    BSUB_RUN_TIME: 30    # 30min
  
  # 中型设计（10K-100K gates）
  MEDIUM_DESIGN:
    BSUB_QUEUE: ai_syn
    BSUB_CORES: 4
    BSUB_MEMORY: 8000    # 8GB
    BSUB_RUN_TIME: 60    # 60min
  
  # 大型设计（100K-1M gates）
  LARGE_DESIGN:
    BSUB_QUEUE: ai_syn
    BSUB_CORES: 8
    BSUB_MEMORY: 16000   # 16GB
    BSUB_RUN_TIME: 120   # 120min
  
  # 超大型设计（>1M gates）
  HUGE_DESIGN:
    BSUB_QUEUE: high_perf
    BSUB_CORES: 16
    BSUB_MEMORY: 32000   # 32GB
    BSUB_RUN_TIME: 240   # 240min
  
  # 根据设计规模动态选择
  BSUB_CONFIG: |
    if ${DESIGN_SIZE} < 10000:
        BSUB_QUEUE: normal
        BSUB_CORES: 2
        BSUB_MEMORY: 4000
    elif ${DESIGN_SIZE} < 100000:
        BSUB_QUEUE: ai_syn
        BSUB_CORES: 4
        BSUB_MEMORY: 8000
    elif ${DESIGN_SIZE} < 1000000:
        BSUB_QUEUE: ai_syn
        BSUB_CORES: 8
        BSUB_MEMORY: 16000
    else:
        BSUB_QUEUE: high_perf
        BSUB_CORES: 16
        BSUB_MEMORY: 32000
```

---

*Chiplet Design Practice*
*文档生成: 2026-05-13*