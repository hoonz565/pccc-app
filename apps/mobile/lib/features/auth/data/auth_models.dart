class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.termsVersion,
    required this.privacyVersion,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      termsVersion: json['terms_version'] as String,
      privacyVersion: json['privacy_version'] as String,
    );
  }

  final String id;
  final String email;
  final String termsVersion;
  final String privacyVersion;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

class AuthResult {
  const AuthResult({required this.user, required this.tokens});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }

  final AuthUser user;
  final AuthTokens tokens;
}

class AuthRequestException implements Exception {
  const AuthRequestException(
    this.message, {
    this.isTransient = false,
    this.invalidSession = false,
  });

  final String message;
  final bool isTransient;
  final bool invalidSession;
}
