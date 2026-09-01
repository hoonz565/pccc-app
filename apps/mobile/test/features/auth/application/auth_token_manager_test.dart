import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firesafe_mobile/core/config/app_environment.dart';
import 'package:firesafe_mobile/core/network/authenticated_dio_provider.dart';
import 'package:firesafe_mobile/core/storage/credential_store.dart';
import 'package:firesafe_mobile/features/auth/application/auth_token_manager.dart';
import 'package:firesafe_mobile/features/auth/data/auth_models.dart';
import 'package:firesafe_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent refresh callers share one rotation', () async {
    final releaseRefresh = Completer<void>();
    final repository = _CountingAuthRepository(releaseRefresh: releaseRefresh);
    final credentialStore = _MemoryCredentialStore('old-refresh-token');
    final manager = AccessTokenManager(() => repository, credentialStore);

    final refreshes = [
      manager.refreshAccessToken(),
      manager.refreshAccessToken(),
      manager.refreshAccessToken(),
    ];
    await Future<void>.delayed(Duration.zero);

    expect(repository.refreshCalls, 1);
    releaseRefresh.complete();
    expect(await Future.wait(refreshes), everyElement('fresh-access-token'));
    expect(credentialStore.refreshToken, 'rotated-refresh-token');
  });

  test('authenticated Dio attaches, refreshes, and retries once', () async {
    final repository = _CountingAuthRepository();
    final credentialStore = _MemoryCredentialStore('old-refresh-token');
    final manager = AccessTokenManager(() => repository, credentialStore)
      ..setAccessToken('stale-access-token');
    final adapter = _AuthenticationAdapter();
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          AppEnvironment(
            apiBaseUrl: Uri(scheme: 'https', host: 'example.test'),
            name: 'test',
          ),
        ),
        accessTokenManagerProvider.overrideWithValue(manager),
      ],
    );
    addTearDown(container.dispose);
    final dio = container.read(authenticatedDioProvider)
      ..httpClientAdapter = adapter;

    final response = await dio.get<Map<String, dynamic>>('/protected');

    expect(response.data, {'ok': true});
    expect(repository.refreshCalls, 1);
    expect(adapter.authorizationHeaders, [
      'Bearer stale-access-token',
      'Bearer fresh-access-token',
    ]);
  });

  test('authenticated Dio never loops after a retried 401', () async {
    final repository = _CountingAuthRepository();
    final manager = AccessTokenManager(
      () => repository,
      _MemoryCredentialStore('old-refresh-token'),
    )..setAccessToken('stale-access-token');
    final adapter = _AuthenticationAdapter(alwaysUnauthorized: true);
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          AppEnvironment(
            apiBaseUrl: Uri(scheme: 'https', host: 'example.test'),
            name: 'test',
          ),
        ),
        accessTokenManagerProvider.overrideWithValue(manager),
      ],
    );
    addTearDown(container.dispose);
    final dio = container.read(authenticatedDioProvider)
      ..httpClientAdapter = adapter;

    await expectLater(
      dio.get<Map<String, dynamic>>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(repository.refreshCalls, 1);
    expect(adapter.authorizationHeaders, hasLength(2));
  });
}

class _CountingAuthRepository implements AuthRepository {
  _CountingAuthRepository({this.releaseRefresh});

  final Completer<void>? releaseRefresh;
  int refreshCalls = 0;

  @override
  Future<AuthResult> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    await releaseRefresh?.future;
    return const AuthResult(
      user: AuthUser(
        id: 'user-id',
        email: 'user@example.test',
        termsVersion: 'draft-v1',
        privacyVersion: 'draft-v1',
      ),
      tokens: AuthTokens(
        accessToken: 'fresh-access-token',
        refreshToken: 'rotated-refresh-token',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<AuthUser> currentUser({required String accessToken}) =>
      throw UnimplementedError();

  @override
  Future<AuthResult> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout({required String accessToken}) async {}
}

class _MemoryCredentialStore implements CredentialStore {
  _MemoryCredentialStore(this.refreshToken);

  String? refreshToken;

  @override
  Future<void> deleteRefreshToken() async => refreshToken = null;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String refreshToken) async {
    this.refreshToken = refreshToken;
  }
}

class _AuthenticationAdapter implements HttpClientAdapter {
  _AuthenticationAdapter({this.alwaysUnauthorized = false});

  final bool alwaysUnauthorized;
  final List<String?> authorizationHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authorization = options.headers['Authorization'] as String?;
    authorizationHeaders.add(authorization);
    if (!alwaysUnauthorized && authorization == 'Bearer fresh-access-token') {
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"error":{"code":"UNAUTHENTICATED"}}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
