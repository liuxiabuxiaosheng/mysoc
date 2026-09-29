# 数字 IC 前端项目经历 Word 文档 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建一份经过视觉检查、可直接用于中文求职简历的单页数字 IC 前端项目经历 Word 文档。

**Architecture:** 使用一个 Python 文档生成脚本将已经验证的项目事实固化为完整和精简两种项目描述。DOCX 采用单页简历式排版，随后用打包的 LibreOffice 工具渲染为 PNG，检查版面后再交付。

**Tech Stack:** python-docx、打包 Python 运行时、LibreOffice 渲染器、SystemVerilog 项目验证记录。

---

### Task 1: 编写经过事实核对的简历文案

**Files:**
- Create: `D:/mySOC/tools/create_digital_ic_resume.py`
- Create: `D:/mySOC/数字IC前端项目经历.docx`
- Reference: `D:/mySOC/FPGA_RISC_V_Audio_AI_SoC_Project_Plan.md`
- Reference: `D:/mySOC/docs/verification/phase8-rv32im-csr-interrupt.md`
- Reference: `D:/mySOC/docs/verification/phase7-audio-pipeline.md`

- [ ] **Step 1: 固化完整项目经历内容**

文档应使用下列项目名称、技术栈和简介：

```text
RISC-V Audio DSP SoC RTL 设计与验证
技术栈：SystemVerilog | RISC-V RV32IM | APB | DMA | BRAM | CDC/Async FIFO | Q1.15 FIR | Icarus Verilog
设计并验证一套面向 FPGA 原型的 RISC-V Audio DSP SoC RTL，覆盖 CPU、片上存储与 APB 外设、DMA、多时钟域音频数据通路和定点 FIR；当前工作以 RTL 仿真验证为边界。
```

- [ ] **Step 2: 固化五条完整成果描述**

```text
• 设计 APB 外设子系统及地址译码，完成 GPIO、Timer、UART TX/RX、寄存器接口和 16 深度收发 FIFO；支持非法访问 PSLVERR、UART 错误状态及可屏蔽中断。
• 实现 64 KiB 片上 BRAM、单 outstanding CPU 请求/响应总线和 CPU-to-APB Bridge；支持 32 bit 读写、字节写使能、APB Setup/Access 时序与错误透传。
• 自研模块化多周期 RV32IM 内核，覆盖取指、译码、执行、访存、写回，支持 Machine CSR、Trap、MUL/DIV/REM 及 Timer、DMA、UART 中断汇聚。
• 实现单通道 DMA 及 CPU/DMA BRAM 仲裁，基于读写状态机完成 BRAM 到 BRAM 和音频 FIFO 端点搬运；覆盖零长度、非对齐、忙态重复启动及 RW1C 状态清除。
• 构建 50 MHz 系统域至 12.5 MHz 音频域的 CDC 数据通路：参数化 Gray-pointer Async FIFO 与 16 阶 Q1.15 FIR；完成 BRAM → DMA → FIFO → FIR → FIFO → DMA → BRAM 的 40 样本端到端逐样本黄金模型比对。
```

- [ ] **Step 3: 添加验证结果及精简替换版**

```text
验证：基于 Icarus Verilog 完成 36 个 SystemVerilog Testbench 回归，全部 PASS；apb_subsystem 与 soc_top 静态 elaboration 通过。

精简替换版：
• 使用 SystemVerilog 完成含多周期 RV32IM、64 KiB BRAM、APB 外设和 DMA 的 SoC RTL 设计，支持 CSR/Trap、异常处理及 Timer/DMA/UART 中断。
• 设计 Gray-pointer Async FIFO 和 16 阶 Q1.15 FIR，完成 50 MHz/12.5 MHz 双时钟域 BRAM-DMA-FIFO-FIR-DMA 音频链路，40 样本逐样本与黄金模型一致。
• 搭建单元至 SoC 的 SystemVerilog 自检回归，覆盖协议时序、异常状态、FIFO 满空/回绕/独立复位及端到端数据搬运；36 个 Testbench 全部 PASS。
```

- [ ] **Step 4: 确认简历边界**

不在正文中写入 FPGA 已上板、Vivado 综合/布局布线、时序收敛、资源/功耗数据、物理音频 I/O、FFT、AI 推理或显示功能。

### Task 2: 生成并检查 DOCX

**Files:**
- Create: `D:/mySOC/数字IC前端项目经历.docx`
- Create: `D:/mySOC/resume_render/page-1.png`
- Modify: `D:/mySOC/tools/create_digital_ic_resume.py`
- Test: `D:/mySOC/resume_render/page-1.png`

- [ ] **Step 1: 使用 python-docx 生成单页文档**

设置 A4 页边距为上/下 0.55 in、左/右 0.65 in；标题使用 18 pt 深蓝色微软雅黑；正文使用 10.5 pt 微软雅黑；项目符号使用圆点；不使用页眉、页脚或标题下横线。

- [ ] **Step 2: 渲染 DOCX**

运行：

```powershell
& $bundledPython $renderer 'D:\mySOC\数字IC前端项目经历.docx' --output_dir 'D:\mySOC\resume_render'
```

预期：生成 `D:\mySOC\resume_render\page-1.png`。

- [ ] **Step 3: 检查最终页面**

检查 PNG 中标题、中文字符、项目符号和段落换行；确认页面为一页，未发生文字裁剪、重叠或溢出。

- [ ] **Step 4: 提交交付物**

```powershell
git add -- 'tools/create_digital_ic_resume.py' '数字IC前端项目经历.docx'
git commit -m 'docs: add digital IC resume project description'
```

## Self Review

- Spec coverage: Task 1 覆盖项目名称、技术栈、完整/精简文案、量化验证和不实表述边界；Task 2 覆盖单页 Word 排版和渲染验证。
- Placeholder scan: 无 TBD、TODO 或待补充内容。
- Type consistency: 所有产物路径和生成流程在两个任务中一致。
