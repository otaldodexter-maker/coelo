import 'package:coelo_superadmin/features/principal_shared/data/principal_signed_media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts an absolute HTTPS URL with a host', () {
    final uri = parsePrincipalSignedMediaUrl('https://media.example/asset?token=abc');
    expect(uri, isNotNull);
    expect(uri!.toString(), 'https://media.example/asset?token=abc');
  });

  test('trims surrounding whitespace before deciding', () {
    expect(parsePrincipalSignedMediaUrl('  https://media.example/asset  '), isNotNull);
  });

  test('refuses anything that is not usable as a private media source', () {
    for (final value in <Object?>[
      null,
      '',
      '   ',
      'media.example/asset',
      'http://media.example/asset',
      'ftp://media.example/asset',
      'file:///etc/passwd',
      'data:image/png;base64,AAAA',
      'javascript:alert(1)',
      'https:///asset',
      'https://user:secret@media.example/asset',
      42,
    ]) {
      expect(parsePrincipalSignedMediaUrl(value), isNull, reason: 'refused source: $value');
    }
  });
}
