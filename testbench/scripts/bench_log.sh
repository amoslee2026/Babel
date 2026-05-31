#!/bin/bash
# bench_log.sh - BabelBench 结构化日志记录器
# 用法:
#   bench_log.sh stage_start <stage_name> [extra_key=value ...]
#   bench_log.sh stage_end   <stage_name> [status=pass|fail] [extra_key=value ...]
#   bench_log.sh event       <event_type> [extra_key=value ...]
#
# 输出: 追加到当前目录或 BENCH_LOG_DIR 下的 bench_log.jsonl
# 每行一个 JSON 对象，包含 timestamp + event + 自定义字段

LOG_DIR="${BENCH_LOG_DIR:-.}"
LOG_FILE="${LOG_DIR}/bench_log.jsonl"

EVENT="${1:?用法: bench_log.sh <stage_start|stage_end|event> <name> [key=value ...]}"
NAME="${2:?缺少 name 参数}"
shift 2

TIMESTAMP=$(date -Iseconds)

# 构建 JSON
JSON="{\"ts\":\"${TIMESTAMP}\",\"event\":\"${EVENT}\",\"stage\":\"${NAME}\""

# 解析 key=value 参数
for arg in "$@"; do
  key="${arg%%=*}"
  val="${arg#*=}"
  # 判断是否为数字
  if [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    JSON="${JSON},\"${key}\":${val}"
  elif [[ "$val" == "true" || "$val" == "false" || "$val" == "null" ]]; then
    JSON="${JSON},\"${key}\":${val}"
  else
    # 转义双引号
    val="${val//\"/\\\"}"
    JSON="${JSON},\"${key}\":\"${val}\""
  fi
done

JSON="${JSON}}"

echo "$JSON" >> "$LOG_FILE"
echo "[bench_log] ${EVENT} ${NAME} $(date +%H:%M:%S)"
