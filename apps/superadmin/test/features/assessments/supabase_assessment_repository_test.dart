import 'dart:convert';

import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/data/supabase_assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('save gradebook returns the authoritative aggregate read after the RPC', () async {
    final calls = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('/rpc/superadmin_assessment_save_gradebook')) {
          return Response(
            jsonEncode({'id': 'book-1', 'version': 2, 'status': 'draft'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/rpc/superadmin_assessment_gradebook_read')) {
          return Response(
            jsonEncode({
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
}
