# Commercial EDA Tools Trial List

> Based on `/eda_tools/bashrc_sample` and directory survey on 2026-05-19

## Test Results Summary

| Tool | Test Status | Notes |
|------|-------------|-------|
| JasperGold | ✅ **可用** | `jg -version` → 2025.12 FCS 64 bits |
| Conformal LEC | ✅ **可用** | `lec_auto -version` → lec 25.20-s200 |
| Xcelium | 🔶 未安装 | 需解压 xrun2501.full.tar.gz |
| Joules | 🔶 安装不完整 | 目录结构缺失 bin/ |
| Sigrity | 🔶 安装不完整 | 缺少主程序入口 |
| DDI | 🔶 未安装 | 需解压合并 7 个 tar 包 |

## License Server Status

```
License server UP (MASTER) v11.19.5
Vendor daemon cdslmd: UP v11.19.5
Expiry: 16-jun-2026 (约 1 个月试用)
```

**Licensed Features (25 total):**

| Feature | Licenses | Purpose |
|---------|----------|---------|
| JasperGold (jasper_papp/pcov/pint) | 2 | Formal verification |
| Xcelium_Single_Core | 2 | Simulation |
| Conformal_Low_Power_GXL | 2 | Logic equivalence check |
| Genus_Synthesis | 2 | RTL synthesis |
| Genus_Low_Power_Opt | 2 | Low-power synthesis |
| Genus_Physical_Opt | 2 | Physical synthesis |
| Innovus_Impl_System | 2 | Place & route |
| Innovus_C | 2 | Implementation core |
| Joules_XL | 1 | RTL power analysis |
| Joules_RTL_Studio | 1 | Power GUI |
| Joules_Implementation_XL_Opt | 1 | Power optimization |
| Tempus_Timing_Signoff_XL | 2 | Timing signoff |
| tempus_advanced_analysis | 2 | Advanced timing |
| Voltus_Power_Integrity_XL | 2 | Power integrity |
| Voltus_Power_Integrity_AA | 2 | Advanced analysis |
| verisium_debug | 2 | Verification debug |
| Integrated_Metrics_Center | 2 | Coverage metrics |
| Cadence_Analytics_* | 2+2 | Analytics tools |
| DFM_Core_Technology | 2 | DFM support |
| Encounter_C | 2 | Legacy P&R |
| Affirma_sim_analysis_env | 2 | Simulation analysis |
| COSLITE_ACCESS | 1 | Support portal access |

---

## License Server

```bash
export CDS_LIC_FILE=5280@Practical_Training
```

All Cadence tools share this license server.

---

## Available Tools Summary

| Tool | Category | Version | Location | Status |
|------|----------|---------|----------|--------|
| JasperGold | Formal Verification | 2025.12, 2025.09p002 | `/eda_tools/cadence_z/jasper2025.12/` | Installed |
| Xcelium | Simulation | 25.01 | `/eda_tools/pkg/xcelium/` | Tarball |
| Conformal (LEC) | Logic Equivalence Check | 25.20-s200 | `/eda_tools/pkg/conformal/` | Installed |
| Joules | Power Analysis | 25.13-s066 | `/eda_tools/pkg/Joules/` | Installed |
| JStudio | Jasper Studio | 25.13-s066 | `/eda_tools/pkg/jstudio/` | Installed |
| DDI | Digital Design Implementation | 25.10.000 | `/eda_tools/pkg/ddi251s/` | Tarball (7 parts) |
| SSV | SystemVerilog Verification | 25.12-s082 | `/eda_tools/pkg/` | Tarball |
| Sigrity | Signal Integrity | 25.10.0201, 25.1.2 | `/eda_tools/pkg/sig25.1.2/` | Installed |
| VSCode | IDE | 1.117.0 | `/eda_tools/other_tools/vscode/` | RPM |

---

## Tool Details

### 1. JasperGold (Formal Verification) ✅

**用途**: 形式化验证、property checking、coverage analysis

**安装路径**:
- `/eda_tools/cadence_z/jasper2025.12/jasper_2025.12/`
- `/eda_tools/cadence_z/jasper2025.12/jasper_2025.09p002/`

**快速启动**:
```bash
export CDS_LIC_FILE=5280@Practical_Training
export PATH="/eda_tools/cadence_z/jasper2025.12/jasper_2025.12/bin:$PATH"
jg -version  # 输出: 2025.12 FCS 64 bits
jg -help     # 查看帮助
jg -fpv      # Formal Property Verification
jg -cov      # Coverage analysis
```

