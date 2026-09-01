import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';
import '../data/area_models.dart';
import '../data/area_repository.dart';

final areaListControllerProvider = NotifierProvider.autoDispose
    .family<AreaListController, AreaListState, String>(AreaListController.new);

class AreaListState {
  const AreaListState({
    this.areas = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Area> areas;
  final bool isLoading;
  final String? errorMessage;
}

class AreaListController extends Notifier<AreaListState> {
  AreaListController(this.facilityId);

  final String facilityId;
  AuthenticatedSessionIdentity? _sessionIdentity;

  @override
  AreaListState build() {
    _sessionIdentity = ref.watch(authenticatedSessionIdentityProvider);
    return const AreaListState();
  }

  Future<void> load() async {
    if (state.isLoading) {
      return;
    }
    final requestSession = _sessionIdentity;
    state = AreaListState(areas: state.areas, isLoading: true);
    try {
      final areas = await ref
          .read(areaRepositoryProvider)
          .list(facilityId: facilityId);
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = AreaListState(areas: areas);
    } on AreaRequestException catch (error) {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      if (error.invalidSession) {
        state = const AreaListState();
        await ref
            .read(appSessionControllerProvider.notifier)
            .invalidateSession();
        return;
      }
      state = error.statusCode == 404
          ? AreaListState(errorMessage: error.message)
          : AreaListState(areas: state.areas, errorMessage: error.message);
    } on Object {
      if (!_isCurrentSession(requestSession)) {
        return;
      }
      state = AreaListState(
        areas: state.areas,
        errorMessage: 'Không thể tải danh sách khu vực. Vui lòng thử lại.',
      );
    }
  }

  void add(
    Area area, {
    required AuthenticatedSessionIdentity? sessionIdentity,
  }) {
    if (!_isCurrentSession(sessionIdentity) || area.facilityId != facilityId) {
      return;
    }
    state = AreaListState(areas: [...state.areas, area]);
  }

  bool _isCurrentSession(AuthenticatedSessionIdentity? sessionIdentity) =>
      ref.mounted &&
      identical(sessionIdentity, _sessionIdentity) &&
      identical(
        sessionIdentity,
        ref.read(authenticatedSessionIdentityProvider),
      );
}
