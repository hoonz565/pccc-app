import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';
import '../data/asset_models.dart';
import '../data/asset_repository.dart';

final assetDetailControllerProvider = NotifierProvider.autoDispose
    .family<AssetDetailController, AssetDetailState, String>(
      AssetDetailController.new,
    );

class AssetDetailState {
  const AssetDetailState({
    this.asset,
    this.isLoading = false,
    this.errorMessage,
  });

  final Asset? asset;
  final bool isLoading;
  final String? errorMessage;
}

class AssetDetailController extends Notifier<AssetDetailState> {
  AssetDetailController(this.assetId);

  final String assetId;
  AuthenticatedSessionIdentity? _sessionIdentity;

  @override
  AssetDetailState build() {
    _sessionIdentity = ref.watch(authenticatedSessionIdentityProvider);
    return const AssetDetailState();
  }

  Future<void> load() async {
    if (state.isLoading) {
      return;
    }
    final requestSession = _sessionIdentity;
    state = AssetDetailState(asset: state.asset, isLoading: true);
    try {
      final asset = await ref
          .read(assetRepositoryProvider)
          .get(assetId: assetId);
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = AssetDetailState(asset: asset);
    } on AssetRequestException catch (error) {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      if (error.invalidSession) {
        state = const AssetDetailState();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      state = error.statusCode == 404
          ? AssetDetailState(errorMessage: error.message)
          : AssetDetailState(asset: state.asset, errorMessage: error.message);
    } on Object {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = AssetDetailState(
        asset: state.asset,
        errorMessage: 'Không thể tải thông tin thiết bị. Vui lòng thử lại.',
      );
    }
  }

  void setAsset(
    Asset asset, {
    required AuthenticatedSessionIdentity? sessionIdentity,
  }) {
    if (_isCurrentSession(sessionIdentity) && asset.id == assetId) {
      state = AssetDetailState(asset: asset);
    }
  }

  bool _isCurrentSession(AuthenticatedSessionIdentity? sessionIdentity) =>
      ref.mounted &&
      identical(sessionIdentity, _sessionIdentity) &&
      identical(
        sessionIdentity,
        ref.read(authenticatedSessionIdentityProvider),
      );
}
