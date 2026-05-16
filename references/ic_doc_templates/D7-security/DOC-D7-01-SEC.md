---
doc-id: DOC-D7-01-SEC
title: Security Architecture & Threat Model
domain: D7-security
version: 0.1
status: draft
parent: DOC-D2-01-ARCH
generated: 2026-04-24T06:15:00+08:00
---

# DOC-D7-01-SEC — Security Architecture & Threat Model

## Document Control

| Field | Value |
|---|---|
| Document ID | DOC-D7-01-SEC |
| Version | 0.1 |
| Classification | CONFIDENTIAL |
| Authors | Security Arch Lead, HW Security Eng |
| Reviewers | SoC Arch, SW Arch, Compliance |
| Approvers | Chief Security Officer, VP Engineering |

### Revision History

| Ver | Date | Author | Description |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | — | Initial draft |
| 1.0 | YYYY-MM-DD | — | Baseline release |

---

## 1. Purpose & Scope

本文档定义高端 Chiplet SoC 的安全架构和威胁模型，覆盖：
- 硬件信任根（Hardware Root of Trust）
- Die-to-Die 链路安全
- 固件/软件可信执行环境
- 供应链与生命周期安全
- 合规目标（FIPS 140-3、Common Criteria EAL4+、SESIP）

不覆盖：应用层软件安全、网络协议安全（由上层文档定义）。

---

## 2. Normative References

| Standard | Version | Application |
|---|---|---|
| NIST SP 800-193 | 2019 | Platform Firmware Resiliency |
| NIST SP 800-155 | Draft | BIOS Integrity Measurement |
| FIPS 140-3 | 2019 | Cryptographic Module Requirements |
| Common Criteria | CC 3.1 R5 | Evaluation Assurance Level |
| SESIP | v1.1 | Security Evaluation Standard for IoT Platforms |
| PSA Certified | L2/L3 | Platform Security Architecture |
| JEDEC JESD47 | G | Stress-test qualification (incl. side-channel) |
| NIST SP 800-90A/B/C | — | DRBG / entropy sources |
| ISO/SAE 21434 | 2021 | Automotive cybersecurity (if applicable) |

---

## 3. Security Objectives

### 3.1 Assets to Protect

| Asset ID | Asset | Classification | Risk if Compromised |
|---|---|---|---|
| AST-001 | Device Root Key (DRK) | SECRET | Identity spoofing, full compromise |
| AST-002 | Attestation Key (AK) | SECRET | False attestation |
| AST-003 | Platform Encryption Key (PEK) | SECRET | Data confidentiality breach |
| AST-004 | Firmware Images | CONFIDENTIAL | Code injection, IP theft |
| AST-005 | Configuration Fuses (eFuse/OTP) | CONFIDENTIAL | Misconfig, downgrade |
| AST-006 | Debug Credentials | RESTRICTED | Unauthorized access |
| AST-007 | Die-to-Die Traffic | CONFIDENTIAL | Eavesdropping, injection |
| AST-008 | Boot Measurement Chain | INTEGRITY | Trust bypass |
| AST-009 | RNG Entropy | INTEGRITY | Weak crypto keys |

### 3.2 Security Properties

| Property | Description | Mechanism |
|---|---|---|
| Confidentiality | Prevent unauthorized read of assets | Encryption, access control |
| Integrity | Prevent unauthorized modification | Digital signatures, CRC, parity |
| Authenticity | Verify origin of firmware/data | PKI, HMAC |
| Availability | Resist denial-of-service | Watchdog, fault isolation |
| Non-repudiation | Audit trail | Secure log, event counter |
| Forward Secrecy | Past sessions not decryptable | Ephemeral keys (ECDH) |

---

## 4. Threat Model (STRIDE)

### 4.1 Trust Boundaries

