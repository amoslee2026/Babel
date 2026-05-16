# Open-Source EDA Toolchain

清华大学集成电路学院芯粒设计实践课开源EDA工具链。

## 概述

本工具链提供完整的数字集成电路设计流程支持，从RTL综合到布局布线、时序分析、DRC/LVS验证。

## 安装位置

```
~/wrk/eda_opensources/install/
```

## 环境配置

```bash
source ~/wrk/eda_opensources/eda_env.sh
```

或添加到 shell 配置文件（~/.bashrc）：

```bash
# 开源EDA工具链
if [ -f ~/wrk/eda_opensources/eda_env.sh ]; then
    source ~/wrk/eda_opensources/eda_env.sh
fi
```

## 工具列表

| 工具 | 版本 | 功能 | 官方文档 |
|------|------|------|----------|
| ABC | latest | 逻辑优化与综合 | [ABC GitHub](https://github.com/berkeley-abc/abc) |
| Yosys | 0.35 | RTL综合 | [Yosys Manual](https://yosyshq.net/yosys/) |
| Magic | 8.3.641 | 布局编辑/DRC/LVS | [Magic Docs](http://opencircuitdesign.com/magic/) |
| Netgen | 1.5 | LVS网表比对 | [Netgen Docs](http://opencircuitdesign.com/netgen/) |
| QRouter | 1.4 | 详细布线 | [QRouter Docs](http://opencircuitdesign.com/qrouter/) |
| Graywolf | latest | 布局布线 | [Graywolf GitHub](https://github.com/rubberduck203/graywolf) |
| OpenSTA | 2.2.0 | 静态时序分析 | [OpenSTA Docs](https://parallaxsw.com/opensta.html) |
| KLayout | 0.30.8 | GDSII查看/编辑/DRC | [KLayout Docs](https://www.klayout.de/doc/) |

## 设计流程

```
RTL代码 ──► Yosys综合 ──► 门级网表
                              │
                              ▼
                        ABC优化
                              │
                              ▼
                    Magic/OpenROAD布局
                              │
                              ▼
                        QRouter布线
                              │
                              ▼
                      OpenSTA时序分析
                              │
                              ▼
                    Magic/KLayout DRC
                              │
                              ▼
                      Netgen LVS验证
                              │
                              ▼
                         GDSII输出
```

## 快速验证

```bash
# 验证所有工具是否可用
source ~/wrk/eda_opensources/eda_env.sh

yosys --version      # Yosys 0.35
magic --version      # Magic 8.3.641
netgen -v            # Netgen 1.5
sta --version        # OpenSTA 2.2.0
klayout --version    # KLayout 0.30.8
```

## 标准单元库

开源EDA工具链推荐以下标准单元库：

| 库 | 来源 | 工艺 | 说明 |
|----|------|------|------|
| SkyWater PDK | Google/SkyWater | SKY130 | 开源130nm PDK，包含标准单元 |
| OpenLane PDK | OpenROAD | 多种 | 集成多种开源PDK |
| Nangate Open Cell Library | Nangate | 45nm | 开源45nm标准单元库 |

获取SkyWater PDK：

```bash
# 安装SkyWater 130nm PDK
git clone https://github.com/google/skywater-pdk.git
cd skywater-pdk
make timing
```

## 相关链接

- [OpenROAD Project](https://theopenroadproject.org/) - 开源P&R平台
- [OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) - 自动化RTL-to-GDSII流程
- [SkyWater PDK](https://github.com/google/skywater-pdk) - 开源130nm PDK
- [Efabless](https://efabless.com/) - 开源芯片设计平台

## 注意事项

1. Magic和QRouter需要X11显示环境（或使用虚拟显示 `xvfb-run`）
2. 时序分析需要对应工艺的.lib文件
3. DRC/LVS需要对应工艺的规则文件
4. 批量处理推荐使用KLayout的命令行工具（strm*系列）

---
*文档生成时间: 2026-05-13*
*清华大学集成电路学院*