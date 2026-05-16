# JasperGold FPV: yan_tca (Tensor Core Array)
# Usage: jg -batch tca_fpv.tcl

set RTL_ROOT /home/lxx/wrk/sim/src

analyze -sv12 \
    $RTL_ROOT/interfaces/yan_interfaces_pkg.sv \
    $RTL_ROOT/cluster/tca/yan_pe.sv \
    $RTL_ROOT/cluster/tca/yan_tca.sv

elaborate -top yan_tca \
    -parameter P_DIM 16 \
    -parameter P_ACC_WIDTH 32 \
    -parameter P_DATA_WIDTH 8 \
    -parameter P_NUM_ACC_GROUPS 8

clock i_clk
reset -expression {!i_rst_n}

# P1: 复位后 busy/done/error 均为 0
assert -name p_reset_status \
    {i_rst_n == 0 |=> (!o_busy && !o_done && !o_error)}

# P2: done 和 error 互斥
assert -name p_done_error_mutex \
    {!(o_done && o_error)}

# P3: 未使能时不接受指令
assert -name p_no_inst_when_disabled \
    {!i_enable |-> !o_inst_ready}

# P4: busy 时 inst_ready 不拉高（背压）
assert -name p_busy_blocks_inst \
    {o_busy |-> !o_inst_ready}

# P5: SRAM 请求地址在使能前不变化
assert -name p_sram_stable_when_idle \
    {!i_enable |=> $stable(o_sram_addr[0])}

cover -name cov_gemm_inst   {i_inst_type == 3'b001 && i_inst_valid && o_inst_ready}
cover -name cov_drain_inst  {i_inst_type == 3'b101 && i_inst_valid && o_inst_ready}
cover -name cov_sparse_mode {i_sparse_en && i_enable}
cover -name cov_done        {o_done}

set_engine_mode {Ht Tri}
prove -all

report -results -file /home/lxx/wrk/sjk2026/formal/tca_fpv_results.txt
report -summary -file /home/lxx/wrk/sjk2026/formal/tca_fpv_summary.txt
