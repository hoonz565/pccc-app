import 'dart:async';

import 'package:firesafe_mobile/core/storage/credential_store.dart';
import 'package:firesafe_mobile/features/auth/application/app_session_controller.dart';
import 'package:firesafe_mobile/features/auth/application/app_session_state.dart';
import 'package:firesafe_mobile/features/auth/application/auth_token_manager.dart';
import 'package:firesafe_mobile/features/auth/data/auth_models.dart';
import 'package:firesafe_mobile/features/auth/data/auth_repository.dart';
import 'package:firesafe_mobile/features/facilities/data/facility_models.dart';
import 'package:firesafe_mobile/features/facilities/data/facility_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold start without a refresh credential becomes unauthenticated',
    () async {
      final container = ProviderContainer(
        overrides: [
          credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(appSessionControllerProvider).status,
        AppSessionStatus.bootstrapping,
      );

      await container.read(appSessionControllerProvider.notifier).bootstrap();

      expect(
        container.read(appSessionControllerProvider).status,
        AppSessionStatus.unauthenticated,
      );
    },
  );

  test('cold start rotates credential and restores Home state', () async {
    final credentialStore = _FakeCredentialStore('old-refresh-token');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _SuccessfulAuthRepository(),
        ),
        facilityRepositoryProvider.overrideWithValue(
          _SuccessfulFacilityRepository(
            facilities: const [
              Facility(
                id: 'facility-id',
                name: 'Kho đã lưu',
                type: 'Kho vận',
                province: 'Hà Nội',
                address: '123 Nguyễn Trãi',
                revision: 1,
              ),
            ],
          ),
        ),
        credentialStoreProvider.overrideWithValue(credentialStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).bootstrap();

    final state = container.read(appSessionControllerProvider);
    expect(state.status, AppSessionStatus.authenticatedReady);
    expect(state.facilities.single.name, 'Kho đã lưu');
    expect(
      container.read(accessTokenManagerProvider).accessToken,
      'access-token',
    );
    expect(credentialStore.refreshToken, 'refresh-token');
  });

  test(
    'invalid refresh clears credential and returns to login state',
    () async {
      final credentialStore = _FakeCredentialStore('revoked-refresh-token');
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _RestoreFailureAuthRepository(
              AuthRequestException(
                'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.',
                invalidSession: true,
              ),
            ),
          ),
          credentialStoreProvider.overrideWithValue(credentialStore),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appSessionControllerProvider.notifier).bootstrap();

      expect(
        container.read(appSessionControllerProvider).status,
        AppSessionStatus.unauthenticated,
      );
      expect(credentialStore.refreshToken, isNull);
    },
  );

  test('transient restore failure preserves credential for retry', () async {
    final credentialStore = _FakeCredentialStore('refresh-token-to-keep');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _RestoreFailureAuthRepository(
            AuthRequestException(
              'Không thể kết nối tới máy chủ. Vui lòng thử lại.',
              isTransient: true,
            ),
          ),
        ),
        credentialStoreProvider.overrideWithValue(credentialStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).bootstrap();

    expect(
      container.read(appSessionControllerProvider).status,
      AppSessionStatus.recoverableBootstrapFailure,
    );
    expect(credentialStore.refreshToken, 'refresh-token-to-keep');
  });

  test(
    'registration stores only refresh credential and authenticates',
    () async {
      final credentialStore = _FakeCredentialStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _SuccessfulAuthRepository(),
          ),
          credentialStoreProvider.overrideWithValue(credentialStore),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(appSessionControllerProvider.notifier)
          .register(
            email: 'user@example.test',
            password: 'a secure passphrase',
          );

      final state = container.read(appSessionControllerProvider);
      expect(state.status, AppSessionStatus.authenticatedNeedsFacility);
      expect(state.user?.email, 'user@example.test');
      expect(
        container.read(accessTokenManagerProvider).accessToken,
        'access-token',
      );
      expect(credentialStore.refreshToken, 'refresh-token');
      expect(
        credentialStore.refreshToken,
        isNot(container.read(accessTokenManagerProvider).accessToken),
      );
    },
  );

  test(
    'registration failure remains unauthenticated with safe error',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _FailingAuthRepository(),
          ),
          credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(appSessionControllerProvider.notifier)
          .register(
            email: 'user@example.test',
            password: 'a secure passphrase',
          );

      final state = container.read(appSessionControllerProvider);
      expect(state.status, AppSessionStatus.unauthenticated);
      expect(state.errorMessage, 'Không thể đăng ký.');
    },
  );

  test('first facility creation advances the session to Home state', () async {
    final facilityRepository = _SuccessfulFacilityRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _SuccessfulAuthRepository(),
        ),
        facilityRepositoryProvider.overrideWithValue(facilityRepository),
        credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(appSessionControllerProvider.notifier);
    await controller.register(
      email: 'user@example.test',
      password: 'a secure passphrase',
    );
    await controller.createFirstFacility(
      name: 'Kho trung tâm',
      type: 'Kho vận',
      province: 'Hà Nội',
      address: '123 Nguyễn Trãi',
    );

    final state = container.read(appSessionControllerProvider);
    expect(state.status, AppSessionStatus.authenticatedReady);
    expect(state.facilities.single.name, 'Kho trung tâm');
    expect(facilityRepository.lastType, 'Kho vận');
  });

  test('login with facilities restores an authenticated Home state', () async {
    final credentialStore = _FakeCredentialStore();
    final facilityRepository = _SuccessfulFacilityRepository(
      facilities: const [
        Facility(
          id: 'existing-facility-id',
          name: 'Nhà máy A',
          type: 'Sản xuất',
          province: 'Đà Nẵng',
          address: '1 Đường Biển',
          revision: 1,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _SuccessfulAuthRepository(),
        ),
        facilityRepositoryProvider.overrideWithValue(facilityRepository),
        credentialStoreProvider.overrideWithValue(credentialStore),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appSessionControllerProvider.notifier)
        .login(email: 'user@example.test', password: 'a secure passphrase');

    final state = container.read(appSessionControllerProvider);
    expect(state.status, AppSessionStatus.authenticatedReady);
    expect(state.facilities.single.name, 'Nhà máy A');
    expect(credentialStore.refreshToken, 'refresh-token');
  });

  test('login without facilities routes to first facility state', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _SuccessfulAuthRepository(),
        ),
        facilityRepositoryProvider.overrideWithValue(
          _SuccessfulFacilityRepository(),
        ),
        credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appSessionControllerProvider.notifier)
        .login(email: 'user@example.test', password: 'a secure passphrase');

    expect(
      container.read(appSessionControllerProvider).status,
      AppSessionStatus.authenticatedNeedsFacility,
    );
  });

  test('invalid login remains unauthenticated with a generic error', () async {
    final credentialStore = _FakeCredentialStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const _FailingAuthRepository(),
        ),
        credentialStoreProvider.overrideWithValue(credentialStore),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appSessionControllerProvider.notifier)
        .login(email: 'user@example.test', password: 'wrong password');

    final state = container.read(appSessionControllerProvider);
    expect(state.status, AppSessionStatus.unauthenticated);
    expect(state.errorMessage, 'Email hoặc mật khẩu không chính xác.');
    expect(credentialStore.refreshToken, isNull);
  });

  test(
    'logout revokes the refresh credential and clears local state',
    () async {
      final authRepository = _LogoutAuthRepository();
      final credentialStore = _FakeCredentialStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          facilityRepositoryProvider.overrideWithValue(
            _SuccessfulFacilityRepository(),
          ),
          credentialStoreProvider.overrideWithValue(credentialStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appSessionControllerProvider.notifier);
      await controller.login(
        email: 'user@example.test',
        password: 'a secure passphrase',
      );
      await controller.logout();

      expect(
        container.read(appSessionControllerProvider).status,
        AppSessionStatus.unauthenticated,
      );
      expect(container.read(accessTokenManagerProvider).accessToken, isNull);
      expect(credentialStore.refreshToken, isNull);
      expect(authRepository.revokedAccessToken, 'access-token');
    },
  );

  test(
    'logout invalidates a paused refresh without restoring credentials',
    () async {
      final authRepository = _PausedRefreshAuthRepository();
      final credentialStore = _FakeCredentialStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          facilityRepositoryProvider.overrideWithValue(
            _SuccessfulFacilityRepository(),
          ),
          credentialStoreProvider.overrideWithValue(credentialStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appSessionControllerProvider.notifier);
      final tokenManager = container.read(accessTokenManagerProvider);
      await controller.login(
        email: 'user@example.test',
        password: 'a secure passphrase',
      );

      final refresh = tokenManager.refreshAccessToken();
      await authRepository.refreshStarted.future;
      final logout = controller.logout();
      final blockedRefresh = tokenManager.refreshAccessToken();
      authRepository.releaseRefresh.complete();

      expect(await refresh, isNull);
      expect(await blockedRefresh, isNull);
      await logout;
      expect(authRepository.refreshCalls, 1);
      expect(
        container.read(appSessionControllerProvider).status,
        AppSessionStatus.unauthenticated,
      );
      expect(tokenManager.accessToken, isNull);
      expect(credentialStore.refreshToken, isNull);
      expect(authRepository.revokedAccessToken, 'access-token');
    },
  );

  test(
    'secure storage deletion failure keeps logout recoverable and observable',
    () async {
      final authRepository = _LogoutAuthRepository();
      final credentialStore = _DeleteFailingCredentialStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          facilityRepositoryProvider.overrideWithValue(
            _SuccessfulFacilityRepository(),
          ),
          credentialStoreProvider.overrideWithValue(credentialStore),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appSessionControllerProvider.notifier);
      await controller.login(
        email: 'user@example.test',
        password: 'a secure passphrase',
      );
      await controller.logout();

      final state = container.read(appSessionControllerProvider);
      expect(state.status, AppSessionStatus.authenticatedNeedsFacility);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('đăng xuất'));
      expect(
        container.read(accessTokenManagerProvider).accessToken,
        'access-token',
      );
      expect(credentialStore.refreshToken, 'refresh-token');
      expect(authRepository.revokedAccessToken, isNull);
    },
  );

  test(
    'facility creation failure preserves authenticated onboarding',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _SuccessfulAuthRepository(),
          ),
          facilityRepositoryProvider.overrideWithValue(
            const _FailingFacilityRepository(),
          ),
          credentialStoreProvider.overrideWithValue(_FakeCredentialStore()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appSessionControllerProvider.notifier);
      await controller.register(
        email: 'user@example.test',
        password: 'a secure passphrase',
      );
      await controller.createFirstFacility(
        name: 'Kho trung tâm',
        type: 'Kho vận',
        province: 'Hà Nội',
        address: '123 Nguyễn Trãi',
      );

      final state = container.read(appSessionControllerProvider);
      expect(state.status, AppSessionStatus.authenticatedNeedsFacility);
      expect(state.errorMessage, 'Không thể tạo cơ sở.');
      expect(
        container.read(accessTokenManagerProvider).accessToken,
        'access-token',
      );
    },
  );
}

