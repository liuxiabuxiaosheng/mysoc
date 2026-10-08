# 数字 IC 校招项目面试模拟文档 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建一份覆盖当前 RISC V Audio DSP SoC 项目的校招模拟面试 Word 文档，包含约 24 道主问题、约 50 道递进追问和可直接口述的项目化参考回答。

**Architecture:** 使用一份 UTF-8 Markdown 文件保存可审阅的面试内容，以独立 Python 脚本解析固定标题结构并生成 DOCX。内容测试负责题量、专题覆盖和项目边界，文档测试负责标题层级、关键文本和文件完整性，最后使用打包的 LibreOffice 渲染器逐页检查版面。

**Tech Stack:** Markdown、Python 3、python-docx、SystemVerilog 项目验证记录、Icarus Verilog、打包 LibreOffice 渲染器。

---

## 文件结构

- Create: `docs/interview/数字IC校招项目面试模拟与参考回答.md`，保存完整问答内容。
- Create: `tools/test_digital_ic_interview_content.py`，验证题量、主题覆盖和禁止性表述。
- Create: `tools/create_digital_ic_interview_docx.py`，解析内容并生成 Word 文档。
- Create: `tools/test_digital_ic_interview_docx.py`，验证 DOCX 结构和关键内容。
- Create: `数字IC校招项目面试模拟与参考回答.docx`，最终交付物。
- Create during QA: `interview_render/`，保存临时逐页 PNG，不纳入最终提交。

### Task 1: 复核项目事实和验证基线

**Files:**
- Reference: `rtl/**/*.sv`
- Reference: `tb/**/*.sv`
- Reference: `sim/run_tests.ps1`
- Reference: `docs/verification/*.md`
- Reference: `docs/superpowers/specs/2026-10-08-digital-ic-interview-simulation-design.md`

- [ ] **Step 1: 运行全部 SystemVerilog 回归**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
```

Expected: 36 个测试均输出 `PASS`，命令退出码为 0。

- [ ] **Step 2: 运行顶层静态 elaboration**

Run:

```powershell
$interviewRtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $interviewRtl
iverilog -g2012 -Wall -tnull -s soc_top $interviewRtl
```

Expected: 两条命令退出码均为 0；允许项目验证记录中已经说明的 Icarus 常量选择 warning。

- [ ] **Step 3: 建立事实清单**

从 RTL 和验证文档记录以下可用事实，并在后续回答中保持一致：

```text
CPU: 多周期 RV32IM，Machine CSR，Direct mtvec，Trap，MUL/DIV/REM
Memory: 64 KiB on-chip RAM，32 bit 数据，4 bit byte enable
Bus: CPU request/response bus，CPU-to-APB bridge，APB interconnect
Peripheral: GPIO，Timer，UART，Audio CTRL，DMA，IRQ Controller
DMA: 单通道，BRAM-to-BRAM，BRAM-to-audio FIFO，audio FIFO-to-BRAM
CDC: 参数化 Gray-pointer Async FIFO，双触发器同步指针
DSP: 16 阶 Q1.15 FIR，舍入，饱和，valid-ready backpressure
Clock simulation: 50 MHz system domain，12.5 MHz audio domain
Audio serial: I2S RX/TX slave 与 audio bridge 已有独立 Testbench
Verification: 36 个 SystemVerilog Testbench
```

- [ ] **Step 4: 记录不可声称已完成的事项**

```text
Vivado synthesis and implementation
Static timing closure and Fmax
Resource and power reports
Complete board-level validation
Physical Codec loopback
FFT
Display subsystem
AI inference
```

### Task 2: 编写内容测试和完整面试稿

**Files:**
- Create: `tools/test_digital_ic_interview_content.py`
- Create: `docs/interview/数字IC校招项目面试模拟与参考回答.md`

- [ ] **Step 1: 编写会失败的内容测试**

Create `tools/test_digital_ic_interview_content.py` with these checks:

```python
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "interview" / "数字IC校招项目面试模拟与参考回答.md"

EXPECTED_IDS = [f"Q{i:02d}" for i in range(1, 25)]
REQUIRED_TERMS = [
    "RV32IM", "APB", "PSLVERR", "BRAM", "CSR", "Trap",
    "DMA", "仲裁", "Gray", "亚稳态", "Q1.15", "饱和",
    "valid-ready", "I2S", "黄金模型", "36 个",
]
BANNED_CLAIMS = [
    "已完成 Vivado 综合", "已实现时序收敛", "已完成板级验证",
    "已完成 FFT", "已实现显示模块", "已实现 AI 推理",
]

text = SOURCE.read_text(encoding="utf-8")
question_ids = re.findall(r"^## (Q\d{2}) ", text, flags=re.MULTILINE)
followups = re.findall(r"^### 追问 \d+", text, flags=re.MULTILINE)

