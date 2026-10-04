import 'dart:typed_data';

enum OcrImageSource { gallery, camera }

class OcrSelectedImage {
  const OcrSelectedImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

class OcrDateCandidate {
  const OcrDateCandidate({
    required this.rawText,
    required this.correctedText,
    required this.normalizedDate,
    required this.confidenceLevel,
    required this.calendarValid,
    required this.validationWarnings,
    required this.imageWarnings,
    required this.engine,
    required this.selectionStrategy,
    required this.requiresConfirmation,
  });

  factory OcrDateCandidate.fromJson(Map<String, dynamic> json) {
    final confidence = json['confidence'] as Map<String, dynamic>;
    final validation = json['validation'] as Map<String, dynamic>;
    final imageQuality = json['image_quality'] as Map<String, dynamic>;
    final provenance = json['provenance'] as Map<String, dynamic>;
    return OcrDateCandidate(
      rawText: json['raw_text'] as String,
      correctedText: json['corrected_text'] as String,
      normalizedDate: json['normalized_date'] as String?,
      confidenceLevel: confidence['level'] as String,
      calendarValid: validation['calendar_valid'] as bool,
      validationWarnings: (validation['warnings'] as List<dynamic>)
          .cast<String>(),
      imageWarnings: (imageQuality['warnings'] as List<dynamic>).cast<String>(),
      engine: provenance['engine'] as String,
      selectionStrategy: provenance['selection_strategy'] as String,
      requiresConfirmation: json['requires_confirmation'] as bool,
    );
  }

  final String rawText;
  final String correctedText;
  final String? normalizedDate;
  final String confidenceLevel;
  final bool calendarValid;
  final List<String> validationWarnings;
  final List<String> imageWarnings;
  final String engine;
  final String selectionStrategy;
  final bool requiresConfirmation;

  String get displayDate {
    final normalized = normalizedDate;
    if (normalized != null) {
      final parts = normalized.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    return correctedText.replaceAll('-', '/');
  }
}

class ReviewedOcrDate {
  const ReviewedOcrDate({
    required this.normalizedDate,
    required this.acceptedUnchanged,
  });

  final String normalizedDate;
  final bool acceptedUnchanged;
}

class OcrRequestException implements Exception {
  const OcrRequestException(
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
