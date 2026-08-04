import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

final class InstitutionLogoFile {
  const InstitutionLogoFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

typedef InstitutionLogoPicker = Future<InstitutionLogoFile?> Function();

Future<InstitutionLogoFile?> pickInstitutionLogo() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    withData: true,
    allowMultiple: false,
    dialogTitle: 'Escolher foto de perfil',
  );
  if (result == null) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) return null;
  return InstitutionLogoFile(name: file.name, bytes: bytes);
}
