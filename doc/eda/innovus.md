# Innovus (Cadence)

## 基本信息

| 属性 | 值 |
|------|-----|
| Vendor | Cadence |
| Version | 25.12-s079 |
| 安装路径 | `/eda_tools/pkg/innovus` |
| 状态 | 已解压 (部分) + Tarball |

## Tarball 文件

| 文件 | 路径 | 大小 |
|------|------|------|
| INNOVUS-25.12-s079 | `/eda_tools/pkg/innovus/1773030321_INNOVUS-25.12-s079_1-lnx86.tar.gz` | 15.8GB |

## 已解压目录

| 目录 | 路径 |
|------|------|
| 根目录 | `/eda_tools/pkg/innovus/lnx86` |
| bin | `/eda_tools/pkg/innovus/lnx86/bin` |
| doc | `/eda_tools/pkg/innovus/lnx86/doc` |
| tools | `/eda_tools/pkg/innovus/lnx86/tools` (symlink) |
| tools.lnx86 | `/eda_tools/pkg/innovus/lnx86/tools.lnx86` |
| share | `/eda_tools/pkg/innovus/lnx86/share` |
| etc | `/eda_tools/pkg/innovus/lnx86/etc` |

## 可执行文件 (bin 目录)

| 文件 | 说明 |
|------|------|
| innovus | 主程序 - 布局布线工具 |
| genus | 综合工具 (如果存在) |
| tempus | 时序分析工具 (如果存在) |
| voltus | 功耗分析工具 (如果存在) |
| [其他工具] | (目录包含大量可执行文件) |

## 文档目录

| 目录 | 路径 |
|------|------|
| 主文档 | `/eda_tools/pkg/innovus/lnx86/doc` |
| 共享文档 | `/eda_tools/pkg/innovus/lnx86/share/doc` |

### 主要文档子目录

| 目录 | 说明 |
|------|------|
| `docindex` | 文档索引 |
| `cdsdoc` | Cadence 文档 |
| `cpf_user` | CPF 用户文档 |
| `cpf_ref` | CPF 参考文档 |

## 环境设置

```bash
export INNOVUS_HOME=/eda_tools/pkg/innovus/lnx86
export PATH=$INNOVUS_HOME/bin:$PATH
export LD_LIBRARY_PATH=$INNOVUS_HOME/tools.lnx86/lib:$LD_LIBRARY_PATH
```

或使用 Cadence ISF 设置脚本（如果存在）。

## 用途

Innovus 是 Cadence 的布局布线工具，用于：
- 物理综合
- placement (布局)
- routing (布线)
- 时序优化
- 功耗优化
- DRC/LVS 检查

## 相关工具

| 工具 | 用途 |
|------|------|
| Genus | 逻辑综合 |
| Tempus | 时序签核分析 |
| Voltus | 功耗分析 |