import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/credential_store.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

final accessTokenManagerProvider = Provider<AccessTokenManager>(
  (ref) => AccessTokenManager(
    () => ref.read(authRepositoryProvider),
    ref.watch(credentialStoreProvider),
  ),
);

class AccessTokenManager {
  AccessTokenManager(this._readAuthRepository, this._credentialStore);

  final AuthRepository Function() _readAuthRepository;
  final CredentialStore _credentialStore;

  String? _accessToken;
  Future<String?>? _refreshInFlight;
  Future<void>? _logoutInFlight;
  bool _logoutInProgress = false;
  int _sessionEpoch = 0;

  String? get accessToken => _accessToken;

  void setAccessToken(String accessToken) {
    _sessionEpoch += 1;
    _accessToken = accessToken;
  }

  Future<String?> refreshAccessToken() {
    if (_logoutInProgress) {
      return Future<String?>.value();
    }
    final pendingRefresh = _refreshInFlight;
    if (pendingRefresh != null) {
      return pendingRefresh;
    }

    final refreshEpoch = _sessionEpoch;
    late final Future<String?> refresh;
    refresh = _performRefresh(refreshEpoch).whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = refresh;
    return refresh;
  }

  Future<String?> _performRefresh(int refreshEpoch) async {
    if (!_canApplyRefresh(refreshEpoch)) {
      return null;
    }
    final refreshToken = await _credentialStore.readRefreshToken();
    if (!_canApplyRefresh(refreshEpoch)) {
      return null;
    }
    if (refreshToken == null) {
      _accessToken = null;
      return null;
    }

    try {
      final result = await _readAuthRepository().refresh(
        refreshToken: refreshToken,
      );
      if (!_canApplyRefresh(refreshEpoch)) {
        return null;
      }
      try {
        await _credentialStore.writeRefreshToken(result.tokens.refreshToken);
      } on Object {
        await clearSession();
        return null;
      }
      if (!_canApplyRefresh(refreshEpoch)) {
        return null;
      }
      _accessToken = result.tokens.accessToken;
      return _accessToken;
    } on AuthRequestException catch (error) {
      if (error.invalidSession) {
        if (_canApplyRefresh(refreshEpoch)) {
          await clearSession();
        }
        return null;
      }
      rethrow;
    }
  }

  bool _canApplyRefresh(int refreshEpoch) =>
      !_logoutInProgress && refreshEpoch == _sessionEpoch;

  Future<void> clearSession() async {
    _sessionEpoch += 1;
    _accessToken = null;
    try {
      await _credentialStore.deleteRefreshToken();
    } on Object {
      // Keep the app unauthenticated even if native secure storage is unavailable.
    }
  }

  Future<void> logout() {
    final pendingLogout = _logoutInFlight;
    if (pendingLogout != null) {
      return pendingLogout;
    }

    late final Future<void> logout;
    logout = _performLogout().whenComplete(() {
      if (identical(_logoutInFlight, logout)) {
        _logoutInFlight = null;
      }
    });
    _logoutInFlight = logout;
    return logout;
  }

  Future<void> _performLogout() async {
    _logoutInProgress = true;
    _sessionEpoch += 1;
    final pendingRefresh = _refreshInFlight;
    try {
      if (pendingRefresh != null) {
        try {
          await pendingRefresh;
        } on Object {
          // Continue with local logout even when an in-flight refresh failed.
        }
      }

      final accessToken = _accessToken;
      try {
        await _credentialStore.deleteRefreshToken();
      } on Object {
        throw const LogoutException(
          'Không thể hoàn tất đăng xuất an toàn. Vui lòng thử lại.',
        );
      }
      _accessToken = null;

      if (accessToken != null) {
        try {
          await _readAuthRepository().logout(accessToken: accessToken);
        } on Object {
          // Local logout remains valid when server revocation is temporarily offline.
        }
      }
    } finally {
      _logoutInProgress = false;
    }
  }
}

class LogoutException implements Exception {
  const LogoutException(this.message);

  final String message;
}
