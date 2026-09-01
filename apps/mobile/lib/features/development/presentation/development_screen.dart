import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../application/connectivity_controller.dart';
import '../application/connectivity_state.dart';

class DevelopmentScreen extends ConsumerStatefulWidget {
  const DevelopmentScreen({super.key});

  @override
  ConsumerState<DevelopmentScreen> createState() => _DevelopmentScreenState();
}

class _DevelopmentScreenState extends ConsumerState<DevelopmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectivityControllerProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityControllerProvider);
    final environment = _environmentName();
    final view = _ConnectivityView.fromStatus(connectivity.status);

    return Scaffold(
      appBar: AppBar(title: const Text('FireSafe Development')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusRow(label: 'API', value: view.api),
                const SizedBox(height: 12),
                _StatusRow(label: 'Database', value: view.database),
                const SizedBox(height: 12),
                _StatusRow(label: 'Environment', value: environment),
                const SizedBox(height: 24),
                if (connectivity.status == ConnectivityStatus.checking)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    onPressed: () {
                      ref.read(connectivityControllerProvider.notifier).check();
                    },
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _environmentName() {
    try {
      return ref.watch(appEnvironmentProvider).name;
    } on Object {
      return 'Configuration Error';
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('$label:')),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ConnectivityView {
  const _ConnectivityView({required this.api, required this.database});

  factory _ConnectivityView.fromStatus(ConnectivityStatus status) {
    return switch (status) {
      ConnectivityStatus.checking => const _ConnectivityView(
        api: 'Checking',
        database: 'Checking',
      ),
      ConnectivityStatus.apiUnavailable => const _ConnectivityView(
        api: 'Unavailable',
        database: 'Unknown',
      ),
      ConnectivityStatus.databaseUnavailable => const _ConnectivityView(
        api: 'Connected',
        database: 'Unavailable',
      ),
      ConnectivityStatus.ready => const _ConnectivityView(
        api: 'Connected',
        database: 'Connected',
      ),
    };
  }

  final String api;
  final String database;
}
