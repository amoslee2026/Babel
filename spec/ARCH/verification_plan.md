# Verification Strategy

## Verification Hierarchy

| Level | Method | Coverage Target | Duration | REQ |
|-------|--------|-----------------|----------|-----|
| Unit | RTL Simulation | 100% code, 95% functional | Per module | - |
| Integration | RTL Simulation | 95% functional | Days | - |
| System | FPGA Emulation | End-to-end scenarios | Weeks | - |
| Silicon | Post-silicon validation | All use cases | Months | REQ-COMPUTE-001~008 |

## Coverage Requirements

| Coverage Type | Target | Tool |
|---------------|--------|------|
| Code Coverage (Line) | 100% | Verilator + coverage |
| Code Coverage (Branch) | 100% | Verilator + coverage |
| Code Coverage (Toggle) | 100% | Verilator + coverage |
| Functional Coverage | 95% | Custom assertions |
| Assertion Coverage | 100% | SVA |

## Key Verification Scenarios

### Compute Verification

| Scenario | Description | REQ |
|----------|-------------|-----|
| GEMM Correctness | Systolic Array 矩阵乘法精度验证 | REQ-COMPUTE-001~003 |
| WS/OS Mode Switch | Weight/Output Stationary 模式切换 | REQ-COMPUTE-004 |
| Pipeline Utilization | Spatial Dataflow 利用率 >= 80% | REQ-COMPUTE-005 |
| Multi-thread Execution | 线程数 >= 2 并发调度 | REQ-COMPUTE-006 |
| Mixed Precision | FP32/FP16/INT8/FP8 混合精度运算 | REQ-COMPUTE-007 |

### Operator Verification

| Operator | Test Cases | REQ |
|----------|------------|-----|
| Attention (M09) | Multi-head, causal, KV cache | REQ-COMPUTE-008 |
| FFN/MatMul (M10) | 矩阵乘法，激活函数 | REQ-COMPUTE-008 |
| RMSNorm (M11) | 归一化精度 | REQ-COMPUTE-008 |
| RoPE (M11) | 位置编码正确性 | REQ-COMPUTE-008 |
| SoftMax (M12) | 数值稳定性 | REQ-SW-003 |

### Memory Verification

| Scenario | Description | REQ |
|----------|-------------|-----|
| DRAM Bandwidth | >= 10 GB/s 带宽测试 | REQ-MEM-002 |
| DRAM Latency | <= 100 ns (row hit) | REQ-MEM-003 |
| ECC SECDED | 单错纠正，双错检测 | REQ-MEM-005 |
| Memory Map | 地址映射无冲突 | - |

### Power Verification

| Scenario | Description | REQ |
|----------|-------------|-----|
| DVFS Switching | 频率/电压切换时间 < 100 us | REQ-PWR-003 |
| Power Modes | Active/Sleep/Deep Sleep 状态转换 | REQ-PWR-002 |
| Power Budget | TDP <= 2 W @ 85°C | REQ-PWR-001 |
| Temperature Range | 0-85°C 工作验证 | REQ-THERM-001 |

### Security Verification

| Scenario | Description | REQ |
|----------|-------------|-----|
| Secure Boot | 签名固件验证流程 | REQ-SEC-001 |
| Key Management | 密钥存储与访问控制 | REQ-SEC-001 |

## Precision Verification

| Precision | Test Method | Accuracy Target | REQ |
|-----------|-------------|-----------------|-----|
| FP32 | Golden reference | Baseline | REQ-COMPUTE-007 |
| FP16 | vs FP32 | <= 0.5% loss | UC-03 |
| INT8 | vs FP32 | <= 0.5% loss | UC-03 |
| FP8 | vs FP32 | <= 0.5% loss | UC-03 |

## End-to-End Verification

| Test | Description | KPI |
|------|-------------|-----|
| TinyStories 15M FP32 | 端到端推理（decode） | TPS >= 100 REQ-PERF-002 |
| TinyStories 15M FP16 | 端到端推理（decode） | TPS >= 200 REQ-PERF-003 |
| TinyStories 15M Prefill | Prompt <= 256 tokens | TTFT <= 50 ms REQ-PERF-004 |
| Accuracy Validation | UC-03 精度损失测试 | <= 0.5% vs FP32 |

## Reliability Testing

| Test | Condition | Target | REQ |
|------|-----------|--------|-----|
| MTTF | 85°C continuous | >= 100k hours | REQ-REL-001 |
| SER | With ECC | <= 1000 FIT | REQ-REL-002 |
| ESD HBM | All IO pins | >= 2 kV | REQ-REL-003 |
| ESD CDM | All pins | >= 500 V | REQ-REL-003 |

## Testbench Architecture

| Component | Description |
|-----------|-------------|
| TB_TOP | Top-level testbench |
| TB_DRIVER | Input stimulus generator |
| TB_MONITOR | Output response checker |
| TB_GOLDEN | Golden model reference |
| TB_SCOREBOARD | Result comparison |

## Simulation Tools

| Tool | Purpose |
|------|---------|
| Verilator | RTL simulation + coverage |
| OpenSTA | Static timing analysis |
| Yosys | RTL synthesis check |

## Regression Strategy

| Level | Frequency | Duration |
|-------|-----------|----------|
| Unit | Every commit | Minutes |
| Integration | Daily | Hours |
| System | Weekly | Days |
| Full regression | Before release | Days |
