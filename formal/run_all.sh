#!/bin/bash
# 运行所有 JasperGold FPV 验证
# Usage: bash run_all.sh

export JASPER_HOME=/eda_tools/cadence_z/jasper2025.12/jasper_2025.12
export PATH=$JASPER_HOME/bin:$PATH

FORMAL_DIR=/home/lxx/wrk/sjk2026/formal
JG=$JASPER_HOME/bin/jg

for tcl in pe_fpv tca_fpv su_fpv; do
    echo "=== Running $tcl ==="
    $JG -batch $FORMAL_DIR/${tcl}.tcl \
        -proj $FORMAL_DIR/${tcl}_proj \
        2>&1 | tee $FORMAL_DIR/${tcl}_run.log
done

echo "=== 所有验证完成，报告在 $FORMAL_DIR/ ==="
