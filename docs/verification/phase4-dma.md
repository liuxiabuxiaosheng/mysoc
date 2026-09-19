# Phase 4 DMA Verification

日期：2026-09-19

本阶段实现并验证单通道 BRAM-to-BRAM DMA。DMA 通过 `0x4000_5000`
窗口配置，使用单 outstanding memory request 在现有 64 KiB BRAM 中搬运
32-bit words。`soc_top` 内部 RAM 仲裁保持 CPU 优先，并将 DMA 请求与 CPU
请求串行化。

## 可重复验证命令

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test dma_controller
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_dma
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test soc_dma
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

## 已验证行为

- `DMA_SRC`、`DMA_DST`、`DMA_LENGTH`、`DMA_CTRL` 和 `DMA_STATUS` APB 读写。
- 多 word BRAM-to-BRAM 搬运，源数据与目标数据逐 word 一致。
- `IDLE → READ_REQ/WAIT → WRITE_REQ/WAIT → DONE` 状态机。
- 读/写响应等待期间 request 地址、方向、数据和 strobe 保持稳定。
- 零长度、非对齐地址和忙状态重复启动置位 sticky configuration error。
- `DONE`、configuration error 和 bus error 使用 RW1C 清除语义。
- CPU 可见 APB 路径配置 DMA，并通过内部 RAM 仲裁完成搬运。
- 原有 Phase 1、Phase 2、Phase 3 测试保持通过。

## 回归结果

`sim/run_tests.ps1 -Test all` 完成并返回退出码 0；新增测试输出：

```text
PASS tb_dma_controller
PASS tb_apb_dma
PASS tb_soc_dma
```

顶层 `apb_subsystem` 与 `soc_top` 的 Icarus null elaboration 均返回退出码
0。Icarus 对现有 `always_comb` 常量选择报告兼容性 warning，不影响编译或
仿真结果。

## 阶段边界

本阶段未实现音频 FIFO 端点、异步 FIFO/CDC、中断、burst、scatter/gather、
多通道 DMA、固件构建工具或 FPGA 板级实现流程。
