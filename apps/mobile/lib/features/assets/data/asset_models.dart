class Asset {
  const Asset({
    required this.id,
    required this.areaId,
    required this.assetCode,
    required this.type,
    required this.subtype,
    required this.capacityValue,
    required this.capacityUnit,
    required this.manufacturer,
    required this.model,
    required this.serial,
    required this.locationText,
    required this.lifecycleState,
    required this.source,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.operationalStatus,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      areaId: json['area_id'] as String,
      assetCode: json['asset_code'] as String,
      type: json['type'] as String,
      subtype: json['subtype'] as String?,
      capacityValue: json['capacity_value'] as num?,
      capacityUnit: json['capacity_unit'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      serial: json['serial'] as String?,
      locationText: json['location_text'] as String?,
      lifecycleState: json['lifecycle_state'] as String,
      source: json['source'] as String,
      revision: json['revision'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      operationalStatus: json['operational_status'] as String?,
    );
  }

  final String id;
  final String areaId;
  final String assetCode;
  final String type;
  final String? subtype;
  final num? capacityValue;
  final String? capacityUnit;
  final String? manufacturer;
  final String? model;
  final String? serial;
  final String? locationText;
  final String lifecycleState;
  final String source;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? operationalStatus;
}

class AssetWriteFields {
  const AssetWriteFields({
    required this.type,
    required this.subtype,
    required this.capacityValue,
    required this.capacityUnit,
    required this.manufacturer,
    required this.model,
    required this.serial,
    required this.locationText,
  });

  final String type;
  final String? subtype;
  final num? capacityValue;
  final String? capacityUnit;
  final String? manufacturer;
  final String? model;
  final String? serial;
  final String? locationText;

  Map<String, dynamic> toJson() => {
    'type': type,
    'subtype': subtype,
    'capacity_value': capacityValue,
    'capacity_unit': capacityUnit,
    'manufacturer': manufacturer,
    'model': model,
    'serial': serial,
    'location_text': locationText,
  };
}

class AssetRequestException implements Exception {
  const AssetRequestException(
    this.message, {
    this.statusCode,
    this.code,
    this.isTransient = false,
    this.invalidSession = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final bool isTransient;
  final bool invalidSession;

  bool get revisionConflict => statusCode == 409 && code == 'VERSION_CONFLICT';
}
