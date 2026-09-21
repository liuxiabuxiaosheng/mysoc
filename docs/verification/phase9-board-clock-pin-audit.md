# Phase 9 AX7010 板卡时钟与管脚核对

日期：2026-09-21  
状态：完成项目资料核对；等待板卡原理图/官方约束文件确认具体管脚

## 1. 本次核对结论

当前项目可以确认的实现目标如下：

- 目标板：ALINX AX7010。
- FPGA 家族：Xilinx Zynq-7000。
- 目标器件：项目文档以 `XC7Z010CLG400-1` 为主；I2S 设计文档写作 `XC7Z010-1CLG400I`。两种写法需要以板卡丝印或 Vivado 器件选择器中的完整 part name 最终统一。
- PL 主时钟：项目架构假定 AX7010 提供 50 MHz PL 输入时钟。
- 当前 RTL 顶层时钟端口：`soc_top.clk_50m`。
- 当前 `clk_gen` 行为：50 MHz 输入直通到 `clk_sys`，尚未使用 MMCM/PLL 或 Vivado Clocking Wizard。

因此，当前阶段可以建立的时钟事实是：

```text
AX7010 PL oscillator (assumed 50 MHz)
        |
        +--> soc_top.clk_50m
                |
                +--> clk_gen.clk_in
                        |
                        +--> clk_sys (currently the same 50 MHz clock)
```

## 2. 已找到的项目证据

以下文件都明确使用或规划了 50 MHz 主时钟：

- `docs/superpowers/specs/2026-09-19-fpga-riscv-audio-soc-mvp-design.md`
  - 记录 AX7010 PL oscillator input 为 50 MHz。
  - 规划后续由 Clocking Wizard 生成 100 MHz system clock。
- `docs/FPGA_RISC_V_Audio_SoC_Implementation_Roadmap.md`
  - 记录当前顶层时钟为 50 MHz 直通。
  - 阶段九规划 50 MHz 输入、100 MHz 系统时钟和 12.5 MHz 演示音频时钟。
- `rtl/top/soc_top.sv`
  - 顶层输入端口名称为 `clk_50m`。
- `rtl/common/clk_gen.sv`
  - 当前实现为 `assign clk_sys = clk_in`。

官方示例约束和开发板原理图进一步确认了以下板级连接：

- `U18`：50 MHz PL 时钟输入；
- `N15`：PL 按键/复位输入；
- `J19`：UART RX；
- `K19`：UART TX；
- `M14`、`M15`、`K16`、`J16`：四个 PL LED；
- `J10`、`J11`：40-pin 扩展口，具体 I2S 信号仍需按所选 Codec 分配。

## 3. 用户照片确认的板卡特征

用户提供的实物照片与 AX7010 项目目标一致，可以观察到：

- PCB 上有明显的 `ALINX` 标识；
- 中央为 Zynq-7000 器件区域；
- 顶部扩展连接器标注为 `J10`，底部扩展连接器标注为 `J11`；
- 两组扩展口均为 2×20 排针形式，对应 40-pin 扩展接口；
- 板上可见 `JTAG`、`USB HOST`、`USB SLAVE`、`HDMI` 和以太网接口；
- 板上有 `PS KEY`、`PL KEY`、`PL LED`、`DONE` 等 PS/PL 调试和用户 I/O 标识。

照片能够确认板卡型号和接口形态，但不能直接确认：

- FPGA 芯片完整订货号及速度/温度等级；
- 50 MHz 振荡器连接到 FPGA 的具体球位；
- J10/J11 每一针对应的 FPGA `PACKAGE_PIN`；
- 某一组扩展口是否已经连接到特定 Codec。

因此，照片证据支持“目标板为 AX7010、使用 40-pin 扩展口”的结论，但不能替代 AX7010 原理图或官方 master XDC。

## 4. 当前不能确认的内容

虽然官方示例和原理图已经确认了时钟、复位、UART 以及 PL LED 的管脚，但以下内容仍不能凭空填写：

- `i2s_bclk`、`i2s_lrclk`、`i2s_sdata_in`、`i2s_sdata_out` 对应的 40-pin 扩展口管脚；
- 外接 Codec 型号、I/O 电平和驱动时序；
- I2S BCLK 周期、输入延迟和输出延迟；
- 其余 GPIO/按键信号在本项目板级封装中的具体分配。

本次用户补充了官方示例 XDC 和原理图后，时钟、复位和 UART 管脚已完成交叉核验，并写入 `constraints/ax7010_soc.xdc`。当前仍未将 I2S 扩展口管脚写成生效约束。

现有文件 `constraints/ax7010_i2s_template.xdc` 仍然只是模板，明确要求根据 Codec 和 AX7010 原理图替换占位符，不能直接用于实现。

## 5. 本阶段的边界

本次核对只确认了项目级时钟和器件假设，没有声称已经完成：

- I2S 和其余未使用接口的 AX7010 实际管脚绑定；
- Vivado 工程创建；
- 50 MHz 主时钟 XDC 的板级验证；
- Clocking Wizard 生成 100 MHz/12.5 MHz 时钟；
- 综合、实现、时序或 PPA 报告。

## 6. 进入真实约束前需要补齐的资料

1. AX7010 对应版本的原理图或官方 master XDC。
2. 板卡上实际使用的 FPGA 完整 part name。
3. 外接音频模块/Codec 型号及其 I2S 时序数据手册。
4. 选择 I2S 使用的 40-pin 扩展口编号和信号分配。

资料齐全后，下一步才能生成可用于 Vivado 实现的真实 XDC，并开始综合、时序和 PPA 测量。
