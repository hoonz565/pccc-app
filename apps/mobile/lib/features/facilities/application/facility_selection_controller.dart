import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_controller.dart';

final selectedFacilityIdProvider =
    NotifierProvider<FacilitySelectionController, String?>(
      FacilitySelectionController.new,
    );

class FacilitySelectionController extends Notifier<String?> {
  String? _selectedFacilityId;

  @override
  String? build() {
    final facilityIds = ref.watch(
      appSessionControllerProvider.select(
        (session) =>
            session.facilities.map((facility) => facility.id).join('|'),
      ),
    );
    final ids = facilityIds.isEmpty ? const <String>[] : facilityIds.split('|');
    if (_selectedFacilityId != null && ids.contains(_selectedFacilityId)) {
      return _selectedFacilityId;
    }
    _selectedFacilityId = ids.firstOrNull;
    return _selectedFacilityId;
  }

  void select(String facilityId) {
    final exists = ref
        .read(appSessionControllerProvider)
        .facilities
        .any((facility) => facility.id == facilityId);
    if (!exists) {
      return;
    }
    _selectedFacilityId = facilityId;
    state = facilityId;
  }
}