assert question_ids == EXPECTED_IDS
assert len(followups) >= 48
for term in REQUIRED_TERMS:
    assert term in text, term
for claim in BANNED_CLAIMS:
    assert claim not in text, claim
assert "## 30 秒项目介绍" in text
assert "## 2 分钟项目介绍" in text
assert "## 项目边界与高风险表述" in text
print("digital IC interview content validation PASS")
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/test_digital_ic_interview_content.py
```

Expected: FAIL with `FileNotFoundError` because the interview source does not exist.

- [ ] **Step 3: 编写 24 道主问题**

Create the Markdown source with exactly these question headings:

```text
Q01 请用两分钟介绍这个项目
Q02 SoC 的整体架构和一笔音频数据的完整流向是什么
Q03 为什么采用多周期 CPU 而不是流水线 CPU
Q04 APB 传输的 Setup 和 Access 阶段如何实现
Q05 APB Interconnect 如何完成地址译码和错误响应
Q06 UART 的收发状态机和 FIFO 如何配合
Q07 Timer 和 IRQ Controller 为什么使用粘滞状态与写一清零
Q08 片上 BRAM 如何支持字节半字和整字访问
Q09 CPU 总线到 APB Bridge 如何处理等待和错误
Q10 RV32IM 多周期控制器如何组织状态和数据通路
Q11 分支跳转和非对齐访问如何处理
Q12 CSR Trap MRET 和 WFI 的执行路径是什么
Q13 Timer DMA UART 中断如何进入 CPU
Q14 RV32M 乘除法如何实现特殊边界条件
Q15 DMA 的寄存器状态机和错误处理如何设计
Q16 CPU 与 DMA 访问 BRAM 时如何仲裁
Q17 为什么多比特数据跨时钟域要使用异步 FIFO
Q18 Gray 指针异步 FIFO 如何判断满空
Q19 异步 FIFO 的独立复位有什么风险
Q20 16 阶 Q1.15 FIR 的位宽舍入和饱和如何设计
Q21 FIR 如何处理 valid-ready 反压
Q22 I2S RX TX 和音频桥接如何工作
Q23 你如何构建自检 Testbench 和黄金模型
Q24 当前项目最大的不足和下一步改进是什么
```

Each question must contain, in order:

```markdown
## Q01 问题标题

**面试官提问**

问题原文

**项目化参考回答**

可直接口述的第一人称回答

### 追问 1

**追问问题**

追问原文

**追问参考回答**

可直接口述的回答

**回答要点**

- 要点
- 常见失误
```

Q01 至 Q24 每题至少包含两个追问。Q17 至 Q21 的 CDC 和定点 DSP 题允许包含第三个追问，以覆盖亚稳态、满空判断、复位、位宽和反压边界。总追问数目标为 50 至 55。

- [ ] **Step 4: 编写开篇和结尾**

The source must begin with:

```text
# 数字 IC 校招项目面试模拟与参考回答
## 使用说明
## 项目事实摘要
## 30 秒项目介绍
## 2 分钟项目介绍
```

The source must end with:

```text
# 面试收尾准备
## 可以向面试官提出的问题
## 项目边界与高风险表述
## 面试前检查清单
```

The 30-second answer should state the design scope and verified result. The 2-minute answer should follow architecture, personal implementation, hardest problems, verification, and boundary. The boundary section must distinguish simulation evidence from synthesis, timing, and board evidence.

- [ ] **Step 5: 运行内容测试**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/test_digital_ic_interview_content.py
```

Expected: `digital IC interview content validation PASS`.

- [ ] **Step 6: 提交内容稿**

```powershell
git add -- 'tools/test_digital_ic_interview_content.py' 'docs/interview/数字IC校招项目面试模拟与参考回答.md'
git commit -m 'docs: add digital IC interview question bank'
```

### Task 3: 生成 Word 文档

**Files:**
- Create: `tools/test_digital_ic_interview_docx.py`
- Create: `tools/create_digital_ic_interview_docx.py`
- Create: `数字IC校招项目面试模拟与参考回答.docx`
- Reference: `tools/create_digital_ic_resume.py`

- [ ] **Step 1: 编写会失败的 DOCX 测试**

Create `tools/test_digital_ic_interview_docx.py`:

```python
from pathlib import Path
from docx import Document

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "数字IC校招项目面试模拟与参考回答.docx"

doc = Document(OUTPUT)
paragraphs = [p for p in doc.paragraphs if p.text.strip()]
text = "\n".join(p.text for p in paragraphs)
question_headings = [
    p.text for p in paragraphs
    if p.style.name == "Heading 2" and p.text.startswith("Q")
]

assert doc.core_properties.title == "数字 IC 校招项目面试模拟与参考回答"
assert len(question_headings) == 24
assert "30 秒项目介绍" in text
assert "Gray 指针异步 FIFO" in text
assert "16 阶 Q1.15 FIR" in text
assert "36 个 SystemVerilog Testbench" in text
assert "项目边界与高风险表述" in text
print("digital IC interview DOCX validation PASS")
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/test_digital_ic_interview_docx.py
```

