#!/bin/bash
# Extended timeout synthesis for complex modules

source ~/wrk/eda_opensources/eda_env.sh
DESIGN_DIR="rtl/designs/NPU_top/synth"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Complex modules needing longer timeout
MODULES="M00_SystolicArray M05_PowerManager M08_ThreadScheduler M10_FFNMatMul M11_RMSNormRoPE M12_SoftMax"

mkdir -p "$DESIGN_DIR/modules_extended"

echo "=== Extended Timeout Synthesis (300s each) ==="

for mod in $MODULES; do
    echo "Processing $mod..."
    (
        mod_file=$(find rtl -name "${mod}.sv" -path "*/src/*" | head -1)
        if [[ -z "$mod_file" ]]; then
            echo "ERROR: $mod file not found"
            exit 1
        fi
        
        cat > "$DESIGN_DIR/modules_extended/${mod}_${TIMESTAMP}.ys" << MODSCRIPT
read_verilog -sv $mod_file
hierarchy -check -top $mod
synth -top $mod -flatten
opt_clean -purge
stat
MODSCRIPT
        
        timeout 300 yosys -s "$DESIGN_DIR/modules_extended/${mod}_${TIMESTAMP}.ys" \
            > "$DESIGN_DIR/modules_extended/${mod}_${TIMESTAMP}.log" 2>&1
        
        if grep -q "Found and reported 0 problems" "$DESIGN_DIR/modules_extended/${mod}_${TIMESTAMP}.log"; then
            echo "✓ $mod completed"
        else
            lines=$(wc -l < "$DESIGN_DIR/modules_extended/${mod}_${TIMESTAMP}.log")
            echo "⏳ $mod: $lines lines (check log for status)"
        fi
    ) &
done

wait
echo "=== All extended synthesis attempts completed ==="
