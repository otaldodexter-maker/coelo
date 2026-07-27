// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

final class InstitutionLogoFile {
  const InstitutionLogoFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<InstitutionLogoFile?> pickInstitutionLogo() async {
  final input = html.FileUploadInputElement()..accept = 'image/png,image/jpeg,image/webp';
  input.click();
  await input.onChange.first;
  final file = input.files?.firstOrNull;
  if (file == null) {
    return null;
  }
  final reader = html.FileReader()..readAsArrayBuffer(file);
  await reader.onLoad.first;
  return InstitutionLogoFile(name: file.name, bytes: Uint8List.view(reader.result! as ByteBuffer));
}
