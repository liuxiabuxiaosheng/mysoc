# FPGA RISC-V Audio AI SoC Platform 项目规划

## 1. 项目名称

基于 RISC-V 的 FPGA 实时音频处理与多时钟域显示 SoC 平台

英文： FPGA RISC-V Audio AI SoC Platform

------------------------------------------------------------------------

# 2. 项目目标

设计并实现一个小型 SoC 系统，将：

-   RISC-V CPU
-   APB/AXI 总线
-   SRAM
-   UART
-   DMA
-   Audio DSP 加速模块
-   VGA/TFT 显示模块
-   CDC/FIFO 数据通路

集成到 FPGA 平台中。

重点体现数字 IC 前端能力：

-   RTL Design
-   FSM
-   FIFO
-   CDC
-   Bus Protocol
-   Memory Interface
-   Hardware Accelerator
-   Verification

------------------------------------------------------------------------

# 3. 总体架构

                        RISC-V CPU

                             |
                             |
                        APB / AXI Bus

                             |
     -------------------------------------------------

     |             |             |                  |

    SRAM        UART          TIMER             DMA


                             |

                       Audio Subsystem

                             |

                  ---------------------

                  |        |          |

                FIFO     FIR        FFT

                  |

              Audio Output


                             |

                      Display Engine

                             |

                        VGA/TFT

     -------------------------------------------------

                     Verification

                  SV Testbench

                  Assertion

                  Coverage

------------------------------------------------------------------------

# 4. 项目开发阶段

------------------------------------------------------------------------

# 当前实现状态（2026-09-19）

本节记录当前仓库中已经实现并实际验证的范围，不替代后续路线图。Phase 1 的完整回归在 Icarus Verilog 13.0 下通过 10 个测试；详细命令、测试名和寄存器映射见 `docs/verification/phase1-apb-peripherals.md`。

| 模块或能力 | 当前状态 | 验证或边界 |
| --- | --- | --- |
| APB Interconnect | 已实现并通过回归 | GPIO、Timer、UART 三个 4 KiB 窗口；未映射访问返回错误。 |
| GPIO | 已实现并通过回归 | 数据、方向和输入寄存器，以及非法偏移错误响应。 |
| Timer | 已实现并通过回归 | Counter、Compare、单次/周期工作和中断状态。 |
| UART | 已实现并通过回归 | TX/RX、TX/RX FIFO、APB 寄存器和错误状态；当前顶层未暴露 UART 中断。 |
| APB/GPIO/Timer/UART Testbench | 已实现并通过完整回归 | 完整回归共 10 个测试，包含单元、互连、子系统和顶层 smoke 测试。 |
| BRAM / SRAM / ROM | 已实现并通过回归 | 已实现 64 KiB on-chip RAM、字节写使能和初始化文件接口。 |
| RISC-V CPU、CPU memory bus、APB bridge | 已实现并通过回归 | 多周期 RV32I CPU 可通过 CPU bus 访问 BRAM 和 APB 外设。 |
| DMA | 已实现并通过回归 | 单通道 BRAM-to-BRAM DMA，含 APB 配置、状态机、错误状态和 CPU/DMA RAM 仲裁；详见 `docs/verification/phase4-dma.md`。 |
| CDC / Async FIFO 集成 | 未实现 | 当前没有多时钟域数据通路。 |
| FIR | 未实现 | 尚无定点 FIR RTL 或 golden model 验证。 |
| VGA / TFT / Display | 未实现 | 尚无显示时序、帧缓冲或物理显示输出。 |
| FFT | 未实现 | 不属于当前 MVP 的已实现功能。 |
| 物理音频输入输出 | 未实现 | 尚未接入 ADC、DAC、I2S 或板级音频接口。 |
| AI 功能 | 未实现 | 当前没有 AI 模型、推理加速器或相关软件栈。 |
| FPGA 时钟与实现流程 | 未实现 | `clk_gen` 仅直通 50 MHz 输入；尚未实例化 Vivado Clocking Wizard，也未完成约束、综合、时序和资源报告。 |

后续应按独立计划依次推进：

1.  BRAM、CPU memory bus、APB bridge，以及带指令测试的 multi-cycle RV32I。
2.  裸机固件镜像生成和 CPU/外设集成。
3.  DMA、异步 FIFO、定点 FIR 和 golden-model 验证。
4.  完整 SoC 集成、Vivado Clocking Wizard、XDC、综合、时序和资源报告。

------------------------------------------------------------------------

# Phase 0：工程框架搭建

## 目标

建立标准 SoC RTL 工程结构。

目录：

    FPGA_SOC_AUDIO

    ├── rtl

    │   ├── cpu

    │   ├── bus

    │   ├── memory

    │   ├── peripheral

    │   ├── audio

    │   ├── display

    │   ├── dma

    │   └── common


    ├── tb

    ├── sim

    └── doc

完成：

-   顶层模块
-   时钟模块
-   复位同步模块
-   基础 Testbench

------------------------------------------------------------------------

# Phase 1：APB Peripheral Subsystem

## 目标

实现 SoC 外设控制总线。

架构：

    CPU/APB Master

           |

    APB Interconnect

           |

    ---------------------

    GPIO

    TIMER

    UART

    ---------------------

实现：

## APB Interconnect

功能：

-   地址译码
-   Slave选择
-   Read Data MUX

## GPIO

地址：

    0x40000000

寄存器：

  地址   功能
  ------ ------------
  0x00   GPIO_DATA
  0x04   GPIO_DIR
  0x08   GPIO_INPUT

