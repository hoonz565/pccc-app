import 'package:firesafe_mobile/features/auth/application/app_session_controller.dart';
import 'package:firesafe_mobile/features/auth/data/auth_models.dart';
import 'package:firesafe_mobile/features/facilities/application/facility_selection_controller.dart';
import 'package:firesafe_mobile/features/facilities/data/facility_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Facility selection is explicit and changes context', () {
    final container = ProviderContainer();
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
              id: 'facility-a',
              name: 'Cơ sở A',
              type: 'Kho',
              province: 'Hà Nội',
              address: 'A',
              revision: 1,
            ),
            Facility(
              id: 'facility-b',
              name: 'Cơ sở B',
              type: 'Kho',
              province: 'Đà Nẵng',
              address: 'B',
              revision: 1,
            ),
          ],
        );

    expect(container.read(selectedFacilityIdProvider), 'facility-a');
    container.read(selectedFacilityIdProvider.notifier).select('facility-b');
    expect(container.read(selectedFacilityIdProvider), 'facility-b');
    container
        .read(selectedFacilityIdProvider.notifier)
        .select('foreign-facility');
    expect(container.read(selectedFacilityIdProvider), 'facility-b');
  });
}
