import 'dart:typed_data';

final class InstitutionLogoFile {
  const InstitutionLogoFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

typedef InstitutionLogoPicker = Future<InstitutionLogoFile?> Function();

Future<InstitutionLogoFile?> pickInstitutionLogo() async => null;
