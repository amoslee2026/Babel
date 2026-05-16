# Design Notes

## Architecture Decisions

### ADR-001: 三星 SF4（4nm）工艺
理由：在 100 mm² 约束下实现目标算力

### ADR-002: 2 GB 3D Stacked DRAM
理由：TinyStories 15M 模型需求，10 GB/s 带宽

### ADR-003: 无主机接口
理由：独立运行边缘设备，减少面积功耗

## Open Issues

| ID | Description | Status |
|----|-------------|--------|
| OPEN-001 | DRAM 供应商选择 | 待确认 |
| OPEN-002 | 封装类型 | 待确认 |
| OPEN-003 | ISA 详细定义 | 进行中 |

## Next Steps

1. IP 模块详细设计
2. ISA 指令集定义
3. 启动 RTL 设计（ic-mas）
