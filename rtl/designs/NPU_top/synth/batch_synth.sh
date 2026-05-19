#!/bin/bash
# Batch synthesis script - parallel module synthesis
# Usage: ./batch_synth.sh

set -eo pipefail
source ~/wrk/eda_opensources/eda_env.sh

DESIGN_DIR="rtl/designs/NPU_top/synth"
TECH_LIB="/home/lxx/wrk/libs/asap7_reference_design/lib/asap7sc7p5t_AO_LVT_TT_nldm_211120.lib"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Module list (excluding sub-modules like M03_AsyncFIFO)
MODULES="M00_SystolicArray M01_DataflowController M02_SRAMScratchpad M03_DRAMController M04_SystemBus M05_PowerManager M06_ClockManager M07_ResetManager M08_ThreadScheduler M09_AttentionUnit M10_FFNMatMul M11_RMSNormRoPE M12_SoftMax M13_ISADecoder M14_SecureBoot M15_JTAGInterface M16_ISAInterface"

mkdir -p "$DESIGN_DIR/modules"

echo "=== Batch Synthesis Started at $TIMESTAMP ==="

# Synthesize each module in parallel (background jobs)
for mod in $MODULES; do
    echo "Starting synthesis of $mod..."
    (
        # Find module file
        mod_file=$(find rtl -name "${mod}.sv" -path "*/src/*" | head -1)
        if [[ -z "$mod_file" ]]; then
            echo "ERROR: Module file not found for $mod"
            exit 1
        fi
        
        # Create per-module synthesis script
        cat > "$DESIGN_DIR/modules/${mod}_${TIMESTAMP}.ys" << MODSCRIPT
read_verilog -sv $mod_file
hierarchy -check -top $mod
synth -top $mod
opt
opt_clean -purge
abc -liberty $TECH_LIB -g AND,OR,NAND,NOR,XOR
opt_clean -purge
write_verilog -noattr $DESIGN_DIR/modules/${mod}_${TIMESTAMP}.v
stat -liberty $TECH_LIB
MODSCRIPT
        
        # Run synthesis
        timeout 120 yosys -s "$DESIGN_DIR/modules/${mod}_${TIMESTAMP}.ys" \
            > "$DESIGN_DIR/modules/${mod}_${TIMESTAMP}.log" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "✓ $mod synthesized successfully"
        else
            echo "✗ $mod synthesis failed"
        fi
    ) &
done

# Wait for all background jobs
wait

echo "=== All module syntheses completed ==="

# Count successful/failed
SUCCESS=$(grep -l "successfully finished" $DESIGN_DIR/modules/*.log 2>/dev/null | wc -l)
FAILED=$(ls $DESIGN_DIR/modules/*.log 2>/dev/null | wc -l)
FAILED=$((FAILED - SUCCESS))

echo "Success: $SUCCESS, Failed: $FAILED"

# List failed modules
if [[ $FAILED -gt 0 ]]; then
    echo "Failed modules:"
    for log in $DESIGN_DIR/modules/*.log; do
        if ! grep -q "successfully finished" "$log"; then
            basename "$log" .log | cut -d_ -f1
        fi
    done
fi
