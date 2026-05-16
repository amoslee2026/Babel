---
doc_id: DOC-D2-04-SWARCH
doc_type: SWARCH
title: Software Architecture Specification
version: 0.1-template
status: template
tier: 1
domain: Architecture
owner: SW Architect
approvers: [CTO, SW Lead, Chief Architect]
parent: DOC-D1-01-PRD
children: [DOC-D2-01-ARCH, DOC-D8-01-BRINGUP, DOC-D6-02-MDBOOT]
references: [Linux kernel ABI, UEFI 2.x, TBBR, ACPI, Device Tree]
generated: 2026-04-23T22:45:00+08:00
---

# Software Architecture Specification — {{ Product Name }}

## 0. Document Control
| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | {{ SW Arch }} | Initial |

---

## 1. Purpose

定义 hardware-software 分割、boot flow、runtime stack、driver model、ISA/programming model 的详细契约，确保 hardware bring-up 与生态系统就绪。

## 2. Software Stack Overview

```
┌────────────────────────────────────────────┐
│  Application (PyTorch / CUDA replacement)  │
├────────────────────────────────────────────┤
│  Framework adapters                        │
├────────────────────────────────────────────┤
│  Runtime / Library (BLAS, cuBLAS-like)     │
├────────────────────────────────────────────┤
│  Driver (Linux kernel / user mode)         │
├────────────────────────────────────────────┤
│  Firmware (BL1/BL2/TF-A, device mgmt)      │
├────────────────────────────────────────────┤
│  Hardware (chiplet SoC)                    │
└────────────────────────────────────────────┘
```

## 3. ISA / Programming Model

- **Host ISA**: {{ ARMv9 / x86-64 / RISC-V RV64GCV }}
- **Accelerator ISA extensions**: {{ Custom tensor ops }}
- **Memory model**: {{ Release consistency / SC }}
- **Exception model**: {{ ... }}

## 4. HW/SW Partition

| Function | HW | Firmware | Kernel Driver | User Library | App |
|---|---|---|---|---|---|
| Matrix multiply | HW engine | — | Queue mgmt | API | ✓ |
| Memory allocation | Page table HW | — | Driver | ✓ | — |
| Power management | HW DVFS | PMU firmware | govenor | — | — |
| Error handling | ECC HW | Log + retry | Interrupt handler | — | — |

## 5. Boot Flow

### 5.1 Boot Stages

```
Power-on → BL1 (ROM) → BL2 (SPI-NOR) → BL31 (TF-A) → UEFI → OS loader → OS kernel
           │            │                │             │      │            │
           │            │                │             │      │            ▼
           │            │                │             │      └──► kernel boot
           │            │                │             └──► Boot Mgr
           │            │                └──► Secure Monitor + PSCI
           │            └──► Platform init, DRAM training, chiplet enum
           └──► Root of Trust, signature check
```

### 5.2 Chiplet-Specific Boot
→ 详细 sequence 在 DOC-D6-02-MDBOOT

## 6. Device Model

### 6.1 Chiplet Enumeration
- How does OS see the chiplets? {{ Single device with NUMA-like nodes / multiple devices }}
- ACPI tables: {{ SRAT, SLIT, PPTT for topology }}
- Device Tree (if embedded): compatible strings + die topology

### 6.2 Interrupt Model
- {{ GICv4 / APIC / custom }}
- MSI / MSI-X assignment across dies

### 6.3 DMA & IOMMU
- {{ SMMU / IOMMU }} placement
- Per-die vs shared

## 7. Driver Architecture

- **Kernel driver**: {{ open source upstream / proprietary }}
- **User-space driver (if any)**: {{ UMD for accelerators }}
- **Framework plugins**: {{ PyTorch backend / OpenXLA / TVM }}

## 8. Management Interface

- **In-band**: MMIO registers (per die)
- **Out-of-band**: {{ BMC via I2C/I3C to management chiplet }}
- **Telemetry**: {{ Redfish over BMC }}

## 9. Security Touchpoints
- Secure boot chain (→ DOC-D7-01-SEC)
- Signed firmware updates
- Attestation (TPM/DICE)

## 10. Software Validation Plan

| Layer | Test Suite | CI |
|---|---|---|
| Firmware | TF-A CI, unit tests | Per commit |
| Driver | kunit / kselftest | Per commit |
| Library | Per-API tests | Nightly |
| Framework | MLPerf, end-to-end | Weekly |

## 11. Quality Checklist

- [ ] HW/SW 分割对所有 PRD 功能明确
- [ ] Boot flow 每阶段 owner + timing 明确
- [ ] Device enumeration 对 OS 可见性定义
- [ ] Interrupt / DMA 跨 die 路由清晰
- [ ] Driver 开发计划（开源/闭源）明确
- [ ] 安全 touchpoint 与 DOC-D7 对齐
- [ ] Framework 支持列表与 PRD REQ-SW-* 一致

## 12. References
- Arm Trusted Firmware: https://www.trustedfirmware.org/
- UEFI Spec: https://uefi.org/specifications
- ACPI Spec: https://uefi.org/specifications
