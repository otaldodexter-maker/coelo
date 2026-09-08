import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The write side of `people.links` had no test against the contract it answers.
///
/// `person_membership_payload_test.dart` proves the shape the client emits.
/// Nothing proved that shape is the shape `superadmin_people_update` accepts.
/// The gap matters because that function refuses an unknown top-level key
/// outright - `update field is not editable` - and because it renames things on
/// the way in: `remove` becomes `revoke`, `role` becomes `role_code`. A rename
/// on either side is invisible until a real save fails or, worse, succeeds
/// while doing nothing.
///
/// These tests read the migration text and compare it against the payload the
/// repository actually puts on the wire. No database is touched, so they run in
/// the ordinary suite; what they cannot prove is that the deployed function
/// matches the migration - OQ-032 is exactly that hazard for Unidades.
const _migration =
    '../../packages/coelo_database/migrations/'
    '20260729141839_superadmin_people_directory.sql';

/// The body of one `create or replace function`, whitespace collapsed.
String _function(String sql, String name) {
  final start = sql.indexOf('create or replace function $name(');
  // Read at load time, before any test runs, so `expect` is not available here.
  if (start == -1) {
    throw StateError('the migration no longer declares $name');
  }
  final next = sql.indexOf('\ncreate ', start + 1);
  final body = next == -1 ? sql.substring(start) : sql.substring(start, next);
  return body.replaceAll(RegExp(r'\s+'), ' ');
}

/// The quoted keys of the first `where key not in (...)` guard in a body.
Set<String> _keyAllowlist(String body) {
  final clause = RegExp(r"where key not in \(([^)]*)\)").firstMatch(body);
  if (clause == null) {
    throw StateError('the key allow-list guard is gone');
  }
  return RegExp(r"'([a-z_]+)'")
      .allMatches(clause.group(1)!)
      .map((match) => match.group(1)!)
      .toSet();
}

PersonMembership _membership() => const PersonMembership(
  id: 'assignment-1',
  membershipId: 'membership-1',
  institutionId: '11111111-1111-4111-8111-111111111111',
  institutionName: 'Casa Nuvem',
  unitId: '22222222-2222-4222-8222-222222222222',
  unitName: 'Unidade Centro',
  groupId: '33333333-3333-4333-8333-333333333333',
  groupName: 'Turma Girassol',
  role: 'guardian',
);

PersonChildContext _childContext() => const PersonChildContext(
  id: 'context-1',
  institutionId: '11111111-1111-4111-8111-111111111111',
  unitId: '22222222-2222-4222-8222-222222222222',
  groupId: '33333333-3333-4333-8333-333333333333',
  childUnitLinkId: 'unit-link-1',
  childGroupLinkId: 'group-link-1',
);

