---
doc-id: DOC-D9-03-COMPLY
title: Compliance Matrix
domain: D9-release
version: 0.1
status: draft
parent: DOC-D1-01-PRD
generated: 2026-04-24T06:15:00+08:00
---

# DOC-D9-03-COMPLY — Compliance Matrix

## Document Control

| Field | Value |
|---|---|
| Document ID | DOC-D9-03-COMPLY |
| Version | 0.1 |
| Classification | CONFIDENTIAL (until release) |
| Authors | Compliance Eng, SoC Arch |
| Reviewers | Security Arch, Reliability, Legal |
| Approvers | VP Engineering, VP Product, Legal Counsel |

### Revision History

| Ver | Date | Author | Description |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | — | Initial draft |
| 1.0 | YYYY-MM-DD | — | Pre-production baseline |
| 2.0 | YYYY-MM-DD | — | Production release |

---

## 1. Purpose & Scope

本文档追踪 [Product Name] 对所有适用标准、法规和行业规范的合规状态。每项合规条目包括：
- 标准/法规版本
- 适用范围
- 合规状态（Compliant / Partial / Non-compliant / N/A）
- 验证方法和证据

本文档是认证申请、客户 RFQ（Request for Qualification）和监管提交的主要参考。

---

## 2. Compliance Summary Dashboard

| Category | Total Requirements | Compliant | Partial | Non-Compliant | N/A |
|---|---|---|---|---|---|
| Interface Standards | [N] | [N] | [N] | [N] | [N] |
| Security / Crypto | [N] | [N] | [N] | [N] | [N] |
| Functional Safety | [N] | [N] | [N] | [N] | [N] |
| Environmental | [N] | [N] | [N] | [N] | [N] |
| EMC / Regulatory | [N] | [N] | [N] | [N] | [N] |
| Reliability / Quality | [N] | [N] | [N] | [N] | [N] |
| **TOTAL** | **[N]** | **[N]** | **[N]** | **[N]** | **[N]** |

**Target:** 100% Compliant or N/A before production release.

---

## 3. Interface Standards Compliance

### 3.1 UCIe (Universal Chiplet Interconnect Express)

| Req ID | Requirement | Source | Status | Evidence | Notes |
|---|---|---|---|---|---|
| UCIe-001 | PHY electrical spec at 20 Gbps/lane | UCIe Spec 2.0 §4 | Compliant | Eye diagram measurements (SVDB-xxx) | — |
| UCIe-002 | Link Training State Machine (LTSM) all states | UCIe Spec 2.0 §5 | Compliant | RTL simulation + silicon LTSM test | — |
| UCIe-003 | Retrain / recovery from link errors | UCIe Spec 2.0 §6 | Compliant | Error injection test (SVDB-xxx) | — |
| UCIe-004 | FDI (Flit-Die Interface) protocol | UCIe Spec 2.0 §7 | Compliant | Functional simulation | — |
| UCIe-005 | Power management (L0, L0p, L1, L2) | UCIe Spec 2.0 §8 | Partial | L1 only (see ERR-001) | A0: L1 disabled via WA |
| UCIe-006 | Advanced (CXL/PCIe) stack map | UCIe Spec 2.0 §9 | N/A | — | Raw-UCIe stack only |
| UCIe-007 | UCIe compliance test suite pass | UCIe Consortium CTS v2.0 | Compliant | Test report [RPT-UCIe-xxx] | — |

**Certification Body:** UCIe Consortium Interoperability Plugfest
**Status:** Passed Plugfest Event [PF-YYYY-NN]

### 3.2 PCIe (PCI Express)

| Req ID | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| PCIE-001 | PCIe Gen 5 electrical (32 GT/s) | PCIe Base Spec 6.0 §4 | Compliant | CTS report |
| PCIE-002 | Gen5 equalization (LPB, full equalization) | PCIe Base Spec 6.0 §4.2 | Compliant | CTS |
| PCIE-003 | TLP / DLLP protocol | PCIe Base Spec 6.0 §2,3 | Compliant | Protocol sim + Si |
| PCIE-004 | PCIe power management (L0s, L1, L1.1, L1.2) | PCIe Base Spec 6.0 §5 | Compliant | PM test suite |
| PCIE-005 | PCIe CTS (Compliance Test Suite) | PCI-SIG CTS Gen5 | Compliant | CTS pass report [RPT-PCIE-xxx] |

