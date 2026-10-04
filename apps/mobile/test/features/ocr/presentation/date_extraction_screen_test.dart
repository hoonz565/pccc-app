import 'package:firesafe_mobile/features/ocr/data/ocr_image_picker.dart';
import 'package:firesafe_mobile/features/ocr/data/ocr_models.dart';
import 'package:firesafe_mobile/features/ocr/data/ocr_repository.dart';
import 'package:firesafe_mobile/features/ocr/presentation/date_extraction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../application/date_extraction_controller_test.dart';

void main() {
  testWidgets('candidate is editable and confirm returns reviewed date', (
    tester,
  ) async {
    ReviewedOcrDate? confirmed;
    final picker = FakeOcrImagePicker();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ocrImagePickerProvider.overrideWithValue(picker),
          ocrRepositoryProvider.overrideWithValue(
            FakeOcrRepository(candidate: candidateFixture()),
          ),
        ],
        child: MaterialApp(
          home: DateExtractionScreen(onConfirmed: (value) => confirmed = value),
        ),
      ),
    );

    await tester.tap(find.text('Chọn ảnh từ thư viện'));
    await tester.pumpAndSettle();

    expect(find.text('Kết quả nhận dạng'), findsOneWidget);
    expect(find.text('Văn bản OCR: 15 - 07 - 2026'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15/07/2026'), findsOneWidget);
    expect(find.text('Độ tin cậy trung bình'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '16/07/2026');
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();

    expect(confirmed?.normalizedDate, '2026-07-16');
    expect(confirmed?.acceptedUnchanged, isFalse);
  });

  testWidgets(
    'backend error renders recovery actions and change-image retries',
    (tester) async {
      final picker = FakeOcrImagePicker();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ocrImagePickerProvider.overrideWithValue(picker),
            ocrRepositoryProvider.overrideWithValue(
              FakeOcrRepository(
                error: const OcrRequestException('Không tìm thấy ngày.'),
              ),
            ),
          ],
          child: const MaterialApp(home: DateExtractionScreen()),
        ),
      );

      await tester.tap(find.text('Chụp ảnh tem'));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy ngày.'), findsOneWidget);
      expect(find.text('Chụp ảnh tem'), findsOneWidget);
      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);

      await tester.tap(find.text('Chọn ảnh từ thư viện'));
      await tester.pumpAndSettle();
      expect(picker.calls, 2);
    },
  );
}
