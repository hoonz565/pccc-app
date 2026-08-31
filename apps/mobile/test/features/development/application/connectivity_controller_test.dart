import 'package:firesafe_mobile/features/development/application/connectivity_controller.dart';
import 'package:firesafe_mobile/features/development/application/connectivity_state.dart';
import 'package:firesafe_mobile/features/development/data/connectivity_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final testCase in _testCases) {
    test('maps ${testCase.probeResult.name}', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityRepositoryProvider.overrideWithValue(
            _FakeConnectivityRepository(testCase.probeResult),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(connectivityControllerProvider).status,
        ConnectivityStatus.checking,
      );

      await container.read(connectivityControllerProvider.notifier).check();

      expect(
        container.read(connectivityControllerProvider).status,
        testCase.expectedStatus,
      );
    });
  }
}

const _testCases = [
  (
    probeResult: ConnectivityProbeResult.apiUnavailable,
    expectedStatus: ConnectivityStatus.apiUnavailable,
  ),
  (
    probeResult: ConnectivityProbeResult.databaseUnavailable,
    expectedStatus: ConnectivityStatus.databaseUnavailable,
  ),
  (
    probeResult: ConnectivityProbeResult.ready,
    expectedStatus: ConnectivityStatus.ready,
  ),
];

class _FakeConnectivityRepository implements ConnectivityRepository {
  const _FakeConnectivityRepository(this.result);

  final ConnectivityProbeResult result;

  @override
  Future<ConnectivityProbeResult> check() async => result;
}
