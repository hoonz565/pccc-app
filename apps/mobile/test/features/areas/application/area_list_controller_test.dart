import 'package:firesafe_mobile/features/areas/application/area_list_controller.dart';
import 'package:firesafe_mobile/features/areas/data/area_models.dart';
import 'package:firesafe_mobile/features/areas/data/area_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/sprint2_fakes.dart';

void main() {
  test('Area lists remain isolated by Facility context', () async {
    final repository = FakeAreaRepository(
      areas: [
        areaFixture(id: 'area-a', facilityId: 'facility-a'),
        areaFixture(id: 'area-b', facilityId: 'facility-b'),
      ],
    );
    final container = ProviderContainer(
      overrides: [areaRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final facilityASubscription = container.listen(
      areaListControllerProvider('facility-a'),
      (_, _) {},
    );
    final facilityBSubscription = container.listen(
      areaListControllerProvider('facility-b'),
      (_, _) {},
    );
    addTearDown(facilityASubscription.close);
    addTearDown(facilityBSubscription.close);

    await container
        .read(areaListControllerProvider('facility-a').notifier)
        .load();
    await container
        .read(areaListControllerProvider('facility-b').notifier)
        .load();

    expect(
      container.read(areaListControllerProvider('facility-a')).areas.single.id,
      'area-a',
    );
    expect(
      container.read(areaListControllerProvider('facility-b')).areas.single.id,
      'area-b',
    );
  });

  test('Area list exposes a recoverable error state', () async {
    final container = ProviderContainer(
      overrides: [
        areaRepositoryProvider.overrideWithValue(
          FakeAreaRepository(
            error: const AreaRequestException('Không thể tải khu vực.'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      areaListControllerProvider('facility-id'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container
        .read(areaListControllerProvider('facility-id').notifier)
        .load();

    final state = container.read(areaListControllerProvider('facility-id'));
    expect(state.areas, isEmpty);
    expect(state.isLoading, isFalse);
    expect(state.errorMessage, 'Không thể tải khu vực.');
  });
}
