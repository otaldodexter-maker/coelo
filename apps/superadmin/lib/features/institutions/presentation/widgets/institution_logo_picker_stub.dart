import 'dart:typed_data';

final class InstitutionLogoFile {
  const InstitutionLogoFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<InstitutionLogoFile?> pickInstitutionLogo() async => null;
