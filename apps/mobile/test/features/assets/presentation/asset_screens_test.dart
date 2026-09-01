import 'dart:async';

import 'package:firesafe_mobile/features/assets/application/asset_detail_controller.dart';
import 'package:firesafe_mobile/features/assets/application/asset_list_controller.dart';
import 'package:firesafe_mobile/features/assets/data/asset_models.dart';
import 'package:firesafe_mobile/features/assets/data/asset_repository.dart';
import 'package:firesafe_mobile/features/assets/presentation/asset_detail_screen.dart';
import 'package:firesafe_mobile/features/assets/presentation/create_asset_screen.dart';
import 'package:firesafe_mobile/features/assets/presentation/edit_asset_screen.dart';
import 'package:firesafe_mobile/features/assets/presentation/asset_list_screen.dart';
import 'package:firesafe_mobile/features/auth/application/app_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/sprint2_fakes.dart';

void main() {
  testWidgets('manual Asset form validates type and capacity pair', (
    tester,
  ) async {
    _useTallView(tester);
    final router = _createRouter();
    await _pumpRouter(tester, router, FakeAssetRepository());
    router.push('/new');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pump();
    expect(find.text('Loại thiết bị là bắt buộc.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Loại thiết bị *'),
      'Bình',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Sức chứa'), '5');
    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pump();
    expect(find.text('Nhập đủ giá trị và đơn vị.'), findsNWidgets(2));
  });

  testWidgets('Asset create is single-submit and navigates to detail', (
    tester,
  ) async {
    _useTallView(tester);
    final completer = Completer<Asset>();
    final repository = FakeAssetRepository(createCompleter: completer.future);
    final router = _createRouter();
    await _pumpRouter(tester, router, repository);
    router.push('/new');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Loại thiết bị *'),
      'Bình chữa cháy',
    );

    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    expect(repository.createCalls, 1);

    completer.complete(assetFixture());
    await tester.pumpAndSettle();
    expect(find.text('Asset detail placeholder'), findsOneWidget);
  });

  testWidgets('ambiguous Asset create error retains the draft', (tester) async {
    _useTallView(tester);
    final repository = FakeAssetRepository(
      error: const AssetRequestException('Mất kết nối.', isTransient: true),
    );
    final router = _createRouter();
    await _pumpRouter(tester, router, repository);
    router.push('/new');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Loại thiết bị *'),
      'Bình chưa xác nhận',
    );

    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Bình chưa xác nhận'), findsOneWidget);
    expect(find.textContaining('Không tự động gửi lại'), findsOneWidget);
  });

  testWidgets('Asset list exposes load more and renders the next page', (
    tester,
  ) async {
    _useTallView(tester);
    final repository = FakeAssetRepository(
      assets: [
        for (var index = 0; index < 50; index += 1)
          assetFixture(id: 'asset-$index', type: 'Asset $index'),
        assetFixture(id: 'asset-50', type: 'Page 2 asset'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AssetListScreen(areaId: 'area-id')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tải thêm'),
      600,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();

    expect(repository.requestedOffsets, [0, 50]);
    expect(find.text('Page 2 asset'), findsOneWidget);
    expect(find.text('Tải thêm'), findsNothing);
  });

  testWidgets('Asset Detail renders approved empty derived states', (
    tester,
  ) async {
    _useTallView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetRepositoryProvider.overrideWithValue(
            FakeAssetRepository(assets: [assetFixture()]),
          ),
        ],
        child: const MaterialApp(home: AssetDetailScreen(assetId: 'asset-id')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('AST-550E8400-E29B-41D4-A716-446655440000'),
      findsOneWidget,
    );
    expect(find.text('Chưa đánh giá'), findsOneWidget);
    expect(find.text('Chưa có mốc dịch vụ'), findsOneWidget);
    expect(find.text('MANUAL'), findsOneWidget);
  });

  testWidgets('safe 404 renders a recoverable Asset Detail state', (
    tester,
  ) async {
    _useTallView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetRepositoryProvider.overrideWithValue(
            FakeAssetRepository(
              error: const AssetRequestException(
                'Không tìm thấy thiết bị.',
                statusCode: 404,
                code: 'ASSET_NOT_FOUND',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: AssetDetailScreen(assetId: 'foreign-asset'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy thiết bị.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('revision conflict keeps edit recoverable without overwrite', (
    tester,
  ) async {
    _useTallView(tester);
    final repository = FakeAssetRepository(
      assets: [assetFixture()],
      updateError: const AssetRequestException(
        'Thiết bị đã được cập nhật.',
        statusCode: 409,
        code: 'VERSION_CONFLICT',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: EditAssetScreen(assetId: 'asset-id')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Loại thiết bị *'),
      'Bình đã sửa',
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repository.lastBaseRevision, 1);
    expect(find.text('Thiết bị đã được cập nhật.'), findsOneWidget);
    expect(find.text('Tải dữ liệu mới nhất'), findsOneWidget);
    expect(find.text('Bình đã sửa'), findsOneWidget);
  });

  testWidgets('conflict reload publishes latest data to form detail and list', (
    tester,
  ) async {
    _useTallView(tester);
    final oldAsset = assetFixture(type: 'Old server asset');
    final latestAsset = _latestAsset(oldAsset);
    final repository = FakeAssetRepository(
      assets: [oldAsset],
      getSequence: [oldAsset, oldAsset, latestAsset],
      updateError: const AssetRequestException(
        'Revision conflict.',
        statusCode: 409,
        code: 'VERSION_CONFLICT',
      ),
    );
    final container = ProviderContainer(
      overrides: [assetRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final detailSubscription = container.listen(
      assetDetailControllerProvider('asset-id'),
      (_, _) {},
    );
    final listSubscription = container.listen(
      assetListControllerProvider('area-id'),
      (_, _) {},
    );
    addTearDown(detailSubscription.close);
    addTearDown(listSubscription.close);
    final sessionIdentity = container.read(
      authenticatedSessionIdentityProvider,
    );
    container
        .read(assetListControllerProvider('area-id').notifier)
        .add(oldAsset, sessionIdentity: sessionIdentity);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const AssetDetailScreen(assetId: 'asset-id'),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => const EditAssetScreen(assetId: 'asset-id'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Loại thiết bị *'),
      'Local conflicting draft',
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tải dữ liệu mới nhất'));
    await tester.pumpAndSettle();
    expect(find.text('Server latest asset'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Server latest location'),
      findsOneWidget,
    );
    expect(
      container.read(assetDetailControllerProvider('asset-id')).asset?.revision,
      2,
    );
    expect(
      container
          .read(assetListControllerProvider('area-id'))
          .assets
          .single
          .revision,
      2,
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Server latest asset'), findsOneWidget);
    expect(find.text('Server latest location'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('successful edit publishes the incremented revision', (
    tester,
  ) async {
    _useTallView(tester);
    final repository = FakeAssetRepository(assets: [assetFixture()]);
    final container = ProviderContainer(
      overrides: [assetRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final detailSubscription = container.listen(
      assetDetailControllerProvider('asset-id'),
      (_, _) {},
    );
    addTearDown(detailSubscription.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Root')),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => const EditAssetScreen(assetId: 'asset-id'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/edit');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Loại thiết bị *'),
      'Bình đã cập nhật',
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repository.lastBaseRevision, 1);
    expect(repository.lastFields?.type, 'Bình đã cập nhật');
    expect(
      container.read(assetDetailControllerProvider('asset-id')).asset?.revision,
      2,
    );
    expect(find.text('Root'), findsOneWidget);
  });
}

Asset _latestAsset(Asset previous) => Asset(
  id: previous.id,
  areaId: previous.areaId,
  assetCode: previous.assetCode,
  type: 'Server latest asset',
  subtype: previous.subtype,
  capacityValue: previous.capacityValue,
  capacityUnit: previous.capacityUnit,
  manufacturer: previous.manufacturer,
  model: previous.model,
  serial: previous.serial,
  locationText: 'Server latest location',
  lifecycleState: previous.lifecycleState,
  source: previous.source,
  revision: 2,
  createdAt: previous.createdAt,
  updatedAt: previous.updatedAt.add(const Duration(minutes: 1)),
  operationalStatus: previous.operationalStatus,
);

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router,
  AssetRepository repository,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [assetRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  ),
);

GoRouter _createRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('Root')),
    ),
    GoRoute(
      path: '/new',
      builder: (_, _) => const CreateAssetScreen(areaId: 'area-id'),
    ),
    GoRoute(
      path: '/assets/:assetId',
      builder: (_, _) => const Scaffold(body: Text('Asset detail placeholder')),
    ),
  ],
);
