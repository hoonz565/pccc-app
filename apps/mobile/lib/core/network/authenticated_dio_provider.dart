import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_token_manager.dart';
import '../../features/auth/data/auth_models.dart';
import '../config/app_environment.dart';

const _retriedRequestKey = 'firesafe_auth_retried';

final authenticatedDioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final tokenManager = ref.watch(accessTokenManagerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: environment.apiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      validateStatus: (status) =>
          status != null && status < 600 && status != 401,
    ),
  );
  dio.interceptors.add(_AuthenticationInterceptor(dio, tokenManager));
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

class _AuthenticationInterceptor extends Interceptor {
  _AuthenticationInterceptor(this._dio, this._tokenManager);

  final Dio _dio;
  final AccessTokenManager _tokenManager;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final accessToken = _tokenManager.accessToken;
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode != 401 ||
        error.requestOptions.extra[_retriedRequestKey] == true) {
      handler.next(error);
      return;
    }

    try {
      final failedAuthorization =
          error.requestOptions.headers['Authorization'] as String?;
      final currentAccessToken = _tokenManager.accessToken;
      final failedAccessToken =
          failedAuthorization?.startsWith('Bearer ') == true
          ? failedAuthorization!.substring('Bearer '.length)
          : null;
      final accessToken =
          currentAccessToken != null && currentAccessToken != failedAccessToken
          ? currentAccessToken
          : await _tokenManager.refreshAccessToken();
      if (accessToken == null) {
        handler.next(error);
        return;
      }

      final retriedOptions = error.requestOptions.copyWith(
        headers: {
          ...error.requestOptions.headers,
          'Authorization': 'Bearer $accessToken',
        },
        extra: {...error.requestOptions.extra, _retriedRequestKey: true},
      );
      final response = await _dio.fetch<dynamic>(retriedOptions);
      handler.resolve(response);
    } on AuthRequestException catch (refreshError) {
      handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          error: refreshError,
          message: refreshError.message,
        ),
      );
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Object {
      handler.next(error);
    }
  }
}
