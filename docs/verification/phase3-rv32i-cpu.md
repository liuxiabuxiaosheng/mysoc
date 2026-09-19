# Phase 3 RV32I CPU Verification

日期：2026-09-19

## 实现范围

本阶段加入模块化、非流水线、多周期 RV32I CPU：

- `rtl/cpu/riscv_core.sv`：FETCH、DECODE、EXECUTE、MEMORY、WRITEBACK、FAULT 状态机。
- `rtl/cpu/riscv_decoder.sv`：LUI/AUIPC、算术逻辑、移位、比较、分支、跳转和访存译码。
- `rtl/cpu/riscv_alu.sv`：加减、逻辑、移位及有符号/无符号比较。
- `rtl/cpu/riscv_imm_gen.sv`：I/S/B/U/J 立即数。
- `rtl/cpu/riscv_regfile.sv`：32×32 寄存器堆，x0 恒为零。
- `rtl/cpu/riscv_control.sv`：控制平面预留模块。

CPU 通过阶段二的单 outstanding request/response 总线访问 BRAM 和 APB。`soc_top` 增加 `INTERNAL_CPU` 参数；默认值为 0，保持原外部 CPU 总线行为不变，仿真时设为 1 可运行内部 CPU。

## 可重复验证命令

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test riscv_units
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test riscv_core
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test riscv_faults
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_cpu
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

## 已覆盖行为

- ALU 加减、比较、逻辑和移位。
- I/S/B/U/J 立即数提取。
- x0 不可写且始终读取为零。
- 算术指令、循环/条件分支、BRAM `SW/LW`、GPIO APB 写入。
- LUI/AUIPC、JAL/JALR 的执行路径已包含在核心译码和状态机中。
- 非法指令 fault code `1`。
- 半字/字非对齐访问 fault code `2`，且不发起数据请求。
- 总线 error fault code `3`。
- SoC 内部程序将 `0x5A` 写入 GPIO，并将 `0x12345678` 写入 BRAM 后进入非法指令停机。

Icarus 的 `always_comb` 常量选择提示为仿真器兼容性 warning，不影响编译、仿真结果或验收命令返回值。

## 阶段边界

本阶段仍未实现乘除法、CSR、中断、Cache、流水线、DMA、固件构建工具和 FPGA 时钟/约束流程。
