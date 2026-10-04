import 'package:firesafe_mobile/core/router/app_router.dart';
import 'package:firesafe_mobile/features/auth/application/app_session_controller.dart';
import 'package:firesafe_mobile/features/auth/data/auth_models.dart';
import 'package:firesafe_mobile/features/areas/data/area_repository.dart';
import 'package:firesafe_mobile/features/assets/data/asset_repository.dart';
import 'package:firesafe_mobile/features/facilities/data/facility_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sprint2_fakes.dart';

void main() {
  testWidgets(
    'authenticated Sprint 2 routes are stable without redirect loop',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          areaRepositoryProvider.overrideWithValue(
            FakeAreaRepository(areas: [areaFixture()]),
          ),
          assetRepositoryProvider.overrideWithValue(
            FakeAssetRepository(assets: [assetFixture()]),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appSessionControllerProvider.notifier)
          .setAuthenticatedFacilities(
            user: const AuthUser(
              id: 'user-id',
              email: 'user@example.test',
              termsVersion: 'draft-v1',
              privacyVersion: 'draft-v1',
            ),
            facilities: const [
              Facility(
                id: 'facility-id',
                name: 'Cơ sở',
                type: 'Kho',
                province: 'Hà Nội',
                address: '1 Đường A',
                revision: 1,
              ),
            ],
          );
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      for (final location in [
        '/ocr/date-extraction',
        '/facilities/facility-id/areas',
        '/areas/area-id/assets',
        '/assets/asset-id',
        '/assets/asset-id/edit',
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, location);
      }
    },
  );
}