**子功能**:
- `-fpv`: Formal Property Verification
- `-cdc`: Clock Domain Crossing
- `-cfpv`: Coverage Formal Property Verification
- `-superlint`: Super Lint
- `-sec`: Security verification

### 2. Xcelium (Simulation) 🔶

**用途**: SystemVerilog/UVM 仿真、混合信号仿真、覆盖率分析

**安装路径**: `/eda_tools/pkg/xcelium/xrun2501.full.tar.gz`

**状态**: 需解压安装 (7.5GB)

**启动命令** (解压后):
```bash
source <install_path>/setup.csh
xrun -f run.f
```

---

### 3. Conformal LEC (Logic Equivalence Check) ✅

**用途**: RTL-to-RTL、RTL-to-Gate 逻辑等价检查

**安装路径**: `/eda_tools/pkg/conformal/lec.25.20-s200/`

**快速启动**:
```bash
export CDS_LIC_FILE=5280@Practical_Training
/eda_tools/pkg/conformal/lec.25.20-s200/bin/lec_auto -version
# 输出: Tool: lec 25.20-s200
```

### 4. Joules (Power Analysis) 🔶 安装不完整

**用途**: RTL 功率估算、功耗分析、动态/静态功耗

**安装路径**: `/eda_tools/pkg/Joules/25.13-s066_1/`

**状态**: ⚠️ 目录结构不完整，缺少 bin/ 主程序

**目录内容**: 只有 etc/studio/ 子目录，无可执行文件

---

### 5. JStudio (Jasper Studio) 🔶 安装不完整

**用途**: JasperGold GUI环境、验证计划管理、覆盖率可视化

**安装路径**: `/eda_tools/pkg/jstudio/25.13-s066_1/`

**状态**: ⚠️ 有 tools.lnx86/bin/ 但缺少主程序入口

---

### 6. DDI (Digital Design Implementation) 🔶 未安装

**用途**: 数字设计实现流程集成平台

**安装路径**: `/eda_tools/pkg/ddi251s/` (7个tar包)

**状态**: 需解压合并安装 (分卷压缩，缺少部分文件)

**文件列表**:
- Base_DDI25.10.000_lnx86_1of7.tar (~3.8GB)
- Base_DDI25.10.000_lnx86_5of7.tar (~4.1GB)
- Base_DDI25.10.000_lnx86_7of7.tar (~1.9GB)

---

### 7. SSV (SystemVerilog Verification)

**用途**: SystemVerilog 验证套件

**安装路径**: `/eda_tools/pkg/1775009115_SSV-25.12-s082_1-lnx86.tar.gz`

**状态**: 需解压安装 (~77MB)

---

### 8. Sigrity (Signal Integrity) 🔶 安装不完整

**用途**: 信号完整性分析、电源完整性、电磁仿真

**安装路径**: `/eda_tools/pkg/sig25.1.2/SIGRITY20251/`

**状态**: ⚠️ 有 tools.lnx86/bin/ 但缺少明确的主程序入口

**额外文件**:
- SIG25.10_25.10.0201.638295_lnx86_64_23469.tar.gz (~12GB)
- SIG25.1.2.tar.gz (~17GB)

**子工具** (在 tools.lnx86/bin/64bit/):
- PowerSI.exe, 3dworkbench.exe, AFSfor3DEM.exe

---

### 9. VSCode

**用途**: 代码编辑、调试、插件扩展

**安装路径**: `/eda_tools/other_tools/vscode/`

**安装方式**: RPM Package

---

## Setup Script Template (可用工具)

```bash
# ~/.bashrc
export CDS_LIC_FILE=5280@Practical_Training

# JasperGold (可用)
export PATH="/eda_tools/cadence_z/jasper2025.12/jasper_2025.12/bin:$PATH"

# Conformal LEC (可用)
alias lec='/eda_tools/pkg/conformal/lec.25.20-s200/bin/lec_auto'
```

## Notes

1. **许可证有效期**: 2026-05-17 至 2026-06-16 (约 1 个月试用)
2. **Shell兼容性**: Cadence 工具默认使用 C shell (csh) setup 脚本，bash 用户需直接设置 PATH 或使用 alias
3. **已验证可用**: JasperGold (`jg`) 和 Conformal LEC (`lec_auto`) 可正常运行
4. **未完成安装**: Xcelium、DDI、SSV 需解压，Joules/JStudio/Sigrity 安装不完整