class _SuccessfulAuthRepository implements AuthRepository {
  const _SuccessfulAuthRepository();

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    return const AuthResult(
      user: AuthUser(
        id: 'user-id',
        email: 'user@example.test',
        termsVersion: 'draft-v1',
        privacyVersion: 'draft-v1',
      ),
      tokens: AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<AuthResult> login({required String email, required String password}) =>
      register(email: email, password: password);

  @override
  Future<AuthResult> refresh({required String refreshToken}) =>
      register(email: 'user@example.test', password: 'not-used-during-refresh');

  @override
  Future<AuthUser> currentUser({required String accessToken}) async {
    return const AuthUser(
      id: 'user-id',
      email: 'user@example.test',
      termsVersion: 'draft-v1',
      privacyVersion: 'draft-v1',
    );
  }

  @override
  Future<void> logout({required String accessToken}) async {}
}

class _LogoutAuthRepository extends _SuccessfulAuthRepository {
  String? revokedAccessToken;

  @override
  Future<void> logout({required String accessToken}) async {
    revokedAccessToken = accessToken;
  }
}

class _PausedRefreshAuthRepository extends _LogoutAuthRepository {
  final refreshStarted = Completer<void>();
  final releaseRefresh = Completer<void>();
  int refreshCalls = 0;

