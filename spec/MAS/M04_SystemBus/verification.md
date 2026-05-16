---
module: M04
type: verification
status: complete
parent: MAS
generated: 2026-05-12T09:20:00Z
---

# M04_SystemBus - 验证计划

## 功能覆盖点

### 1. 仲裁公平性

| Coverage Point | Description | Target |
|----------------|-------------|--------|
| RR_SEQUENCE | 4个 master 按 Round-Robin 顺序获得授权 | 100% |
| PRIORITY_OVERRIDE | 优先级模式下高优先级 master 优先 | 100% |
| STARVATION_FREE | 任意 master 等待时间 < 100 cycles | 100% |
| CONCURRENT_REQ | 2/3/4 个 master 同时请求 | 100% |

### 2. 带宽验证

| Coverage Point | Description | Target |
|----------------|-------------|--------|
| BW_M00_40PCT | M00 占用带宽 35%-45% | 95% |
| BW_M01_20PCT | M01 占用带宽 15%-25% | 95% |
| BW_M02_30PCT | M02 占用带宽 25%-35% | 95% |
| BW_M03_10PCT | M03 占用带宽 5%-15% | 95% |
| BW_TOTAL_10GBPS | 总带宽 >= 10 GB/s | 100% |

### 3. 协议合规性

| Coverage Point | Description | Target |
|----------------|-------------|--------|
| AXI_HANDSHAKE | valid/ready 握手符合 AXI4 规范 | 100% |
| ADDR_DECODE | 地址正确路由到 SRAM/DRAM | 100% |
| BURST_LENGTH | 支持 1-16 burst | 100% |
| OUTSTANDING_TXN | 支持最多4个未完成事务 | 100% |

### 4. 死锁检测

| Coverage Point | Description | Target |
|----------------|-------------|--------|
| TIMEOUT_TRIGGER | 超时机制在 16 cycles 触发 | 100% |
| DEADLOCK_DETECT | BUS_STATUS.deadlock_detect 正确置位 | 100% |
| SW_RESET_RECOVERY | 软件复位恢复正常 | 100% |

## 断言 (Assertions)

### SVA 断言列表

```systemverilog
// 1. 仲裁互斥性
property arb_mutex;
    @(posedge clk) $onehot0({grant_m00, grant_m01, grant_m02, grant_m03});
endproperty
assert_arb_mutex: assert property (arb_mutex);

// 2. 握手协议
property axi_handshake;
    @(posedge clk) (awvalid && awready) |-> ##1 wvalid;
endproperty
assert_axi_handshake: assert property (axi_handshake);

// 3. 超时检测
property timeout_check;
    @(posedge clk) (state == TRANSFER) |-> ##[1:16] (state == RELEASE or state == ERROR);
endproperty
assert_timeout: assert property (timeout_check);

// 4. 地址对齐
property addr_aligned;
    @(posedge clk) awvalid |-> (awaddr[4:0] == 5'b0);  // 32-byte aligned
endproperty
assert_addr_aligned: assert property (addr_aligned);

// 5. FIFO 不溢出
property fifo_no_overflow;
    @(posedge clk) wfifo_full |-> !wvalid;
endproperty
assert_fifo_overflow: assert property (fifo_no_overflow);
```

## 仿真场景

### Scenario 1: Round-Robin 基本测试

**目标:** 验证4个 master 轮流获得总线访问权。

**步骤:**
1. 4个 master 同时发起请求
2. 观察授权顺序：M00 → M01 → M02 → M03 → M00
3. 每个 master 完成1次传输后释放
4. 检查 rr_ptr 正确更新

**预期结果:** 每个 master 获得1次授权，顺序正确。

### Scenario 2: 优先级仲裁测试

**目标:** 验证优先级模式下高优先级 master 优先。

**步骤:**
1. 配置 ARB_CFG: M00=3, M01=2, M02=1, M03=0
2. 设置 BUS_CTRL.arb_mode = 1
3. 4个 master 同时请求
4. 观察授权顺序：M00 → M01 → M02 → M03

**预期结果:** 高优先级 master 先获得授权。

### Scenario 3: 带宽压力测试

**目标:** 验证总带宽 >= 10 GB/s。

**步骤:**
1. 4个 master 持续发起最大 burst (16 cycles)
2. 运行 1ms 仿真时间
3. 读取 BW_COUNTER_Mx 寄存器
4. 计算总带宽

**预期结果:** 总带宽 >= 10 GB/s，各 master 带宽符合分配比例。

### Scenario 4: 死锁恢复测试

**目标:** 验证超时机制和软件复位。

**步骤:**
1. M00 发起传输但 slave 不响应 ready
2. 等待 16 cycles
3. 检查 BUS_STATUS.deadlock_detect = 1
4. 写 BUS_CTRL.sw_reset = 1
5. 检查状态机回到 IDLE

**预期结果:** 超时触发，软件复位成功恢复。

### Scenario 5: 地址解码测试

**目标:** 验证地址正确路由到 SRAM/DRAM。

**步骤:**
1. M00 访问 0x0000_0000 (SRAM)
2. M01 访问 0x8000_0000 (DRAM)
3. 检查 slave_sel 信号
4. 验证数据路由到正确 slave

**预期结果:** SRAM 地址路由到 S0，DRAM 地址路由到 S1。

## 随机化测试

### UVM 测试环境

```systemverilog
class bus_transaction extends uvm_sequence_item;
    rand bit [1:0] master_id;
    rand bit [31:0] addr;
    rand bit [255:0] data;
    rand bit [3:0] burst_len;
    rand bit rw;  // 0=read, 1=write
    
    constraint addr_range {
        addr inside {[32'h0000_0000:32'h0FFF_FFFF],  // SRAM
                     [32'h8000_0000:32'h8FFF_FFFF]}; // DRAM
    }
    
    constraint burst_len_c {
        burst_len inside {[1:16]};
    }
endclass
```

### 随机场景

1. **Random Traffic:** 4个 master 随机发起读写请求，运行 10000 cycles
2. **Burst Mix:** 混合 burst 长度 (1/4/8/16)，验证流水线正确性
3. **Address Stress:** 随机地址访问，验证地址解码
4. **Back-to-Back:** 连续无间隙传输，验证最大带宽

## 覆盖率目标

| Metric | Target |
|--------|--------|
| Line Coverage | >= 95% |
| Branch Coverage | >= 90% |
| FSM Coverage | 100% |
| Functional Coverage | >= 95% |
| Assertion Pass Rate | 100% |

## 回归测试

### 每日回归

- Scenario 1-5 基本测试
- 随机化测试 (1000 cycles)
- 断言检查

### 完整回归

- 所有场景 + 随机化测试 (100000 cycles)
- 覆盖率报告
- 时序分析
- 功耗分析
