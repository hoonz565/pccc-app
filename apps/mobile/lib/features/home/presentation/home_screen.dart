import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider);
    final facility = session.facilities.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FireSafe'),
        actions: [
          TextButton(
            onPressed: session.isLoading
                ? null
                : () =>
                      ref.read(appSessionControllerProvider.notifier).logout(),
            child: session.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Đăng xuất'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đã đăng nhập: ${session.user?.email ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              facility == null
                  ? 'Chưa có cơ sở.'
                  : 'Cơ sở hiện tại: ${facility.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sprint 1 xác nhận luồng định danh và cơ sở đầu tiên đã hoàn tất.',
            ),
            if (session.errorMessage case final errorMessage?) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
