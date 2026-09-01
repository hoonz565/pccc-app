import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/credential_store.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../../facilities/data/facility_models.dart';
import '../../facilities/data/facility_repository.dart';
import 'app_session_state.dart';
import 'auth_token_manager.dart';

final appSessionControllerProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );

final authenticatedSessionIdentityProvider =
    Provider<AuthenticatedSessionIdentity?>((ref) {
      final principalId = ref.watch(
        appSessionControllerProvider.select((session) => session.user?.id),
      );
      return principalId == null
          ? null
          : AuthenticatedSessionIdentity(principalId);
    });

class AuthenticatedSessionIdentity {
  const AuthenticatedSessionIdentity(this.principalId);

  final String principalId;
}

class AppSessionController extends Notifier<AppSessionState> {
  @override
  AppSessionState build() => const AppSessionState.bootstrapping();

  Future<void> bootstrap() async {
    if (state.status != AppSessionStatus.bootstrapping &&
        state.status != AppSessionStatus.recoverableBootstrapFailure) {
      return;
    }
    state = const AppSessionState.bootstrapping();
    try {
      final accessToken = await ref
          .read(accessTokenManagerProvider)
          .refreshAccessToken();
      if (accessToken == null) {
        state = const AppSessionState.unauthenticated();
        return;
      }
      final user = await ref
          .read(authRepositoryProvider)
          .currentUser(accessToken: accessToken);
      final facilities = await ref.read(facilityRepositoryProvider).list();
      setAuthenticatedFacilities(user: user, facilities: facilities);
    } on AuthRequestException catch (error) {
      if (error.invalidSession) {
        await ref.read(accessTokenManagerProvider).clearSession();
        state = const AppSessionState.unauthenticated();
      } else {
        state = AppSessionState.recoverableBootstrapFailure(error.message);
      }
    } on FacilityRequestException catch (error) {
      if (error.invalidSession) {
        await ref.read(accessTokenManagerProvider).clearSession();
        state = const AppSessionState.unauthenticated();
      } else {
        state = AppSessionState.recoverableBootstrapFailure(error.message);
      }
    } on Object {
      state = const AppSessionState.recoverableBootstrapFailure(
        'Không thể khôi phục phiên đăng nhập. Vui lòng thử lại.',
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = const AppSessionState.unauthenticated(isLoading: true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .register(email: email, password: password);
      await ref
          .read(credentialStoreProvider)
          .writeRefreshToken(result.tokens.refreshToken);
      ref
          .read(accessTokenManagerProvider)
          .setAccessToken(result.tokens.accessToken);
      state = AppSessionState.authenticatedNeedsFacility(user: result.user);
    } on AuthRequestException catch (error) {
      state = AppSessionState.unauthenticated(errorMessage: error.message);
    } on Object {
      state = const AppSessionState.unauthenticated(
        errorMessage:
            'Không thể lưu phiên đăng nhập an toàn. Vui lòng thử lại.',
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AppSessionState.unauthenticated(isLoading: true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await ref
          .read(credentialStoreProvider)
          .writeRefreshToken(result.tokens.refreshToken);
      ref
          .read(accessTokenManagerProvider)
          .setAccessToken(result.tokens.accessToken);
      final facilities = await ref.read(facilityRepositoryProvider).list();
      setAuthenticatedFacilities(user: result.user, facilities: facilities);
    } on AuthRequestException catch (error) {
      state = AppSessionState.unauthenticated(errorMessage: error.message);
    } on FacilityRequestException catch (error) {
      if (error.invalidSession) {
        await ref.read(accessTokenManagerProvider).clearSession();
        state = const AppSessionState.unauthenticated();
      } else {
        state = AppSessionState.recoverableBootstrapFailure(error.message);
      }
    } on Object {
      state = const AppSessionState.unauthenticated(
        errorMessage:
            'Không thể lưu phiên đăng nhập an toàn. Vui lòng thử lại.',
      );
    }
  }

  Future<void> createFirstFacility({
    required String name,
    required String type,
    required String province,
    required String address,
  }) async {
    final user = state.user;
    final accessToken = ref.read(accessTokenManagerProvider).accessToken;
    if (user == null || accessToken == null) {
      state = const AppSessionState.unauthenticated();
      return;
    }
    state = AppSessionState.authenticatedNeedsFacility(
      user: user,
      isLoading: true,
    );
    try {
      final facility = await ref
          .read(facilityRepositoryProvider)
          .create(name: name, type: type, province: province, address: address);
      state = AppSessionState.authenticatedReady(
        user: user,
        facilities: [facility],
      );
    } on FacilityRequestException catch (error) {
      if (error.invalidSession) {
        await ref.read(accessTokenManagerProvider).clearSession();
        state = const AppSessionState.unauthenticated();
      } else {
        state = AppSessionState.authenticatedNeedsFacility(
          user: user,
          errorMessage: error.message,
        );
      }
    } on Object {
      state = AppSessionState.authenticatedNeedsFacility(
        user: user,
        errorMessage: 'Không thể tạo cơ sở. Vui lòng thử lại.',
      );
    }
  }

  Future<void> logout() async {
    final authenticatedState = state;
    state = authenticatedState.withInteraction(isLoading: true);
    try {
      await ref.read(accessTokenManagerProvider).logout();
      state = const AppSessionState.unauthenticated();
    } on LogoutException catch (error) {
      state = authenticatedState.withInteraction(errorMessage: error.message);
    } on Object {
      state = authenticatedState.withInteraction(
        errorMessage: 'Không thể hoàn tất đăng xuất. Vui lòng thử lại.',
      );
    }
  }

  Future<void> invalidateSession() async {
    await ref.read(accessTokenManagerProvider).clearSession();
    state = const AppSessionState.unauthenticated();
  }

  void setAuthenticatedFacilities({
    required AuthUser user,
    required List<Facility> facilities,
  }) {
    state = facilities.isEmpty
        ? AppSessionState.authenticatedNeedsFacility(user: user)
        : AppSessionState.authenticatedReady(
            user: user,
            facilities: facilities,
          );
  }
}
