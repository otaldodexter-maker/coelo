import 'dart:convert';

/// Candidate test-only guard for the two nominal identity READ replay bases.
/// Parsing is a safety check, not JWT signature validation or proof of a seed.
final class IdentityReadLocalConfig {
  IdentityReadLocalConfig(Map<String, String> environment, {int? nowSeconds}) {
    if (environment['COELO_IDENTITY_LOCAL_RUNTIME'] != '1') _reject();
    profile = environment['COELO_IDENTITY_LOCAL_PROFILE'] ?? '';
    if (!const {'Users49', 'Models50'}.contains(profile)) _reject();
    scenario = environment['COELO_IDENTITY_LOCAL_SCENARIO'] ?? 'initial';
    if (!(profile == 'Users49'
            ? const {'initial', 'users-scoped', 'users-membership-revoked'}
            : const {'initial', 'models-domain-denied', 'models-membership-revoked'})
        .contains(scenario)) {
      _reject();
    }
    final uri = Uri.tryParse(environment['COELO_IDENTITY_LOCAL_URL'] ?? '');
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
      _reject();
    }
    origin = uri.replace(path: '');
    publicKey = environment['COELO_IDENTITY_LOCAL_ANON_KEY'] ?? '';
    if (_claims(publicKey)['role'] != 'anon') _reject();
    readerToken = environment['COELO_IDENTITY_READER_JWT'] ?? '';
    invalidSessionToken = environment['COELO_IDENTITY_INVALID_SESSION_JWT'] ?? '';
    final now = nowSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final entry in {
      readerToken: readerSessionId,
      invalidSessionToken: invalidSessionId,
    }.entries) {
      final claims = _claims(entry.key);
      if (claims['sub'] != readerAuthId ||
          claims['session_id'] != entry.value ||
          claims['role'] != 'authenticated' ||
          claims['aal'] != 'aal1' ||
          claims['exp'] is! int ||
          (claims['exp'] as int) <= now ||
          (claims['exp'] as int) > now + 3600) {
        _reject();
      }
    }
    if (readerToken == invalidSessionToken) _reject();
    if (scenario != 'initial' &&
        scenario != 'users-scoped' &&
        environment['COELO_IDENTITY_INITIAL_READER_JWT'] != readerToken) {
      _reject();
    }
  }

  late final String profile;
  late final String scenario;
  late final Uri origin;
  late final String publicKey;
  late final String readerToken;
  late final String invalidSessionToken;
  bool get isUsersScoped => scenario.startsWith('users-');
  bool get isMembershipRevoked => scenario.endsWith('membership-revoked');
  bool get isDomainDenied => scenario == 'models-domain-denied';
  String get _prefix => isUsersScoped
      ? '9'
      : profile == 'Users49'
      ? 'e'
      : 'f';
  String get _readerSuffix => isUsersScoped ? '003' : '001';
  String get readerAuthId => '${_prefix}1000000-0000-4000-8000-000000000$_readerSuffix';
  String get readerSessionId => '${_prefix}2000000-0000-4000-8000-000000000$_readerSuffix';
  String get invalidSessionId => '${_prefix}2000000-0000-4000-8000-000000000099';

  Set<String> get rpcNames => {
    'superadmin_auth_bootstrap_context',
    if (profile == 'Users49') ...{
      'superadmin_internal_user_profiles',
      'superadmin_internal_users_list',
      'superadmin_internal_user_detail',
    } else ...{
      'superadmin_access_profile_models_cursor',
      'superadmin_access_profile_model_detail',
      'superadmin_access_permission_catalog',
    },
  };

  void validateRequest(String method, Uri uri) {
    if (method != 'POST' ||
        uri.scheme != origin.scheme ||
        uri.host != origin.host ||
        uri.port != origin.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 4 ||
        uri.pathSegments.take(3).join('/') != 'rest/v1/rpc' ||
        !rpcNames.contains(uri.pathSegments.last)) {
      _reject();
    }
  }

  static Map<String, dynamic> _claims(String token) {
    try {
      final segments = token.split('.');
      if (segments.length != 3) _reject();
      return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(segments[1])))) as Map,
      );
    } catch (_) {
      _reject();
    }
  }

  static Never _reject() =>
      throw const FormatException('Identity local runtime configuration rejected.');
}
