import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String refreshToken);

  Future<void> deleteRefreshToken();
}

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => const FlutterSecureCredentialStore(FlutterSecureStorage()),
);

class FlutterSecureCredentialStore implements CredentialStore {
  const FlutterSecureCredentialStore(this._storage);

  static const _refreshTokenKey = 'firesafe_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String refreshToken) =>
      _storage.write(key: _refreshTokenKey, value: refreshToken);

  @override
  Future<void> deleteRefreshToken() => _storage.delete(key: _refreshTokenKey);
}
