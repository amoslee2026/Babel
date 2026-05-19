#!/bin/bash
# Simplified batch synthesis - no ABC library mapping
# Uses generic gates (techmap) instead

set -eo pipefail
source ~/wrk/eda_opensources/eda_env.sh

DESIGN_DIR="rtl/designs/NPU_top/synth"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

MODULES="M00_SystolicArray M01_DataflowController M02_SRAMScratchpad M03_DRAMController M04_SystemBus M05_PowerManager M06_ClockManager M07_ResetManager M08_ThreadScheduler M09_AttentionUnit M10_FFNMatMul M11_RMSNormRoPE M12_SoftMax M13_ISADecoder M14_SecureBoot M15_JTAGInterface M16_ISAInterface"

mkdir -p "$DESIGN_DIR/modules_simple"

echo "=== Simplified Batch Synthesis Started at $TIMESTAMP ==="

for mod in $MODULES; do
    echo "Synthesizing $mod..."
    (
        mod_file=$(find rtl -name "${mod}.sv" -path "*/src/*" | head -1)
        if [[ -z "$mod_file" ]]; then
            echo "ERROR: $mod file not found"
            exit 1
        fi
        
        # Simplified script - techmap only, no ABC
        cat > "$DESIGN_DIR/modules_simple/${mod}_${TIMESTAMP}.ys" << MODSCRIPT
read_verilog -sv $mod_file
hierarchy -check -top $mod
synth -top $mod -flatten
opt_clean -purge
write_verilog -noattr $DESIGN_DIR/modules_simple/${mod}_${TIMESTAMP}.v
stat
MODSCRIPT
        
        timeout 60 yosys -s "$DESIGN_DIR/modules_simple/${mod}_${TIMESTAMP}.ys" \
            > "$DESIGN_DIR/modules_simple/${mod}_${TIMESTAMP}.log" 2>&1
        
        if grep -q "Found and reported 0 problems" "$DESIGN_DIR/modules_simple/${mod}_${TIMESTAMP}.log"; then
            echo "✓ $mod OK"
        else
            echo "✗ $mod FAILED"
        fi
    ) &
done

wait

echo "=== Done ==="
echo "Results in: $DESIGN_DIR/modules_simple/"
