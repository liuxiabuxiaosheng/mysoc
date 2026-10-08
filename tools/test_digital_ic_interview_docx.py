from pathlib import Path

from docx import Document


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "数字IC校招项目面试模拟与参考回答.docx"


def main():
    doc = Document(OUTPUT)
    paragraphs = [p for p in doc.paragraphs if p.text.strip()]
    text = "\n".join(p.text for p in paragraphs)
    question_headings = [
        p.text
        for p in paragraphs
        if p.style.name == "Heading 2" and p.text.startswith("Q")
    ]
    followup_headings = [
        p.text
        for p in paragraphs
        if p.style.name == "Heading 3" and p.text.startswith("追问")
    ]
    footer_xml = "".join(
        section.footer._element.xml for section in doc.sections
    )

    assert doc.core_properties.title == "数字 IC 校招项目面试模拟与参考回答"
    assert len(question_headings) == 24, len(question_headings)
    assert len(followup_headings) == 53, len(followup_headings)
    assert "30 秒项目介绍" in text
    assert "Gray 指针异步 FIFO" in text
    assert "16 阶 Q1.15 FIR" in text
    assert "36 个 SystemVerilog Testbench" in text
    assert "项目边界与高风险表述" in text
    assert "w:instrText" in footer_xml and "PAGE" in footer_xml
    print("digital IC interview DOCX validation PASS")


if __name__ == "__main__":
    main()