void main() {
  final sql = File(_migration).readAsStringSync();
  final wrapper = _function(sql, 'public.superadmin_people_update');
  final writer = _function(sql, 'app_private.update_superadmin_person');

  Future<Map<String, dynamic>> onTheWire(PersonUpdate update) async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response('{}', 200, headers: {'content-type': 'application/json'}, request: request);
      }),
    );
    addTearDown(client.dispose);
    try {
      await SupabasePersonDirectoryRepository(client).updatePerson(update);
    } on Object {
      // The response is not what this test is about; the request is.
    }
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    return (body['p_update'] as Map).cast<String, dynamic>();
  }

  /// Everything a save can carry, both link kinds at once.
  PersonUpdate fullUpdate() => PersonUpdate(
    personId: '44444444-4444-4444-8444-444444444444',
    expectedUpdatedAt: DateTime.utc(2026, 1, 1),
    firstName: 'Ana',
    lastName: 'Lima',
    displayName: 'Ana Lima',
    legalName: 'Ana Lima',
    membershipChanges: [
      PersonMembershipChange.add(_membership()),
      PersonMembershipChange.update(_membership()),
      PersonMembershipChange.remove(_membership()),
    ],
    childContextChanges: [
      PersonChildContextChange.add(_childContext()),
      PersonChildContextChange.update(_childContext()),
      PersonChildContextChange.remove(_childContext()),
    ],
  );

  test('every key the client sends is a key the function accepts', () async {
    // The guard raises on the first unknown key, so an extra field on the
    // client does not degrade - it fails the whole save.
    final payload = await onTheWire(fullUpdate());
    expect(_keyAllowlist(wrapper), containsAll(payload.keys));
  });

  test('what survives the strip is exactly what the identity patch allows', () async {
    // The wrapper hands the writer `p_update` minus the routing keys. Whatever
    // is left has to match the writer's own allow-list, or the save dies one
    // frame later with `identity field is not editable`.
    final payload = await onTheWire(fullUpdate());
    const stripped = {
      'person_id',
      'expected_updated_at',
      'context_changes',
      'membership_changes',
      'child_context_changes',
    };
    for (final key in stripped) {
      expect(wrapper, contains("- '$key'"), reason: 'the wrapper stopped stripping $key');
    }
    expect(payload.keys.toSet().difference(stripped), equals(_keyAllowlist(writer)));
  });

  test('the type of a person is not something a save can change', () {
    // The form holds a mutable `type`, and the writer will not persist it. So
    // the field decides which list the screen collects while the server keeps
    // deciding by the stored value - see the routing test below.
    expect(_keyAllowlist(writer), isNot(contains('person_type')));
    expect(_keyAllowlist(wrapper), isNot(contains('person_type')));
  });

  test('the words the client uses are words the writer answers to', () async {
    final payload = await onTheWire(fullUpdate());
    final operations = [
      ...(payload['membership_changes'] as List).cast<Map<String, dynamic>>(),
      ...(payload['child_context_changes'] as List).cast<Map<String, dynamic>>(),
    ].map((change) => change['operation'] as String).toSet();
    expect(operations, {'add', 'update', 'remove'});

    // `remove` is not a word the writer knows; the wrapper translates it.
    expect(wrapper, contains("when change ->> 'operation' = 'remove' then 'revoke'"));
    expect(writer, contains("change ->> 'operation' = 'add'"));
    expect(writer, contains("change ->> 'operation' in ('update', 'revoke')"));
    expect(
      writer,
      contains('unsupported membership operation'),
      reason: 'an unknown operation must raise, not pass through quietly',
    );
  });

  test('the role travels under one name and lands under another', () async {
    final payload = await onTheWire(fullUpdate());
    final change = (payload['membership_changes'] as List).first as Map<String, dynamic>;
    expect(change['role'], 'guardian');
    expect(change.containsKey('role_code'), isFalse);
    expect(wrapper, contains("coalesce(change ->> 'role_code', change ->> 'role')"));
  });

  test('a link with no id sends no id, and the wrapper reads the absence', () async {
    // An added link points at nothing yet. The client omits or nulls the id and
    // the wrapper reads it with `->>`, which answers null for both.
    final payload = await onTheWire(fullUpdate());
    final added = (payload['membership_changes'] as List).first as Map<String, dynamic>;
    expect(added['assignment_id'], isNull);
    expect(wrapper, contains("'assignment_id', change ->> 'assignment_id'"));

    final bare = await onTheWire(
      PersonUpdate(
        personId: '44444444-4444-4444-8444-444444444444',
        expectedUpdatedAt: DateTime.utc(2026, 1, 1),
        firstName: 'Ana',
        lastName: 'Lima',
        displayName: 'Ana Lima',
        legalName: 'Ana Lima',
        childContextChanges: [
          PersonChildContextChange.add(
            const PersonChildContext(
              id: 'context-1',
              institutionId: '11111111-1111-4111-8111-111111111111',
            ),
          ),
        ],
      ),
    );
    final context = (bare['child_context_changes'] as List).single as Map<String, dynamic>;
    expect(context.containsKey('child_unit_link_id'), isFalse);
    expect(wrapper, contains("'child_unit_link_id', change ->> 'child_unit_link_id'"));
  });

  test('the server picks one list by the stored type and drops the other in silence', () async {
    // This is the hazard, written down so nobody removes it by accident.
    //
    // The payload carries both lists. The function reads the person's stored
    // `person_type` and then reads *one* of them: child contexts for a child,
    // memberships for anyone else. The list that does not match is not refused,
    // not warned about, not mentioned in the returned payload - it is simply
    // never looked at, and the save reports success.
    //
    // Nothing on the client prevents filling the wrong one: the view model
    // exposes both lists and a mutable `type` that the server never reads.
    final payload = await onTheWire(fullUpdate());
    expect((payload['membership_changes'] as List), isNotEmpty);
    expect((payload['child_context_changes'] as List), isNotEmpty);

    expect(
      wrapper,
      contains(
        "when person_type = 'child' then coalesce(p_update -> 'child_context_changes', '[]'::jsonb) "
        "else coalesce(p_update -> 'membership_changes', '[]'::jsonb) end",
      ),
      reason: 'if this branch changed shape, the silent-drop note needs rewriting',
    );
  });
}
