import 'package:coelo_superadmin/features/auth/data/supabase_superadmin_auth_context_gateway.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts only a strict successful internal bootstrap envelope', () async {
    final gateway = SupabaseSuperadminAuthContextGateway.fromCaller(
      () async => {
        'ok': true,
        'data': {
          'platform_role_code': 'operations',
          'scope_kind': 'institution',
          'scope_institution_id': '60000000-0000-4000-8000-000000000001',
          'permission_codes': ['platform.read'],
          'aal': 'aal1',
        },
        'error': null,
      },
    );

    final context = await gateway.bootstrap();

    expect(context, isNotNull);
    expect(context!.platformRoleCode, 'operations');
    expect(context.scopeKind, SuperadminAuthScopeKind.institution);
    expect(context.scopeInstitutionId, '60000000-0000-4000-8000-000000000001');
    expect(context.permissionCodes, {'platform.read'});
    expect(context.aal, 'aal1');
  });

  test('denies malformed, negative and provider-failing bootstrap responses', () async {
    for (final response in <Object?>[
      {
        'ok': false,
        'data': null,
        'error': {'code': 'SAI_PERMISSION_DENIED'},
      },
      {
        'ok': true,
        'data': {'platform_role_code': 'operations'},
      },
      {
        'ok': true,
        'data': {
          'platform_role_code': 'operations',
          'scope_kind': 'other',
          'permission_codes': <String>[],
          'aal': 'aal1',
        },
      },
    ]) {
      final gateway = SupabaseSuperadminAuthContextGateway.fromCaller(() async => response);
      expect(await gateway.bootstrap(), isNull);
    }
    final failing = SupabaseSuperadminAuthContextGateway.fromCaller(
      () => Future<Object?>.error(Exception('provider detail')),
    );
    expect(await failing.bootstrap(), isNull);
  });
}
