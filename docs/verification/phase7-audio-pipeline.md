# Phase 7 音频 DMA/FIFO/FIR 数据链路验证

日期：2026-09-19  
状态：已实现并通过 Icarus Verilog 仿真

## 实现范围

系统数据路径为：

```text
BRAM → DMA → system-domain input Async FIFO
     → audio-domain 16-tap Q1.15 FIR
     → audio-domain output Async FIFO
     → DMA → BRAM
```

新增 `rtl/audio/audio_pipeline.sv`，并在 `soc_top` 中接入：

- DMA 的 BRAM→输入 FIFO 和输出 FIFO→BRAM 端点。
- 独立 `audio_clk`/`audio_rst_n`，默认实例仍使用系统时钟以兼容旧 testbench。
- 音频控制寄存器、FIR 系数写入、状态、样本计数和最后输出样本。
- 输入 FIFO 深度为 16 个 16-bit 样本；集成默认输出 FIFO 为 64 个样本，以允许单 DMA 先完成输入搬运后再启动输出搬运。

## 端到端测试

测试文件：`tb/top/tb_soc_audio.sv`

- 系统时钟 50 MHz，音频时钟 12.5 MHz，独立复位释放。
- BRAM 中写入 40 个有符号 16-bit 样本，按两个样本一个 32-bit word 打包。
- 通过 APB 写入 16 个 FIR 系数：`h[0]=0x7fff`，其余为零。
- DMA 输入端点地址：`0x4000_3008`；输出端点地址：`0x4000_300c`。
- 软件 Q1.15 舍入模型逐样本比较输出 BRAM。
- 40 个样本使 16-entry 输入 FIFO 出现 ready 反压；传输期间没有 FIFO 溢出或欠载。
- 验证 DMA Done、音频样本计数和输出数据顺序。

## 验证命令

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test audio_pipeline
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_audio
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all

$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

本次回归结果：所有既有测试以及 `tb_audio_pipeline`、`tb_soc_audio` 均输出 `PASS`；两个顶层静态 elaboration 命令退出码为 0。Icarus 对既有 `always_comb` 常量选择报告 warning，不影响编译结果。

## 边界与非目标

- DMA 长度按 32-bit word 计数，输入样本数必须为偶数。
- 尚未实现 I2S/PDM、ADC/DAC、真实音频时钟约束、FFT、显示和 AI 推理。
- 跨域控制配置假定在一次处理运行开始前完成；运行中不修改 FIR 系数。
