import 'package:firesafe_mobile/app.dart';
import 'package:firesafe_mobile/core/config/app_environment.dart';
import 'package:firesafe_mobile/core/network/dio_provider.dart';
import 'package:firesafe_mobile/features/development/data/connectivity_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the FireSafe development screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            AppEnvironment(
              apiBaseUrl: Uri.parse('http://example.test'),
              name: 'test',
            ),
          ),
          connectivityRepositoryProvider.overrideWithValue(
            _FakeConnectivityRepository(ConnectivityProbeResult.ready),
          ),
        ],
        child: const FireSafeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FireSafe Development'), findsOneWidget);
    expect(find.text('API:'), findsOneWidget);
    expect(find.text('Database:'), findsOneWidget);
    expect(find.text('Environment:'), findsOneWidget);
  });
}

class _FakeConnectivityRepository implements ConnectivityRepository {
  const _FakeConnectivityRepository(this.result);

  final ConnectivityProbeResult result;

  @override
  Future<ConnectivityProbeResult> check() async => result;
}
