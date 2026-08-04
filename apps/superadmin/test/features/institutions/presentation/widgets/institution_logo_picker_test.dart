import 'dart:typed_data';

import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_logo_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the approved profile picker configuration and returns image bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final picker = _FakeFilePicker(
      FilePickerResult([PlatformFile(name: 'instituicao.png', size: bytes.length, bytes: bytes)]),
    );
    FilePicker.platform = picker;

    final result = await pickInstitutionLogo();

    expect(result?.name, 'instituicao.png');
    expect(result?.bytes, bytes);
    expect(picker.type, FileType.custom);
    expect(picker.allowedExtensions, ['png', 'jpg', 'jpeg', 'webp']);
    expect(picker.withData, isTrue);
    expect(picker.allowMultiple, isFalse);
    expect(picker.dialogTitle, 'Escolher foto de perfil');
  });

  test('returns null when the approved picker is cancelled', () async {
    FilePicker.platform = _FakeFilePicker(null);

    expect(await pickInstitutionLogo(), isNull);
  });
}

final class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;
  FileType? type;
  List<String>? allowedExtensions;
  bool? withData;
  bool? allowMultiple;
  String? dialogTitle;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.dialogTitle = dialogTitle;
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.withData = withData;
    this.allowMultiple = allowMultiple;
    return result;
  }
}
