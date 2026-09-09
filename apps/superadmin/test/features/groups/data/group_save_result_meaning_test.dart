import 'dart:convert';

import 'package:coelo_superadmin/features/groups/data/supabase_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What a group save result actually means, written down before someone reads
/// more into it.
///
/// `superadmin_group_save` is one call and answers one thing: the whole payload
/// was applied, or it raised. It says nothing per stage. The repository turns
/// that single yes into five yeses - group, people, professionals, activity
/// links, invites - by looping over the enum and calling every one a success.
///
/// That is not a lie today, because the call is atomic: if it returned, all five
/// were applied together. It is a fabricated granularity, and two things follow
/// that are worth pinning rather than discovering later.
///
/// First, a stage the request carried nothing for still reports success. A save
/// with no invites answers "invites: success", and the domain has a `skipped`
/// status sitting unused that would say it properly.
///
/// Second, the screen's per-stage failure report is unreachable through this
/// repository. Failures arrive as thrown exceptions, never as failure steps, so
/// `hasFailure` is always false here and the branch that walks the steps to
/// highlight a broken form step never runs in production.
///
/// I asked C00 whether the client should synthesize this at all; the question is
/// open, so this test states the current meaning rather than changing it.
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

Map<String, Object?> _row() => {
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
};

void main() {
  Future<GroupDirectorySaveResult> save({Object? response, int status = 200}) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode(response ?? _row()),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    return SupabaseGroupDirectoryRepository(client).saveComposition(
      GroupDirectorySaveRequest(
        requestId: '55555555-5555-4555-8555-000000000001',
        record: _record(),
      ),
    );
  }

  test('one yes from the server becomes five yeses on the way back', () async {
    final result = await save();
    expect(result.steps, hasLength(GroupDirectorySaveStage.values.length));
    expect(result.isSuccess, isTrue);
    expect(
      result.steps.map((step) => step.stage).toSet(),
      GroupDirectorySaveStage.values.toSet(),
      reason: 'the granularity is the client loop, not the server answer',
    );
  });

  test('a stage the save carried nothing for still says success, not skipped', () async {
    // The request above has no people, no professionals, no activity links and
    // no invites. All four come back successful anyway.
    final result = await save();
    final invites = result.steps.firstWhere(
      (step) => step.stage == GroupDirectorySaveStage.invites,
    );
    expect(invites.status, GroupDirectorySaveStepStatus.success);
    expect(
      invites.status,
      isNot(GroupDirectorySaveStepStatus.skipped),
      reason:
          'skipped exists in the domain and would say this properly; the '
          'production repository never reaches for it',
    );
  });

  test('a failure never arrives as a step, so the per-stage report is unreachable', () async {
    // The screen walks result.steps to highlight the form step that broke. With
    // this repository that walk never runs: the call throws instead.
    await expectLater(
      save(response: {'message': 'denied', 'code': '42501'}, status: 403),
      throwsA(isA<Exception>()),
    );
  });

  test('the vocabulary the screen depends on still exists', () {
    // If any of these disappear, the unreachable branch stops compiling and the
    // gap above becomes visible on its own.
    expect(GroupDirectorySaveStepStatus.values, contains(GroupDirectorySaveStepStatus.skipped));
    expect(GroupDirectorySaveStepStatus.values, contains(GroupDirectorySaveStepStatus.failure));
    const failed = GroupDirectorySaveStepResult(
      stage: GroupDirectorySaveStage.people,
      status: GroupDirectorySaveStepStatus.failure,
    );
    expect(failed.isFailure, isTrue);
    expect(failed.isSuccessfulOrSkipped, isFalse);
  });
}
