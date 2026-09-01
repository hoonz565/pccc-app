import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/authenticated_dio_provider.dart';
import '../../auth/data/auth_models.dart';
import 'area_models.dart';

abstract interface class AreaRepository {
  Future<List<Area>> list({required String facilityId});

  Future<Area> create({required String facilityId, required String name});
}

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => DioAreaRepository(ref.watch(authenticatedDioProvider)),
);

class DioAreaRepository implements AreaRepository {
  const DioAreaRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Area>> list({required String facilityId}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/v1/facilities/$facilityId/areas',
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((item) => Area.fromJson(item as Map<String, dynamic>))
            .toList(growable: false);
      }
      throw _responseException(
        response.statusCode,
        response.data,
        fallback: 'Không thể tải danh sách khu vực. Vui lòng thử lại.',
      );
    } on DioException catch (error) {
      throw _dioException(error);
    } on AreaRequestException {
      rethrow;
    } on Object {
      throw const AreaRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<Area> create({
    required String facilityId,
    required String name,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/facilities/$facilityId/areas',
        data: {'name': name},
      );
      if (response.statusCode == 201 && response.data != null) {
        return Area.fromJson(response.data!);
      }
      throw _responseException(
        response.statusCode,
        response.data,
        fallback: 'Không thể tạo khu vực. Dữ liệu chưa được lưu.',
      );
    } on DioException catch (error) {
      throw _dioException(error);
    } on AreaRequestException {
      rethrow;
    } on Object {
      throw const AreaRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  AreaRequestException _dioException(DioException error) {
    final refreshError = error.error;
    if (refreshError is AuthRequestException) {
      return AreaRequestException(
        refreshError.message,
        isTransient: refreshError.isTransient,
        invalidSession: refreshError.invalidSession,
      );
    }
    return AreaRequestException(
      'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
      statusCode: error.response?.statusCode,
      isTransient: error.response == null,
      invalidSession: error.response?.statusCode == 401,
    );
  }

  AreaRequestException _responseException(
    int? statusCode,
    Object? data, {
    required String fallback,
  }) {
    String? code;
    String? message;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        code = error['code'] as String?;
        message = error['message'] as String?;
      }
    }
    return AreaRequestException(
      message ?? fallback,
      statusCode: statusCode,
      code: code,
      isTransient: (statusCode ?? 0) >= 500,
      invalidSession: statusCode == 401,
    );
  }
}
