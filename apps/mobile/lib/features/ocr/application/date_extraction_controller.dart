import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';
import '../data/ocr_image_picker.dart';
import '../data/ocr_models.dart';
import '../data/ocr_repository.dart';

enum DateExtractionStatus {
  idle,
  selecting,
  uploading,
  processing,
  candidateReady,
  confirmed,
  error,
}

class DateExtractionState {
  const DateExtractionState({
    this.status = DateExtractionStatus.idle,
    this.selectedImage,
    this.candidate,
    this.reviewedDate = '',
    this.confirmedDate,
    this.errorMessage,
  });

  final DateExtractionStatus status;
  final OcrSelectedImage? selectedImage;
  final OcrDateCandidate? candidate;
  final String reviewedDate;
  final ReviewedOcrDate? confirmedDate;
  final String? errorMessage;

  bool get isBusy =>
      status == DateExtractionStatus.selecting ||
      status == DateExtractionStatus.uploading ||
      status == DateExtractionStatus.processing;
}

final dateExtractionControllerProvider =
    NotifierProvider.autoDispose<DateExtractionController, DateExtractionState>(
      DateExtractionController.new,
    );

class DateExtractionController extends Notifier<DateExtractionState> {
  AuthenticatedSessionIdentity? _sessionIdentity;

  @override
  DateExtractionState build() {
    _sessionIdentity = ref.watch(authenticatedSessionIdentityProvider);
    return const DateExtractionState();
  }

  Future<void> selectAndExtract(OcrImageSource source) async {
    if (state.isBusy) {
      return;
    }
    final previous = state;
    final requestSession = _sessionIdentity;
    state = DateExtractionState(
      status: DateExtractionStatus.selecting,
      candidate: previous.candidate,
      reviewedDate: previous.reviewedDate,
    );
    try {
      final selected = await ref.read(ocrImagePickerProvider).pick(source);
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      if (selected == null) {
        state = previous;
        return;
      }
      state = DateExtractionState(
        status: DateExtractionStatus.uploading,
        selectedImage: selected,
      );
      final candidate = await ref
          .read(ocrRepositoryProvider)
          .extractDate(
            image: selected,
            onSendProgress: (sent, total) {
              if (_isCurrentSession(requestSession) &&
                  total > 0 &&
                  sent >= total &&
                  state.status == DateExtractionStatus.uploading) {
                state = DateExtractionState(
                  status: DateExtractionStatus.processing,
                  selectedImage: selected,
                );
              }
            },
          );
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = DateExtractionState(
        status: DateExtractionStatus.candidateReady,
        selectedImage: selected,
        candidate: candidate,
        reviewedDate: candidate.displayDate,
      );
    } on OcrRequestException catch (error) {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      if (error.invalidSession) {
        state = const DateExtractionState();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      state = DateExtractionState(
        status: DateExtractionStatus.error,
        selectedImage: state.selectedImage,
        errorMessage: error.message,
      );
    } on Object {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = DateExtractionState(
        status: DateExtractionStatus.error,
        selectedImage: state.selectedImage,
        errorMessage: 'Không thể xử lý ảnh. Vui lòng chọn hoặc chụp ảnh khác.',
      );
    }
  }

  void editDate(String value) {
    final candidate = state.candidate;
    if (candidate == null || state.isBusy) {
      return;
    }
    state = DateExtractionState(
      status: DateExtractionStatus.candidateReady,
      selectedImage: state.selectedImage,
      candidate: candidate,
      reviewedDate: value,
    );
  }

  ReviewedOcrDate? confirm() {
    final candidate = state.candidate;
    if (candidate == null ||
        state.status != DateExtractionStatus.candidateReady) {
      return null;
    }
    final normalized = _normalizeReviewedDate(state.reviewedDate);
    if (normalized == null) {
      state = DateExtractionState(
        status: DateExtractionStatus.candidateReady,
        selectedImage: state.selectedImage,
        candidate: candidate,
        reviewedDate: state.reviewedDate,
        errorMessage:
            'Ngày xác nhận không hợp lệ. Hãy nhập theo định dạng DD/MM/YYYY.',
      );
      return null;
    }
    final reviewed = ReviewedOcrDate(
      normalizedDate: normalized,
      acceptedUnchanged: normalized == candidate.normalizedDate,
    );
    state = DateExtractionState(
      status: DateExtractionStatus.confirmed,
      selectedImage: state.selectedImage,
      candidate: candidate,
      reviewedDate: state.reviewedDate,
      confirmedDate: reviewed,
    );
    return reviewed;
  }

  bool _isCurrentSession(AuthenticatedSessionIdentity? sessionIdentity) =>
      ref.mounted &&
      identical(sessionIdentity, _sessionIdentity) &&
      identical(
        sessionIdentity,
        ref.read(authenticatedSessionIdentityProvider),
      );
}

String? _normalizeReviewedDate(String value) {
  final match = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$')
      .firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