  @override
  Future<AuthResult> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    refreshStarted.complete();
    await releaseRefresh.future;
    return const AuthResult(
      user: AuthUser(
        id: 'user-id',
        email: 'user@example.test',
        termsVersion: 'draft-v1',
        privacyVersion: 'draft-v1',
      ),
      tokens: AuthTokens(
        accessToken: 'late-access-token',
        refreshToken: 'late-refresh-token',
        expiresIn: 900,
      ),
    );
  }
}

class _FailingAuthRepository implements AuthRepository {
  const _FailingAuthRepository();

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    throw const AuthRequestException('Không thể đăng ký.');
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    throw const AuthRequestException('Email hoặc mật khẩu không chính xác.');
  }

  @override
  Future<AuthResult> refresh({required String refreshToken}) async {
    throw const AuthRequestException('Không thể khôi phục phiên.');
  }

  @override
  Future<AuthUser> currentUser({required String accessToken}) async {
    throw const AuthRequestException('Không thể tải người dùng.');
  }

  @override
  Future<void> logout({required String accessToken}) async {
    throw const AuthRequestException('Không thể đăng xuất.');
  }
}

class _FakeCredentialStore implements CredentialStore {
  _FakeCredentialStore([this.refreshToken]);

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

class _DeleteFailingCredentialStore extends _FakeCredentialStore {
  @override
  Future<void> deleteRefreshToken() async {
    throw StateError('secure storage unavailable');
  }
}

class _RestoreFailureAuthRepository implements AuthRepository {
  const _RestoreFailureAuthRepository(this.error);

  final AuthRequestException error;

  @override
  Future<AuthResult> refresh({required String refreshToken}) async {
    throw error;
  }

  @override
  Future<AuthUser> currentUser({required String accessToken}) async {
    throw error;
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    throw error;
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    throw error;
  }

  @override
  Future<void> logout({required String accessToken}) async {
    throw error;
  }
}

class _SuccessfulFacilityRepository implements FacilityRepository {
  _SuccessfulFacilityRepository({this.facilities = const []});

  final List<Facility> facilities;
  String? lastType;

  @override
  Future<Facility> create({
    required String name,
    required String type,
    required String province,
    required String address,
  }) async {
    lastType = type;
    return Facility(
      id: 'facility-id',
      name: name,
      type: type,
      province: province,
      address: address,
      revision: 1,
    );
  }

  @override
  Future<List<Facility>> list() async => facilities;
}

class _FailingFacilityRepository implements FacilityRepository {
  const _FailingFacilityRepository();

  @override
  Future<Facility> create({
    required String name,
    required String type,
    required String province,
    required String address,
  }) async {
    throw const FacilityRequestException('Không thể tạo cơ sở.');
  }

  @override
  Future<List<Facility>> list() async => const [];
}