```
┌──────────────────────────────────────────────────────┐
│ Untrusted External                                   │
│  ┌─────────────────────────────────────────────────┐ │
│  │ Platform (OS/Hypervisor — Semi-trusted)         │ │
│  │  ┌──────────────────────────────────────────┐  │ │
│  │  │ TEE / Secure Enclave (Trusted)           │  │ │
│  │  │  ┌────────────────────────────────────┐  │  │ │
│  │  │  │ Hardware RoT (Fully Trusted)        │  │  │ │
│  │  │  │  - Boot ROM (immutable)             │  │  │ │
│  │  │  │  - HW Crypto Engine                 │  │  │ │
│  │  │  │  - Key Store (fuse-locked)          │  │  │ │
│  │  │  │  - TRNG                             │  │  │ │
│  │  │  └────────────────────────────────────┘  │  │ │
│  │  └──────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘

Trust Boundary Crossings (TB):
  TB-1: External PCIe/UCIe ↔ SoC
  TB-2: Normal World (REE) ↔ Secure World (TEE)
  TB-3: Host Die ↔ Satellite Die (D2D link)
  TB-4: Debug interface ↔ SoC internals
  TB-5: Manufacturing test ↔ Production mode
```

### 4.2 Threat Table (STRIDE × Asset)

| Threat ID | Category | Threat Description | Affected Asset | Likelihood | Impact | Risk | Mitigation |
|---|---|---|---|---|---|---|---|
| THR-001 | Spoofing | Rogue die impersonates trusted die on D2D link | AST-007 | M | H | HIGH | Mutual auth (D2D-Auth), certificate pinning |
| THR-002 | Tampering | Attacker modifies firmware image in flash | AST-004 | H | H | CRITICAL | Secure Boot + signature verification |
| THR-003 | Repudiation | Firmware update without audit trail | AST-004 | L | M | LOW | Secure monotonic counter, signed manifest |
| THR-004 | Info Disclosure | Side-channel attack on crypto engine (power/EM) | AST-001 | M | H | HIGH | Masked S-box, constant-time logic, EM shielding |
| THR-005 | Info Disclosure | Die-to-Die link eavesdropping | AST-007 | M | H | HIGH | AES-256-GCM encryption on D2D |
| THR-006 | Denial of Service | Glitch attack to bypass secure boot | AST-008 | M | H | HIGH | Glitch detector, redundant voltage sensors |
| THR-007 | Elevation of Privilege | Debug port enabled in production | AST-006 | H | H | CRITICAL | Fuse-lock debug; auth-gated JTAG |
| THR-008 | Tampering | eFuse bit flip via laser fault injection | AST-005 | L | H | MED | ECC on fuse array; read-back verify |
| THR-009 | Info Disclosure | Cold-boot attack on DRAM key residue | AST-003 | L | H | MED | Key zeroization on power-down |
| THR-010 | Spoofing | Supply chain counterfeit die insertion | AST-001 | L | H | MED | Die ID + attestation at manufacturing |
| THR-011 | Tampering | Rollback to vulnerable firmware version | AST-004 | M | H | HIGH | Anti-rollback (monotonic counter + min-version fuse) |
| THR-012 | Info Disclosure | Shared memory leakage across VM boundaries | AST-007 | M | M | MED | SMMU/IOMMU isolation, scrubbing |

### 4.3 Attack Surface Summary

| Surface | Entry Point | Exposure |
|---|---|---|
| Debug / JTAG | Physical / remote | High (production: locked) |
| UCIe / PCIe | Package pins | Medium (link auth) |
| DRAM interface | PCB traces | Low (encryption) |
| Firmware update | SW / OTA | High (signed manifest) |
| Supply chain | Fab, OSAT, logistics | Low (die ID + attestation) |
| Analog / power | Probe station | Low (shields, sensors) |

---

## 5. Security Architecture

### 5.1 Hardware Root of Trust (HRoT)

