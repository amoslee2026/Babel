# Verification Strategy

## Verification Hierarchy

| Level | Method | Coverage |
|-------|--------|----------|
| Unit | Simulation | 100% code |
| Integration | Simulation | 95% functional |
| System | FPGA | End-to-end |

## Key Scenarios

1. Systolic Array GEMM 正确性
2. Dataflow 多线程调度
3. DRAM 10 GB/s 带宽验证
4. 低功耗模式测试
5. TinyStories 端到端推理
