import 'package:flutter_riverpod/flutter_riverpod.dart';

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => AppEnvironment.fromCompileTime(),
);

class AppEnvironment {
  const AppEnvironment({required this.apiBaseUrl, required this.name});

  factory AppEnvironment.fromCompileTime() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const name = String.fromEnvironment('APP_ENV', defaultValue: 'development');

    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is required. Pass it with --dart-define=API_BASE_URL=<url>.',
      );
    }

    final parsedUrl = Uri.tryParse(apiBaseUrl);
    if (parsedUrl == null ||
        !{'http', 'https'}.contains(parsedUrl.scheme.toLowerCase()) ||
        parsedUrl.host.isEmpty) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) URL.');
    }

    return AppEnvironment(apiBaseUrl: parsedUrl, name: name);
  }

  final Uri apiBaseUrl;
  final String name;
}