Expected: FAIL with `PackageNotFoundError` because the DOCX does not exist.

- [ ] **Step 3: 编写 DOCX 生成脚本**

Implement `tools/create_digital_ic_interview_docx.py` with these responsibilities:

```python
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "interview" / "数字IC校招项目面试模拟与参考回答.md"
OUTPUT = ROOT / "数字IC校招项目面试模拟与参考回答.docx"
FONT = "Microsoft YaHei"
```

The script must:

1. Create an A4 portrait document with 0.72 inch top and bottom margins and 0.78 inch left and right margins.
2. Apply Word `Title`, `Heading 1`, `Heading 2`, and `Heading 3` styles using black or restrained dark blue text and no decorative rule.
3. Parse `#`, `##`, `###`, bold labels, normal paragraphs, and bullet lines from the Markdown source.
4. Set East Asian fonts through `w:rFonts` so Chinese renders consistently.
5. Set `keep_with_next` on headings and label paragraphs, and prevent a question heading from being stranded at the bottom of a page.
6. Add a static contents section listing the seven interview rounds and the closing section.
7. Add a centered page number field in the footer using OOXML `PAGE` field elements.
8. Set core title and subject properties and clear the author property.

Use these visual sizes:

```text
Title: 20 pt
Subtitle: 11 pt
Heading 1: 15 pt
Heading 2: 12.5 pt
Heading 3: 11 pt
Body: 10.5 pt with 1.18 line spacing
Labels: 10.5 pt bold in dark blue
Footer page number: 9 pt gray
```

- [ ] **Step 4: 生成并验证 DOCX**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/create_digital_ic_interview_docx.py
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/test_digital_ic_interview_docx.py
```

Expected: generator prints the output path and test prints `digital IC interview DOCX validation PASS`.

- [ ] **Step 5: 提交生成器和 DOCX**

```powershell
git add -- 'tools/create_digital_ic_interview_docx.py' 'tools/test_digital_ic_interview_docx.py' '数字IC校招项目面试模拟与参考回答.docx'
git commit -m 'docs: generate digital IC interview workbook'
```

### Task 4: 渲染和逐页质量检查

**Files:**
- Verify: `数字IC校招项目面试模拟与参考回答.docx`
- Create during QA: `interview_render/page-*.png`
- Reference: `C:/Users/23100/.codex/plugins/cache/openai-primary-runtime/documents/26.921.10847/skills/documents/render_docx.py`

- [ ] **Step 1: 渲染 Word 文档**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\23100\.codex\plugins\cache\openai-primary-runtime\documents\26.921.10847\skills\documents\render_docx.py' 'D:\mySOC\数字IC校招项目面试模拟与参考回答.docx' --output_dir 'D:\mySOC\interview_render' --emit_pdf
```

Expected: one PNG per page and a non-empty PDF are created in `interview_render`.

- [ ] **Step 2: 检查每一页图像**

Inspect every `page-*.png` at full size. Confirm:

```text
No clipped Chinese text
No overlapping paragraphs
No isolated question heading at a page bottom
No broken bullet indentation
No large accidental blank regions
Page numbers are centered and visible
Question and answer labels remain visually distinct
```

- [ ] **Step 3: 修正版式并重新渲染**

If a defect appears, modify only the generator, regenerate the DOCX, rerun both tests, and render again. Repeat until every final PNG passes inspection.

- [ ] **Step 4: 运行文档结构与可访问性检查**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\23100\.codex\plugins\cache\openai-primary-runtime\documents\26.921.10847\skills\documents\scripts\a11y_audit.py' 'D:\mySOC\数字IC校招项目面试模拟与参考回答.docx'
```

Expected: no critical heading, table, or image accessibility error. The document contains no images or data tables.

- [ ] **Step 5: 最终验证**

Run:

```powershell
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/test_digital_ic_interview_content.py
& 'C:\Users\23100\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/test_digital_ic_interview_docx.py
git diff --check
git status --short
```

Expected: both tests print `PASS`, `git diff --check` prints no error, and only intentional final changes are present.

## Self Review

- Spec coverage: Tasks 1 through 4 cover project fact validation, 24 main questions, at least 48 follow-ups, both introduction lengths, project boundaries, Word formatting, page numbers, rendering, and final checks.
- Placeholder scan: The plan contains no deferred implementation requirement; every content section, question title, command, path, and acceptance criterion is specified.
- Type consistency: The source and output paths are identical across tests and generator; both tests use the bundled Python runtime and the DOCX output name matches the design specification.
