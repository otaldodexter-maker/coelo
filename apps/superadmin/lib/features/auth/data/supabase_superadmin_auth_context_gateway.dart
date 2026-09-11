import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/superadmin_auth_context.dart';

typedef SuperadminAuthBootstrapCaller = Future<Object?> Function();

final class SupabaseSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  SupabaseSuperadminAuthContextGateway(SupabaseClient client)
    : this.fromCaller(() => client.rpc('superadmin_auth_bootstrap_context'));

  SupabaseSuperadminAuthContextGateway.fromCaller(this._callBootstrap);

  final SuperadminAuthBootstrapCaller _callBootstrap;

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final _codePattern = RegExp(r'^[a-z][a-z0-9_.-]{0,79}$');

  @override
  Future<SuperadminAuthContext?> bootstrap() async {
    try {
      final response = await _callBootstrap();
      if (response is! Map || response['ok'] != true || response['error'] != null) {
        return null;
      }
      final data = response['data'];
      if (data is! Map) return null;
      final roleCode = data['platform_role_code'];
      final scopeValue = data['scope_kind'];
      final institutionId = data['scope_institution_id'];
      final permissionValues = data['permission_codes'];
      final aal = data['aal'];
      if (roleCode is! String ||
          !_codePattern.hasMatch(roleCode) ||
          permissionValues is! List ||
          aal is! String ||
          !const {'aal1', 'aal2'}.contains(aal)) {
        return null;
      }
      final scopeKind = switch (scopeValue) {
        'platform' => SuperadminAuthScopeKind.platform,
        'institution' => SuperadminAuthScopeKind.institution,
        _ => null,
      };
      if (scopeKind == null ||
          (scopeKind == SuperadminAuthScopeKind.platform && institutionId != null) ||
          (scopeKind == SuperadminAuthScopeKind.institution &&
              (institutionId is! String || !_uuidPattern.hasMatch(institutionId)))) {
        return null;
      }
      final permissions = <String>{};
      for (final permission in permissionValues) {
        if (permission is! String || !_codePattern.hasMatch(permission)) return null;
        permissions.add(permission);
      }
      if (!permissions.contains('platform.read')) return null;
      return SuperadminAuthContext(
        platformRoleCode: roleCode,
        scopeKind: scopeKind,
        scopeInstitutionId: institutionId as String?,
        permissionCodes: Set.unmodifiable(permissions),
        aal: aal,
      );
    } on Exception {
      return null;
    }
  }
}
