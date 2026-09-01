import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthResult> register({
    required String email,
    required String password,
  });

  Future<AuthResult> login({required String email, required String password});

  Future<AuthResult> refresh({required String refreshToken});

  Future<AuthUser> currentUser({required String accessToken});

  Future<void> logout({required String accessToken});
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DioAuthRepository(ref.watch(dioProvider)),
);

class DioAuthRepository implements AuthRepository {
  const DioAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'terms_accepted': true,
          'privacy_accepted': true,
        },
      );
      if (response.statusCode == 201 && response.data != null) {
        return AuthResult.fromJson(response.data!);
      }
      throw AuthRequestException(_safeMessage(response.data));
    } on DioException catch (error) {
      throw AuthRequestException(
        'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
        isTransient: error.response == null,
      );
    } on AuthRequestException {
      rethrow;
    } on Object {
      throw const AuthRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200 && response.data != null) {
        return AuthResult.fromJson(response.data!);
      }
      throw AuthRequestException(
        _safeMessage(
          response.data,
          fallback: 'Email hoặc mật khẩu không chính xác.',
        ),
      );
    } on DioException catch (error) {
      throw AuthRequestException(
        'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
        isTransient: error.response == null,
      );
    } on AuthRequestException {
      rethrow;
    } on Object {
      throw const AuthRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<AuthResult> refresh({required String refreshToken}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      if (response.statusCode == 200 && response.data != null) {
        return AuthResult.fromJson(response.data!);
      }
      throw AuthRequestException(
        _safeMessage(
          response.data,
          fallback: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.',
        ),
        isTransient: (response.statusCode ?? 0) >= 500,
        invalidSession: response.statusCode == 401,
      );
    } on DioException catch (error) {
      throw AuthRequestException(
        'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
        isTransient:
            error.response == null || (error.response?.statusCode ?? 0) >= 500,
      );
    } on AuthRequestException {
      rethrow;
    } on Object {
      throw const AuthRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
        isTransient: true,
      );
    }
  }

  @override
  Future<AuthUser> currentUser({required String accessToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        return AuthUser.fromJson(response.data!);
      }
      throw AuthRequestException(
        _safeMessage(
          response.data,
          fallback: 'Không thể khôi phục thông tin tài khoản.',
        ),
        isTransient: (response.statusCode ?? 0) >= 500,
        invalidSession: response.statusCode == 401,
      );
    } on DioException catch (error) {
      throw AuthRequestException(
        'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
        isTransient:
            error.response == null || (error.response?.statusCode ?? 0) >= 500,
      );
    } on AuthRequestException {
      rethrow;
    } on Object {
      throw const AuthRequestException(
        'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.',
        isTransient: true,
      );
    }
  }

  @override
  Future<void> logout({required String accessToken}) async {
    try {
      final response = await _dio.post<void>(
        '/api/v1/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (response.statusCode == 204) {
        return;
      }
      throw const AuthRequestException(
        'Không thể thu hồi phiên trên máy chủ.',
        isTransient: true,
      );
    } on DioException catch (error) {
      throw AuthRequestException(
        'Không thể kết nối tới máy chủ để thu hồi phiên.',
        isTransient:
            error.response == null || (error.response?.statusCode ?? 0) >= 500,
      );
    } on AuthRequestException {
      rethrow;
    } on Object {
      throw const AuthRequestException(
        'Phản hồi từ máy chủ không hợp lệ.',
        isTransient: true,
      );
    }
  }

  String _safeMessage(
    Map<String, dynamic>? data, {
    String fallback =
        'Không thể đăng ký tài khoản. Vui lòng kiểm tra lại thông tin.',
  }) {
    final error = data?['error'];
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    return fallback;
  }
}
