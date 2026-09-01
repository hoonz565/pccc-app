import 'package:firesafe_mobile/core/storage/credential_store.dart';

class EmptyTestCredentialStore implements CredentialStore {
  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String refreshToken) async {}
}
