import 'dart:convert';

import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The membership delta had no test at the wire.
///
/// The view model tests build the delta and never save; the adapter test
/// asserts the RPC path and never looks at the payload. So nothing proved that
/// pressing "Revogar vínculo" produces JSON the server understands - and the
/// server does translate it: `operation: remove` becomes `revoke` on the way in
/// (20260729141839_superadmin_people_directory.sql:2743). A rename on either
/// side would have gone unnoticed until a revocation silently did nothing.
PersonMembership _membership({String id = 'assignment-1', String? membershipId = 'membership-1'}) =>
    PersonMembership(
      id: id,
      membershipId: membershipId,
      institutionId: '11111111-1111-4111-8111-111111111111',
      institutionName: 'Casa Nuvem',
      unitId: '22222222-2222-4222-8222-222222222222',
      unitName: 'Unidade Centro',
      groupId: '33333333-3333-4333-8333-333333333333',
      groupName: 'Turma Girassol',
      role: 'guardian',
    );

void main() {
  Future<Map<String, dynamic>> capturedUpdate(PersonUpdate update) async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'id': '44444444-4444-4444-8444-444444444444',
            'display_name': 'Ana Lima',
            'legal_name': 'Ana Lima',
            'person_type': 'adult',
            'status': 'active',
            'updated_at': '2026-01-02T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    try {
      await SupabasePersonDirectoryRepository(client).updatePerson(update);
    } on Object {
      // The response shape is not what this test is about; the request is.
    }
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    return (body['p_update'] as Map).cast<String, dynamic>();
  }

  PersonUpdate update({List<PersonMembershipChange> changes = const []}) => PersonUpdate(
    personId: '44444444-4444-4444-8444-444444444444',
    expectedUpdatedAt: DateTime.utc(2026, 1, 1),
    firstName: 'Ana',
    lastName: 'Lima',
    displayName: 'Ana Lima',
    legalName: 'Ana Lima',
    membershipChanges: changes,
  );

  test('the optimistic version travels with every edit', () async {
    final payload = await capturedUpdate(update());
    expect(payload['person_id'], '44444444-4444-4444-8444-444444444444');
    expect(payload['expected_updated_at'], '2026-01-01T00:00:00.000Z');
  });

  test('adding a link carries no assignment id, because there is nothing to point at', () async {
    final payload = await capturedUpdate(
      update(changes: [PersonMembershipChange.add(_membership())]),
    );
    final change = (payload['membership_changes'] as List).single as Map<String, dynamic>;
    expect(change['operation'], 'add');
    expect(change['assignment_id'], isNull);
    expect(change['membership_id'], 'membership-1');
    expect(change['institution_id'], '11111111-1111-4111-8111-111111111111');
    expect(change['unit_id'], '22222222-2222-4222-8222-222222222222');
    expect(change['group_id'], '33333333-3333-4333-8333-333333333333');
    expect(change['role'], 'guardian');
  });

  test('revoking a link points at the assignment it is revoking', () async {
    final payload = await capturedUpdate(
      update(changes: [PersonMembershipChange.remove(_membership(id: 'assignment-9'))]),
    );
    final change = (payload['membership_changes'] as List).single as Map<String, dynamic>;
    // The client says "remove"; the server reads it as "revoke". Pinning the
    // client half is what makes the server half checkable at all.
    expect(change['operation'], 'remove');
    expect(change['assignment_id'], 'assignment-9');
  });

  test('changing a role updates in place instead of removing and adding', () async {
    final payload = await capturedUpdate(
      update(changes: [PersonMembershipChange.update(_membership(id: 'assignment-5'))]),
    );
    final change = (payload['membership_changes'] as List).single as Map<String, dynamic>;
    expect(change['operation'], 'update');
    expect(change['assignment_id'], 'assignment-5');
  });

  test('several changes travel in one command, in the order they were made', () async {
    final payload = await capturedUpdate(
      update(
        changes: [
          PersonMembershipChange.add(_membership(id: 'a', membershipId: 'm-a')),
          PersonMembershipChange.remove(_membership(id: 'b', membershipId: 'm-b')),
          PersonMembershipChange.update(_membership(id: 'c', membershipId: 'm-c')),
        ],
      ),
    );
    final changes = (payload['membership_changes'] as List).cast<Map<String, dynamic>>();
    expect(changes.map((entry) => entry['operation']), ['add', 'remove', 'update']);
    expect(changes.map((entry) => entry['membership_id']), ['m-a', 'm-b', 'm-c']);
  });

  test('an edit with no link changes says so with an empty list, never by omission', () async {
    // Unlike the group members payload, absence here is not a removal - the
    // server iterates the array. An empty array is the honest "nothing changed".
    final payload = await capturedUpdate(update());
    expect(payload.containsKey('membership_changes'), isTrue);
    expect(payload['membership_changes'], isEmpty);
    expect(payload['child_context_changes'], isEmpty);
  });
}
