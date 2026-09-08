import 'dart:convert';

import 'package:coelo_superadmin/features/groups/data/supabase_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The membership payload had no test at the wire, and it is the one payload in
/// this family where a mistake is destructive.
///
/// `superadmin_group_save` treats `local_people` as a full-set replacement:
/// every active assignment whose person is absent from the array is set to
/// inactive. The guard is `if p_payload ? 'local_people'` - omitting the key
/// leaves the membership alone, and sending an empty array removes everyone.
///
/// The client sends the key unconditionally. So a save issued while the form
/// holds no members - a failed hydration, a step never opened - asks the server
/// to empty the group, and nothing in the client says so. These tests pin the
/// shape and write the hazard down where the next person will meet it.
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

GroupDirectoryPersonBinding _person(String id, String role) =>
    GroupDirectoryPersonBinding(id: id, name: 'Pessoa $id', identifier: '@$id', role: role);

void main() {
  Future<Map<String, dynamic>> capturedSave(GroupDirectorySaveRequest request) async {
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

  test('members and professionals travel as one set of person and role', () async {
    final payload = await capturedSave(
      GroupDirectorySaveRequest(
        requestId: 'group-save-1',
        record: _record(),
        people: [
          _person('44444444-4444-4444-8444-000000000001', 'student'),
          _person('44444444-4444-4444-8444-000000000002', 'guardian'),
        ],
        professionals: [_person('44444444-4444-4444-8444-000000000003', 'professional')],
      ),
    );

    expect(payload['local_people'], [
      {'person_id': '44444444-4444-4444-8444-000000000001', 'role_code': 'student'},
      {'person_id': '44444444-4444-4444-8444-000000000002', 'role_code': 'guardian'},
      {'person_id': '44444444-4444-4444-8444-000000000003', 'role_code': 'professional'},
    ]);
  });

  test('removing someone means sending the set without them, not a removal flag', () async {
    // This is the whole reason the shape matters: there is no "remove" command.
    // Absence from the array is the removal.
    final payload = await capturedSave(
      GroupDirectorySaveRequest(
        requestId: 'group-save-2',
        record: _record(),
        people: [_person('44444444-4444-4444-8444-000000000001', 'student')],
      ),
    );

    final people = (payload['local_people'] as List).cast<Map<String, dynamic>>();
    expect(people.map((entry) => entry['person_id']), [
      '44444444-4444-4444-8444-000000000001',
    ]);
    expect(
      people.any((entry) => entry.containsKey('command') || entry.containsKey('operation')),
      isFalse,
      reason: 'the server reads the array as the complete set, not as a delta',
    );
  });

  test('a save with no members asks the server to empty the group', () async {
    // Pinned deliberately, and it is a hazard rather than a feature. The key is
    // always sent, and the server only leaves membership alone when the key is
    // absent. A save issued before the members step ever loaded would therefore
    // deactivate everyone, with nothing in the client warning about it.
    final payload = await capturedSave(
      GroupDirectorySaveRequest(requestId: 'group-save-3', record: _record()),
    );

    expect(payload.containsKey('local_people'), isTrue);
    expect(payload['local_people'], isEmpty);
  });
}
