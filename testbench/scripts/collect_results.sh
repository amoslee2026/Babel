#!/bin/bash
# collect_results.sh - 从 Babel workflow 运行产物中提取指标
# 用法: bash testbench/scripts/collect_results.sh <sandbox_dir>

SANDBOX="${1:?Usage: collect_results.sh <sandbox_dir>}"
RESULTS_DIR="${SANDBOX}/results"
mkdir -p "${RESULTS_DIR}"

echo "=== BabelBench: Collecting results from ${SANDBOX} ==="

# --- 辅助函数 ---
json_val() {
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))" "$1" "$2" 2>/dev/null || echo "null"
}

# --- Stage 1: Arch/Spec ---
echo "[Stage 1: Arch/Spec]"
ARCH_MODULES=0
ARCH_CLOCK_DOMAINS=0
ARCH_IO_COUNT=0
ARCH_MAS_FILES=0

if [ -d "${SANDBOX}/spec/MAS" ]; then
  ARCH_MODULES=$(find "${SANDBOX}/spec/MAS" -maxdepth 1 -type d -name "M*" | wc -l)
  ARCH_MAS_FILES=$(find "${SANDBOX}/spec/MAS" -name "MAS.md" | wc -l)
  echo "  Modules: ${ARCH_MODULES}, MAS files: ${ARCH_MAS_FILES}"
fi

if [ -f "${SANDBOX}/spec/ARCH/clock_reset_spec.md" ]; then
  ARCH_CLOCK_DOMAINS=$(grep -c "clk_" "${SANDBOX}/spec/ARCH/clock_reset_spec.md" 2>/dev/null); ARCH_CLOCK_DOMAINS=${ARCH_CLOCK_DOMAINS:-0}
  echo "  Clock domains: ${ARCH_CLOCK_DOMAINS}"
fi

if [ -f "${SANDBOX}/spec/ARCH/io_pinout.md" ]; then
  ARCH_IO_COUNT=$(grep -cE "^\|" "${SANDBOX}/spec/ARCH/io_pinout.md" 2>/dev/null || true); ARCH_IO_COUNT=${ARCH_IO_COUNT:-0}
  ARCH_IO_COUNT=$((ARCH_IO_COUNT > 2 ? ARCH_IO_COUNT - 2 : 0))
  echo "  IO signals: ${ARCH_IO_COUNT}"
fi

ARCH_COMPLETED=0
[ -d "${SANDBOX}/spec/MAS" ] && [ ${ARCH_MODULES} -gt 0 ] && ARCH_COMPLETED=1

# --- Stage 2: RTL ---
echo "[Stage 2: RTL]"
RTL_FILES=0
RTL_LINES=0
RTL_LINT_ERRORS=0
RTL_LINT_WARNINGS=0

if [ -f "${SANDBOX}/rtl_artifact.json" ]; then
  RTL_FILES=$(json_val "${SANDBOX}/rtl_artifact.json" "len(d.get('rtl_files',[]))")
  echo "  RTL files: ${RTL_FILES}"
fi

RTL_DIR=$(find "${SANDBOX}/rtl" -type d -name "src" 2>/dev/null | head -1)
if [ -n "${RTL_DIR}" ]; then
  RTL_LINES=$(find "${RTL_DIR}" -name "*.sv" -exec cat {} + 2>/dev/null | wc -l)
  echo "  Total lines: ${RTL_LINES}"
fi

# Run lint if RTL exists and verilator available
if [ ${RTL_FILES} -gt 0 ] && command -v verilator &>/dev/null; then
  LINT_OUTPUT=$(find "${SANDBOX}/rtl" -name "*.sv" -exec verilator --lint-only {} + 2>&1 || true)
  RTL_LINT_ERRORS=$(echo "${LINT_OUTPUT}" | grep -c "%Error" 2>/dev/null || true); RTL_LINT_ERRORS=${RTL_LINT_ERRORS:-0}
  RTL_LINT_WARNINGS=$(echo "${LINT_OUTPUT}" | grep -c "%Warning" 2>/dev/null || true); RTL_LINT_WARNINGS=${RTL_LINT_WARNINGS:-0}
  echo "  Lint errors: ${RTL_LINT_ERRORS}, warnings: ${RTL_LINT_WARNINGS}"
fi

RTL_COMPLETED=0
[ ${RTL_FILES} -gt 0 ] && RTL_COMPLETED=1

