# IP 分类与编号规则

**Version**: 1.0  
**Generated**: 2026-04-23

## 1. IP 分类体系

### 1.1 计算模块 IP (COMP)

| IP 类别 | 编码 | 特征 | 典型应用 |
|---------|------|------|----------|
| CPU Core | cpu_core | 通用计算、指令集架构 | RISC-V、ARM、x86 |
| GPU Core | gpu_core | 并行计算、图形渲染 | Shader Core、RT Core |
| NPU/TPU | ai_accel | AI推理/训练、矩阵运算 | 矩阵乘法、卷积加速 |
| DSP | dsp | 信号处理、FFT/FIR | 音频、通信 |
| Vector Unit | vector | SIMD/向量运算 | AVX、NEON、RISC-V V |
| Crypto Engine | crypto | 加解密、哈希 | AES、SHA、RSA |

### 1.2 访存模块 IP (MEM)

| IP 类别 | 编码 | 特征 | 典型应用 |
|---------|------|------|----------|
| SRAM Controller | sram_ctrl | 片上SRAM访问 | L1/L2 Cache |
| Cache Controller | cache_ctrl | Cache管理、一致性 | L1/L2/L3 |
| HBM Controller | hbm_ctrl | HBM2/3访问 | 高带宽内存 |
| DDR Controller | ddr_ctrl | DDR4/5访问 | 主存 |
| Coherence Controller | coherence | 跨die一致性 | CHI、CXL |
| NoC Router | noc_router |片上网络路由 | Mesh/NoC |

## 2. 编号规则

### 2.1 文档编号格式

```
IP-<Category>-<Serial>-<ShortCode>
```

| 字段 | 说明 | 示例 |
|------|------|------|
| Category | COMP/MEM/COMMON | COMP |
| Serial | 01-99 | 02 |
| ShortCode | 文档类型缩写 | MAS、PIPELINE、VERIFY |

### 2.2 实例编号格式

实例化文档增加项目前缀：
```
<Project>-IP-<Category>-<Serial>-<ShortCode>-v<Version>
```

示例：`MyChip-IP-COMP-02-MAS-npu_core-v0.1`

### 2.3 Testpoint 编号

```
TP-<IP_ID>-<Feature>-<Scenario>-<Serial>
```

示例：`TP-IP-COMP-02-EXEC-ALU-001`

## 3. 文档层级关系

```
                    DOC-D2-01-ARCH (系统架构)
                           │
                           ▼
                    DOC-D3-01-MAS (模块MAS)
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
    IP-COMP-XX-*    IP-MEM-XX-*    IP-COMMON-XX-*
    (计算IP文档)     (访存IP文档)    (共用文档)
```

## 4. 子模块编号

复杂 IP 内部子模块编号：

| 层级 | 编号格式 | 示例 |
|------|----------|------|
| Block级 | `<IP_ID>-BLK-<Name>` | IP-COMP-02-BLK-ALU |
| Sub-block级 | `<Block_ID>-SUB-<Name>` | IP-COMP-02-BLK-ALU-SUB-ADD |
| FSM级 | `<Block_ID>-FSM-<Name>` | IP-COMP-02-BLK-ALU-FSM-CTRL |

## 5. 寄存器编号

寄存器地址采用分层编码：

```
<BaseAddr> + <BlockOffset> + <RegOffset>
```

| 层级 | 位宽 | 说明 |
|------|------|------|
| BaseAddr | 16-bit | IP基地址 |
| BlockOffset | 8-bit | Block偏移 |
| RegOffset | 8-bit | 寄存器偏移 |

## 6. 版本管理

| 版本 | 含义 | 触发条件 |
|------|------|----------|
| 0.1-template | 模板 | 未实例化 |
| 0.1 | 初稿 | 实例化开始 |
| 0.5 | 评审 | 内容完整 |
| 1.0 | 冻结 | RTL对应版本锁定 |
| 1.1+ | 变更 | ECN 触发 |

## 7. 状态流转

```
template → draft → review → approved → frozen
                      │
                      ▼
                   deprecated
```

| 状态 | 说明 |
|------|------|
| template | 原始模板 |
| draft | 内容填写中 |
| review | 等待评审 |
| approved | 评审通过 |
| frozen | 版本锁定 |
| deprecated | 废弃（保留历史）|