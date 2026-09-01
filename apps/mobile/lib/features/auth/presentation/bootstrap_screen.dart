import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_session_controller.dart';
import '../application/app_session_state.dart';

class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appSessionControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appSessionControllerProvider);
    return Scaffold(
      body: Center(
        child: state.status == AppSessionStatus.recoverableBootstrapFailure
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Không thể khôi phục phiên.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref
                        .read(appSessionControllerProvider.notifier)
                        .bootstrap(),
                    child: const Text('Thử lại'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