# --- Stage 3: Verification ---
echo "[Stage 3: Verification]"
VER_FUNC_COV=0
VER_LINE_COV=0
VER_BRANCH_COV=0
VER_TOGGLE_COV=0
VER_TEST_COUNT=0
VER_TEST_PASS=0
VER_TEST_FAIL=0
VER_ITERATIONS=0

TEST_REPORT=$(find "${SANDBOX}" -name "test_report_final.json" -o -name "test_report.json" 2>/dev/null | head -1)
if [ -n "${TEST_REPORT}" ]; then
  VER_FUNC_COV=$(json_val "${TEST_REPORT}" "d.get('functional_coverage',0)")
  VER_LINE_COV=$(json_val "${TEST_REPORT}" "d.get('code_coverage',{}).get('line',0)")
  VER_BRANCH_COV=$(json_val "${TEST_REPORT}" "d.get('code_coverage',{}).get('branch',0)")
  VER_TOGGLE_COV=$(json_val "${TEST_REPORT}" "d.get('code_coverage',{}).get('toggle',0)")
  VER_TEST_COUNT=$(json_val "${TEST_REPORT}" "len(d.get('tests',[]))")
  VER_TEST_PASS=$(json_val "${TEST_REPORT}" "sum(1 for t in d.get('tests',[]) if t.get('status')=='pass')")
  VER_TEST_FAIL=$(json_val "${TEST_REPORT}" "sum(1 for t in d.get('tests',[]) if t.get('status')=='fail')")
  VER_ITERATIONS=$(json_val "${TEST_REPORT}" "d.get('iteration_count',1)")
  echo "  Functional coverage: ${VER_FUNC_COV}%"
  echo "  Line/branch/toggle: ${VER_LINE_COV}%/${VER_BRANCH_COV}%/${VER_TOGGLE_COV}%"
  echo "  Tests: ${VER_TEST_PASS}/${VER_TEST_COUNT} passed"
fi

VER_COMPLETED=0
[ -n "${TEST_REPORT}" ] && VER_COMPLETED=1

# --- Stage 4: Synthesis ---
echo "[Stage 4: Synthesis]"
SYNTH_TOTAL=0
SYNTH_PASSED=0
SYNTH_FAILED=0
SYNTH_AREA=0
SYNTH_FREQ=0

SYNTH_REPORT=$(find "${SANDBOX}" -name "synth_report.json" 2>/dev/null | head -1)
if [ -n "${SYNTH_REPORT}" ]; then
  SYNTH_TOTAL=$(json_val "${SYNTH_REPORT}" "d.get('modules_total',0)")
  SYNTH_PASSED=$(json_val "${SYNTH_REPORT}" "d.get('modules_passed',0)")
  SYNTH_FAILED=$(json_val "${SYNTH_REPORT}" "d.get('modules_failed',0)")
  SYNTH_FREQ=$(json_val "${SYNTH_REPORT}" "d.get('target_frequency_mhz',0)")
  SYNTH_AREA=$(json_val "${SYNTH_REPORT}" "sum(m.get('area_estimate_um2',0) for m in d.get('modules',{}).values() if isinstance(m,dict))")
  echo "  Modules: ${SYNTH_PASSED}/${SYNTH_TOTAL} passed"
  echo "  Area: ${SYNTH_AREA} um2"
fi

SYNTH_COMPLETED=0
[ -n "${SYNTH_REPORT}" ] && SYNTH_COMPLETED=1

# --- Stage 5: PD ---
echo "[Stage 5: PD]"
PD_FLOORPLAN=0
PD_PLACEMENT=0
PD_ROUTING=0
PD_DRC_VIOLATIONS=-1
PD_LVS_MATCH=0
PD_WNS=0
PD_GDS=0
PD_GDS_SIZE=0
PD_DIE_AREA=0