```
HRoT Block Diagram
──────────────────
  ┌─────────────────────────────────────────────────┐
  │ Boot ROM (read-only after power-on)             │
  │   └─ Immutable first-stage bootloader           │
  │   └─ Public key hash burned in fuse             │
  ├─────────────────────────────────────────────────┤
  │ Crypto Engine (HW accelerator)                  │
  │   ├─ AES-256 (GCM, CTR, CBC)                   │
  │   ├─ SHA-3 / SHA-2                              │
  │   ├─ RSA-4096 / ECDSA P-384                    │
  │   ├─ HMAC                                       │
  │   └─ DRBG (CTR_DRBG, AES-256)                  │
  ├─────────────────────────────────────────────────┤
  │ TRNG                                            │
  │   ├─ Physical entropy source (ring osc × N)    │
  │   ├─ Health test (NIST SP 800-90B)             │
  │   └─ Continuous health monitoring              │
  ├─────────────────────────────────────────────────┤
  │ Key Store                                       │
  │   ├─ Fuse-based root keys (DRK, AK)            │
  │   ├─ Volatile key RAM (session keys)           │
  │   └─ Key derivation (HKDF-SHA256)              │
  ├─────────────────────────────────────────────────┤
  │ Secure OTP / eFuse                              │
  │   ├─ Boot policy bits                          │
  │   ├─ Debug lock bits                           │
  │   ├─ Minimum firmware version (anti-rollback)  │
  │   └─ Lifecycle state machine                  │
  └─────────────────────────────────────────────────┘
```

### 5.2 Secure Boot Chain

```
Power-On Reset
     │
     ▼
Boot ROM (HRoT, immutable)
  └─ Verify BL1 signature (ECDSA P-384, key hash in fuse)
     │ FAIL → Fatal halt
     ▼
BL1 — First-stage Bootloader (in OTP/ROM)
  └─ Verify BL2 signature
  └─ Measure BL2 → extend PCR[0]
     ▼
BL2 — Trusted Firmware-A / OEM FW
  └─ Init secure storage
  └─ Load BL31 (EL3 runtime), BL32 (TEE-OS), BL33 (non-secure FW)
  └─ Verify each stage signature
  └─ Extend PCR[1..N]
     ▼
BL31 / BL32 (Secure World)
  └─ TEE-OS (OP-TEE or proprietary)
  └─ Trusted Applications
     ▼
BL33 (Normal World)
  └─ UEFI / OS bootloader
  └─ Remote attestation via EAT/DICE

Anti-rollback enforcement:
  - Fuse-burned min_version field
  - Each BL image embeds monotonic_version
  - Boot ROM refuses image.version < fuse.min_version
```

### 5.3 Die-to-Die (D2D) Link Security

#### 5.3.1 Authentication Protocol

```
Host Die                           Satellite Die
    │                                    │
    │── Hello (nonce_H, caps) ──────────►│
    │                                    │
    │◄─ Hello_Resp (nonce_S, cert_S) ────│
    │                                    │
    │── Cert_H, Sign(nonce_H||nonce_S) ─►│
    │   Verify cert_S ←──────────────────│
    │                                    │
    │◄─ Sign(nonce_S||nonce_H) ──────────│
    │   Verify cert_H                    │
    │                                    │
    │── ECDH KeyShare_H ────────────────►│
    │◄─ ECDH KeyShare_S ─────────────────│
    │                                    │
    [Derive session key = HKDF(shared_secret, nonce_H, nonce_S)]
    │                                    │
    │══ Encrypted UCIe flit stream ═════►│  (AES-256-GCM)
```

#### 5.3.2 D2D Security Policy

| Parameter | Value | Notes |
|---|---|---|
| Key agreement | ECDHE P-384 | Forward secrecy |
| Session cipher | AES-256-GCM | 128-bit auth tag |
| Key rotation | Every 2^32 flits | GCM nonce exhaustion prevention |
| Cert format | X.509 v3 or DICE certificate chain | Burned at manufacturing |
| Replay protection | 64-bit sequence number | Monotonic per session |
| Latency overhead | ≤ 10 ns/flit | HW accelerated |

### 5.4 Debug Security & Lifecycle

#### 5.4.1 Lifecycle States

```
         Manufacturing → Development → Production → End-of-Life
         ─────────────────────────────────────────────────────
Debug         OPEN           OPEN         LOCKED       LOCKED
JTAG          Full           Full         AuthOnly      None
Test mode     Full           Full         None          None
Fuse prog     Yes            Yes          No            No
Anti-rollback No             No           Yes           Yes
```

#### 5.4.2 Debug Authentication

