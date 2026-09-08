import 'dart:convert';

/// Test-only: never import into lib or a client bundle.
final class A01LocalRuntimeConfig {
  A01LocalRuntimeConfig.fromEnvironment(Map<String, String> environment) {
    if (environment['COELO_A01_LOCAL_RUNTIME'] != '1') {
      throw const FormatException('A01 local runtime requires explicit opt-in.');
    }
    origin = validateOrigin(environment['COELO_A01_LOCAL_URL'] ?? '');
    publicKey = environment['COELO_A01_LOCAL_ANON_KEY'] ?? '';
    if (publicKey.isEmpty) throw const FormatException('Local anon key is required.');
    final keyClaims = _claims(publicKey);
    if (keyClaims['role'] != 'anon') {
      throw const FormatException('Only a local anon API key is accepted.');
    }
    for (final actor in const {'reader': 102, 'revoked': 104, 'denied': 106}.entries) {
      final token = environment['COELO_A01_${actor.key.toUpperCase()}_JWT'] ?? '';
      validateActorToken(token, actor.value);
      tokens[actor.key] = token;
    }
  }

  late final Uri origin;
  late final String publicKey;
  final tokens = <String, String>{};

  static Uri validateOrigin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        !uri.hasPort ||
        uri.port < 1024 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('A01 requires an explicit loopback HTTP origin and port.');
    }
    return uri.replace(path: '');
  }

  static void validateActorToken(String token, int actor) {
    final claims = _claims(token);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!const {102, 104, 106}.contains(actor) ||
        claims['sub'] != id(actor) ||
        claims['session_id'] != id(actor + 100) ||
        claims['role'] != 'authenticated' ||
        claims['aal'] != 'aal2' ||
        claims['exp'] is! int ||
        (claims['exp'] as int) <= now ||
        (claims['exp'] as int) > now + 3600) {
      throw const FormatException('A01 token does not match the short-lived synthetic actor.');
    }
  }

  static String id(int suffix) => '8a200000-0000-4000-8000-${suffix.toString().padLeft(12, '0')}';

  static Map<String, dynamic> _claims(String token) {
    try {
      final segments = token.split('.');
      if (segments.length != 3) throw const FormatException();
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(segments[1])))) as Map,
      );
    } catch (_) {
      // Do not include the input, JWT, API key or decoded claims in errors.
      throw const FormatException('Invalid local runtime credential format.');
    }
  }
}
