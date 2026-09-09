import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/features/groups/data/supabase_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The last write in Estruturas that had no measurement against its function.
///
/// `group_members_payload_test.dart` covers the destructive part - the member
/// set that replaces rather than patches. What nothing covered is the shape of
/// the payload as a whole, and `superadmin_group_save` is strict about it: any
/// key outside its list of fourteen raises `unknown group payload key` and the
/// save dies entirely.
///
/// So a field added to the group form and wired to the payload without a
/// migration does not degrade. It takes the whole save down, including the
/// members, on the first attempt. That is a good failure and a loud one, and it
/// deserves to be caught here rather than there.
const _migration =
    '../../packages/coelo_database/migrations/'
    '20260811151254_group_management_security.sql';

/// The fourteen keys the function subtracts before demanding an empty object.
Set<String> _allowlist(String sql) {
  final guard = RegExp(
    r"p_payload - array\[([^\]]*)\]",
    dotAll: true,
  ).firstMatch(sql);
  if (guard == null) {
    throw StateError('the group payload allow-list is gone');
  }
  return RegExp("'([a-z_]+)'")
      .allMatches(guard.group(1)!)
      .map((match) => match.group(1)!)
      .toSet();
}

GroupRecord _record() => GroupRecord(
  id: '33333333-3333-4333-8333-333333333333',
  institutionId: '11111111-1111-4111-8111-111111111111',
  institutionName: 'Casa Nuvem',
  unitId: '22222222-2222-4222-8222-222222222222',
  unitName: 'Unidade Centro',
  name: 'Turma Girassol',
  groupType: 'class',
  status: GroupStatus.active,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  managementVersion: 2,
);

GroupDirectoryPersonBinding _person() => GroupDirectoryPersonBinding(
  id: '44444444-4444-4444-8444-000000000001',
  name: 'Ana Lima',
  identifier: '@ana',
  role: 'student',
);

void main() {
  final allowed = _allowlist(File(_migration).readAsStringSync());

  Future<Map<String, dynamic>> onTheWire(GroupDirectorySaveRequest request) async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon',
      httpClient: MockClient((httpRequest) async {
        captured = httpRequest;
        return Response(
          jsonEncode({
            'id': '33333333-3333-4333-8333-333333333333',
            'institution_id': '11111111-1111-4111-8111-111111111111',
            'institution_name': 'Casa Nuvem',
            'unit_id': '22222222-2222-4222-8222-222222222222',
            'unit_name': 'Unidade Centro',
            'name': 'Turma Girassol',
            'group_type': 'class',
            'status': 'active',
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'management_version': 3,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: httpRequest,
        );
      }),
    );
    addTearDown(client.dispose);
    await SupabaseGroupDirectoryRepository(client).saveComposition(request);
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    return (body['p_payload'] as Map).cast<String, dynamic>();
  }

  test('the allow-list was read and has the shape the function documents', () {
    expect(allowed, hasLength(14));
    expect(allowed, containsAll(<String>['name', 'local_people', 'branding', 'type_request']));
  });

  test('a save carrying everything it can carry stays inside the fourteen', () async {
    final payload = await onTheWire(
      GroupDirectorySaveRequest(
        requestId: '55555555-5555-4555-8555-000000000001',
        record: _record(),
        people: [_person()],
        professionals: const [],
        activityIds: const ['66666666-6666-4666-8666-000000000001'],
        branding: const {'display_name': 'Girassol'},
        typeRequestLabel: 'Turma mista',
        typeRequestJustification: 'A unidade combina faixas etarias.',
      ),
    );

    expect(
      payload.keys.toSet().difference(allowed),
      isEmpty,
      reason: 'a key outside the list raises unknown group payload key and takes '
          'the whole save down, members included',
    );
  });

  test('the location the form no longer collects is not in either list', () {
    // The picker was removed because there was nowhere to send the choice. Both
    // halves of that are pinned: the function has no key, and the client sends
    // none. `group_location_selection_test.dart` holds the form side.
    expect(allowed.where((key) => key.contains('location')), isEmpty);
  });

  test('an empty composition still sends the member set, which is the hazard', () async {
    // Not a rule, a hazard, and it is written down in group_members_payload_test
    // as well. Recorded here because the allow-list is what makes `local_people`
    // a full-set replacement rather than a patch.
    final payload = await onTheWire(
      GroupDirectorySaveRequest(
        requestId: '55555555-5555-4555-8555-000000000002',
        record: _record(),
      ),
    );
    expect(payload.containsKey('local_people'), isTrue);
    expect(payload['local_people'], isEmpty);
    expect(allowed, contains('local_people'));
  });
}
