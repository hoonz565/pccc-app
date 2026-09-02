import 'dart:typed_data';

import 'package:firesafe_mobile/features/ocr/application/date_extraction_controller.dart';
import 'package:firesafe_mobile/features/ocr/data/ocr_image_picker.dart';
import 'package:firesafe_mobile/features/ocr/data/ocr_models.dart';
import 'package:firesafe_mobile/features/ocr/data/ocr_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller exposes upload, processing, and candidate states', () async {
    final repository = FakeOcrRepository(candidate: candidateFixture());
    final container = ProviderContainer(
      overrides: [
        ocrImagePickerProvider.overrideWithValue(FakeOcrImagePicker()),
        ocrRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final statuses = <DateExtractionStatus>[];
    final subscription = container.listen(
      dateExtractionControllerProvider,
      (_, next) => statuses.add(next.status),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(dateExtractionControllerProvider.notifier)
        .selectAndExtract(OcrImageSource.gallery);

    expect(
      statuses,
      containsAllInOrder([
        DateExtractionStatus.selecting,
        DateExtractionStatus.uploading,
        DateExtractionStatus.processing,
        DateExtractionStatus.candidateReady,
      ]),
    );
    expect(
      container.read(dateExtractionControllerProvider).reviewedDate,
      '15/07/2026',
    );
  });

  test('controller exposes backend error and allows a later retry', () async {
    final repository = FakeOcrRepository(
      error: const OcrRequestException('Không tìm thấy ngày.'),
    );
    final picker = FakeOcrImagePicker();
    final container = ProviderContainer(
      overrides: [
        ocrImagePickerProvider.overrideWithValue(picker),
        ocrRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      dateExtractionControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container
        .read(dateExtractionControllerProvider.notifier)
        .selectAndExtract(OcrImageSource.camera);

    final state = container.read(dateExtractionControllerProvider);
    expect(state.status, DateExtractionStatus.error);
    expect(state.errorMessage, 'Không tìm thấy ngày.');
    expect(picker.calls, 1);
  });

  test('confirm reports accepted versus user-corrected date', () async {
    final container = ProviderContainer(
      overrides: [
        ocrImagePickerProvider.overrideWithValue(FakeOcrImagePicker()),
        ocrRepositoryProvider.overrideWithValue(
          FakeOcrRepository(candidate: candidateFixture()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      dateExtractionControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      dateExtractionControllerProvider.notifier,
    );
    await controller.selectAndExtract(OcrImageSource.gallery);

    expect(controller.confirm()?.acceptedUnchanged, isTrue);

    await controller.selectAndExtract(OcrImageSource.gallery);
    controller.editDate('16/07/2026');
    final corrected = controller.confirm();
    expect(corrected?.normalizedDate, '2026-07-16');
    expect(corrected?.acceptedUnchanged, isFalse);
  });
}

class FakeOcrImagePicker implements OcrImagePicker {
  int calls = 0;

  @override
  Future<OcrSelectedImage?> pick(OcrImageSource source) async {
    calls += 1;
    return OcrSelectedImage(
      name: 'label.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
    );
  }
}

class FakeOcrRepository implements OcrRepository {
  FakeOcrRepository({this.candidate, this.error});

  final OcrDateCandidate? candidate;
  final OcrRequestException? error;

  @override
  Future<OcrDateCandidate> extractDate({
    required OcrSelectedImage image,
    OcrUploadProgress? onSendProgress,
  }) async {
    onSendProgress?.call(image.bytes.length, image.bytes.length);
    if (error case final requestError?) {
      throw requestError;
    }
    return candidate!;
  }
}

OcrDateCandidate candidateFixture() => const OcrDateCandidate(
  rawText: '15 - 07 - 2026',
  correctedText: '15-07-2026',
  normalizedDate: '2026-07-15',
  confidenceLevel: 'medium',
  calendarValid: true,
  validationWarnings: [],
  imageWarnings: [],
  engine: 'fake-ocr',
  selectionStrategy: 'anchor_associated',
  requiresConfirmation: true,
);
