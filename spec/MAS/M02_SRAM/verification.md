---
module: M02
type: verification
status: complete
parent: MAS
generated: 2026-05-12T09:25:00Z
---

# M02_SRAM 验证规范

## 功能覆盖点

### 读写操作

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_RD_BASIC | 基本读操作，各 bank | 100% |
| COV_WR_BASIC | 基本写操作，各 bank | 100% |
| COV_RD_WR_SAME_ADDR | 写后立即读同地址 | 100% |
| COV_RD_ALL_BANKS | 读覆盖全部 4 个 bank | 100% |
| COV_WR_ALL_BANKS | 写覆盖全部 4 个 bank | 100% |
| COV_ADDR_BOUNDARY | 地址边界：0x00000, 0x1FFFF | 100% |
| COV_FULL_DATA | 全 0 / 全 1 / 随机数据 | 100% |

### ECC 功能

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_ECC_NO_ERR | 无错误读操作 | 100% |
| COV_ECC_SEC | 单比特错误自动纠正 | 100% |
| COV_ECC_DED | 双比特错误检测 | 100% |
| COV_ECC_SEC_ALL_BITS | 256 个数据位各翻转一次 | 100% |
| COV_ECC_DED_ALL_PAIRS | 任意两位同时翻转 | 10% (采样) |
| COV_ECC_PARITY_BIT | 校验位本身翻转 | 100% |

### Bank 冲突

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_BANK_CONFLICT_M00_M01 | M00 与 M01 同 bank 冲突 | 100% |
| COV_BANK_CONFLICT_M00_BUS | M00 与 Bus 同 bank 冲突 | 100% |
| COV_BANK_NO_CONFLICT | 不同 bank 并发访问 | 100% |
| COV_ARB_PRIORITY | 仲裁优先级验证 | 100% |

### 总线接口

| 覆盖点 | 描述 | 目标覆盖率 |
|--------|------|-----------|
| COV_BUS_RD | 总线读操作 | 100% |
| COV_BUS_WR | 总线写操作 | 100% |
| COV_BUS_TIMEOUT | 总线超时处理 | 100% |

## 断言

### 协议断言

```systemverilog
// 读使能和写使能不能同时有效
property p_no_rw_conflict;
    @(posedge clk) not (re && we);
endproperty
assert property (p_no_rw_conflict) else $error("RW conflict");

// ready 信号在操作完成后必须拉高
property p_ready_after_read;
    @(posedge clk) re |-> ##[1:4] ready;
endproperty
assert property (p_ready_after_read) else $error("Read timeout");

// ECC 错误时 ecc_err 必须有效
property p_ecc_err_valid;
    @(posedge clk) ready |-> ecc_err inside {2'b00, 2'b01, 2'b10};
endproperty
assert property (p_ecc_err_valid) else $error("Invalid ecc_err");

// 单比特纠正后数据必须正确
property p_sec_corrected;
    @(posedge clk) (ready && ecc_err == 2'b01) |->
        (rdata == expected_corrected_data);
endproperty
assert property (p_sec_corrected) else $error("SEC correction failed");

// 地址不超出范围
property p_addr_range;
    @(posedge clk) (re || we) |-> (addr <= 19'h1FFFF);
endproperty
assert property (p_addr_range) else $error("Address out of range");
```

### 功能断言

```systemverilog
// 写后读一致性
property p_write_read_consistency;
    logic [255:0] wr_data;
    @(posedge clk)
    (we, wr_data = wdata) |-> ##2 (re && addr == $past(addr, 2)) |-> ##2 (rdata == wr_data);
endproperty

// ECC 计数器单调递增
property p_ecc_cnt_monotonic;
    @(posedge clk) $stable(ECC_STATUS) || (ECC_STATUS >= $past(ECC_STATUS));
endproperty
assert property (p_ecc_cnt_monotonic) else $error("ECC counter decreased");
```

## 仿真场景

### 场景 1：基本读写

```
1. 复位
2. 写 addr=0x00000, data=0xDEADBEEF...
3. 读 addr=0x00000
4. 验证 rdata == wdata, ecc_err == 2'b00
```

### 场景 2：ECC 单比特纠正

```
1. 写 addr=0x00100, data=known_pattern
2. 强制翻转 SRAM 内部 bit[0]（通过 force 语句）
3. 读 addr=0x00100
4. 验证 rdata == known_pattern（已纠正）
5. 验证 ecc_err == 2'b01
6. 验证 ECC_STATUS.SEC_CNT 递增
```

### 场景 3：ECC 双比特检测

```
1. 写 addr=0x00200, data=known_pattern
2. 强制翻转 SRAM 内部 bit[0] 和 bit[1]
3. 读 addr=0x00200
4. 验证 ecc_err == 2'b10
5. 验证 ECC_STATUS.DED_CNT 递增
6. 验证 ECC_ADDR == 0x00200
```

### 场景 4：Bank 冲突仲裁

```
1. M00 请求读 bank 0
2. M01 同时请求读 bank 0
3. 验证 M00 先获得授权
4. 验证 M01 等待 1 cycle 后获得授权
5. 验证两次读数据均正确
```

### 场景 5：多 bank 并发

```
1. M00 读 bank 0
2. M01 读 bank 1（同时）
3. 验证两个请求均在 2 cycle 内完成
4. 验证无冲突
```

### 场景 6：边界地址

```
1. 写/读 addr=0x00000（最小地址）
2. 写/读 addr=0x1FFFF（最大地址）
3. 验证数据正确
```

### 场景 7：寄存器访问

```
1. 读 SRAM_CTRL，验证复位值
2. 写 SRAM_CTRL.ECC_EN=0，禁用 ECC
3. 写入数据，注入错误，读出
4. 验证 ecc_err 不变（ECC 已禁用）
5. 重新使能 ECC
```

## 覆盖率目标

| 类型 | 目标 |
|------|------|
| 行覆盖率 | 95% |
| 分支覆盖率 | 90% |
| 条件覆盖率 | 85% |
| 功能覆盖率 | 100% |
| 断言通过率 | 100% |
