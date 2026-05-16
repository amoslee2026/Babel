---
module: M03
type: verification
status: complete
---

# M03_DRAMController — 验证规范

## 1. 功能覆盖点

### 1.1 读写带宽

| 覆盖点 | 目标 | 验证方法 |
|--------|------|----------|
| 持续读带宽 | >= 10 GB/s | 128B burst × 1000 次，统计吞吐 |
| 持续写带宽 | >= 10 GB/s | 128B burst × 1000 次，统计吞吐 |
| 读写混合带宽 | >= 10 GB/s | 50%读/50%写交替，统计合计 |
| 写缓冲满反压 | 正确反压 | 填满 8 条目写��冲，检查 awready=0 |

### 1.2 延迟

| 覆盖点 | 目标 | 验证方法 |
|--------|------|----------|
| Row-hit 读延迟 | <= 100 ns | 连续访问同一行，测量 AR→R 延迟 |
| Row-miss 读延迟 | 记录基线 | 随机地址访问，测量含 PRECHARGE+ACT |
| 写响应延迟 | 记录基线 | 测量 AW→B 延迟 |

### 1.3 刷新

| 覆盖点 | 目标 | 验证方法 |
|--------|------|----------|
| 定期刷新触发 | 每 3.9 us 一次 | 监控 REF 命令间隔 |
| 刷新推迟 | 最多 8 次 | 连续阻塞刷新，验证第 9 次强制执行 |
| 刷新期间无读写 | 无命令冲突 | 断言 tRFC 期间 CMD 总线空闲 |
| 自刷新进入/退出 | 正确握手 | 写 DRAM_CTRL[1]=1，验证 CKE 拉低 |

### 1.4 ECC

| 覆盖点 | 目标 | 验证方法 |
|--------|------|----------|
| 单比特错误纠正 | 自动纠正 | 注入 1-bit 翻转，验证读回数据正确 |
| 单比特错误记录 | ECC_STATUS[0]=1 | 检查 SBE 标志置位 |
| 双比特错误检测 | 中断上报 | 注入 2-bit 翻转，验证 DBE 标志+中断 |
| ECC 禁用模式 | 透传数据 | DRAM_CTRL[2]=0，验证无 ECC 开销 |
| 全零/全一数据 | 无误报 | 写入 0x00/0xFF 模式，验证 ECC 无误 |

### 1.5 D2D 协议

| 覆盖点 | 目标 | 验证方法 |
|--------|------|----------|
| 命令/地址奇偶校验 | 无误传输 | 检查 ca_parity 信号正确性 |
| DQS 训练 | PHY 锁定 | 上电后 DQS 对齐完成标志 |
| alert_n 响应 | 正确处理 | 拉低 alert_n，验证控制器暂停并上报 |
| Round-trip 延迟 | <= 100 ns | 测量 CMD 发出到 DQ 返回时间 |

---

## 2. 断言（SVA）

```systemverilog
// 断言1：ACTIVATE 后必须等待 tRCD 才能发 READ/WRITE
property p_tRCD;
  @(posedge clk) (state == ACTIVATE) |->
    ##[tRCD_cycles:$] (state == READ || state == WRITE);
endproperty
assert property (p_tRCD);

// 断言2：刷新间隔不超过 tREFI × 9（最多推迟 8 次）
property p_refresh_max_defer;
  @(posedge clk) $rose(refresh_req) |->
    ##[0:tREFI_cycles*9] $rose(refresh_ack);
endproperty
assert property (p_refresh_max_defer);

// 断言3：ECC 双比特错误必须触发中断
property p_dbe_irq;
  @(posedge clk) $rose(ecc_dbe) |-> ##[0:4] $rose(irq_ecc);
endproperty
assert property (p_dbe_irq);

// 断言4：写缓冲满时 awready 必须为低
property p_wr_buf_backpressure;
  @(posedge clk) (wr_buf_full) |-> !axi_awready;
endproperty
assert property (p_wr_buf_backpressure);

// 断言5：tRFC 期间 D2D CMD 总线空闲
property p_rfc_cmd_idle;
  @(posedge clk) (state == REFRESH) |-> (d2d_cmd == CMD_NOP);
endproperty
assert property (p_rfc_cmd_idle);
```

---

## 3. 仿真场景

| 场景 ID | 名称 | 描述 | 通过标准 |
|---------|------|------|----------|
| SIM_01 | 上电初始化 | 复位释放后完成 200 us 初始化序列 | IDLE 状态，DQS 训练完成 |
| SIM_02 | 顺序读 | 256 次连续地址读，BL8 | 带宽 >= 10 GB/s，数据正确 |
| SIM_03 | 顺序写 | 256 次连续地址写，BL8 | 带宽 >= 10 GB/s，写响应 OKAY |
| SIM_04 | 随机读写 | 1000 次随机地址读写混合 | 无数据错误，无死锁 |
| SIM_05 | Row-hit 延迟 | 连续访问同一行 100 次 | 延迟 <= 100 ns |
| SIM_06 | ECC 单比特注入 | 随机位置注入 1-bit 翻转 × 100 | 全部自动纠正，SBE 计数正确 |
| SIM_07 | ECC 双比特注入 | 注入 2-bit 翻转 × 10 | DBE 标志置位，中断触发 |
| SIM_08 | 刷新推迟压力 | 连续阻塞刷新 8 次后释放 | 第 9 次强制刷新，无数据损坏 |
| SIM_09 | 自刷新进入退出 | 写 SELF_REFRESH=1 后恢复 | CKE 正确，退出后可正常访问 |
| SIM_10 | D2D alert_n | 拉低 alert_n 信号 | 控制器暂停，上报状态寄存器 |
| SIM_11 | 写缓冲满反压 | 快速写直到缓冲满 | awready 正确反压，无数据丢失 |
| SIM_12 | 带宽压力测试 | 读写同时满负荷 1 ms | 合计带宽 >= 10 GB/s |
