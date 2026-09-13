import 'dart:convert';

import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/data/supabase_assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('keeps configured-period timezone server-owned on save', () {
    final period = AssessmentConfiguredPeriod(
      id: '',
      name: 'Período anual',
      ordinal: 1,
      academicYear: 2027,
      startsOn: DateTime(2027),
      endsOn: DateTime(2027, 12, 31),
      entryClosesAt: DateTime(2027, 12, 31, 18),
      familyReleaseAt: DateTime(2028, 1, 2, 8),
    );

    expect(period.toJson(), isNot(contains('timezone')));
  });

  test('preserves an explicit configured-period timezone for validation', () {
    final period = AssessmentConfiguredPeriod(
      id: 'period-1',
      name: 'Período anual',
      ordinal: 1,
      academicYear: 2027,
      startsOn: DateTime(2027),
      endsOn: DateTime(2027, 12, 31),
      entryClosesAt: DateTime(2027, 12, 31, 18),
      familyReleaseAt: DateTime(2028, 1, 2, 8),
      timezone: 'America/Manaus',
    );

    expect(period.toJson()['timezone'], 'America/Manaus');
  });

  test('save gradebook returns the authoritative aggregate read after the RPC', () async {
    final calls = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('/rpc/superadmin_assessment_save_gradebook')) {
          return Response(
            jsonEncode({
              'ok': true,
              'data': {'id': 'book-1', 'version': 2, 'status': 'draft'},
              'error': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/rpc/superadmin_assessment_gradebook_read')) {
          return Response(
            jsonEncode({
              'ok': true,
              'data': {
                'gradebook': {
                  'id': 'book-1',
                  'management_version': 9,
                  'status': 'reviewed',
                  'activity_group_link_id': 'link-1',
                  'institution_id': 'institution-1',
                  'institution_name': 'Colégio Horizonte',
                  'unit_id': 'unit-1',
                  'unit_name': 'Centro',
                  'group_id': 'group-1',
                  'group_name': '2º A',
                  'activity_id': 'activity-1',
                  'activity_name': 'Inglês',
                  'period_id': 'period-1',
                  'period_name': '1º bimestre',
                },
                'configuration': null,
                'students': <Object?>[],
                'events': [
                  {
                    'id': 'event-1',
                    'event_kind': 'reviewed',
                    'actor_person_id': 'person-reviewer',
                    'reason': 'Pendências conferidas',
                    'version': 9,
                    'created_at': '2027-07-06T12:00:00Z',
                  },
                ],
              },
              'error': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return Response('not found', 404, request: request);
      }),
    );
    addTearDown(client.dispose);
    const source = AssessmentGradebook(
      id: 'book-1',
      version: 1,
      status: AssessmentGradebookStatus.draft,
      context: AssessmentContext.sample(),
      students: [],
    );

    final result = await SupabaseAssessmentRepository(client).saveGradebook(source);

    expect(calls, [
      endsWith('/rpc/superadmin_assessment_save_gradebook'),
      endsWith('/rpc/superadmin_assessment_gradebook_read'),
    ]);
    expect(result.version, 9);
    expect(result.status, AssessmentGradebookStatus.reviewed);
    expect(result.events, hasLength(1));
    expect(result.events.single.kind, 'reviewed');
    expect(result.events.single.reason, 'Pendências conferidas');
    expect(result.events.single.actorPersonId, 'person-reviewer');
  });

  test(
    'save configuration reloads the exact saved draft instead of the active configuration',
    () async {
      final calls = <Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          calls.add(request);
          if (request.url.path.endsWith('/rpc/superadmin_assessment_save_configuration')) {
            return _json({'id': 'draft-r10', 'version': 1, 'status': 'draft'}, request);
          }
          if (request.url.path.endsWith('/rpc/superadmin_assessment_configuration_read_by_id')) {
            return _json(
              _configurationEnvelope('draft-r10', 'draft', 'R08 sintético — revisão R10'),
              request,
            );
          }
          if (request.url.path.endsWith('/rpc/superadmin_assessment_configuration_read')) {
            return _json(
              _configurationEnvelope('active-old', 'active', 'Período ativo antigo'),
              request,
            );
          }
          return Response('not found', 404, request: request);
        }),
      );
      addTearDown(client.dispose);
      const source = AssessmentConfiguration(
        id: 'active-old',
        activityId: 'activity-r10',
        institutionId: 'institution-r10',
        unitId: 'unit-r10',
        periodicity: 'annual',
        scaleKind: AssessmentScaleKind.numeric,
        version: 2,
        status: 'active',
        instruments: [],
        competencies: [],
        availableCompetencies: [],
        concepts: [],
        periods: [],
      );

      final saved = await SupabaseAssessmentRepository(client).saveConfiguration(source);

      expect(saved.id, 'draft-r10');
      expect(saved.status, 'draft');
      expect(saved.periods.single.name, 'R08 sintético — revisão R10');
      expect(calls.map((request) => request.url.path), [
        endsWith('/rpc/superadmin_assessment_save_configuration'),
        endsWith('/rpc/superadmin_assessment_configuration_read_by_id'),
      ]);
      final readBody = jsonDecode(calls.last.body) as Map<String, dynamic>;
      expect(readBody, {'target_configuration': 'draft-r10'});
    },
  );

  test('maps internal v2 envelopes without exposing backend details', () async {
    SupabaseAssessmentRepository repositoryFor(String code, int status) {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({
              'ok': false,
              'data': null,
              'error': {'code': code, 'http_status': status},
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      return SupabaseAssessmentRepository(client);
    }

    await expectLater(
      repositoryFor('SAI_PERMISSION_DENIED', 403).fetchClosingQueue(),
      throwsA(isA<AssessmentUnauthorizedException>()),
    );
    await expectLater(
      repositoryFor('ASSESSMENT_INVALID_STATE', 409).fetchClosingQueue(),
      throwsA(isA<AssessmentVersionConflictException>()),
    );
    await expectLater(
      repositoryFor('ASSESSMENT_INVALID_INPUT', 422).fetchClosingQueue(),
      throwsA(isA<AssessmentOfflineException>()),
    );
    for (final code in ['SAI_INTERNAL_ERROR', 'SAI_UNKNOWN_ERROR']) {
      await expectLater(
        repositoryFor(code, 500).fetchClosingQueue(),
        throwsA(isA<AssessmentOfflineException>()),
      );
    }
    for (final code in [
      'SAI_AUTH_REQUIRED',
      'SAI_SESSION_INVALID',
      'SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED',
      'SAI_MEMBERSHIP_REVOKED',
      'SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED',
    ]) {
      await expectLater(
        repositoryFor(code, 0).fetchClosingQueue(),
        throwsA(isA<AssessmentUnauthorizedException>()),
      );
    }
    await expectLater(
      repositoryFor('SAI_CONCURRENT_CHANGE', 409).fetchClosingQueue(),
      throwsA(isA<AssessmentVersionConflictException>()),
    );
  });
}

Response _json(Object? data, Request request) => Response(
  jsonEncode({'ok': true, 'data': data, 'error': null}),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _configurationEnvelope(String id, String status, String periodName) => {
  'configuration': {
    'id': id,
    'activity_id': 'activity-r10',
    'institution_id': 'institution-r10',
    'unit_id': 'unit-r10',
    'periodicity': 'annual',
    'result_scale_kind': 'numeric',
    'scale_options': {'step': 0.1},
    'allow_final_override': false,
    'management_version': 1,
    'status': status,
  },
  'instruments': <Object?>[],
  'concepts': <Object?>[],
  'competencies': <Object?>[],
  'available_competencies': <Object?>[],
  'periods': [
    {
      'id': 'period-r10',
      'name': periodName,
      'ordinal': 1,
      'academic_year': 2026,
      'starts_on': '2026-01-01',
      'ends_on': '2026-12-31',
      'entry_closes_at': '2026-12-31T18:00:00Z',
      'family_release_at': '2027-01-02T08:00:00Z',
      'timezone': 'America/Sao_Paulo',
      'status': 'active',
    },
  ],
};
