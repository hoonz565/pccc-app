import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/authenticated_dio_provider.dart';
import '../../auth/data/auth_models.dart';
import 'ocr_models.dart';

typedef OcrUploadProgress = void Function(int sent, int total);

abstract interface class OcrRepository {
  Future<OcrDateCandidate> extractDate({
    required OcrSelectedImage image,
    OcrUploadProgress? onSendProgress,
  });
}

final ocrRepositoryProvider = Provider<OcrRepository>(
  (ref) => DioOcrRepository(ref.watch(authenticatedDioProvider)),
);

class DioOcrRepository implements OcrRepository {
  const DioOcrRepository(this._dio);

  final Dio _dio;

  @override
  Future<OcrDateCandidate> extractDate({
    required OcrSelectedImage image,
    OcrUploadProgress? onSendProgress,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ocr/date-extractions',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(
            image.bytes,
            filename: image.name,
            contentType: DioMediaType.parse(image.mimeType),
          ),
          'expected_field_type': 'inspection_date',
        }),
        onSendProgress: onSendProgress,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return OcrDateCandidate.fromJson(response.data!);
      }
      throw _responseException(response.statusCode, response.data);
    } on DioException catch (error) {
      final refreshError = error.error;
      if (refreshError is AuthRequestException) {
        throw OcrRequestException(
          refreshError.message,
          isTransient: refreshError.isTransient,
          invalidSession: refreshError.invalidSession,
        );
      }
      throw OcrRequestException(
        'Không thể kết nối tới máy chủ nhận dạng. Vui lòng thử lại.',
        statusCode: error.response?.statusCode,
        isTransient:
            error.response == null || (error.response?.statusCode ?? 0) >= 500,
        invalidSession: error.response?.statusCode == 401,
      );
    } on OcrRequestException {
      rethrow;
    } on Object {
      throw const OcrRequestException(
        'Phản hồi nhận dạng không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  OcrRequestException _responseException(int? statusCode, Object? data) {
    String? code;
    String? message;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        code = error['code'] as String?;
        message = error['message'] as String?;
      }
    }
    return OcrRequestException(
      message ?? 'Không thể nhận dạng ngày. Vui lòng chụp hoặc chọn ảnh khác.',
      statusCode: statusCode,
      code: code,
      isTransient: (statusCode ?? 0) >= 500,
      invalidSession: statusCode == 401,
    );
  }
}
