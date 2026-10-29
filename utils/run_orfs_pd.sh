#!/usr/bin/env bash
# run_orfs_pd.sh — Run the OpenROAD-flow-scripts ASAP7 flow (synth → floorplan →
# place → CTS → route → fill → GDS + LEC + timing report) inside a container.
#
# Why: OpenROAD has no prebuilt Linux binary and the litex-hub conda builds are
# uninstallable (libboost 1.73 dropped from conda-forge). The official
# `openroad/orfs` image ships a working OpenROAD + yosys + KLayout.
#
# Usage:
#   utils/run_orfs_pd.sh /tmp/babel-orfs/M13/config.mk
#
# Layout contract: the config.mk must live directly in the work directory and
# reference sources as /work/<...> paths (the work dir is bind-mounted at /work).
#   /tmp/babel-orfs/M13/
#     config.mk          # exports DESIGN_NAME / PLATFORM=asap7 / VERILOG_FILES ...
#     constraint.sdc
#     <rtl>.sv
#
# Outputs land in <work>/{results,logs,reports,objects}; 6_final.gds is the
# streamed-out layout.
set -euo pipefail

CONFIG="${1:?usage: run_orfs_pd.sh <config.mk> [work_dir]}"
WORK="${2:-$(dirname "$CONFIG")}"
IMAGE="${ORFS_IMAGE:-docker.io/openroad/orfs:latest}"
CONFIG_NAME="$(basename "$CONFIG")"

[[ -f "$CONFIG" ]] || { echo "config not found: $CONFIG" >&2; exit 2; }

podman run --rm -v "$WORK":/work:Z "$IMAGE" \
  make -C /OpenROAD-flow-scripts/flow \
    DESIGN_CONFIG="/work/$CONFIG_NAME" \
    RESULTS_DIR=/work/results \
    LOG_DIR=/work/logs \
    REPORTS_DIR=/work/reports \
    OBJECTS_DIR=/work/objects

echo "GDS:  $WORK/results/6_final.gds"
echo "WNS:  $(grep -A2 'report_wns' "$WORK"/reports/6_finish.rpt 2>/dev/null | tail -1 | tr -s ' ' || echo n/a)"
echo "AREA: $(grep -o 'Design area [0-9]* um^2' "$WORK"/logs/6_report.log 2>/dev/null | tail -1 || echo n/a)"
