import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/date_extraction_controller.dart';
import '../data/ocr_models.dart';

class DateExtractionScreen extends ConsumerWidget {
  const DateExtractionScreen({this.onConfirmed, super.key});

  final ValueChanged<ReviewedOcrDate>? onConfirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dateExtractionControllerProvider);
    final controller = ref.read(dateExtractionControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhận dạng ngày trên tem')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ảnh chỉ được dùng để tạo kết quả nhận dạng tạm thời. '
                    'Không có dữ liệu thiết bị hoặc kiểm tra nào tự động được lưu.',
                  ),
                  const SizedBox(height: 20),
                  if (state.isBusy) _BusyState(status: state.status),
                  if (!state.isBusy && state.candidate == null)
                    _SelectionActions(
                      onCamera: () =>
                          controller.selectAndExtract(OcrImageSource.camera),
                      onGallery: () =>
                          controller.selectAndExtract(OcrImageSource.gallery),
                    ),
                  if (state.candidate case final candidate?) ...[
                    _CandidateReview(
                      state: state,
                      candidate: candidate,
                      onChanged: controller.editDate,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isBusy
                                ? null
                                : () => controller.selectAndExtract(
                                    OcrImageSource.camera,
                                  ),
                            child: const Text('Chụp lại'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isBusy
                                ? null
                                : () => controller.selectAndExtract(
                                    OcrImageSource.gallery,
                                  ),
                            child: const Text('Chọn ảnh khác'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          state.status == DateExtractionStatus.candidateReady
                          ? () {
                              final result = controller.confirm();
                              if (result == null) {
                                return;
                              }
                              final callback = onConfirmed;
                              if (callback != null) {
                                callback(result);
                              } else if (context.canPop()) {
                                context.pop(result);
                              }
                            }
                          : null,
                      child: const Text('Xác nhận'),
                    ),
                  ],
                  if (state.errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (state.status == DateExtractionStatus.confirmed) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ngày đã được người dùng xác nhận cho luồng gọi. '
                      'Dữ liệu chưa được lưu vào hồ sơ thiết bị.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusyState extends StatelessWidget {
  const _BusyState({required this.status});

  final DateExtractionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      DateExtractionStatus.selecting => 'Đang mở ảnh…',
      DateExtractionStatus.uploading => 'Đang tải ảnh lên…',
      _ => 'Đang xử lý nhận dạng…',
    };
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(label),
      ],
    );
  }
}

class _SelectionActions extends StatelessWidget {
  const _SelectionActions({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onCamera,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Chụp ảnh tem'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn ảnh từ thư viện'),
        ),
      ],
    );
  }
}

class _CandidateReview extends StatelessWidget {
  const _CandidateReview({
    required this.state,
    required this.candidate,
    required this.onChanged,
  });

  final DateExtractionState state;
  final OcrDateCandidate candidate;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final needsWarning =
        candidate.confidenceLevel != 'high' ||
        !candidate.calendarValid ||
        candidate.imageWarnings.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Kết quả nhận dạng',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Văn bản OCR: ${candidate.rawText}'),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(candidate.rawText),
          initialValue: state.reviewedDate,
          enabled: state.status == DateExtractionStatus.candidateReady,
          decoration: const InputDecoration(
            labelText: 'Ngày nhận dạng',
            hintText: 'DD/MM/YYYY',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.datetime,
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        Text(_confidenceLabel(candidate.confidenceLevel)),
        if (needsWarning) ...[
          const SizedBox(height: 8),
          const Text('Vui lòng kiểm tra kết quả nhận dạng trước khi xác nhận.'),
        ],
      ],
    );
  }
}

String _confidenceLabel(String level) => switch (level) {
  'high' => 'Độ tin cậy cao',
  'medium' => 'Độ tin cậy trung bình',
  _ => 'Cần kiểm tra lại',
};
