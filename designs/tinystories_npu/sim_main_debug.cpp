#include "verilated.h"
#ifndef TOP_CLASS
#error "Define TOP_CLASS at compile time"
#endif
#define _STR(x) #x
#define STR(x) _STR(x)
#define TOP_HEADER STR(TOP_CLASS.h)
#include TOP_HEADER

vluint64_t main_time = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    TOP_CLASS* top = new TOP_CLASS;

    top->clk_i_ext = 0;
    top->eval();

    int last_fsm = -1;
    while (!Verilated::gotFinish() && main_time < 200) {
        top->clk_i_ext = (main_time % 2) == 0 ? 1 : 0;
        top->eval();

        if ((main_time % 2) == 0 && main_time > 0) {
            int fsm = top->dut__DOT__debug_state;
            int nxt = top->dut__DOT__next_state;

            if (fsm != 0 || last_fsm != 0 || fsm != last_fsm) {
                printf("[t=%lu] fsm=%d nxt=%d busy=%d start=%d qv=%d kv=%d vv=%d actv=%d qkv_rdy=%d\n",
                       main_time/2, fsm, nxt,
                       (int)top->dut__DOT__attn_busy_o,
                       (int)top->attn_start_i,
                       (int)top->q_valid_i, (int)top->k_valid_i,
                       (int)top->v_valid_i, (int)top->act_valid_i,
                       (int)top->dut__DOT__qkv_ready_o);
            }
            last_fsm = fsm;
        }

        main_time++;
    }

    printf("Sim ended at t=%lu\n", main_time/2);
    VerilatedCov::write("coverage.dat");
    delete top;
    return 0;
}
