import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/area_list_controller.dart';

class AreaListScreen extends ConsumerStatefulWidget {
  const AreaListScreen({required this.facilityId, super.key});

  final String facilityId;

  @override
  ConsumerState<AreaListScreen> createState() => _AreaListScreenState();
}

class _AreaListScreenState extends ConsumerState<AreaListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(areaListControllerProvider(widget.facilityId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(areaListControllerProvider(widget.facilityId));
    return Scaffold(
      appBar: AppBar(title: const Text('Khu vực')),
      body: _body(state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/facilities/${widget.facilityId}/areas/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tạo khu vực'),
      ),
    );
  }

  Widget _body(AreaListState state) {
    if (state.isLoading && state.areas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.areas.isEmpty) {
      return _RecoverableError(
        message: state.errorMessage!,
        onRetry: () => ref
            .read(areaListControllerProvider(widget.facilityId).notifier)
            .load(),
      );
    }
    if (state.areas.isEmpty) {
      return const Center(child: Text('Chưa có khu vực trong cơ sở này.'));
    }
    return RefreshIndicator(
      onRefresh: () => ref
          .read(areaListControllerProvider(widget.facilityId).notifier)
          .load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: state.areas.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final area = state.areas[index];
          return ListTile(
            title: Text(area.name),
            subtitle: Text('Revision ${area.revision}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/areas/${area.id}/assets'),
          );
        },
      ),
    );
  }
}

class _RecoverableError extends StatelessWidget {
  const _RecoverableError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
