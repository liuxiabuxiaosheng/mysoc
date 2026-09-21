# FPGA RISC-V Audio SoC 实现路径

更新日期：2026-09-19  
目标平台：ALINX AX7010，XC7Z010CLG400-1  
项目目录：`D:\fpga_soc\mySOC`

## 1. 总体路线

```text
APB外设平台（已完成）
        ↓
BRAM与CPU总线
        ↓
自研多周期RV32I
        ↓
CPU运行裸机程序
        ↓
DMA控制器
        ↓
Async FIFO与CDC
        ↓
定点FIR音频处理
        ↓
SoC系统级集成
        ↓
Vivado综合与AX7010验证
```

实施原则：每个阶段都必须具备自检测试、明确验收标准和可重复执行的验证命令，通过后再进入下一阶段。

## 2. 当前状态：APB外设平台

状态：已完成并通过仿真验证。

已实现：

- APB Interconnect。
- GPIO及两级输入同步。
- 单次/周期Timer和粘滞状态位。
- UART TX、UART RX。
- 深度16的TX/RX FIFO。
- UART APB寄存器和错误状态。
- APB外设子系统集成。
- 第一阶段SoC顶层壳。
- 10个自动化自检Testbench。

当前限制：

- `soc_top`中的APB主设备暂时为空闲连接。
- 已实现并验证 CPU、64 KiB BRAM、DMA；尚无音频数据链路。
- 当前顶层时钟为50 MHz直通，尚未使用Clocking Wizard。
- 尚未执行Vivado综合、时序分析和板级验证。

## 3. 阶段二：片上存储与CPU总线

### 目标

建立CPU访问程序存储、数据存储和APB外设的基础通路。

### 建议文件

```text
rtl/
├── memory/
│   └── onchip_ram.sv
└── bus/
    ├── cpu_bus_decoder.sv
    └── cpu_apb_bridge.sv
```

### 实现内容

- 64 KiB片上BRAM。
- 32位读写数据。
- 4位Byte Enable。
- 使用初始化文件加载程序。
- `0x0000_0000–0x0000_FFFF`映射到BRAM。
- `0x4000_0000`以上外设地址转换为APB访问。
- CPU请求保持到`ready`或`error`返回。
- APB Bridge实现Setup和Access阶段。

### 验收标准

- BRAM整字、半字和字节写入正确。
- CPU总线能够读写BRAM。
- CPU总线能够通过Bridge读写GPIO。
- APB等待期间地址、方向和写数据保持稳定。
- 非法地址返回Bus Error。

## 4. 阶段三：自研多周期RV32I CPU

### 微架构

```text
FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK
```

### 模块划分

```text
rtl/cpu/
├── riscv_core.sv
├── riscv_control.sv
├── riscv_decoder.sv
├── riscv_alu.sv
├── riscv_regfile.sv
└── riscv_imm_gen.sv
```

### 指令实现顺序

1. 寄存器堆和`x0`恒零。
2. ALU算术、逻辑和比较。
3. I/S/B/U/J五类立即数生成。
4. `LUI`、`AUIPC`。
5. `ADD/SUB/AND/OR/XOR`。
6. 移位和比较指令。
7. `LW/SW`。
8. 条件分支。
9. `JAL/JALR`。
10. `LB/LH/LBU/LHU/SB/SH`。

第一版不实现流水线、Cache、乘除法扩展和完整CSR。非法指令或非对齐访问进入停止状态并输出Fault Code。

### 验收标准

- 每类指令都有自检测试。
- 能执行手工机器码程序。
- 能完成循环、函数跳转和内存读写。
- 能执行RISC-V裸机编译器生成的基础程序。

## 5. 阶段四：软件启动与外设控制

状态：DMA 阶段已完成；软件启动与外设控制仍待实现。

### 建议目录

```text
software/
├── linker.ld
├── start.S
├── main.c
├── gpio.h
├── timer.h
├── uart.h
└── Makefile
```

### 启动流程

```text
RISC-V GCC → ELF → Binary/Hex → BRAM初始化 → CPU从0x00000000启动
```

### 第一份系统程序

- 写入GPIO固定图案。
- UART发送`Hello RISC-V SoC`。
- 配置并轮询Timer。
- Timer到期后清状态并翻转GPIO。

### 验收标准

- CPU从BRAM复位向量启动。
- UART Testbench解码出指定字符串。
- GPIO输出指定值。
- Timer能够被软件轮询和清除。

该阶段是项目的第一个完整SoC闭环。

## 6. 阶段五：DMA控制器

### 寄存器

| Offset | 寄存器 | 功能 |
| --- | --- | --- |
| `0x00` | `DMA_SRC` | 源地址 |
| `0x04` | `DMA_DST` | 目标地址 |
| `0x08` | `DMA_LENGTH` | 32位字数量 |
| `0x0C` | `DMA_CTRL` | 启动控制 |
| `0x10` | `DMA_STATUS` | Busy、Done和错误状态 |

### 状态机

```text
IDLE → READ_REQ → READ_WAIT → WRITE_REQ → WRITE_WAIT → DONE
```

### 实现顺序

1. BRAM到BRAM搬运。
2. CPU与DMA的存储访问仲裁。
3. BRAM到音频输入FIFO。
4. 音频输出FIFO到BRAM。

