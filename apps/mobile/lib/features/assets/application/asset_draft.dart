import '../data/asset_models.dart';

class AssetDraft {
  const AssetDraft({
    this.type = '',
    this.subtype = '',
    this.capacityValue = '',
    this.capacityUnit = '',
    this.manufacturer = '',
    this.model = '',
    this.serial = '',
    this.locationText = '',
  });

  factory AssetDraft.fromAsset(Asset asset) {
    return AssetDraft(
      type: asset.type,
      subtype: asset.subtype ?? '',
      capacityValue: asset.capacityValue?.toString() ?? '',
      capacityUnit: asset.capacityUnit ?? '',
      manufacturer: asset.manufacturer ?? '',
      model: asset.model ?? '',
      serial: asset.serial ?? '',
      locationText: asset.locationText ?? '',
    );
  }

  final String type;
  final String subtype;
  final String capacityValue;
  final String capacityUnit;
  final String manufacturer;
  final String model;
  final String serial;
  final String locationText;

  String? validate() {
    if (type.trim().isEmpty) {
      return 'Loại thiết bị là bắt buộc.';
    }
    final hasCapacityValue = capacityValue.trim().isNotEmpty;
    final hasCapacityUnit = capacityUnit.trim().isNotEmpty;
    if (hasCapacityValue != hasCapacityUnit) {
      return 'Giá trị và đơn vị sức chứa phải được nhập cùng nhau.';
    }
    if (hasCapacityValue) {
      final value = num.tryParse(capacityValue.trim());
      if (value == null || value <= 0) {
        return 'Giá trị sức chứa phải lớn hơn 0.';
      }
    }
    return null;
  }

  AssetWriteFields toWriteFields() {
    final validationError = validate();
    if (validationError != null) {
      throw AssetDraftValidationException(validationError);
    }
    return AssetWriteFields(
      type: type.trim(),
      subtype: _optional(subtype),
      capacityValue: capacityValue.trim().isEmpty
          ? null
          : num.parse(capacityValue.trim()),
      capacityUnit: _optional(capacityUnit),
      manufacturer: _optional(manufacturer),
      model: _optional(model),
      serial: _optional(serial),
      locationText: _optional(locationText),
    );
  }

  static String? _optional(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

class AssetDraftValidationException implements Exception {
  const AssetDraftValidationException(this.message);

  final String message;
}
