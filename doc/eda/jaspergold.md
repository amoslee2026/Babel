# JasperGold (Cadence)

## 基本信息

| 属性 | 值 |
|------|-----|
| Vendor | Cadence |
| 版本 | 2025.12, 2025.09p002 |
| 安装路径 | `/eda_tools/cadence/jasper2025.12` |

## 版本目录

| 版本 | 路径 |
|------|------|
| 2025.12 | `/eda_tools/cadence/jasper2025.12/jasper_2025.12` |
| 2025.09p002 | `/eda_tools/cadence/jasper2025.12/jasper_2025.09p002` |

## 可执行文件

### 2025.12 版本

| 文件 | 路径 | 说明 |
|------|------|------|
| jg | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jg` | 主程序 (JasperGold) |
| jc | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jc` | Jasper Compiler |
| jg_frontend | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jg_frontend` | 前端解析器 |
| jg_proof | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jg_proof` | 证明引擎 |
| jg_agent | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jg_agent` | Agent 工具 |
| jg_session | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jg_session` | Session 管理 |
| jg_bridge | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/jg_bridge` | Bridge 工具 |
| help | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/bin/help` | 帮助工具 |

## 文档目录

| 文档类型 | 路径 |
|------|------|
| 主文档 | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/doc/` |
| HTML 文档 | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/doc/HTML/` |
| 安装说明 | `/eda_tools/cadence/jasper2025.12/jasper_2025.12/doc/INSTALL.pdf` |

### 主要文档文件

| 文件 | 说明 |
|------|------|
| `jasper_command_reference.pdf` | 命令参考手册 |
| `jasper_cdc_userguide.pdf` | CDC 用户指南 |
| `jasper_caf_userguide.pdf` | CAF 用户指南 |
| `jasper_apps_userguide.pdf` | Apps 用户指南 |
| `jasper_cov_userguide.pdf` | 覆盖率用户指南 |
| `jasper_csr_userguide.pdf` | CSR 用户指南 |
| `AN_clocking_management.pdf` | 时钟管理应用笔记 |
| `AN_scripting.pdf` | 脚本编写应用笔记 |
| `BPS_user_guide.pdf` | BPS 用户指南 |

## 环境设置

```bash
export JASPER_HOME=/eda_tools/cadence/jasper2025.12/jasper_2025.12
export PATH=$JASPER_HOME/bin:$PATH
```

## 用途

JasperGold 是形式验证工具，用于：
- 形式化属性验证 (FPV)
- 时钟域交叉验证 (CDC)
- 连通性检查
- 安全验证
- 覆盖率分析