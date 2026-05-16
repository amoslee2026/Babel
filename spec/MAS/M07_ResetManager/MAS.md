---
module: M07
type: MAS
status: complete
parent: TOP
module_type: io
generated: 2026-05-12T09:20:00Z
---

# M07 ResetManager — 模块架构规范

## 1. 模块概述

ResetManager 负责 TinyStories NPU 的全局与局部复位管理。运行于 CLK_AON（32 KHz）时钟域，归属 PD_AON 电源域，在整个芯片生命周期内���续上电。

主要职责：
- 检测并消抖上电复位（POR）信号
- 接收软件复位请求（寄存器写触发）
- 接收看门狗超时复位请求（WDT）
- 生成同步后的全局复位 `rst_global_n` 及局部复位 `rst_main_n`、`rst_sys_n`
- 维护复位状态寄存器供软件查询

工艺：Samsung SF4 4nm，标准单元库 SC9T_LL。

---

## 2. 接口信号表

| 信号名           | 位宽 | 方向 | 时钟域    | 描述                          |
|-----------------|------|------|-----------|-------------------------------|
| clk_aon         | 1    | in   | CLK_AON   | 32 KHz 常开时钟               |
| por_n           | 1    | in   | async     | 上电复位，低有效，来自 PMU    |
| wdt_rst_req     | 1    | in   | CLK_AON   | 看门狗超时复位请求            |
| sw_rst_req      | 1    | in   | CLK_AON   | 软件复位请求（寄存器触发）    |
| rst_global_n    | 1    | out  | CLK_AON   | 全局复位，低有效              |
| rst_main_n      | 1    | out  | CLK_AON   | 主域复位（PD_MAIN），低有效   |
| rst_sys_n       | 1    | out  | CLK_AON   | 系统总线复位，低有效          |
| apb_psel        | 1    | in   | CLK_AON   | APB 片选                      |
| apb_penable     | 1    | in   | CLK_AON   | APB 使能                      |
| apb_pwrite      | 1    | in   | CLK_AON   | APB 写使能                    |
| apb_paddr       | 8    | in   | CLK_AON   | APB 地址（字节地址）          |
| apb_pwdata      | 32   | in   | CLK_AON   | APB 写数据                    |
| apb_prdata      | 32   | out  | CLK_AON   | APB 读数据                    |
| apb_pready      | 1    | out  | CLK_AON   | APB 就绪                      |
| scan_mode       | 1    | in   | —         | DFT 扫描模式使能              |
| scan_rst_n      | 1    | in   | —         | DFT 扫描复位                  |

---

## 3. 复位源列表

| 复位源       | 触发条件                          | 优先级 | 影响范围                        |
|-------------|-----------------------------------|--------|---------------------------------|
| POR         | `por_n` 低电平（上电或掉电恢复）  | 最高   | rst_global_n + rst_main_n + rst_sys_n |
| WDT 复位    | `wdt_rst_req` 高脉冲              | 次高   | rst_global_n + rst_main_n + rst_sys_n |
| 软件复位    | RST_CTRL[SW_RST]=1                | 最低   | 可配置（RST_CTRL[SCOPE]）       |

---

## 4. 复位序列（上电流程）

```
t0  por_n 拉低（PMU 检测到 VDD 上升）
t1  ResetManager 进入 POR_ASSERT 状态，所有复位输出拉低
t2  por_n 拉高（VDD 稳定）
t3  消抖计数器启动（16 个 CLK_AON 周期 ≈ 500 µs）
t4  消抖完成，进入 POR_RELEASE 状态
t5  rst_global_n 同步释放（2-FF 同步器）
t6  延迟 8 CLK_AON 后释放 rst_main_n
t7  延迟 4 CLK_AON 后释放 rst_sys_n
t8  进入 RUNNING 状态，复位序列完成
```

---

## 5. 寄存器列表

基地址：由 SoC 地址映射决定，APB 偏移如下。

### RST_CTRL（偏移 0x00，RW）

| 位域     | 位  | 访问 | 复位值 | 描述                                      |
|---------|-----|------|--------|-------------------------------------------|
| SW_RST  | 0   | W1S  | 0      | 写 1 触发软件复位，自动清零               |
| SCOPE   | 2:1 | RW   | 2'b11  | 复位范围：00=仅sys，01=main+sys，11=全局  |
| WDT_EN  | 3   | RW   | 1      | WDT 复位使能                              |
| RSVD    | 31:4| RO   | 0      | 保留                                      |

### RST_STATUS（偏移 0x04，RO）

| 位域        | 位  | 访问 | 复位值 | 描述                        |
|------------|-----|------|--------|-----------------------------|
| POR_FLAG   | 0   | RO   | 1      | 上次复位由 POR 触发         |
| WDT_FLAG   | 1   | RO   | 0      | 上次复位由 WDT 触发         |
| SW_FLAG    | 2   | RO   | 0      | 上次复位由软件触发          |
| RST_ACTIVE | 3   | RO   | —      | 当前复位输出状态（任一有效）|
| RSVD       | 31:4| RO   | 0      | 保留                        |

写 RST_CTRL[SW_RST]=1 可清除 RST_STATUS 标志位。

### WDT_CFG（偏移 0x08，RW）

| 位域        | 位   | 访问 | 复位值     | 描述                              |
|------------|------|------|------------|-----------------------------------|
| WDT_PERIOD | 15:0 | RW   | 16'hFFFF   | 看门狗超时周期（CLK_AON 计数）    |
| WDT_KICK   | 16   | W1S  | 0          | 写 1 喂狗，自动清零               |
| WDT_LOCK   | 17   | RW   | 0          | 写 1 锁定 WDT_PERIOD，需 POR 解锁 |
| RSVD       | 31:18| RO   | 0          | 保留                              |
