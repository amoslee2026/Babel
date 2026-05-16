# Verilator

## 基本信息

| 属性 | 值 |
|------|-----|
| Vendor | Wilson Snyder |
| Version | 5.024 |
| 安装路径 | `/eda_tools/verilator/5.024` |
| 默认版本链接 | `/eda_tools/verilator/default` → `/eda_tools/verilator/5.024` |

## 可执行文件

| 文件 | 路径 | 说明 |
|------|------|------|
| verilator | `/eda_tools/verilator/5.024/bin/verilator` | 主程序 (Perl wrapper) |
| verilator_bin | `/eda_tools/verilator/5.024/bin/verilator_bin` | 核心二进制 (10.6MB) |
| verilator_coverage | `/eda_tools/verilator/5.024/bin/verilator_coverage` | 覆盖率分析 |
| verilator_coverage_bin_dbg | `/eda_tools/verilator/5.024/bin/verilator_coverage_bin_dbg` | 覆盖率调试版本 (1.3MB) |

## 文档目录

| 目录 | 路径 |
|------|------|
| 文档 | `/eda_tools/verilator/5.024/share/` |

## 环境设置

```bash
source /eda_tools/verilator/5.024/setup.sh
```

或手动设置：

```bash
export PATH=/eda_tools/verilator/5.024/bin:$PATH
```

## 用途

Verilator 是开源的 Verilog/SystemVerilog 仿真器，将 RTL 代码编译为 C++ 代码进行高速仿真。常用于：
- RTL 功能验证
- 覆盖率分析
- 与 C++ 测试平台集成