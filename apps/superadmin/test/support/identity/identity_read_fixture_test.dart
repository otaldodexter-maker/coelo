import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Users fixture isolates scope denial from membership revocation', () {
    final fixture = _fixture('users49-scoped-fixture.json');
    expect(fixture['base'], 'Users49');
    final reader = fixture['reader'] as Map<String, dynamic>;
    expect(reader['auth_user_id'], '91000000-0000-4000-8000-000000000003');
    expect(reader['session_id'], '92000000-0000-4000-8000-000000000003');
    expect(reader['aal'], 'aal1');
    final phases = fixture['phases'] as List<dynamic>;
    final scoped = phases[0] as Map<String, dynamic>;
    final revoked = phases[1] as Map<String, dynamic>;
    expect(scoped['scenario'], 'users-scoped');
    expect(scoped['expected_total'], 2);
    expect(scoped['expected_identity_ids'], contains(reader['identity_id']));
    expect(scoped['denied_detail_ids'], contains('93000000-0000-4000-8000-000000000005'));
    expect(scoped['expected_denial'], 'SAI_PERMISSION_DENIED');
    expect(revoked['scenario'], 'users-membership-revoked');
    expect(revoked['mutation_target'], reader['membership_id']);
    expect(revoked['expected_denial'], 'SAI_MEMBERSHIP_REVOKED');
    expect(
      revoked['must_preserve'],
      containsAll(['same JWT bytes', 'auth.sessions row', 'active auth-link']),
    );
    expect(fixture['required_existing_capabilities'], ['platform.read', 'platform.member.read']);
  });
  test('Models fixture preserves last Owner and separates domain denial', () {
    final fixture = _fixture('models50-phases-fixture.json');
    expect(fixture['base'], 'Models50');
    final reader = fixture['reader'] as Map<String, dynamic>;
    final backup = fixture['backup_owner_candidate'] as Map<String, dynamic>;
    expect(backup['requires_nominal_approval'], isTrue);
    expect(backup['role'], 'owner');
    expect(backup['scope_kind'], 'platform');
    expect(backup['required_status'], 'active');
    expect(backup['identity_id'], isNot(reader['identity_id']));
    expect(backup['auth_user_id'], 'f1000000-0000-4000-8000-000000000003');
    final phases = fixture['phases'] as List<dynamic>;
    final denied = phases[1] as Map<String, dynamic>;
    final revoked = phases[2] as Map<String, dynamic>;
    expect(denied['scenario'], 'models-domain-denied');
    expect(denied['denied_domain'], 'institution');
    expect(denied['allowed_domains'], ['platform', 'principal']);
    expect(denied['expected_denial'], 'SAI_PERMISSION_DENIED');
    expect(revoked['scenario'], 'models-membership-revoked');
    expect(revoked['mutation_target'], reader['membership_id']);
    expect(revoked['expected_denial'], 'SAI_MEMBERSHIP_REVOKED');
    expect(revoked['precondition'], contains('last-Owner'));
    expect(
      revoked['must_preserve'],
      containsAll(['same JWT bytes', 'active auth-link', 'auth.sessions row']),
    );
  });
  for (final file in ['users49-scoped-fixture.json', 'models50-phases-fixture.json']) {
    test('$file remains candidate with no credentials or executable grants', () {
      final fixture = _fixture(file);
      expect(fixture['status'], 'candidate-not-executed');
      expect(fixture['seed_kind'], 'committed-local-only-separate-from-pgtap');
      expect(fixture['source_sha256_lf'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(fixture['execution_gate'], contains('JSON is not executable SQL'));
      expect(jsonEncode(fixture), isNot(contains('service_role')));
      expect(jsonEncode(fixture), isNot(contains('eyJ')));
    });
  }
}

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(
          File(
            '../../packages/coelo_database/runtime-candidates/identity/$name',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