PD_REPORT=$(find "${SANDBOX}" -name "pd_report_final.json" -o -name "pd_report.json" 2>/dev/null | head -1)
if [ -n "${PD_REPORT}" ]; then
  PD_FLOORPLAN=$(json_val "${PD_REPORT}" "1 if d.get('floorplan_status',{}).get('success') else 0")
  PD_PLACEMENT=$(json_val "${PD_REPORT}" "1 if d.get('placement_status',{}).get('success') else 0")
  PD_ROUTING=$(json_val "${PD_REPORT}" "1 if d.get('routing_status',{}).get('success') else 0")
  PD_DRC_VIOLATIONS=$(json_val "${PD_REPORT}" "d.get('drc_status',{}).get('violations', -1)")
  PD_LVS_MATCH=$(json_val "${PD_REPORT}" "1 if d.get('lvs_status',{}).get('match') else 0")
  PD_WNS=$(json_val "${PD_REPORT}" "d.get('timing_status',{}).get('wns_ns', 0)")
  PD_GDS=$(json_val "${PD_REPORT}" "1 if d.get('gds_status',{}).get('success') else 0")
  PD_GDS_SIZE=$(json_val "${PD_REPORT}" "d.get('gds_status',{}).get('gds_size_bytes', 0)")
  DIE_W=$(json_val "${PD_REPORT}" "d.get('floorplan_status',{}).get('die_width_um', 0)")
  DIE_H=$(json_val "${PD_REPORT}" "d.get('floorplan_status',{}).get('die_height_um', 0)")
  PD_DIE_AREA=$(python3 -c "print(${DIE_W} * ${DIE_H})" 2>/dev/null || echo 0)
  echo "  Floorplan: ${PD_FLOORPLAN}, Placement: ${PD_PLACEMENT}, Routing: ${PD_ROUTING}"
  echo "  DRC violations: ${PD_DRC_VIOLATIONS}, LVS match: ${PD_LVS_MATCH}"
  echo "  WNS: ${PD_WNS} ns, GDS: ${PD_GDS} (${PD_GDS_SIZE} bytes)"
fi

PD_COMPLETED=0
[ -n "${PD_REPORT}" ] && PD_COMPLETED=1

# --- 汇总 stages completed ---
STAGES_COMPLETED=$((ARCH_COMPLETED + RTL_COMPLETED + VER_COMPLETED + SYNTH_COMPLETED + PD_COMPLETED))

# --- 写入 metrics.json ---
cat > "${RESULTS_DIR}/metrics.json" << METRICS_EOF
{
  "collected": "$(date -Iseconds)",
  "sandbox": "${SANDBOX}",
  "stage_metrics": {
    "arch": {
      "completed": ${ARCH_COMPLETED},
      "module_count": ${ARCH_MODULES},
      "mas_files_count": ${ARCH_MAS_FILES},
      "clock_domain_count": ${ARCH_CLOCK_DOMAINS},
      "io_count": ${ARCH_IO_COUNT}
    },
    "rtl": {
      "completed": ${RTL_COMPLETED},
      "file_count": ${RTL_FILES},
      "total_lines": ${RTL_LINES},
      "lint_errors": ${RTL_LINT_ERRORS},
      "lint_warnings": ${RTL_LINT_WARNINGS}
    },
    "verification": {
      "completed": ${VER_COMPLETED},
      "functional_coverage": ${VER_FUNC_COV},
      "line_coverage": ${VER_LINE_COV},
      "branch_coverage": ${VER_BRANCH_COV},
      "toggle_coverage": ${VER_TOGGLE_COV},
      "test_count": ${VER_TEST_COUNT},
      "test_pass_count": ${VER_TEST_PASS},
      "test_fail_count": ${VER_TEST_FAIL},
      "iteration_count": ${VER_ITERATIONS}
    },
    "synthesis": {
      "completed": ${SYNTH_COMPLETED},
      "modules_total": ${SYNTH_TOTAL},
      "modules_passed": ${SYNTH_PASSED},
      "modules_failed": ${SYNTH_FAILED},
      "total_area_um2": ${SYNTH_AREA},
      "target_freq_mhz": ${SYNTH_FREQ}
    },
    "pd": {
      "completed": ${PD_COMPLETED},
      "floorplan_success": ${PD_FLOORPLAN},
      "placement_success": ${PD_PLACEMENT},
      "routing_success": ${PD_ROUTING},
      "drc_violations": ${PD_DRC_VIOLATIONS},
      "lvs_match": ${PD_LVS_MATCH},
      "wns_ns": ${PD_WNS},
      "gds_success": ${PD_GDS},
      "gds_size_bytes": ${PD_GDS_SIZE},
      "die_area_um2": ${PD_DIE_AREA}
    }
  },
  "efficiency_metrics": {
    "stages_completed": ${STAGES_COMPLETED},
    "stages_total": 5
  }
}
METRICS_EOF

echo ""
echo "=== Results collected ==="
echo "Stages completed: ${STAGES_COMPLETED}/5"
echo "Metrics saved to: ${RESULTS_DIR}/metrics.json"
echo ""
echo "Next step: python3 testbench/scripts/score.py ${SANDBOX}"
