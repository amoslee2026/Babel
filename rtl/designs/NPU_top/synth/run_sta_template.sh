#!/bin/bash
# OpenSTA Timing Analysis Template for NPU_top
# Requires: synthesized netlist + SDC constraints + Liberty timing library

source ~/wrk/eda_opensources/eda_env.sh

DESIGN="NPU_top"
NETLIST="rtl/designs/NPU_top/synth/netlist.v"
SDC="rtl/designs/NPU_top/constraints/NPU_top.sdc"
LIB="libs/asap7_reference_design/lib/asap7sc7p5t_AO_LVT_TT_nldm_211120.lib"
LOG="rtl/designs/NPU_top/sta/sta_report.log"

mkdir -p rtl/designs/NPU_top/sta

echo "Running OpenSTA for $DESIGN..."
opensta << STA_SCRIPT
read_liberty $LIB
read_verilog $NETLIST
link_design $DESIGN
read_sdc $SDC
report_checks -path_delay max -slack_less_than 0
report_checks -path_delay min
report_timing -max_paths 10
report_clocks
report_power
exit
STA_SCRIPT

echo "STA report saved to $LOG"
