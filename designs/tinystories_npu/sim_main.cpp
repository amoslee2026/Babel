#include "verilated.h"
#include "verilated_vcd_c.h"
// Include generated header - defined via -DTOP_HEADER="Vtb_XXX.h"
#ifndef TOP_CLASS
#error "Define TOP_CLASS (e.g. -DTOP_CLASS=Vtb_M09_AttentionUnit) at compile time"
#endif
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define HEADER_STR TOSTRING(TOP_CLASS.h)
#include HEADER_STR

vluint64_t main_time = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    TOP_CLASS* top = new TOP_CLASS;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("sim_results/trace.vcd");

    top->clk_i_ext = 0;
    top->eval();

    while (!Verilated::gotFinish() && main_time < 10000000) {
        top->clk_i_ext = (main_time % 2) == 0 ? 1 : 0;
        top->eval();
        tfp->dump(main_time);
        main_time++;
    }

    tfp->close();
    VerilatedCov::write("coverage.dat");

    delete tfp;
    delete top;
    return 0;
}
