# RV32IM CSR、Trap 与 SoC 中断体系设计

## 目标

在现有多周期 RV32I SoC 上一次性加入第一阶段 CPU 基础能力：

- 最小 Machine-mode CSR 集合。
- 异常入口、`ECALL`、`EBREAK`、`MRET` 和 `WFI`。
- Timer、DMA、UART 中断接入 CPU。
- RV32M 乘除法扩展。
- 保持现有外部 CPU 接口和既有测试兼容。

## 当前基线

当前 `riscv_core` 使用 `FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK → FAULT` 多周期状态机，支持 RV32I，但没有 CSR、Trap、中断和 M 扩展。Timer 只有顶层 `timer_irq` 输出，DMA 只有状态寄存器，UART 没有 CPU 中断输出。`soc_top` 默认使用外部 CPU 请求，内部 CPU 通过 `INTERNAL_CPU=1` 启用。

## 方案

采用模块化方案，而不是把全部功能继续堆入一个文件：

```text
riscv_core
 ├── riscv_decoder
 ├── riscv_alu
 ├── riscv_regfile
 ├── riscv_csr
 └── riscv_muldiv

Timer ───────┐
DMA ─────────┼─> irq_controller ─> CPU irq_timer/irq_external
UART ────────┘
```

`riscv_core` 仍然负责总体时序和状态转移；`riscv_csr` 只负责 CSR 存储、CSR 指令语义和 Trap 状态；`riscv_muldiv` 负责 M 扩展运算；`irq_controller` 负责外部源的使能、pending 和清除。

## CSR 设计

第一版只实现 Machine Mode，支持以下 CSR：

| CSR | 地址 | 说明 |
|---|---:|---|
| `mstatus` | `0x300` | `MIE`、`MPIE`、`MPP` 基本状态 |
| `mie` | `0x304` | `MTIE`、`MEIE`、`MSIE` |
| `mtvec` | `0x305` | Direct Trap 入口，低两位固定为 0 |
| `mscratch` | `0x340` | 软件临时寄存器 |
| `mepc` | `0x341` | Trap 返回 PC |
| `mcause` | `0x342` | Trap 原因 |
| `mtval` | `0x343` | 异常附加信息 |
| `mip` | `0x344` | `MTIP`、`MEIP`、`MSIP` pending |
| `cycle` | `0xC00` | 递增周期计数 |
| `time` | `0xC01` | 与 cycle 同步的简化时间计数 |

支持指令：

```text
CSRRW  CSRRS  CSRRC
CSRRWI CSRRSI CSRRCI
ECALL  EBREAK MRET WFI
```

`WFI` 第一版采用可唤醒等待语义：CPU 停止发起新的 memory request，直到可屏蔽中断到来；不引入额外低功耗时钟门控。

## Trap 语义

Trap 进入时：

```text
mepc       <= 当前指令 PC
mcause     <= {interrupt, cause_code}
mtval      <= 指令、地址或 0
mstatus.MPIE <= mstatus.MIE
mstatus.MIE  <= 0
PC           <= mtvec & 32'hffff_fffc
```

`MRET` 执行时：

```text
mstatus.MIE  <= mstatus.MPIE
mstatus.MPIE <= 1
PC            <= mepc
```

异常编码：

| Code | 含义 |
|---:|---|
| `0` | Instruction Address Misaligned |
| `2` | Illegal Instruction |
| `4` | Load Address Misaligned |
| `5` | Load Bus Error |
| `6` | Store Address Misaligned |
| `7` | Store Bus Error |
| `8` | Environment Call from M-mode |
| `11` | Breakpoint |

中断编码：

| Code | 含义 |
|---:|---|
| `3` | Machine Software Interrupt |
| `7` | Machine Timer Interrupt |
| `11` | Machine External Interrupt |

兼容规则：当 `mtvec == 0` 时，既有非法指令、非对齐访问和总线错误继续进入当前 `halted/fault_code` 路径；配置非零 `mtvec` 后才进入 Trap Handler。这样不会改变现有 CPU 和顶层 smoke 测试的预期。

## 中断设计

新增 `irq_controller`，放在 SoC 系统域。APB 地址窗口为：

```text
0x4000_7000 ~ 0x4000_7FFF
```

寄存器：

| Offset | 名称 | 说明 |
|---|---|---|
| `0x00` | `IRQ_ENABLE` | bit0 Timer、bit1 DMA、bit2 UART |
| `0x04` | `IRQ_PENDING` | 当前 pending 状态，只读 |
| `0x08` | `IRQ_CLEAR` | 写 1 清除控制器 latch |
| `0x0C` | `IRQ_STATUS` | enable、pending 和输出状态 |

Timer 输出连接到 `mip.MTIP`。DMA 和 UART 通过控制器汇聚到 `mip.MEIP`。外部中断为固定优先级，软件通过外设状态寄存器确定具体来源。

中断源语义：

- Timer：保留现有 sticky timer status，并作为 MTIP 输入。
- DMA：完成、配置错误或总线错误置位 DMA IRQ；原有状态寄存器清除语义不变。
- UART：RX FIFO 非空、帧错误或溢出触发 UART IRQ；增加 UART 控制位允许软件屏蔽。

## RV32M 设计

新增 `riscv_muldiv` 模块，支持：

```text
MUL MULH MULHSU MULHU
DIV DIVU REM REMU
```

乘法先使用 32×32→64 位运算，便于映射到 FPGA DSP；除法采用 32 次迭代的 non-restoring 算法。CPU 增加：

```text
MEXT_START → MEXT_WAIT → WRITEBACK
```

除法边界遵循 RISC-V：

- 除零时 `DIV/DIVU = 0xffffffff`。
- 除零时 `REM/REMU = dividend`。
- `INT_MIN / -1 = INT_MIN`，余数为 0。

## 接口兼容

`riscv_core` 仅增加：

```systemverilog
input logic irq_timer;
input logic irq_external;
```

原有 memory request/response、`halted`、`fault_code` 和 `dbg_pc` 保持不变。`soc_top` 为新增中断端口提供内部连接；旧 testbench 未连接的可选顶层端口不改变既有测试流程。

## 测试策略

新增测试：

```text
tb/cpu/tb_riscv_csr.sv
tb/cpu/tb_riscv_trap.sv
tb/cpu/tb_riscv_muldiv.sv
tb/peripheral/tb_irq_controller.sv
tb/top/tb_soc_irq.sv
tb/top/tb_soc_rv32im.sv
```

测试覆盖：

- CSR 读写、置位、清零和只读计数器。
- `ECALL`、`EBREAK`、`MRET`、`WFI`。
- 非法指令、非对齐访问、总线错误 Trap。
- Timer、DMA、UART 中断使能、pending、清除和屏蔽。
- 所有 RV32M 指令、负数、除零和 `INT_MIN/-1`。
- 原有 26 个测试继续通过。
- 新增测试与完整 `sim/run_tests.ps1 -Test all` 回归通过。

## 非目标

本阶段不实现：

- Supervisor/User Mode。
- PLIC/CLINT 的完整标准实现。
- 向量扩展。
- 流水线和乱序执行。
- 中断嵌套。
- 真实 FPGA 时钟约束和 XDC。

这些内容留到后续阶段。
