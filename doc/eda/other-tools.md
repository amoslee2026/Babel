# Other Tools

## VSCode

| 属性 | 值 |
|------|-----|
| Vendor | Microsoft |
| Version | 1.117.0 |
| 安装路径 | `/eda_tools/other_tools/vscode` |
| 文件类型 | RPM Package |

### 文件

| 文件 | 路径 | 大小 |
|------|------|------|
| code-1.117.0 RPM | `/eda_tools/other_tools/vscode/code-1.117.0-1776814401.el8.x86_64.rpm` | 214MB |

### 安装方法

```bash
sudo rpm -ivh /eda_tools/other_tools/vscode/code-1.117.0-1776814401.el8.x86_64.rpm
```

或用户模式安装（需提取后配置）。

---

## Cadence Tarballs (未解压)

以下为未解压的 Cadence 工具压缩包：

### Sigrity

| 属性 | 值 |
|------|-----|
| Version | 25.10.0201.638295 |
| 文件 | `/eda_tools/pkg/SIG25.10_25.10.0201.638295_lnx86_64_23469.tar.gz` |
| 大小 | 12.25GB |

用途：信号完整性 (SI) 和电源完整性 (PI) 分析。

### JasperGold Base

| 属性 | 值 |
|------|-----|
| Version | 25.12.000 |
| 文件 | `/eda_tools/pkg/Base_JASPER25.12.000_lnx86_1of1.tgz` |
| 大小 | 2.45GB |

### JasperGold Update

| 属性 | 值 |
|------|-----|
| Version | 25.09.002 |
| 文件 | `/eda_tools/pkg/Update_JASPER25.09.002_lnx86_1of1.tgz` |
| 大小 | 2.42GB |

### SSV (Smart Safety Verification)

| 属性 | 值 |
|------|-----|
| Version | 25.12-s082 |
| 文件 | `/eda_tools/pkg/1775009115_SSV-25.12-s082_1-lnx86.tar.gz` |
| 大小 | 81MB |

用途：安全功能验证。

---

## Cadence PKG 目录

`/eda_tools/pkg` 目录包含已安装的 Cadence 公共组件：

| 目录 | 说明 |
|------|------|
| `bin` | 公共工具脚本 |
| `share` | 共享资源 |
| `tools.lnx86` | Linux 64位工具 |
| `oa_v22.62.007` | OpenAccess 数据库 |
| `openmpi` | MPI 库 |
| `include` | 头文件 |
| `atlas_clarity` | Atlas Clarity 组件 |

### 公共可执行文件

| 文件 | 路径 |
|------|------|
| cds_tools.sh | `/eda_tools/pkg/bin/cds_tools.sh` |
| cds_plat | `/eda_tools/pkg/bin/cds_plat` |
| cds_root.sh | `/eda_tools/pkg/bin/cds_root.sh` |