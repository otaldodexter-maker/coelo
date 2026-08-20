import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

final class FormPickedAsset {
  const FormPickedAsset({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

final class FormAssetPicker {
  FormAssetPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<List<FormPickedAsset>> capturePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return const [];
    return [await _read(file)];
  }

  Future<List<FormPickedAsset>> pickGallery({int limit = 5}) async {
    if (limit < 1 || limit > 5) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 5');
    }
    final files = limit == 1
        ? <XFile>[?await _picker.pickImage(source: ImageSource.gallery)]
        : await _picker.pickMultiImage(limit: limit);
    return Future.wait(files.map(_read));
  }

  Future<FormPickedAsset> _read(XFile file) async {
    final mimeType = _approvedMimeType(file);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('A imagem deve ter no máximo 10 MB.');
    }
    return FormPickedAsset(bytes: bytes, mimeType: mimeType);
  }

  String _approvedMimeType(XFile file) {
    final reported = file.mimeType?.toLowerCase();
    if (reported == 'image/jpeg' || reported == 'image/png' || reported == 'image/webp') {
      return reported!;
    }
    final path = file.path.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    throw const FormatException('Formato de imagem não permitido.');
  }
}
