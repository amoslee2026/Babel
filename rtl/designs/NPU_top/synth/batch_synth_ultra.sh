#!/bin/bash
# Ultra-long timeout synthesis for complex modules

source ~/wrk/eda_opensources/eda_env.sh
DESIGN_DIR="rtl/designs/NPU_top/synth"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# All modules with ultra-long timeout
MODULES="M00_SystolicArray M01_DataflowController M02_SRAMScratchpad M03_DRAMController M04_SystemBus M05_PowerManager M06_ClockManager M07_ResetManager M08_ThreadScheduler M09_AttentionUnit M10_FFNMatMul M11_RMSNormRoPE M12_SoftMax M13_ISADecoder M14_SecureBoot M15_JTAGInterface M16_ISAInterface"

mkdir -p "$DESIGN_DIR/modules_ultra"

echo "=== Ultra-Long Timeout Synthesis (1800s = 30min each) ==="
echo "Started at: $(date)"

for mod in $MODULES; do
    echo "Processing $mod..."
    (
        mod_file=$(find rtl -name "${mod}.sv" -path "*/src/*" | head -1)
        if [[ -z "$mod_file" ]]; then
            echo "ERROR: $mod file not found"
            exit 1
        fi
        
        cat > "$DESIGN_DIR/modules_ultra/${mod}_${TIMESTAMP}.ys" << MODSCRIPT
read_verilog -sv $mod_file
hierarchy -check -top $mod
synth -top $mod -flatten
opt_clean -purge
stat
MODSCRIPT
        
        # 1800s = 30 minutes timeout
        timeout 1800 yosys -s "$DESIGN_DIR/modules_ultra/${mod}_${TIMESTAMP}.ys" \
            > "$DESIGN_DIR/modules_ultra/${mod}_${TIMESTAMP}.log" 2>&1
        
        if grep -q "Found and reported 0 problems" "$DESIGN_DIR/modules_ultra/${mod}_${TIMESTAMP}.log"; then
            echo "✓ $mod completed successfully"
        elif grep -q "Printing statistics" "$DESIGN_DIR/modules_ultra/${mod}_${TIMESTAMP}.log"; then
            echo "✓ $mod completed (stats printed)"
        else
            lines=$(wc -l < "$DESIGN_DIR/modules_ultra/${mod}_${TIMESTAMP}.log")
            echo "⏳ $mod: $lines lines processed"
        fi
    ) &
done

# 等待所有任务完成（最多1800s）
wait

echo ""
echo "=== All synthesis completed at: $(date) ==="

# 生成结果报告
echo ""
echo "=== Results Summary ==="
success=0
failed=0
for log in $DESIGN_DIR/modules_ultra/*.log; do
    mod=$(basename "$log" .log | cut -d_ -f1)
    if grep -q "Found and reported 0 problems" "$log" || grep -q "Printing statistics" "$log"; then
        success=$((success + 1))
        echo "✓ $mod"
    else
        failed=$((failed + 1))
        echo "✗ $mod"
    fi
done

echo ""
echo "Success: $success / 17"