**Certification Body:** PCI-SIG
**Status:** [Compliance certificate number / pending]

### 3.3 IEEE 1838 (Die Wrapper for 3D-SIC Test)

| Req ID | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| 1838-001 | Die wrapper architecture | IEEE 1838-2019 §5 | Compliant | DFT spec DOC-D5-01-DFT |
| 1838-002 | WIR (Wrapper Instruction Register) | IEEE 1838-2019 §6 | Compliant | RTL verification |
| 1838-003 | Test access network (TAN) | IEEE 1838-2019 §7 | Compliant | Boundary scan test |

### 3.4 JEDEC / Memory Interface

| Req ID | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| MEM-001 | HBM3 PHY spec | JEDEC JESD238A | Compliant | PHY characterization |
| MEM-002 | ECC support (SEC-DED) | JEDEC JESD79 | Compliant | ECC injection test |
| MEM-003 | JEDEC JEP30 chiplet model | JEP30 + OCP CDXML | Compliant | CDXML file delivered (DOC-D4-01-PKG) |

---

## 4. Security & Cryptography Compliance

### 4.1 FIPS 140-3

| Req ID | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| FIPS-001 | Approved cryptographic algorithms only | FIPS 140-3 §4.5 | Compliant | Algorithm list (DOC-D7-01-SEC §5.5) |
| FIPS-002 | TRNG (entropy source health tests) | NIST SP 800-90B | Compliant | Health test silicon validation |
| FIPS-003 | DRBG (CTR_DRBG AES-256) | NIST SP 800-90A | Compliant | CAVP test vectors pass |
| FIPS-004 | AES-GCM implementation | FIPS 197 + SP800-38D | Compliant | CAVP vectors pass |
| FIPS-005 | SHA-384 / SHA-512 | FIPS 180-4 | Compliant | CAVP vectors pass |
| FIPS-006 | ECDSA P-384 | FIPS 186-5 | Compliant | CAVP vectors pass |
| FIPS-007 | Key management (zeroization) | FIPS 140-3 §4.9 | Compliant | Power-off zeroization test |
| FIPS-008 | Physical security (Level 2: tamper evidence) | FIPS 140-3 §4.6 | In Progress | Lab evaluation pending |

**Target Level:** FIPS 140-3 Level 2
**Certification Laboratory:** [Lab name TBD]
**Estimated Certification Date:** YYYY-MM

### 4.2 Common Criteria

| Req ID | Requirement | Source | Status | Evidence |
|---|---|---|---|---|
| CC-001 | Security Target (ST) document complete | CC 3.1 R5 | In Progress | ST draft v0.3 |
| CC-002 | Protection Profile alignment | PP-IC-xxx | In Progress | Gap analysis complete |
| CC-003 | ADV_FSP.3 (functional spec) | CC ADV class | Planned | — |
| CC-004 | ALC_CMC.4 (config management) | CC ALC class | Planned | — |
| CC-005 | AVA_VAN.3 (vulnerability assessment) | CC AVA class | Planned | Penetration test scheduled |

**Target Level:** EAL4+
**Certification Body:** [CCTL name TBD]
**Estimated Certification Date:** YYYY-MM

### 4.3 PSA Certified

| Req ID | Requirement | Level | Status | Evidence |
|---|---|---|---|---|
| PSA-001 | Security model analysis | L2 | Compliant | PSA security analysis doc |
| PSA-002 | Security test results | L2 | Compliant | PSA certified test report |
| PSA-003 | Isolation (TEE from REE) | L2 | Compliant | Formal analysis + silicon test |

**Status:** PSA Certified Level 2 achieved (Certificate No. [PSA-CERT-xxx])

