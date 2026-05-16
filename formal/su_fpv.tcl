# JasperGold FPV: yan_su (Scalar Unit)
# Usage: jg -batch su_fpv.tcl

set RTL_ROOT /home/lxx/wrk/sim/src

analyze -sv12 \
    $RTL_ROOT/interfaces/yan_interfaces_pkg.sv \
    $RTL_ROOT/cluster/su/yan_su.sv

elaborate -top yan_su \
    -parameter P_SR_DEPTH 16 \
    -parameter P_TDR_DEPTH 8 \
    -parameter P_LOOP_DEPTH 4 \
    -parameter P_INST_QUEUE_DEPTH 4

clock i_clk
reset -expression {!i_rst_n}

# P1: 复位后 PC 为初始值
assert -name p_reset_pc \
    {i_rst_n == 0 |=> (o_pc == $past(i_pc_init))}

# P2: halt 时 busy 不拉高
assert -name p_halt_not_busy \
    {i_halt |=> !o_busy}

# P3: done 和 error 互斥
assert -name p_done_error_mutex \
    {!(o_done && o_error)}

# P4: inst_ready 在 error 时不拉高
assert -name p_no_ready_on_error \
    {o_error |-> !o_inst_ready}

cover -name cov_tca_dispatch  {o_tca_dispatch_valid}
cover -name cov_ve_dispatch   {o_ve_dispatch_valid}
cover -name cov_branch_taken  {i_op_type == 8'h30 && i_inst_valid}
cover -name cov_loop          {i_op_type == 8'h40 && i_inst_valid}

set_engine_mode {Ht Tri}
prove -all

report -results -file /home/lxx/wrk/sjk2026/formal/su_fpv_results.txt
report -summary -file /home/lxx/wrk/sjk2026/formal/su_fpv_summary.txt