## TIMER

地址：

    0x40001000

功能：

-   Counter
-   Compare
-   Interrupt

------------------------------------------------------------------------

# Phase 2：UART Controller IP

## 目标

实现可被 CPU 控制的 UART 外设。

架构：

    APB

     |

    UART Register Bank

     |

    -------------------

    TX FIFO

    RX FIFO

    -------------------

    UART TX

    UART RX

寄存器：

  Offset   名称          功能
  -------- ------------- ---------------
  0x00     UART_DATA     发送/接收数据
  0x04     UART_STATUS   状态
  0x08     UART_CTRL     控制
  0x0C     UART_BAUD     波特率

实现：

-   UART TX FSM
-   UART RX FSM
-   TX FIFO
-   RX FIFO
-   中断

验证：

-   APB 写数据
-   UART发送
-   Loopback
-   APB读回

------------------------------------------------------------------------

# Phase 3：Memory System

## 目标

建立片上存储系统。

实现：

-   SRAM Controller
-   ROM
-   Dual Port RAM

学习：

-   地址映射
-   Byte Enable
-   Memory Interface

------------------------------------------------------------------------

# Phase 4：DMA Controller

## 目标

实现硬件数据搬运。

架构：

    Peripheral

        |

    DMA

        |

    Memory

功能：

-   Source Address
-   Destination Address
-   Transfer Length
-   Start
-   Done Interrupt

状态机：

    IDLE

     ↓

    READ

     ↓

    WRITE

     ↓

    DONE

------------------------------------------------------------------------

# Phase 5：Clock Domain Crossing

## 目标

实现真实 SoC 多时钟域通信。

时钟：

    System Clock

    100MHz


    Audio Clock

    12.288MHz


    UART Clock

    Baud Clock

实现：

-   双触发器同步
-   Pulse Synchronizer
-   Async FIFO

重点：

-   Gray Code
-   Pointer Synchronization
-   Metastability

------------------------------------------------------------------------

# Phase 6：Audio Processing Accelerator

## 目标

设计硬件音频处理模块。

数据流：

    ADC

     |

    Async FIFO

     |

    Audio Processing

     |

    DAC

实现：

## FIR Filter

内容：

-   Shift Register
-   Multiply
-   Accumulator
-   Pipeline

## FFT Accelerator

内容：

-   Butterfly
-   Complex Multiply
-   Pipeline

## Volume Control

内容：

-   Gain
-   Saturation

------------------------------------------------------------------------

# Phase 7：Display Engine

## 目标

实现实时数据显示。

结构：

    Frame Buffer RAM

            |

    VGA Controller

            |

    TFT Display

实现：

-   VGA Timing
-   Pixel Counter
-   RGB Generator
-   Dual Port RAM

------------------------------------------------------------------------

# Phase 8：RISC-V CPU Integration

## 目标

接入 CPU。

支持：

RV32I

模块：

-   PC
-   Decoder
-   Register File
-   ALU
-   Memory Interface

CPU访问：

    UART Register

    GPIO Register

    Timer Register

    DMA Register

------------------------------------------------------------------------

# Phase 9：Verification

## 目标

建立芯片级验证。

实现：

## Testbench

包括：

-   APB Master Driver
-   UART Driver
-   Audio Stimulus

## Assertion

例如：

FIFO：

    count <= DEPTH

APB：

    VALID期间数据保持

## Coverage

覆盖：

-   地址空间
-   状态机
-   异常情况

------------------------------------------------------------------------

# Phase 10：FPGA验证

目标：

上板运行。

测试：

-   UART通信
-   音频输入输出
-   VGA显示
-   DMA传输

记录：

-   LUT
-   FF
-   BRAM
-   Fmax
-   Power

------------------------------------------------------------------------

# 5. 项目亮点与简历边界

当前阶段简历描述（仅陈述当前仓库已经实现并通过仿真的内容）：

> 使用 SystemVerilog 实现并仿真验证 APB 外设子系统，完成 GPIO、Timer、
> UART TX/RX、同步 FIFO、寄存器接口与地址互连；通过单元、互连、子系统和
> 顶层 smoke test 覆盖寄存器访问、错误响应、UART 收发与复位行为。

未来目标模板（只有在对应 RTL、集成验证与实现结果完成后才可使用，不代表当前状态）：

> 目标是设计并实现基于 RISC-V 的 FPGA SoC 平台，在已验证的 APB、GPIO、
> Timer 和 UART 基础上继续完成 DMA、异步 FIFO、多时钟域数据传输、音频硬件
> 加速与显示链路，并以匹配的 Testbench、断言、综合和时序结果支撑相关描述。

------------------------------------------------------------------------

# 6. 面试重点准备

重点掌握：

## RTL

-   FSM
-   Pipeline
-   Blocking / Non-blocking
-   always_ff

## CDC

-   Metastability
-   Synchronizer
-   Async FIFO

## Bus

-   APB
-   AXI
-   VALID/READY

## Memory

-   SRAM
-   BRAM
-   Dual Port RAM

## Accelerator

-   MAC
-   Pipeline
-   Throughput
-   Latency

------------------------------------------------------------------------

# 7. 开发顺序原则

不要追求功能数量。

优先：

1.  总线
2.  外设
3.  存储
4.  DMA
5.  CDC
6.  Accelerator
7.  CPU
8.  系统验证

最终形成：

一个完整的小型 FPGA SoC 平台。
