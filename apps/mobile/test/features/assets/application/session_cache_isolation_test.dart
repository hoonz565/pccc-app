import 'dart:async';

import 'package:firesafe_mobile/core/storage/credential_store.dart';
import 'package:firesafe_mobile/features/areas/application/area_list_controller.dart';
import 'package:firesafe_mobile/features/areas/data/area_models.dart';
import 'package:firesafe_mobile/features/areas/data/area_repository.dart';
import 'package:firesafe_mobile/features/assets/application/asset_detail_controller.dart';
import 'package:firesafe_mobile/features/assets/application/asset_list_controller.dart';
import 'package:firesafe_mobile/features/assets/data/asset_models.dart';
import 'package:firesafe_mobile/features/assets/data/asset_repository.dart';
import 'package:firesafe_mobile/features/auth/application/app_session_controller.dart';
import 'package:firesafe_mobile/features/auth/data/auth_models.dart';
import 'package:firesafe_mobile/features/facilities/data/facility_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/sprint2_fakes.dart';
import '../../../helpers/test_credential_store.dart';

void main() {
  test(
    'logout isolates principal cache and safe 404 cannot reveal stale data',
    () async {
      final areaRepository = FakeAreaRepository(
        areas: [
          areaFixture(
            id: 'shared-area',
            facilityId: 'shared-facility',
            name: 'Principal A area',
          ),
        ],
      );
      final assetRepository = FakeAssetRepository(
        assets: [
          assetFixture(
            id: 'shared-asset',
            areaId: 'shared-area',
            type: 'Principal A asset',
          ),
        ],
      );
      final container = _container(areaRepository, assetRepository);
      addTearDown(container.dispose);
      _authenticate(container, _userA);
      final subscriptions = _listenToProtectedState(container);
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });

      await _loadAll(container);
      expect(
        container
            .read(areaListControllerProvider('shared-facility'))
            .areas
            .single
            .name,
        'Principal A area',
      );
      expect(
        container
            .read(assetListControllerProvider('shared-area'))
            .assets
            .single
            .type,
        'Principal A asset',
      );
      expect(
        container
            .read(assetDetailControllerProvider('shared-asset'))
            .asset
            ?.type,
        'Principal A asset',
      );

      await container.read(appSessionControllerProvider.notifier).logout();
      _expectProtectedStateCleared(container);
      _authenticate(container, _userB);
      areaRepository.error = const AreaRequestException(
        'Area not found.',
        statusCode: 404,
        code: 'AREA_NOT_FOUND',
      );
      assetRepository.error = const AssetRequestException(
        'Asset not found.',
        statusCode: 404,
        code: 'ASSET_NOT_FOUND',
      );

      await _loadAll(container);
      _expectProtectedStateCleared(container);
      expect(
        container
            .read(areaListControllerProvider('shared-facility'))
            .errorMessage,
        'Area not found.',
      );
      expect(
        container
            .read(assetDetailControllerProvider('shared-asset'))
            .errorMessage,
        'Asset not found.',
      );

      areaRepository
        ..error = null
        ..areas = [
          areaFixture(
            id: 'shared-area',
            facilityId: 'shared-facility',
            name: 'Principal B area',
          ),
        ];
      assetRepository
        ..error = null
        ..assets = [
          assetFixture(
            id: 'shared-asset',
            areaId: 'shared-area',
            type: 'Principal B asset',
          ),
        ];

      await _loadAll(container);
      expect(
        container
            .read(areaListControllerProvider('shared-facility'))
            .areas
            .single
            .name,
        'Principal B area',
      );
      expect(
        container
            .read(assetListControllerProvider('shared-area'))
            .assets
            .single
            .type,
        'Principal B asset',
      );
      expect(
        container
            .read(assetDetailControllerProvider('shared-asset'))
            .asset
            ?.type,
        'Principal B asset',
      );
    },
  );

  test(
    'invalid session clears loading and same key reloads after login',
    () async {
      final areaRepository = FakeAreaRepository();
      final assetRepository = FakeAssetRepository(
        assets: [assetFixture(type: 'Old session asset')],
      );
      final container = _container(areaRepository, assetRepository);
      addTearDown(container.dispose);
      _authenticate(container, _userA);
      final subscription = container.listen(
        assetListControllerProvider('area-id'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container
          .read(assetListControllerProvider('area-id').notifier)
          .load();
      expect(
        container
            .read(assetListControllerProvider('area-id'))
            .assets
            .single
            .type,
        'Old session asset',
      );

      assetRepository.error = const AssetRequestException(
        'Session expired.',
        statusCode: 401,
        invalidSession: true,
      );
      await container
          .read(assetListControllerProvider('area-id').notifier)
          .load();
      expect(container.read(appSessionControllerProvider).user, isNull);
      final invalidState = container.read(
        assetListControllerProvider('area-id'),
      );
      expect(invalidState.assets, isEmpty);
      expect(invalidState.isLoading, isFalse);

      _authenticate(container, _userA);
      assetRepository
        ..error = null
        ..assets = [assetFixture(type: 'Fresh login asset')];
      await container
          .read(assetListControllerProvider('area-id').notifier)
          .load();

      final freshState = container.read(assetListControllerProvider('area-id'));
      expect(freshState.assets.single.type, 'Fresh login asset');
      expect(freshState.isLoading, isFalse);
    },
  );

  test(
    'pending pagination from an old principal cannot publish to the new one',
    () async {
      final pendingSecondPage = Completer<List<Asset>>();
      var firstPage = [
        for (var index = 0; index < assetPageSize; index += 1)
          assetFixture(id: 'a-$index'),
      ];
      final assetRepository = FakeAssetRepository(
        listHandler: ({required areaId, required limit, required offset}) {
          return offset == 0
              ? Future.value(firstPage)
              : pendingSecondPage.future;
        },
      );
      final container = _container(FakeAreaRepository(), assetRepository);
      addTearDown(container.dispose);
      _authenticate(container, _userA);
      final subscription = container.listen(
        assetListControllerProvider('area-id'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        assetListControllerProvider('area-id').notifier,
      );

      await controller.load();
      final pendingLoadMore = controller.loadMore();
      await container.read(appSessionControllerProvider.notifier).logout();
      _authenticate(container, _userB);
      pendingSecondPage.complete([assetFixture(id: 'late-a')]);
      await pendingLoadMore;

      var state = container.read(assetListControllerProvider('area-id'));
      expect(state.assets, isEmpty);
      expect(state.isLoadingMore, isFalse);

      firstPage = [assetFixture(id: 'b-0', type: 'Principal B asset')];
      await container
          .read(assetListControllerProvider('area-id').notifier)
          .load();
      state = container.read(assetListControllerProvider('area-id'));
      expect(state.assets.single.id, 'b-0');
      expect(state.assets.single.type, 'Principal B asset');
    },
  );
}

ProviderContainer _container(
  FakeAreaRepository areaRepository,
  FakeAssetRepository assetRepository,
) => ProviderContainer(
  overrides: [
    credentialStoreProvider.overrideWithValue(EmptyTestCredentialStore()),
    areaRepositoryProvider.overrideWithValue(areaRepository),
    assetRepositoryProvider.overrideWithValue(assetRepository),
  ],
);

void _authenticate(ProviderContainer container, AuthUser user) {
  container
      .read(appSessionControllerProvider.notifier)
      .setAuthenticatedFacilities(user: user, facilities: const [_facility]);
}

List<ProviderSubscription<Object?>> _listenToProtectedState(
  ProviderContainer container,
) => [
  container.listen<AreaListState>(
    areaListControllerProvider('shared-facility'),
    (_, _) {},
  ),
  container.listen<AssetListState>(
    assetListControllerProvider('shared-area'),
    (_, _) {},
  ),
  container.listen<AssetDetailState>(
    assetDetailControllerProvider('shared-asset'),
    (_, _) {},
  ),
];

Future<void> _loadAll(ProviderContainer container) async {
  await container
      .read(areaListControllerProvider('shared-facility').notifier)
      .load();
  await container
      .read(assetListControllerProvider('shared-area').notifier)
      .load();
  await container
      .read(assetDetailControllerProvider('shared-asset').notifier)
      .load();
}

void _expectProtectedStateCleared(ProviderContainer container) {
  final areaState = container.read(
    areaListControllerProvider('shared-facility'),
  );
  final assetListState = container.read(
    assetListControllerProvider('shared-area'),
  );
  final assetDetailState = container.read(
    assetDetailControllerProvider('shared-asset'),
  );
  expect(areaState.areas, isEmpty);
  expect(areaState.isLoading, isFalse);
  expect(assetListState.assets, isEmpty);
  expect(assetListState.isLoading, isFalse);
  expect(assetListState.isLoadingMore, isFalse);
  expect(assetDetailState.asset, isNull);
  expect(assetDetailState.isLoading, isFalse);
}

const _userA = AuthUser(
  id: 'user-a',
  email: 'a@example.com',
  termsVersion: '1',
  privacyVersion: '1',
);

const _userB = AuthUser(
  id: 'user-b',
  email: 'b@example.com',
  termsVersion: '1',
  privacyVersion: '1',
);

const _facility = Facility(
  id: 'shared-facility',
  name: 'Shared UUID facility',
  type: 'Other',
  province: 'HCM',
  address: 'Address',
  revision: 1,
);
