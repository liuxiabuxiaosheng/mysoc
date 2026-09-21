# Phase 8 RV32IM、CSR、Trap 与 SoC 中断验证

日期：2026-09-20  
状态：已实现并通过 Icarus Verilog 仿真

## 实现范围

本阶段在原多周期 RV32I CPU 上增加：

- Machine-mode CSR：`mstatus`、`mie`、`mtvec`、`mscratch`、`mepc`、`mcause`、`mtval`、`mip`、`cycle`、`time`。
- CSR 指令：`CSRRW/CSRRS/CSRRC` 及立即数版本。
- System 指令：`ECALL`、`EBREAK`、`MRET`、`WFI`。
- Direct Trap 入口和 Machine Timer/External Interrupt。
- RV32M：`MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU`。
- APB IRQ Controller，基址 `0x4000_7000`。
- Timer、DMA、UART IRQ 源。

## Trap 和中断行为

当 `mtvec != 0` 且中断使能满足条件时，CPU 保存 `mepc/mcause/mtval`，清除 `mstatus.MIE`，跳转到 `mtvec`。`MRET` 恢复 `MIE` 并返回 `mepc`。

为保持旧验证兼容，`mtvec == 0` 时非法指令、非对齐访问和总线错误仍进入原有 `halted/fault_code` 路径。

IRQ Controller 寄存器：

| Offset | 功能 |
|---|---|
| `0x00` | IRQ_ENABLE，bit0 Timer、bit1 DMA、bit2 UART |
| `0x04` | IRQ_PENDING，只读 |
| `0x08` | IRQ_CLEAR，写 1 清 pending |
| `0x0C` | IRQ_STATUS |

Timer 输出 `MTIP`；DMA Done/Error 和 UART RX/Error 汇聚为 `MEIP`。

## RV32M 边界

- 乘法返回低 32 位或高 32 位，支持 signed/unsigned 组合。
- 除法使用 32 次迭代状态机。
- 除零时 `DIV/DIVU=0xffffffff`，`REM/REMU=dividend`。
- `INT_MIN/-1` 返回 `INT_MIN`，余数返回 0。

## 新增测试

```text
tb_riscv_csr
tb_riscv_trap
tb_riscv_muldiv
tb_irq_controller
tb_uart_irq
tb_soc_rv32im
tb_soc_irq
```

## 验证命令

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem @($rtl)
iverilog -g2012 -Wall -tnull -s soc_top @($rtl)
```

当前完整回归共 33 个测试，全部输出 `PASS`；两个顶层静态 elaboration 命令退出码为 0。Icarus 仍会对部分 `always_comb` 的常量选择报告 warning，不影响编译、仿真和验收结果。

## 阶段边界

本阶段未实现 Supervisor/User Mode、完整 PLIC/CLINT、向量扩展、流水线、中断嵌套和 XDC。UART IRQ 采用 RX 非空或 RX sticky error 的 level 语义，软件需要读取数据或清除错误后再清除 IRQ pending。
