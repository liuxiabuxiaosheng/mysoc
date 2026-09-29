# 数字 IC 前端项目经历设计

## 目标

生成一份可直接粘贴到中文求职简历的 Word 项目经历，面向数字 IC 前端 RTL 设计岗位。内容仅覆盖仓库中已经实现并通过仿真验证的能力，不包含个人信息、教育经历、板级上电、综合实现、时序收敛或未完成的功能。

## 交付物

一个单页 DOCX，包含两个可独立使用的内容块：

1. 完整版项目经历：项目名、技术栈、项目简介和 5 条成果描述。
2. 精简替换版：3 条高密度成果，用于一页简历空间受限的场景。

## 内容边界

- 项目名称使用“RISC-V Audio DSP SoC RTL 设计与验证”。
- 技术栈覆盖 SystemVerilog、RISC-V RV32IM、APB、DMA、BRAM、CDC/Async FIFO、定点 FIR、Icarus Verilog。
- 成果覆盖 APB 外设与 UART、64 KiB BRAM 和 CPU 总线、多周期 RV32IM 与异常/中断、DMA 与仲裁、CDC 音频 FIR 端到端链路。
- 验证证据使用“33 个 SystemVerilog Testbench 全部 PASS”及“顶层静态 elaboration 通过”。
- 明确避免声称完成 FPGA 上板、Vivado 综合/实现、STA、资源/功耗报告、物理音频 I/O、FFT、AI 推理或显示模块。

## 版式

采用 A4 单页、简洁的中文技术简历样式：深蓝色标题、无装饰性横线、正文 10.5 pt、项目要点使用圆点列表；不使用页眉页脚。

## 验证

使用 python-docx 创建文档，调用打包的 LibreOffice 渲染为 PNG，并逐页检查中文字体、项目符号、换行和页面溢出。
