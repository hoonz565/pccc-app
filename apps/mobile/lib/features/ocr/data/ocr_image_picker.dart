import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_models.dart';

abstract interface class OcrImagePicker {
  Future<OcrSelectedImage?> pick(OcrImageSource source);
}

final ocrImagePickerProvider = Provider<OcrImagePicker>(
  (ref) => PluginOcrImagePicker(ImagePicker()),
);

class PluginOcrImagePicker implements OcrImagePicker {
  const PluginOcrImagePicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<OcrSelectedImage?> pick(OcrImageSource source) async {
    final picked = await _picker.pickImage(
      source: source == OcrImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (picked == null) {
      return null;
    }
    return OcrSelectedImage(
      name: picked.name,
      bytes: await picked.readAsBytes(),
      mimeType: picked.mimeType ?? _mimeFromName(picked.name),
    );
  }

  static String _mimeFromName(String name) {
    final normalized = name.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
