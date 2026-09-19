# Phase 6 FIR Verification

日期：2026-09-19

本阶段实现独立 16 阶定点 FIR 原语：16-bit signed Q1.15 输入与系数，40-bit
累加器，单样本流式 valid-ready 接口和可编程系数存储。

## 可重复验证命令

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test fir_filter
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

## 已验证行为

- Tap 0 使用新输入样本，Tap 1 至 Tap 15 使用历史样本。
- Q1.15 乘加、四舍五入、算术右移 15 位和 16-bit 饱和。
- 单位脉冲响应和多样本响应。
- 正饱和与负饱和。
- 输出 backpressure 下 `out_sample` 保持稳定，输入不会越过单项输出寄存器。
- 系数同步写入与复位后的历史清零。
- CPU、DMA、Async FIFO 和既有外设回归不受影响。

## 回归结果

完整回归返回退出码 0，新增测试输出：

```text
PASS tb_fir_filter
```

连同此前测试共 23 个 Testbench 通过；`soc_top` 顶层 Icarus null
elaboration 返回退出码 0。Icarus 对常量选择报告兼容性 warning，不影响编译
或仿真结果。

## 阶段边界

本阶段未实现 DMA/Async FIFO 音频链路、I2S、FFT、显示或 FPGA 板级时钟约束。
