import 'dart:async';

import 'package:firesafe_mobile/app.dart';
import 'package:firesafe_mobile/core/config/app_environment.dart';
import 'package:firesafe_mobile/core/network/dio_provider.dart';
import 'package:firesafe_mobile/features/development/data/connectivity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows checking while the probe is pending', (tester) async {
    final repository = _PendingConnectivityRepository();
    await _pumpApp(tester, repository);

    expect(find.text('Checking'), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.complete(ConnectivityProbeResult.ready);
    await tester.pumpAndSettle();
  });

  for (final testCase in _testCases) {
    testWidgets('shows ${testCase.name}', (tester) async {
      await _pumpApp(tester, _ImmediateConnectivityRepository(testCase.result));
      await tester.pumpAndSettle();

      final sharedStatus = testCase.apiText == testCase.databaseText;
      expect(find.text(testCase.apiText), findsNWidgets(sharedStatus ? 2 : 1));
      if (!sharedStatus) {
        expect(find.text(testCase.databaseText), findsOneWidget);
      }
      expect(find.text('test'), findsOneWidget);
    });
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  ConnectivityRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          AppEnvironment(
            apiBaseUrl: Uri.parse('http://example.test'),
            name: 'test',
          ),
        ),
        connectivityRepositoryProvider.overrideWithValue(repository),
      ],
      child: const FireSafeApp(),
    ),
  );
  await tester.pump();
}

const _testCases = [
  (
    name: 'API unavailable',
    result: ConnectivityProbeResult.apiUnavailable,
    apiText: 'Unavailable',
    databaseText: 'Unknown',
  ),
  (
    name: 'database unavailable',
    result: ConnectivityProbeResult.databaseUnavailable,
    apiText: 'Connected',
    databaseText: 'Unavailable',
  ),
  (
    name: 'ready',
    result: ConnectivityProbeResult.ready,
    apiText: 'Connected',
    databaseText: 'Connected',
  ),
];

class _ImmediateConnectivityRepository implements ConnectivityRepository {
  const _ImmediateConnectivityRepository(this.result);

  final ConnectivityProbeResult result;

  @override
  Future<ConnectivityProbeResult> check() async => result;
}

class _PendingConnectivityRepository implements ConnectivityRepository {
  final _completer = Completer<ConnectivityProbeResult>();

  @override
  Future<ConnectivityProbeResult> check() => _completer.future;

  void complete(ConnectivityProbeResult result) => _completer.complete(result);
}
