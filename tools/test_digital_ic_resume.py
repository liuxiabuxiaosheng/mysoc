from pathlib import Path

from docx import Document


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "数字IC前端项目经历.docx"


def main():
    doc = Document(OUTPUT)
    text = "\n".join(p.text for p in doc.paragraphs)
    assert "36 个 SystemVerilog Testbench 回归，全部 PASS" in text
    assert "33 个 SystemVerilog Testbench 回归，全部 PASS" not in text
    print("resume test-count validation PASS")


if __name__ == "__main__":
    main()
