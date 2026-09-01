import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/app_session_controller.dart';
import '../../features/auth/application/app_session_state.dart';
import '../../features/auth/presentation/bootstrap_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/areas/presentation/area_list_screen.dart';
import '../../features/areas/presentation/create_area_screen.dart';
import '../../features/assets/presentation/asset_detail_screen.dart';
import '../../features/assets/presentation/asset_list_screen.dart';
import '../../features/assets/presentation/create_asset_screen.dart';
import '../../features/assets/presentation/edit_asset_screen.dart';
import '../../features/facilities/presentation/first_facility_screen.dart';
import '../../features/home/presentation/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref
    ..onDispose(refreshNotifier.dispose)
    ..listen(appSessionControllerProvider, (_, _) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: '/bootstrap',
    refreshListenable: refreshNotifier,
    redirect: (context, routerState) {
      final session = ref.read(appSessionControllerProvider);
      final location = routerState.matchedLocation;
      return switch (session.status) {
        AppSessionStatus.bootstrapping ||
        AppSessionStatus.recoverableBootstrapFailure =>
          location == '/bootstrap' ? null : '/bootstrap',
        AppSessionStatus.unauthenticated =>
          location == '/login' || location == '/register' ? null : '/login',
        AppSessionStatus.authenticatedNeedsFacility =>
          location == '/onboarding/facility' ? null : '/onboarding/facility',
        AppSessionStatus.authenticatedReady =>
          _isAuthenticatedProductRoute(location) ? null : '/home',
      };
    },
    routes: [
      GoRoute(path: '/bootstrap', builder: (_, _) => const BootstrapScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/onboarding/facility',
        builder: (_, _) => const FirstFacilityScreen(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/facilities/:facilityId/areas',
        builder: (_, state) =>
            AreaListScreen(facilityId: state.pathParameters['facilityId']!),
      ),
      GoRoute(
        path: '/facilities/:facilityId/areas/new',
        builder: (_, state) =>
            CreateAreaScreen(facilityId: state.pathParameters['facilityId']!),
      ),
      GoRoute(
        path: '/areas/:areaId/assets',
        builder: (_, state) =>
            AssetListScreen(areaId: state.pathParameters['areaId']!),
      ),
      GoRoute(
        path: '/areas/:areaId/assets/new',
        builder: (_, state) =>
            CreateAssetScreen(areaId: state.pathParameters['areaId']!),
      ),
      GoRoute(
        path: '/assets/:assetId/edit',
        builder: (_, state) =>
            EditAssetScreen(assetId: state.pathParameters['assetId']!),
      ),
      GoRoute(
        path: '/assets/:assetId',
        builder: (_, state) =>
            AssetDetailScreen(assetId: state.pathParameters['assetId']!),
      ),
    ],
  );
});

bool _isAuthenticatedProductRoute(String location) {
  return location == '/home' ||
      location.startsWith('/facilities/') ||
      location.startsWith('/areas/') ||
      location.startsWith('/assets/');
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
