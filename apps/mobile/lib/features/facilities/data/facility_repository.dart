import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/authenticated_dio_provider.dart';
import '../../auth/data/auth_models.dart';
import 'facility_models.dart';

abstract interface class FacilityRepository {
  Future<Facility> create({
    required String name,
    required String type,
    required String province,
    required String address,
  });

  Future<List<Facility>> list();
}

final facilityRepositoryProvider = Provider<FacilityRepository>(
  (ref) => DioFacilityRepository(ref.watch(authenticatedDioProvider)),
);

class DioFacilityRepository implements FacilityRepository {
  const DioFacilityRepository(this._dio);

  final Dio _dio;

  @override
  Future<Facility> create({
    required String name,
    required String type,
    required String province,
    required String address,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/facilities',
        data: {
          'name': name,
          'type': type,
          'province': province,
          'address': address,
        },
      );
      if (response.statusCode == 201 && response.data != null) {
        return Facility.fromJson(response.data!);
      }
      throw FacilityRequestException(_safeMessage(response.data));
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallback: 'Không thể kết nối tới máy chủ. Dữ liệu chưa được lưu.',
      );
    } on FacilityRequestException {
      rethrow;
    } on Object {
      throw const FacilityRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<List<Facility>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/v1/facilities');
      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((item) => Facility.fromJson(item as Map<String, dynamic>))
            .toList(growable: false);
      }
      throw FacilityRequestException(_safeMessage(response.data));
    } on DioException catch (error) {
      throw _mapDioException(
        error,
        fallback: 'Không thể tải danh sách cơ sở. Vui lòng thử lại.',
      );
    } on FacilityRequestException {
      rethrow;
    } on Object {
      throw const FacilityRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  String _safeMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
    }
    return 'Không thể xử lý cơ sở. Vui lòng kiểm tra lại thông tin.';
  }

  FacilityRequestException _mapDioException(
    DioException error, {
    required String fallback,
  }) {
    final refreshError = error.error;
    if (refreshError is AuthRequestException) {
      return FacilityRequestException(
        refreshError.message,
        isTransient: refreshError.isTransient,
        invalidSession: refreshError.invalidSession,
      );
    }
    final invalidSession = error.response?.statusCode == 401;
    return FacilityRequestException(
      invalidSession
          ? 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.'
          : fallback,
      isTransient: error.response == null,
      invalidSession: invalidSession,
    );
  }
}