### 验收标准

- 搬运结果与源数据完全一致。
- 零长度、地址非对齐和忙状态重复启动能够报错。
- CPU与DMA不会同时驱动存储接口。
- Done和Error保持到软件清除。

## 7. 阶段六：Async FIFO与CDC

状态：已完成独立 Async FIFO/CDC 原语验证，并已接入阶段七系统级音频链路。

### 时钟域

```text
100 MHz系统域 → Async FIFO → 12.5 MHz音频域
```

### 实现内容

- Binary Pointer。
- Gray Code Pointer。
- 双触发器指针同步。
- Full/Empty判断。
- Overflow/Underflow状态。
- 复位和指针回绕处理。

### 验收标准

- 读写时钟使用不同周期和不同初始相位。
- 跨时钟域后数据顺序保持正确。
- 覆盖满、空、回绕和独立复位。
- 多位数据只能通过Async FIFO跨时钟域。

## 8. 阶段七：16阶定点FIR

状态：独立 FIR 原语及 DMA/Async FIFO 音频链路均已完成并通过仿真。

### 数据格式

- 输入样本：16位有符号Q1.15。
- 系数：16位有符号Q1.15。
- 抽头：16。
- 内部累加器：至少36位。
- 输出：舍入或截位后饱和到16位。

### 数据路径

```text
输入样本 → 16级移位寄存器 → 16组乘法 → 扩展精度累加 → 截位与饱和 → 输出
```

### 验收标准

- 单位脉冲响应正确。
- 阶跃响应正确。
- 支持正负样本和系数。
- 正负溢出执行饱和而不是回绕。
- RTL结果与软件黄金模型逐样本完全一致。

## 9. 阶段八：系统级音频数据链路

状态：已完成。实现文件为 `rtl/audio/audio_pipeline.sv`，端到端证据见 `docs/verification/phase7-audio-pipeline.md`。

```text
CPU把数字音频样本写入BRAM
            ↓
CPU配置DMA
            ↓
DMA读取输入样本
            ↓
Async Input FIFO
            ↓
16阶FIR
            ↓
Async Output FIFO
            ↓
DMA写回BRAM
            ↓
CPU检查结果
```

### 验收标准

- DMA传输数量和FIR输出数量一致。
- 正常流程没有FIFO溢出或欠载。
- 输出样本顺序正确。
- 最终结果与软件黄金模型一致。

实际验收还覆盖了 50 MHz 系统时钟、12.5 MHz 音频时钟、40 个样本的 DMA 双向搬运、输入 FIFO 反压、FIR 系数配置、样本计数和 FIFO 错误状态。

完成该阶段后，项目可以准确描述为仿真验证的RISC-V Audio DSP SoC。

## 10. 阶段九：Vivado与AX7010

### 实现内容

- 选择`XC7Z010CLG400-1`。
- 添加AX7010引脚约束。
- Clocking Wizard输入50 MHz。
- 生成100 MHz系统时钟。
- 生成12.5 MHz演示音频时钟。
- 添加主时钟、生成时钟和异步时钟组约束。
- 运行综合、实现和时序分析。
- 记录LUT、FF、BRAM、DSP和Fmax。

### 第一版上板验收

- CPU启动成功。
- UART输出指定字符串。
- GPIO或LED显示程序运行状态。
- 不要求真实音频、VGA、FFT或AI上板。

## 11. 可选扩展

核心MVP完成后再考虑：

- 五级流水线RV32I。
- 中断和机器模式CSR。
- I2S或PDM音频接口。
- FFT加速器。
- VGA频谱显示。
- MFCC或关键词识别。

未实现前必须标记为未来设计或可选扩展，不能描述为已经完成。

## 12. 优先级与里程碑

| 优先级 | 阶段 | 核心成果 |
| --- | --- | --- |
| 1 | BRAM与CPU总线 | 建立CPU访问基础 |
| 2 | 多周期RV32I | 完成项目核心处理器 |
| 3 | 软件启动 | UART输出第一条CPU程序信息 |
| 4 | DMA | 已完成：建立硬件数据搬运通路 |
| 5 | Async FIFO | 已完成：完成 CDC 数据传输 |
| 6 | FIR | 已完成：完成独立 16 阶定点 FIR 原语 |
| 7 | 系统集成 | 完成Audio DSP SoC数据链路 |
| 8 | Vivado | 获得资源和时序结果 |
| 9 | FFT、显示、AI | 可选增强功能 |

## 13. 下一步

第二阶段已增加通用 16-bit stereo I2S slave RX/TX 与异步 FIFO 桥接原语。AX7010 的具体管脚、Codec 电气标准和 I2S 输入输出延迟仍需依据选定外接音频模块填写 `constraints/ax7010_i2s_template.xdc`，不能在未选定 Codec 时假定固定值。

下一个具体里程碑：

> 为已验证的 RV32I CPU 和 DMA/音频链路加入软件启动目录、链接脚本、启动代码和可加载的 BRAM 固件镜像，完成 CPU 配置 GPIO、UART、Timer 和 DMA 的裸机闭环；随后进入 Vivado 时钟、约束和板级验证。
