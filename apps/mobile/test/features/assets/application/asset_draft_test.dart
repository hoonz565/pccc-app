import 'package:firesafe_mobile/features/assets/application/asset_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual Asset draft requires type', () {
    expect(const AssetDraft().validate(), 'Loại thiết bị là bắt buộc.');
  });

  test('capacity value and unit are both present or both absent', () {
    expect(
      const AssetDraft(type: 'Bình', capacityValue: '5').validate(),
      'Giá trị và đơn vị sức chứa phải được nhập cùng nhau.',
    );
    expect(
      const AssetDraft(
        type: 'Bình',
        capacityValue: '-1',
        capacityUnit: 'kg',
      ).validate(),
      'Giá trị sức chứa phải lớn hơn 0.',
    );
    expect(
      const AssetDraft(
        type: ' Bình ',
        capacityValue: '5.5',
        capacityUnit: ' kg ',
      ).validate(),
      isNull,
    );
  });

  test('draft normalizes optional fields for the creation use case', () {
    final fields = const AssetDraft(
      type: ' Bình ',
      serial: '   ',
      locationText: ' Cửa số 2 ',
    ).toWriteFields();

    expect(fields.type, 'Bình');
    expect(fields.serial, isNull);
    expect(fields.locationText, 'Cửa số 2');
  });
}