```
Debug Unlock Request:
  1. Host sends challenge (nonce, debug_scope_bits)
  2. Issuer (OEM security server) signs (nonce || scope || device_id)
  3. HRoT verifies signature against OEM public key in fuse
  4. If valid: grant scoped JTAG access for N minutes
  5. Audit event logged to secure monotonic counter

Debug Scope Bits:
  [0] Scan chain access
  [1] Breakpoint / trace
  [2] Memory read
  [3] Memory write
  [4] Secure world access
  [7:5] Reserved
```

### 5.5 Cryptographic Algorithm Policy

| Function | Allowed Algorithms | Minimum Key Length | Notes |
|---|---|---|---|
| Symmetric encryption | AES-GCM, AES-CTR | 256-bit | No AES-ECB |
| Key wrap | AES-KW (RFC 3394) | 256-bit | — |
| Asymmetric sign | ECDSA P-384, RSA-PSS | 384-bit / 4096-bit | No RSA-PKCS1.5 |
| Key agreement | ECDHE P-384, X25519 | — | — |
| Hash | SHA-384, SHA-512, SHA3-256 | — | No MD5, SHA-1 |
| DRBG | CTR_DRBG (AES-256) | — | NIST SP 800-90A |
| KDF | HKDF-SHA384, SP800-108 | — | — |

**Deprecated (PROHIBITED):** DES, 3DES, RC4, MD5, SHA-1, RSA < 2048-bit, ECC < 256-bit.

### 5.6 Side-Channel Attack Mitigations

| Attack Vector | Mitigation | Implementation Level |
|---|---|---|
| Power analysis (SPA/DPA) | Masked S-box, dual-rail logic | RTL |
| Electromagnetic (EMA) | Metal shields, spread-spectrum clocks | Physical |
| Timing (timing oracle) | Constant-time comparison, blinding | RTL/FW |
| Fault injection (voltage/clock glitch) | Voltage monitors, clock monitors, redundant FSM | RTL |
| Laser fault injection | Active mesh, light sensors | Physical |
| Acoustic | Encapsulant (if required) | Package |

Validation: TVLA (Test Vector Leakage Assessment) with t-test threshold |t| < 4.5 across 10^6 traces.

---

## 6. Secure Storage

### 6.1 Key Hierarchy

```
Device Root Key (DRK) — burned in fuse at manufacturing
         │
         ├─ Attestation Key (AK) = KDF(DRK, "attest", die_id)
         │       └─ Signs EAT/DICE attestation tokens
         │
         ├─ Platform Encryption Key (PEK) = KDF(DRK, "encrypt", die_id)
         │       └─ Wraps all stored secrets
         │
         └─ Firmware Integrity Key (FIK) = KDF(DRK, "fw-verify", die_id)
                 └─ Verifies firmware signatures (HW verify path)

Session Keys (ephemeral, never stored):
  - D2D session key = HKDF(ECDHE_shared || nonce_H || nonce_S)
  - TEE session key = HKDF(PEK || session_id || nonce)
```

### 6.2 Secure Non-Volatile Storage

| Storage | Use | Protection |
|---|---|---|
| eFuse / OTP | Root keys, policy bits | One-time programmable, ECC |
| Secure flash region | Signed firmware, attestation cert | AES-256 encrypted, CRC |
| Anti-tamper battery-backed RAM | Ephemeral keys, counters | Zeroize on tamper detect |
| SRAM (power-on) | Key derivation intermediates | Scrubbed after use |

---

## 7. Attestation & Provenance

### 7.1 Device Identity

| Component | Standard | Format |
|---|---|---|
| Die unique ID | 128-bit random (burned at manufacturing) | Hex string |
| Certificate chain | DICE (RFC 9482) | X.509 DER |
| Platform manifest | CoSWID (RFC 9393) | CBOR |
| Attestation token | EAT (RFC 9711) | CBOR/JWT |

### 7.2 DICE Certificate Chain

