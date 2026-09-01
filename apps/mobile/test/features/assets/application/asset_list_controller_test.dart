import 'dart:async';

import 'package:firesafe_mobile/features/assets/application/asset_list_controller.dart';
import 'package:firesafe_mobile/features/assets/data/asset_models.dart';
import 'package:firesafe_mobile/features/assets/data/asset_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/sprint2_fakes.dart';

void main() {
  test('Asset lists remain isolated by Area context', () async {
    final repository = FakeAssetRepository(
      assets: [
        assetFixture(id: 'asset-a', areaId: 'area-a'),
        assetFixture(id: 'asset-b', areaId: 'area-b'),
      ],
    );
    final container = ProviderContainer(
      overrides: [assetRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final areaASubscription = container.listen(
      assetListControllerProvider('area-a'),
      (_, _) {},
    );
    final areaBSubscription = container.listen(
      assetListControllerProvider('area-b'),
      (_, _) {},
    );
    addTearDown(areaASubscription.close);
    addTearDown(areaBSubscription.close);

    await container.read(assetListControllerProvider('area-a').notifier).load();
    await container.read(assetListControllerProvider('area-b').notifier).load();

    expect(
      container.read(assetListControllerProvider('area-a')).assets.single.id,
      'asset-a',
    );
    expect(
      container.read(assetListControllerProvider('area-b')).assets.single.id,
      'asset-b',
    );
  });

  test(
    'Asset pagination loads offset 50 once and removes duplicates',
    () async {
      final firstPage = [
        for (var index = 0; index < assetPageSize; index += 1)
          assetFixture(id: 'asset-$index'),
      ];
      final secondPageCompleter = Completer<List<Asset>>();
      final repository = FakeAssetRepository(
        listHandler: ({required areaId, required limit, required offset}) {
          if (offset == 0) {
            return Future.value(firstPage);
          }
          return secondPageCompleter.future;
        },
      );
      final container = ProviderContainer(
        overrides: [assetRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        assetListControllerProvider('area-id'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        assetListControllerProvider('area-id').notifier,
      );

      await controller.load();
      expect(
        container.read(assetListControllerProvider('area-id')).assets,
        hasLength(50),
      );
      expect(
        container.read(assetListControllerProvider('area-id')).nextOffset,
        50,
      );
      expect(
        container.read(assetListControllerProvider('area-id')).hasMore,
        isTrue,
      );

      final firstLoadMore = controller.loadMore();
      final duplicateLoadMore = controller.loadMore();
      expect(repository.listCalls, 2);
      expect(repository.requestedOffsets, [0, 50]);

      secondPageCompleter.complete([
        assetFixture(id: 'asset-49'),
        for (var index = 50; index < 63; index += 1)
          assetFixture(id: 'asset-$index'),
      ]);
      await Future.wait([firstLoadMore, duplicateLoadMore]);

      final state = container.read(assetListControllerProvider('area-id'));
      expect(state.assets, hasLength(63));
      expect(state.assets.map((asset) => asset.id).toSet(), hasLength(63));
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    },
  );

  test('Asset list exposes a recoverable error state', () async {
    final container = ProviderContainer(
      overrides: [
        assetRepositoryProvider.overrideWithValue(
          FakeAssetRepository(
            error: const AssetRequestException('Không thể tải thiết bị.'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      assetListControllerProvider('area-id'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container
        .read(assetListControllerProvider('area-id').notifier)
        .load();

    final state = container.read(assetListControllerProvider('area-id'));
    expect(state.assets, isEmpty);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, 'Không thể tải thiết bị.');
  });
}
