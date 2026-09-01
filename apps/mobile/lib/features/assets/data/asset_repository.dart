import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/authenticated_dio_provider.dart';
import '../../auth/data/auth_models.dart';
import 'asset_models.dart';

abstract interface class AssetRepository {
  Future<List<Asset>> list({
    required String areaId,
    int limit = 50,
    int offset = 0,
  });

  Future<Asset> create({
    required String areaId,
    required AssetWriteFields fields,
  });

  Future<Asset> get({required String assetId});

  Future<Asset> update({
    required String assetId,
    required int baseRevision,
    required AssetWriteFields fields,
  });
}

final assetRepositoryProvider = Provider<AssetRepository>(
  (ref) => DioAssetRepository(ref.watch(authenticatedDioProvider)),
);

class DioAssetRepository implements AssetRepository {
  const DioAssetRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Asset>> list({
    required String areaId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/v1/areas/$areaId/assets',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((item) => Asset.fromJson(item as Map<String, dynamic>))
            .toList(growable: false);
      }
      throw _responseException(
        response.statusCode,
        response.data,
        fallback: 'Không thể tải danh sách thiết bị. Vui lòng thử lại.',
      );
    } on DioException catch (error) {
      throw _dioException(error);
    } on AssetRequestException {
      rethrow;
    } on Object {
      throw const AssetRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<Asset> create({
    required String areaId,
    required AssetWriteFields fields,
  }) => _write(
    method: 'POST',
    path: '/api/v1/areas/$areaId/assets',
    expectedStatus: 201,
    data: fields.toJson(),
  );

  @override
  Future<Asset> get({required String assetId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/assets/$assetId',
      );
      if (response.statusCode == 200 && response.data != null) {
        return Asset.fromJson(response.data!);
      }
      throw _responseException(
        response.statusCode,
        response.data,
        fallback: 'Không thể tải thông tin thiết bị.',
      );
    } on DioException catch (error) {
      throw _dioException(error);
    } on AssetRequestException {
      rethrow;
    } on Object {
      throw const AssetRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<Asset> update({
    required String assetId,
    required int baseRevision,
    required AssetWriteFields fields,
  }) => _write(
    method: 'PATCH',
    path: '/api/v1/assets/$assetId',
    expectedStatus: 200,
    data: {...fields.toJson(), 'base_revision': baseRevision},
  );

  Future<Asset> _write({
    required String method,
    required String path,
    required int expectedStatus,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(method: method),
      );
      if (response.statusCode == expectedStatus && response.data != null) {
        return Asset.fromJson(response.data!);
      }
      throw _responseException(
        response.statusCode,
        response.data,
        fallback: method == 'POST'
            ? 'Không thể tạo thiết bị. Dữ liệu chưa được xác nhận đã lưu.'
            : 'Không thể cập nhật thiết bị. Vui lòng thử lại.',
      );
    } on DioException catch (error) {
      throw _dioException(error);
    } on AssetRequestException {
      rethrow;
    } on Object {
      throw const AssetRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  AssetRequestException _dioException(DioException error) {
    final refreshError = error.error;
    if (refreshError is AuthRequestException) {
      return AssetRequestException(
        refreshError.message,
        isTransient: refreshError.isTransient,
        invalidSession: refreshError.invalidSession,
      );
    }
    return AssetRequestException(
      'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
      statusCode: error.response?.statusCode,
      isTransient: error.response == null,
      invalidSession: error.response?.statusCode == 401,
    );
  }

  AssetRequestException _responseException(
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
    return AssetRequestException(
      message ?? fallback,
      statusCode: statusCode,
      code: code,
      isTransient: (statusCode ?? 0) >= 500,
      invalidSession: statusCode == 401,
    );
  }
}
