# Phase 5 Async FIFO / CDC Verification

日期：2026-09-19

本阶段实现参数化 `async_fifo`，默认 16-bit 数据、16 entries。写域和读域
使用独立时钟与复位，Gray 编码指针通过双触发器同步，满/空判断只使用本地
指针和已同步指针。

## 可重复验证命令

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test async_fifo
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

## 已验证行为

- 不同周期、不同相位的写/读时钟下数据顺序保持一致。
- FIFO 满/空状态和指针回绕。
- 满状态写入置位 sticky `overflow`。
- 空状态读取置位 sticky `underflow`。
- 读写数据保持在各自时钟域，跨域仅同步 Gray 指针。
- 写侧和读侧独立复位释放顺序；双方复位后恢复 empty、无错误状态。
- DMA、CPU、APB 及既有外设回归不受影响。

## 回归结果

完整回归返回退出码 0，包含新增测试：

```text
PASS tb_async_fifo
```

连同此前测试共 22 个 Testbench 通过；`soc_top` 顶层 Icarus null
elaboration 返回退出码 0。Icarus 对 `always_comb` 常量选择报告兼容性
warning，不影响编译或仿真结果。

## 阶段边界

本阶段未接入 DMA 音频端点、FIR、I2S、Vivado Clocking Wizard 或板级多时钟
约束。独立复位期间不承诺保留尚未清空的数据；正常使用应在双方复位后开始
传输。
