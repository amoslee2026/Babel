#!/usr/bin/env bash
# run_yosys_asap7_map.sh — Map one RTL module to ASAP7 standard cells with Yosys.
#
# Why this exists: the stock ABC script (`&nf`, supergate flow) SIGSEGVs
# (status 8B) on ASAP7 NLDM liberty. The verified path is
#   synth -noabc -> dfflibmap(seq) -> abc -liberty <comb> -script "+strash;map"
# with combinational and sequential cells living in different liberty files.
#
# Usage:
#   utils/run_yosys_asap7_map.sh --top M13_ISADecoder --rtl path/to/M13.sv \
#       --comb-lib <SIMPLE_*.lib> --seq-lib <SEQ_*.lib> --out-dir /tmp/map
#
#   # or from a file list (one source per line):
#   utils/run_yosys_asap7_map.sh --top NPU_top --file-list file_list.f \
#       --lib-root libs/asap7/asap7sc7p5t_28 --out-dir /tmp/map
set -euo pipefail

TOP=""
RTL=""
FILE_LIST=""
LIB_ROOT="${ASAP7_LIB_ROOT:-libs/asap7/asap7sc7p5t_28}"
CORNER="${ASAP7_CORNER:-SS}"
VT="${ASAP7_VT:-RVT}"
COMB_LIB=""
SEQ_LIB=""
OUT_DIR=""
YOSYS_BIN="${YOSYS_BIN:-yosys}"
ABC_SCRIPT="${ABC_SCRIPT:-+strash;map}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --top) TOP="$2"; shift 2 ;;
    --rtl) RTL="$2"; shift 2 ;;
    --file-list) FILE_LIST="$2"; shift 2 ;;
    --lib-root) LIB_ROOT="$2"; shift 2 ;;
    --corner) CORNER="$2"; shift 2 ;;
    --vt) VT="$2"; shift 2 ;;
    --comb-lib) COMB_LIB="$2"; shift 2 ;;
    --seq-lib) SEQ_LIB="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --yosys) YOSYS_BIN="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TOP" ]] || { echo "--top is required" >&2; exit 2; }
if [[ -z "$RTL" && -z "$FILE_LIST" ]]; then
  echo "either --rtl or --file-list is required" >&2; exit 2
fi

resolve_lib() {  # <family>
  local family="$1" hits
  hits=$(compgen -G "$LIB_ROOT/LIB/NLDM/asap7sc7p5t_${family}_${VT}_${CORNER}_nldm_*.lib" || true)
  [[ -n "$hits" ]] || hits=$(compgen -G "$LIB_ROOT/**/asap7sc7p5t_${family}_${VT}_${CORNER}_nldm_*.lib" || true)
  [[ -n "$hits" ]] || { echo "no ${family}/${VT}/${CORNER} liberty under $LIB_ROOT" >&2; return 1; }
  printf '%s\n' $hits | sort | head -1
}

[[ -n "$COMB_LIB" ]] || COMB_LIB=$(resolve_lib SIMPLE)
[[ -n "$SEQ_LIB" ]] || SEQ_LIB=$(resolve_lib SEQ)
for f in "$COMB_LIB" "$SEQ_LIB"; do
  [[ -f "$f" ]] || { echo "liberty not found: $f" >&2; exit 2; }
done

OUT_DIR="${OUT_DIR:-/tmp/babel-synth/${TOP}}"
mkdir -p "$OUT_DIR"
YS="$OUT_DIR/${TOP}.ys"
LOG="$OUT_DIR/${TOP}.log"
NETLIST="$OUT_DIR/${TOP}_mapped.v"

{
  echo "read_verilog -sv"
  if [[ -n "$FILE_LIST" ]]; then
    while IFS= read -r line; do
      line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
      [[ -n "$line" ]] && echo "read_verilog -sv $line"
    done < "$FILE_LIST"
  else
    echo "read_verilog -sv $RTL"
  fi
  echo "hierarchy -check -top $TOP"
  echo "synth -top $TOP -noabc"
  echo "dfflibmap -liberty $SEQ_LIB"
  echo "abc -liberty $COMB_LIB -script $ABC_SCRIPT"
  echo "opt_clean -purge"
  echo "write_verilog -noattr $NETLIST"
  echo "stat -liberty $COMB_LIB"
  echo "stat -liberty $SEQ_LIB"
} > "$YS"

if ! "$YOSYS_BIN" -s "$YS" > "$LOG" 2>&1; then
  echo "FAIL: yosys exited non-zero; see $LOG" >&2
  tail -20 "$LOG" >&2 || true
  exit 1
fi

if grep -qE '^[[:space:]]+[0-9]+[[:space:]]+[_]' "$LOG"; then
  echo "FAIL: generic \$_ cells remain unmapped; see $LOG" >&2
  exit 1
fi

echo "OK: $TOP mapped"
grep -E 'Chip area for module|of which used for sequential' "$LOG" || true
grep -E '^[[:space:]]+[0-9]+[[:space:]]+[0-9.]+[[:space:]]+[A-Za-z0-9_]+_ASAP7' "$LOG" || true
echo "script:  $YS"
echo "log:     $LOG"
echo "netlist: $NETLIST"
