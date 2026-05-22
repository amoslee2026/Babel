# Open-Source EDA Toolchain - User Guide

本文档提供各开源EDA工具的使用指南和典型工作流程示例。

---

## 1. Yosys - RTL综合

### 1.1 基本使用

```bash
# 启动Yosys交互模式
yosys

# 综合Verilog文件
yosys -p "read_verilog design.v; synth; write_verilog synthesized.v"
```

### 1.2 典型综合脚本

创建 `synth.ys` 脚本文件：

```tcl
# synth.ys - Yosys综合脚本示例

# 读取Verilog设计
read_verilog design.v

# 语法检查
hierarchy -check

# 高层次综合优化
proc
opt
fsm
opt
memory
opt

# 逻辑优化
techmap
opt

# 映射到目标库
dfflibmap -liberty /path/to/library.lib
abc -liberty /path/to/library.lib

# 清理
clean

# 输出网表
write_verilog -noattr design_synth.v
write_edif design.edif
```

执行：

```bash
yosys synth.ys
```

### 1.3 常用命令

| 命令 | 功能 |
|------|------|
| `read_verilog` | 读取Verilog文件 |
| `synth` | 完整综合流程 |
| `hierarchy -check` | 模块层次检查 |
| `proc` | 进程转换 |
| `opt` | 优化 |
| `techmap` | 技术映射 |
| `abc` | ABC综合 |
| `dfflibmap` | 触发器映射 |
| `write_verilog` | 输出Verilog |
| `write_edif` | 输出EDIF |

### 1.4 可综合性检查

Yosys可以检测不可综合的代码：

```bash
yosys -p "read_verilog -sv design.v; hierarchy -check; proc; check"
```

---

## 2. Magic - 布局编辑与DRC/LVS

### 2.1 启动Magic

```bash
# 图形界面模式
magic design.mag

# 命令行模式（无显示）
magic -dnull -noconsole design.mag

# 使用虚拟显示
xvfb-run magic design.mag
```

### 2.2 常用命令

在Magic命令窗口中：

```
# 加载技术文件
tech load sky130A

# 绘制矩形
box 0 0 100 200
paint metal1

# DRC检查
drc check
drc find

# 提取网表用于LVS
extract all
ext2spice design.ext

# 保存布局
save design.mag
writeall force

# 导出GDS
gds write design.gds
```

### 2.3 DRC脚本示例

创建 `drc_check.tcl`：

```tcl
# DRC检查脚本
tech load sky130A
drc on
drc catchup
drc count
drc find
quit
```

执行：

```bash
magic -dnull -noconsole design.mag < drc_check.tcl
```

---

## 3. Netgen - LVS验证

### 3.1 基本使用

```bash
# 比较两个网表
netgen -lvs layout.spice schematic.spice
```

### 3.2 LVS脚本

创建 `lvs.tcl`：

```tcl
# LVS脚本
readnet spice layout.spice
readnet verilog schematic.v
lvs layout schematic
report
quit
```

执行：

```bash
netgen -batch lvs.tcl
```

---

## 4. KLayout - GDSII查看与DRC

### 4.1 图形界面

```bash
# 打开GDS文件
klayout design.gds

# 批量模式
klayout -b design.gds
```

### 4.2 命令行工具

| 工具 | 功能 |
|------|------|
| `strm2gds` | 转换为GDSII |
| `strm2oas` | 转换为OASIS |
| `strm2cif` | 转换为CIF |
| `strm2dxf` | 转换为DXF |
| `strmcmp` | 比较两个布局 |
| `strmxor` | XOR比较 |
| `strmclip` | 裁剪布局 |
| `strmrun` | 运行脚本 |

### 4.3 DRC脚本示例

创建 `drc.rb` (Ruby)：

```ruby
# KLayout DRC脚本
input("design.gds")

# 定义规则
metal1.width(0.15.um).output("Metal1 min width")
metal1.space(0.15.um).output("Metal1 min spacing")
metal2.width(0.2.um).output("Metal2 min width")

# 输出报告
report("DRC Report")
```

执行：

```bash
klayout -b -r drc.rb design.gds -o drc_report.txt
```

---

## 5. OpenSTA - 静态时序分析

### 5.1 基本使用

```bash
# 启动STA
sta

# 运行脚本
sta timing.tcl
```

### 5.2 时序分析脚本

创建 `timing.tcl`：

```tcl
# OpenSTA脚本

# 读入库文件
read_liberty /path/to/library.lib

# 读入网表
read_verilog design_synth.v

# 设置顶层模块
link_design top_module

# 创建时钟
create_clock -name clk -period 10 [get_ports clk]

# 设置输入延迟
set_input_delay -clock clk 2 [get_ports input*]

# 设置输出延迟
set_output_delay -clock clk 3 [get_ports output*]

# 时序分析报告
report_timing
report_clocks
report_checks

# 输出SDC
write_sdc design.sdc
```

---

## 6. 完整设计流程示例

### 6.1 RTL到GDSII流程脚本

创建 `flow.sh`：

```bash
#!/bin/bash
# 完整设计流程

DESIGN="mychip"
LIB="/path/to/library.lib"

# Step 1: RTL综合
echo "=== Synthesis ==="
yosys -p "
    read_verilog ${DESIGN}.v
    hierarchy -check
    synth
    dfflibmap -liberty ${LIB}
    abc -liberty ${LIB}
    write_verilog ${DESIGN}_synth.v
"

# Step 2: 时序分析
echo "=== Timing Analysis ==="
sta timing.tcl

# Step 3: 布局 (使用Magic或其他工具)
echo "=== Placement ==="
# 需要手动进行或使用OpenROAD

# Step 4: DRC检查
echo "=== DRC ==="
magic -dnull -noconsole ${DESIGN}.mag < drc_check.tcl

# Step 5: LVS验证
echo "=== LVS ==="
netgen -lvs ${DESIGN}.spice ${DESIGN}_synth.v

# Step 6: 导出GDS
echo "=== Export GDS ==="
klayout -b ${DESIGN}.gds

echo "=== Flow Complete ==="
```

---

## 7. 常见问题解决

### 7.1 Magic无显示问题

```bash
# 使用虚拟显示
xvfb-run magic design.mag

# 或使用null显示模式
magic -dnull -noconsole design.mag
```

### 7.2 Yosys找不到模块

检查模块层次：

```tcl
hierarchy -check -top top_module
```

### 7.3 时序分析无时钟

确保正确设置时钟：

```tcl
create_clock -name clk -period 10 [get_ports clk]
```

### 7.4 KLayout库加载失败

设置LD_LIBRARY_PATH：

```bash
export LD_LIBRARY_PATH="$HOME/wrk/eda_opensources/install:$LD_LIBRARY_PATH"
```

---

## 8. 参考资源

- [Yosys Documentation](https://yosyshq.net/yosys/documentation.html)
- [Magic User's Manual](http://opencircuitdesign.com/magic/userguide.html)
- [KLayout Documentation](https://www.klayout.de/doc/)
- [OpenSTA Manual](https://parallaxsw.com/opensta.html)
- [OpenLane Tutorial](https://github.com/The-OpenROAD-Project/OpenLane/tree/master/docs)

---
*Chiplet Design Lab*
*Chiplet Design Practice*