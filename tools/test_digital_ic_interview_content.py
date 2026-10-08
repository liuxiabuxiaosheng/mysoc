from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "interview" / "数字IC校招项目面试模拟与参考回答.md"

EXPECTED_IDS = [f"Q{i:02d}" for i in range(1, 25)]
REQUIRED_TERMS = [
    "RV32IM",
    "APB",
    "PSLVERR",
    "BRAM",
    "CSR",
    "Trap",
    "DMA",
    "仲裁",
    "Gray",
    "亚稳态",
    "Q1.15",
    "饱和",
    "valid-ready",
    "I2S",
    "黄金模型",
    "36 个",
]
BANNED_CLAIMS = [
    "已完成 Vivado 综合",
    "已实现时序收敛",
    "已完成板级验证",
    "已完成 FFT",
    "已实现显示模块",
    "已实现 AI 推理",
]


def main():
    text = SOURCE.read_text(encoding="utf-8")
    question_ids = re.findall(r"^## (Q\d{2}) ", text, flags=re.MULTILINE)
    followups = re.findall(r"^### 追问 \d+", text, flags=re.MULTILINE)

    assert question_ids == EXPECTED_IDS, question_ids
    assert 50 <= len(followups) <= 55, len(followups)
    for term in REQUIRED_TERMS:
        assert term in text, term
    for claim in BANNED_CLAIMS:
        assert claim not in text, claim
    assert "## 30 秒项目介绍" in text
    assert "## 2 分钟项目介绍" in text
    assert "## 项目边界与高风险表述" in text
    print("digital IC interview content validation PASS")


if __name__ == "__main__":
    main()
