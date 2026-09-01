import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/asset_list_controller.dart';

class AssetListScreen extends ConsumerStatefulWidget {
  const AssetListScreen({required this.areaId, super.key});

  final String areaId;

  @override
  ConsumerState<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends ConsumerState<AssetListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetListControllerProvider(widget.areaId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetListControllerProvider(widget.areaId));
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết bị PCCC')),
      body: _body(state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/areas/${widget.areaId}/assets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thiết bị'),
      ),
    );
  }

  Widget _body(AssetListState state) {
    if (state.isLoading && state.assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref
                    .read(assetListControllerProvider(widget.areaId).notifier)
                    .load(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.assets.isEmpty) {
      return const Center(child: Text('Chưa có thiết bị trong khu vực này.'));
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(assetListControllerProvider(widget.areaId).notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: state.assets.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          if (index == state.assets.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  if (state.loadMoreErrorMessage case final error?) ...[
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton(
                    onPressed: state.isLoadingMore
                        ? null
                        : () => ref
                              .read(
                                assetListControllerProvider(widget.areaId)
                                    .notifier,
                              )
                              .loadMore(),
                    child: state.isLoadingMore
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tải thêm'),
                  ),
                ],
              ),
            );
          }
          final asset = state.assets[index];
          return ListTile(
            title: Text(asset.type),
            subtitle: Text(asset.assetCode),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/assets/${asset.id}'),
          );
        },
      ),
    );
  }
}
