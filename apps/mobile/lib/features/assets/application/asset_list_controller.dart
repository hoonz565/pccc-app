import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';
import '../data/asset_models.dart';
import '../data/asset_repository.dart';

final assetListControllerProvider = NotifierProvider.autoDispose
    .family<AssetListController, AssetListState, String>(
      AssetListController.new,
    );

const assetPageSize = 50;

class AssetListState {
  const AssetListState({
    this.assets = const [],
    this.nextOffset = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.loadMoreErrorMessage,
  });

  final List<Asset> assets;
  final int nextOffset;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? loadMoreErrorMessage;
}

class AssetListController extends Notifier<AssetListState> {
  AssetListController(this.areaId);

  final String areaId;
  AuthenticatedSessionIdentity? _sessionIdentity;

  @override
  AssetListState build() {
    _sessionIdentity = ref.watch(authenticatedSessionIdentityProvider);
    return const AssetListState();
  }

  Future<void> load() async {
    if (state.isLoading || state.isLoadingMore) {
      return;
    }
    final requestSession = _sessionIdentity;
    state = AssetListState(
      assets: state.assets,
      nextOffset: state.nextOffset,
      hasMore: state.hasMore,
      isLoading: true,
    );
    try {
      final page = await ref
          .read(assetRepositoryProvider)
          .list(areaId: areaId, limit: assetPageSize, offset: 0);
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      final assets = _uniqueAssetsForArea(page);
      state = AssetListState(
        assets: assets,
        nextOffset: page.length,
        hasMore: page.length == assetPageSize,
      );
    } on AssetRequestException catch (error) {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      if (error.invalidSession) {
        state = const AssetListState();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      state = error.statusCode == 404
          ? AssetListState(errorMessage: error.message, hasMore: false)
          : AssetListState(
              assets: state.assets,
              nextOffset: state.nextOffset,
              hasMore: state.hasMore,
              errorMessage: error.message,
            );
    } on Object {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = AssetListState(
        assets: state.assets,
        nextOffset: state.nextOffset,
        hasMore: state.hasMore,
        errorMessage: 'Không thể tải danh sách thiết bị. Vui lòng thử lại.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    final requestSession = _sessionIdentity;
    final requestOffset = state.nextOffset;
    state = AssetListState(
      assets: state.assets,
      nextOffset: state.nextOffset,
      hasMore: state.hasMore,
      isLoadingMore: true,
      errorMessage: state.errorMessage,
    );
    try {
      final page = await ref
          .read(assetRepositoryProvider)
          .list(areaId: areaId, limit: assetPageSize, offset: requestOffset);
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      final ids = state.assets.map((asset) => asset.id).toSet();
      final appended = <Asset>[
        for (final asset in page)
          if (asset.areaId == areaId && ids.add(asset.id)) asset,
      ];
      state = AssetListState(
        assets: [...state.assets, ...appended],
        nextOffset: requestOffset + page.length,
        hasMore: page.length == assetPageSize,
        errorMessage: state.errorMessage,
      );
    } on AssetRequestException catch (error) {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      if (error.invalidSession) {
        state = const AssetListState();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      if (error.statusCode == 404) {
        state = AssetListState(errorMessage: error.message, hasMore: false);
        return;
      }
      state = AssetListState(
        assets: state.assets,
        nextOffset: state.nextOffset,
        hasMore: state.hasMore,
        errorMessage: state.errorMessage,
        loadMoreErrorMessage: error.message,
      );
    } on Object {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = AssetListState(
        assets: state.assets,
        nextOffset: state.nextOffset,
        hasMore: state.hasMore,
        errorMessage: state.errorMessage,
        loadMoreErrorMessage: 'Không thể tải thêm thiết bị. Vui lòng thử lại.',
      );
    }
  }

  void add(
    Asset asset, {
    required AuthenticatedSessionIdentity? sessionIdentity,
  }) {
    if (!_isCurrentSession(sessionIdentity) || asset.areaId != areaId) {
      return;
    }
    final alreadyExists = state.assets.any((current) => current.id == asset.id);
    state = AssetListState(
      assets: alreadyExists ? state.assets : [...state.assets, asset],
      nextOffset: state.nextOffset,
      hasMore: state.hasMore,
    );
  }

  void replace(
    Asset asset, {
    required AuthenticatedSessionIdentity? sessionIdentity,
  }) {
    if (!_isCurrentSession(sessionIdentity) || asset.areaId != areaId) {
      return;
    }
    state = AssetListState(
      assets: [
        for (final current in state.assets)
          if (current.id == asset.id) asset else current,
      ],
      nextOffset: state.nextOffset,
      hasMore: state.hasMore,
    );
  }

  List<Asset> _uniqueAssetsForArea(List<Asset> page) {
    final ids = <String>{};
    return [
      for (final asset in page)
        if (asset.areaId == areaId && ids.add(asset.id)) asset,
    ];
  }

  bool _isCurrentSession(AuthenticatedSessionIdentity? sessionIdentity) =>
      ref.mounted &&
      identical(sessionIdentity, _sessionIdentity) &&
      identical(
        sessionIdentity,
        ref.read(authenticatedSessionIdentityProvider),
      );
}
