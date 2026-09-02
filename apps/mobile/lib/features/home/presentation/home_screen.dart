import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/app_session_controller.dart';
import '../../facilities/application/facility_selection_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider);
    final selectedFacilityId = ref.watch(selectedFacilityIdProvider);
    final selectedFacility = session.facilities
        .where((facility) => facility.id == selectedFacilityId)
        .firstOrNull;
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đã đăng nhập: ${session.user?.email ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Chọn cơ sở làm việc',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(selectedFacilityId),
                initialValue: selectedFacilityId,
                decoration: const InputDecoration(labelText: 'Cơ sở'),
                items: [
                  for (final facility in session.facilities)
                    DropdownMenuItem(
                      value: facility.id,
                      child: Text(facility.name),
                    ),
                ],
                onChanged: session.isLoading
                    ? null
                    : (facilityId) {
                        if (facilityId != null) {
                          ref
                              .read(selectedFacilityIdProvider.notifier)
                              .select(facilityId);
                        }
                      },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: selectedFacility == null
                    ? null
                    : () => context.push(
                        '/facilities/${selectedFacility.id}/areas',
                      ),
                icon: const Icon(Icons.apartment),
                label: const Text('Xem khu vực và thiết bị'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/ocr/date-extraction'),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Nhận dạng ngày trên tem'),
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
      ),
    );
  }
}