```
Device Identity Composition Engine (DICE):

Layer 0 (UDS — Unique Device Secret, fuse-burned):
  └─ CDI_0 = HASH(UDS || boot_config)
         └─ Certificate_0: DeviceID cert, signed by UDS key

Layer 1 (Boot Measurement):
  └─ CDI_1 = HASH(CDI_0 || BL1_measurement)
         └─ Certificate_1: Alias cert, signed by CDI_0 key

Layer N (OS/Application):
  └─ CDI_N = HASH(CDI_{N-1} || FW_N_measurement)
         └─ Certificate_N: App alias cert

Final alias cert presented for remote attestation
```

### 7.3 Supply Chain Attestation

| Phase | Action | Record |
|---|---|---|
| Wafer sort | Die ID injection + KGD test pass | Test database |
| Packaging (OSAT) | Multi-die pairing verification | Assembly manifest |
| Final test | Board-level attestation provisioning | Certificate chain |
| Customer receive | Attestation verification against OEM CA | On-device |

---

## 8. Security Validation Requirements

### 8.1 Pre-Silicon (RTL/Emulation)

| Test | Pass Criteria |
|---|---|
| Formal verification of crypto FSM | No counterexample found |
| TVLA on crypto engine model | \|t\| < 4.5 over 10^5 traces |
| Boot sequence fuzzing | No bypass paths identified |
| Threat model coverage | All HIGH/CRITICAL threats have test coverage |

### 8.2 Post-Silicon Validation

| Test | Method | Pass Criteria |
|---|---|---|
| SCA power analysis | DPA workstation, 10^6 traces | No key-correlated leakage |
| Glitch injection | Crowbar + clock glitch, 10^4 attempts | No secure boot bypass |
| Laser fault injection | FA equipment, systematic scan | No sensitive data extraction |
| JTAG lock verification | External debugger, production fused part | All debug access denied |
| Anti-rollback | Flash older FW version | Boot refusal confirmed |
| Attestation chain | DICE chain verify, remote verifier | Valid chain end-to-end |

### 8.3 Certification Targets

| Certification | Target Level | Timeline |
|---|---|---|
| FIPS 140-3 | Level 2 (crypto module) | Post-silicon + 6 months |
| Common Criteria | EAL4+ (protection profile TBD) | Post-silicon + 12 months |
| PSA Certified | Level 2 | Post-silicon + 3 months |

---

## 9. Security Review Gates

| Gate | Milestone | Required Sign-off |
|---|---|---|
| Threat model review | Arch freeze | Security Arch Lead + CSO |
| RTL security review | RTL freeze | HW Security Eng + external audit |
| Penetration test | Tape-out + 4 wk | Third-party security lab |
| Certification submission | Silicon validation complete | Certification body |

---

## 10. Open Issues

| Issue ID | Description | Owner | Target Date |
|---|---|---|---|
| SEC-001 | TVLA test vector set selection | HW Security | — |
| SEC-002 | D2D cert format (X.509 vs DICE raw) | Security Arch | — |
| SEC-003 | Automotive ISO/SAE 21434 applicability | Compliance | — |

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| HRoT | Hardware Root of Trust |
| TRNG | True Random Number Generator |
| DRBG | Deterministic Random Bit Generator |
| DICE | Device Identity Composition Engine |
| EAT | Entity Attestation Token |
| TVLA | Test Vector Leakage Assessment |
| SCA | Side-Channel Attack |
| DPA | Differential Power Analysis |
| TEE | Trusted Execution Environment |
| KDF | Key Derivation Function |
| HKDF | HMAC-based Key Derivation Function |
| UDS | Unique Device Secret |
| CDI | Compound Device Identity |

---

## Appendix B — Related Documents

| Doc ID | Title | Relationship |
|---|---|---|
| DOC-D2-01-ARCH | System Architecture Spec | Parent: security requirements source |
| DOC-D2-05-DIC | Die Interface Contract | D2D security parameters |
| DOC-D3-01-MAS | Module Architecture Spec | HRoT block implementation |
| DOC-D5-01-DFT | DFT Plan | Test mode security lockdown |
| DOC-D6-01-VPLAN | Verification Plan | Security test coverage |
| DOC-D9-03-COMPLY | Compliance Matrix | Certification tracking |
