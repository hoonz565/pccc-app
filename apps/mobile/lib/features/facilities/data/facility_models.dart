class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.province,
    required this.address,
    required this.revision,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      province: json['province'] as String,
      address: json['address'] as String,
      revision: json['revision'] as int,
    );
  }

  final String id;
  final String name;
  final String type;
  final String province;
  final String address;
  final int revision;
}

class FacilityRequestException implements Exception {
  const FacilityRequestException(
    this.message, {
    this.isTransient = false,
    this.invalidSession = false,
  });

  final String message;
  final bool isTransient;
  final bool invalidSession;
}
