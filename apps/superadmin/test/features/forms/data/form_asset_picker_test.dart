import 'dart:typed_data';

import 'package:coelo_superadmin/features/forms/data/form_asset_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('Photo requests camera capture and keeps an approved MIME type', () async {
    final platform = _Picker(single: XFile.fromData(Uint8List.fromList([1]), mimeType: 'image/png'));
    final picker = FormAssetPicker(picker: platform);

    final result = await picker.capturePhoto();

    expect(platform.source, ImageSource.camera);
    expect(result.single.mimeType, 'image/png');
  });

  test('Gallery requests existing images with a server-compatible limit', () async {
    final platform = _Picker(
      multiple: [XFile.fromData(Uint8List.fromList([1]), mimeType: 'image/webp')],
    );
    final picker = FormAssetPicker(picker: platform);

    final result = await picker.pickGallery(limit: 4);

    expect(platform.limit, 4);
    expect(result.single.mimeType, 'image/webp');
  });

  test('rejects unapproved formats before upload', () async {
    final picker = FormAssetPicker(
      picker: _Picker(single: XFile.fromData(Uint8List.fromList([1]), mimeType: 'image/gif')),
    );

    expect(picker.capturePhoto(), throwsA(isA<FormatException>()));
  });
}

final class _Picker extends ImagePicker {
  _Picker({this.single, this.multiple = const []});

  final XFile? single;
  final List<XFile> multiple;
  ImageSource? source;
  int? limit;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    return single;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    this.limit = limit;
    return multiple;
  }
}
