from firesafe_api.ocr.paddle_recognizer import PaddleDateRecognizer


def test_paddle_adapter_translates_provider_payload_at_boundary() -> None:
    boxes = PaddleDateRecognizer._translate_results(  # noqa: SLF001
        [
            {
                "res": {
                    "rec_texts": ["Ngày thực hiện", "15-07-2026"],
                    "rec_scores": [0.96, 0.94],
                    "rec_polys": [
                        [[10, 10], [160, 10], [160, 40], [10, 40]],
                        [[170, 10], [280, 10], [280, 40], [170, 40]],
                    ],
                }
            }
        ]
    )

    assert [box.text for box in boxes] == ["Ngày thực hiện", "15-07-2026"]
    assert boxes[1].confidence == 0.94
    assert boxes[1].bbox is not None
    assert boxes[1].bbox.x_min == 170
    assert boxes[1].bbox.x_max == 280
