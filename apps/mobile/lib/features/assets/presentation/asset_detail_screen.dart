import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/asset_detail_controller.dart';
import '../data/asset_models.dart';

class AssetDetailScreen extends ConsumerStatefulWidget {
  const AssetDetailScreen({required this.assetId, super.key});

  final String assetId;

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetDetailControllerProvider(widget.assetId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetDetailControllerProvider(widget.assetId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết thiết bị'),
        actions: [
          if (state.asset != null)
            IconButton(
              tooltip: 'Chỉnh sửa',
              onPressed: () => context.push('/assets/${widget.assetId}/edit'),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: _body(state),
    );
  }

  Widget _body(AssetDetailState state) {
    if (state.isLoading && state.asset == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.asset == null) {
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
                    .read(
                      assetDetailControllerProvider(widget.assetId).notifier,
                    )
                    .load(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    final asset = state.asset;
    if (asset == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(asset.type, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _DetailRow(label: 'Mã thiết bị', value: asset.assetCode),
        _DetailRow(label: 'Loại phụ', value: _display(asset.subtype)),
        _DetailRow(label: 'Sức chứa', value: _capacity(asset)),
        _DetailRow(label: 'Nhà sản xuất', value: _display(asset.manufacturer)),
        _DetailRow(label: 'Model', value: _display(asset.model)),
        _DetailRow(label: 'Serial', value: _display(asset.serial)),
        _DetailRow(
          label: 'Vị trí chi tiết',
          value: _display(asset.locationText),
        ),
        _DetailRow(label: 'Vòng đời', value: asset.lifecycleState),
        _DetailRow(label: 'Nguồn', value: asset.source),
        _DetailRow(label: 'Revision', value: asset.revision.toString()),
        _DetailRow(
          label: 'Trạng thái vận hành',
          value: asset.operationalStatus ?? 'Chưa đánh giá',
        ),
        const _DetailRow(label: 'Mốc dịch vụ', value: 'Chưa có mốc dịch vụ'),
      ],
    );
  }

  String _capacity(Asset asset) {
    if (asset.capacityValue == null || asset.capacityUnit == null) {
      return 'Chưa cập nhật';
    }
    return '${asset.capacityValue} ${asset.capacityUnit}';
  }

  String _display(String? value) => value ?? 'Chưa cập nhật';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
