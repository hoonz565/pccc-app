class Area {
  const Area({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      name: json['name'] as String,
      revision: json['revision'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String facilityId;
  final String name;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AreaRequestException implements Exception {
  const AreaRequestException(
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
}
