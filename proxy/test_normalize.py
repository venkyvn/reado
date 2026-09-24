import unittest

from normalize import AnalyzeFailure, normalize, parse_model_text


class NormalizeTests(unittest.TestCase):
    def test_keeps_valid_items_and_drops_empty(self):
        payload = normalize({
            "segments": [
                {"source_en": "Hello", "translation_vi": "Xin chào"},
                {"source_en": "  ", "translation_vi": "bỏ"},
            ],
            "vocabulary": [
                {
                    "term": "Hello",
                    "pos": "NOUN",
                    "meaning_vi": "xin chào",
                    "example": "Hello",
                    "cefr": "a2",
                    "ipa": "",
                },
                {"term": "", "pos": "noun", "meaning_vi": "x", "example": "x"},
            ],
            "summary_vi": "tóm tắt",
        })
        self.assertEqual(len(payload["segments"]), 1)
        self.assertEqual(payload["vocabulary"][0]["pos"], "noun")
        self.assertEqual(payload["vocabulary"][0]["cefr"], "A2")
        self.assertNotIn("ipa", payload["vocabulary"][0])

    def test_unknown_pos_becomes_other(self):
        payload = normalize({
            "segments": [{"source_en": "Run", "translation_vi": "Chạy"}],
            "vocabulary": [{
                "term": "Run",
                "pos": "interjection",
                "meaning_vi": "chạy",
                "example": "Run",
            }],
        })
        self.assertEqual(payload["vocabulary"][0]["pos"], "other")

    def test_empty_page_is_not_english(self):
        with self.assertRaises(AnalyzeFailure) as caught:
            normalize({"segments": [], "vocabulary": [], "summary_vi": ""})
        self.assertEqual(caught.exception.code, "NON_ENGLISH_TEXT")

    def test_strips_markdown_fence(self):
        data = parse_model_text('```json\n{"segments": []}\n```')
        self.assertEqual(data["segments"], [])


if __name__ == "__main__":
    unittest.main()