---

## 5. Functional Safety Compliance

### 5.1 ISO 26262 (Automotive)

*(Applicable if automotive configuration ordered)*

| Req ID | Requirement | Source | ASIL Target | Status | Evidence |
|---|---|---|---|---|---|
| FS-001 | Safety plan | ISO 26262-2:2018 §6 | ASIL-B | Compliant | Safety plan doc |
| FS-002 | Hazard analysis & risk assessment (HARA) | ISO 26262-3:2018 §6 | ASIL-B | Compliant | HARA report |
| FS-003 | Technical safety concept | ISO 26262-4:2018 §6 | ASIL-B | In Progress | — |
| FS-004 | HW safety requirements | ISO 26262-5:2018 §6 | ASIL-B | In Progress | — |
| FS-005 | HW architectural metrics (PMHF, LFM, DC) | ISO 26262-5:2018 §8 | ASIL-B | Planned | FTA, FMEDA |
| FS-006 | SW safety requirements | ISO 26262-6:2018 §6 | ASIL-B | Planned | — |
| FS-007 | Production control | ISO 26262-7:2018 | ASIL-B | Planned | — |
| FS-008 | SEooC (Safety Element out of Context) documentation | ISO 26262-10:2018 | ASIL-B | In Progress | SEooC report (DOC-D2-05-DIC) |

**Target:** ISO 26262 ASIL-B (SEooC)
**Certification Body:** [TÜV SÜD / SGS-TÜV / Exida TBD]
**Estimated Sign-off:** YYYY-MM

### 5.2 IEC 62443 (Industrial Cybersecurity — if applicable)

| Req ID | Requirement | Level | Status |
|---|---|---|---|
| IEC-001 | Security Level 2 capability | SL2 | Planned |

---

## 6. Environmental Compliance

### 6.1 RoHS / REACH / WEEE

| Regulation | Version | Scope | Status | Certificate / Declaration |
|---|---|---|---|---|
| EU RoHS 3 | Directive 2015/863/EU | All materials in BOM | Compliant | DOC: [ROHS-DECL-xxx] |
| EU REACH | SVHC candidate list | No SVHC > 0.1% w/w | Compliant | DOC: [REACH-DECL-xxx] |
| EU WEEE | Directive 2012/19/EU | Product category | Compliant | Producer registration No. [xxx] |
| China RoHS | SJ/T 11364-2014 | All hazardous substances | Compliant | Conformity doc [xxx] |
| US TSCA | Toxic Substances Control Act | All chemical substances | Compliant | [xxx] |

### 6.2 Conflict Minerals (Dodd-Frank §1502)

| Mineral | Supplier Audit Status | EICC/GeSI CMR Filed |
|---|---|---|
| Tantalum (Ta) | Conflict-free sourced | Yes |
| Tin (Sn) | Conflict-free sourced | Yes |
| Tungsten (W) | Conflict-free sourced | Yes |
| Gold (Au) | Conflict-free sourced | Yes |

**CMR Report:** Available on request. Filed annually per SEC rule 13p-1.

---

## 7. EMC & Regulatory Compliance

| Region | Regulation | Standard | Status | Test House | Report |
|---|---|---|---|---|---|
| USA | FCC Part 15 Class B | ANSI C63.4 | Planned | [Lab TBD] | — |
| EU | CE Mark — Radio (RED) | EN 55032, EN 55024 | Planned | [Lab TBD] | — |
| EU | CE Mark — EMC | EN 61000-4 series | Planned | [Lab TBD] | — |
| Japan | VCCI Class B | VCCI-CISPR 32 | Planned | [Lab TBD] | — |
| Korea | KC | KC Mark | Planned | [Lab TBD] | — |
| China | CCC / SRRC | GB/T 9254 | Planned | [Lab TBD] | — |

---

## 8. Reliability & Quality Standards

