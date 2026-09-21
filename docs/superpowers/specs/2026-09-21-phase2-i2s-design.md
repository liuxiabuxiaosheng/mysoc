# 第二阶段：AX7010 通用 I2S 音频接口设计

日期：2026-09-21  
目标板：ALINX AX7010，XC7Z010-1CLG400I  目标：在现有仿真验证的 DMA/Async FIFO/FIR 音频链路上增加外接 Codec 的 I2S RX/TX 接口。

## 1. 范围与假设

本阶段不绑定具体 ADC、DAC 或 Codec 型号。AX7010 通过 40-pin 扩展口连接外部音频模块，外部 Codec 提供 BCLK 和 LRCLK，FPGA 作为 I2S slave。

固定支持：

- 16-bit stereo、MSB first；
- 标准 I2S 一位时序偏移：LRCLK 翻转后的第一个 BCLK 周期不发送有效数据；
- 左声道先传、右声道后传；
- RX 与 TX 各自独立工作；
- RX/TX 串行时钟域与现有 audio_pipeline 时钟域之间使用异步 FIFO；
- 不在本阶段加入 Codec 的 I2C 初始化、采样率配置或 PDM/CIC。

已有 DMA/BRAM 音频路径保持不变，I2S 路径作为新的外部音频入口和出口。

## 2. 总体架构

```text
外部 ADC/Codec
   BCLK/LRCLK/SDATA
          |
      i2s_rx_slave
          |
   RX async FIFO（串行时钟域 -> audio_clk）
          |
      audio_pipeline
       FIR/DSP
          |
   TX async FIFO（audio_clk -> 串行时钟域）
          |
      i2s_tx_slave
          |
外部 DAC/Codec
```

RX 将每个完整的左/右 16-bit 样本打包成内部 16-bit 样本流，顺序为 L、R。TX 从内部样本流按同样顺序重新组成 stereo 帧。

## 3. RTL 模块

### 3.1 `rtl/audio/i2s_rx_slave.sv`

接口输入为 `i2s_bclk`、`i2s_lrclk`、`i2s_sdata` 和复位，输出为 `sample_valid`、`sample_data`、`sample_channel`。在 BCLK 上升沿采样 SDATA，检测 LRCLK 的声道状态并实现一位 I2S 偏移；收到第 16 个有效位后产生一个周期的 `sample_valid`。帧边界异常时丢弃未完成样本并重新同步。

### 3.2 `rtl/audio/i2s_tx_slave.sv`

接口输入为 BCLK/LRCLK、`sample_valid`、`sample_data` 和 `sample_ready`，输出 `i2s_sdata`。在 LRCLK 变化后插入一个 BCLK 空位，在下降沿更新数据，使接收端能够在上升沿稳定采样。内部为左右声道各一个 16-bit 缓冲，TX 空载时发送零样本并置 `underrun` 状态。

### 3.3 `rtl/audio/i2s_audio_bridge.sv`

桥接 I2S 样本流和现有 `audio_pipeline`。RX/TX 采用 `async_fifo` 做跨时钟域；桥接层负责 L/R 样本顺序、反压、空载填零以及 sticky overflow/underflow 状态。该模块不修改 FIR 算法，也不改变现有 DMA 接口。

### 3.4 `rtl/top/soc_top.sv`

新增可选顶层端口：

- `i2s_bclk`；
- `i2s_lrclk`；
- `i2s_sdata_in`；
- `i2s_sdata_out`。

通过参数或控制信号选择现有 DMA 音频路径与 I2S 外部路径。默认保持原有 DMA 路径，避免破坏当前测试和已有软件寄存器行为。

## 4. 时钟与复位

- `i2s_bclk` 视为外部时钟输入，只在 I2S RX/TX 模块中使用；
- `audio_clk` 继续作为 FIR 和系统音频处理时钟；
- I2S 复位与 `audio_rst_n` 分离同步，桥接 FIFO 两侧分别复位；
- XDC 中将 `i2s_bclk` 声明为外部时钟，实际周期由 Codec/板卡决定；在未确定 Codec 型号前只提供模板约束，不填写具体管脚号和电气标准。

## 5. 错误处理

- RX 在 LRCLK 中途变化或帧长度不足时丢弃当前移位寄存器内容，等待下一帧；
- RX FIFO overflow、TX FIFO underflow 使用 sticky 状态，直到显式清除；
- TX 没有可用样本时输出零并保持时序连续；
- 不对外部 Codec 的模拟、电源或 I2C 配置负责，这些属于板级适配层。

## 6. 验证计划

新增测试：

1. `tb_i2s_rx_slave`：发送已知左右声道位流，检查 16-bit 样本、声道顺序和一位偏移。
2. `tb_i2s_tx_slave`：输入已知样本，检查 BCLK/LRCLK/SDATA 边沿关系和空载填零。
3. `tb_i2s_audio_bridge`：使用不同频率的 I2S 时钟与 `audio_clk`，检查跨域后样本顺序、反压和错误状态。
4. `tb_soc_i2s`：AX7010 顶层端口 loopback，经 FIR 后检查输出样本。

所有已有测试必须继续通过；验收至少包括原有 33 个测试和新增 I2S 测试。

## 7. 后续扩展边界

后续阶段可在不改变本阶段样本流接口的前提下增加：

- I2S master 模式和可编程采样率；
- Codec I2C 初始化；
- PDM RX 与 CIC decimator；
- AX7010 具体 40-pin XDC 管脚及 IO 时序约束；
- FFT/AI 加速器接入 `audio_pipeline`。

