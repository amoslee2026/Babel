# JasperGold FPV: yan_pe
# Usage: jg -batch pe_fpv.tcl

set RTL_ROOT /home/lxx/wrk/sim/src

# ── 1. 读取设计 ──────────────────────────────────────────────────────────────
analyze -sv12 \
    $RTL_ROOT/interfaces/yan_interfaces_pkg.sv \
    $RTL_ROOT/cluster/tca/yan_pe.sv

elaborate -top yan_pe \
    -parameter P_ROW_IDX 0 \
    -parameter P_COL_IDX 0 \
    -parameter P_ACC_WIDTH 32 \
    -parameter P_DATA_WIDTH 8

# ── 2. 时钟/复位 ─────────────────────────────────────────────────────────────
clock i_clk
reset -expression {!i_rst_n}

# ── 3. 属性（SVA）────────────────────────────────────────────────────────────

# P1: 复位后累加器为 0
assert -name p_reset_clears_acc \
    {i_rst_n == 0 |=> (o_psum == 0 && o_acc == 0)}

# P2: 不使能时输出保持稳定
assert -name p_no_acc_en_stable \
    {!i_acc_en |=> $stable(o_acc)}

# P3: 稀疏门控信号正确
assert -name p_clk_gate_logic \
    {(i_sparse_en && i_zero_weight) == o_clk_gate}

# P4: INT8 模式 — 输出不超过 32 位有符号范围
assert -name p_int8_no_overflow \
    {(i_precision == 2'b00 && i_acc_en) |=> \
     ($signed(o_acc) >= -2147483648 && $signed(o_acc) <= 2147483647)}

# P5: 激活数据水平传播（systolic 流）
assert -name p_act_propagation \
    {(i_acc_en) |=> (o_act == $past(i_act))}

# ── 4. 覆盖点 ────────────────────────────────────────────────────────────────
cover -name cov_int8_acc    {i_precision == 2'b00 && i_acc_en}
cover -name cov_int4_acc    {i_precision == 2'b01 && i_acc_en}
cover -name cov_fp8_acc     {i_precision == 2'b10 && i_acc_en}
cover -name cov_sparse_skip {i_sparse_en && i_zero_weight}
cover -name cov_systolic    {i_dataflow_mode == 2'b00 && i_acc_en}
cover -name cov_spatial     {i_dataflow_mode == 2'b01 && i_acc_en}

# ── 5. 证明 ──────────────────────────────────────────────────────────────────
set_engine_mode {Ht Tri}
prove -all

# ── 6. 报告 ──────────────────────────────────────────────────────────────────
report -results -file /home/lxx/wrk/sjk2026/formal/pe_fpv_results.txt
report -summary -file /home/lxx/wrk/sjk2026/formal/pe_fpv_summary.txt