| Standard | Requirement | Status | Evidence |
|---|---|---|---|
| JEDEC JESD47 | Stress-test qualification | Compliant | Qual report [QUAL-xxx] |
| JEDEC JESD22-A108 | HTOL (1000 h @ 125 °C) | Compliant | HTOL data [HTOL-xxx] |
| JEDEC JESD22-A104 | Temperature cycling (1000 cycles) | Compliant | TC data |
| JEDEC J-STD-020 | Moisture sensitivity (MSL 3) | Compliant | MSL test report |
| AEC-Q100 | Automotive IC qualification (Grade 1) | In Progress | Qual plan submitted |
| IPC-7711/7721 | PCB assembly / rework | N/A | — |
| IATF 16949 | Automotive quality system (OEM only) | Planned | — |

---

## 9. Intellectual Property & Licensing

| Component | IP Owner | License Type | Usage Rights | Notes |
|---|---|---|---|---|
| Arm Cortex-A cores | Arm Ltd. | Commercial license | Integrated in silicon | Under NDA / license agreement |
| UCIe PHY | [3rd-party IP vendor] | Commercial | Integrated | Licensed per unit volume |
| OP-TEE | Linaro / open-source | BSD 2-clause | SW only | Source available |
| Trusted Firmware-A | Arm / open-source | BSD 3-clause | SW only | Source available |
| [Other IP] | [Owner] | [License] | — | — |

**Patent Landscape:** Patent freedom-to-operate (FTO) analysis completed YYYY-MM-DD. Report: [FTO-xxx]. No blocking patents identified.

---

## 10. Standards Watchlist (Upcoming)

Monitor for impact to future silicon revisions:

| Standard | Current Status | Expected Release | Potential Impact |
|---|---|---|---|
| UCIe 3.0 | Draft | YYYY | 40 Gbps/lane PHY changes |
| PCIe 7.0 | Draft | YYYY | 128 GT/s — new equalization |
| FIPS 140-3 Annexes | In revision | YYYY | New algorithm approvals |
| ISO 26262:2026 Ed.3 | Planned | YYYY | HARA methodology update |
| IEEE 1838-202x | In ballot | YYYY | 3D-SIC test extensions |

---

## 11. Compliance Gating for Release

Production release requires all of the following:

| Gate | Requirement | Status |
|---|---|---|
| PG-01 | UCIe CTS pass | [ ] |
| PG-02 | PCIe CTS pass | [ ] |
| PG-03 | FIPS 140-3 Level 2 certificate | [ ] |
| PG-04 | PSA Certified Level 2 certificate | [ ] |
| PG-05 | RoHS / REACH declarations signed | [ ] |
| PG-06 | FCC / CE mark approval | [ ] |
| PG-07 | JEDEC qualification (HTOL + TC) pass | [ ] |
| PG-08 | AEC-Q100 Grade 1 (if automotive) | [ ] |
| PG-09 | Zero open S1/S2 errata without customer acceptance | [ ] |
| PG-10 | Legal sign-off (IP, export control) | [ ] |

---

## Appendix A — Acronyms

| Term | Definition |
|---|---|
| ASIL | Automotive Safety Integrity Level |
| CAVP | Cryptographic Algorithm Validation Program |
| CMR | Conflict Minerals Report |
| CTS | Compliance Test Suite |
| EICC | Electronic Industry Citizenship Coalition |
| FTO | Freedom to Operate |
| HARA | Hazard Analysis and Risk Assessment |
| MTTF | Mean Time to Failure |
| PMHF | Probabilistic Metric for random Hardware Failures |
| SEooC | Safety Element out of Context |
| SVHC | Substances of Very High Concern |

---

## Appendix B — Related Documents

| Doc ID | Title | Relationship |
|---|---|---|
| DOC-D1-01-PRD | Product Requirements Document | Compliance requirements source |
| DOC-D7-01-SEC | Security Architecture & Threat Model | Security compliance evidence |
| DOC-D5-01-DFT | DFT Plan | IEEE 1838 compliance evidence |
| DOC-D9-01-DS | Datasheet | Published compliance claims |
| DOC-D9-02-ERRATA | Errata Document | Non-compliance tracking |
