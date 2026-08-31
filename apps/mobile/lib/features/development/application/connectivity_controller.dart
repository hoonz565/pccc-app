import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/connectivity_repository.dart';
import 'connectivity_state.dart';

final connectivityControllerProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );

class ConnectivityController extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() => const ConnectivityState.checking();

  Future<void> check() async {
    state = const ConnectivityState.checking();

    try {
      final result = await ref.read(connectivityRepositoryProvider).check();
      state = switch (result) {
        ConnectivityProbeResult.apiUnavailable => const ConnectivityState(
          ConnectivityStatus.apiUnavailable,
        ),
        ConnectivityProbeResult.databaseUnavailable => const ConnectivityState(
          ConnectivityStatus.databaseUnavailable,
        ),
        ConnectivityProbeResult.ready => const ConnectivityState(
          ConnectivityStatus.ready,
        ),
      };
    } on Object {
      state = const ConnectivityState(ConnectivityStatus.apiUnavailable);
    }
  }
}
