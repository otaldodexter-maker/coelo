import 'dart:convert';

import 'package:coelo_superadmin/features/daily_routine/data/supabase_routine_repository.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('directory uses one paginated server-side RPC with scoped filters', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode({
            'items': [
              {
                'id': 'application-1',
                'kind': 'application',
                'name': 'Rotina Berçário',
                'status': 'active',
                'origin_scope_kind': 'institution',
                'institution_id': '00000000-0000-4000-8000-000000000001',
                'version': 3,
                'total_count': 21,
                'can_manage': true,
                'origin_label': 'Instituição Aurora',
                'effective_label': 'Unidade Centro',
              },
            ],
            'total_count': 21,
            'can_manage': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final page = await SupabaseRoutineRepository(client).fetchPage(
      const RoutineDirectoryQuery(
        kind: RoutineEntryKind.application,
        search: ' berçário ',
        status: 'active',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-1',
        page: 2,
        pageSize: 20,
      ),
    );

    expect(requests, hasLength(1), reason: 'directory RPC must not fan out into N+1 reads');
    expect(requests.single.url.path, endsWith('/rpc/superadmin_routine_directory'));
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body, {
      'p_kind': 'application',
      'p_search': 'berçário',
      'p_status': 'active',
      'p_institution_id': 'institution-1',
      'p_unit_id': 'unit-1',
      'p_group_id': 'group-1',
      'p_limit': 20,
      'p_offset': 20,
    });
    expect(page.totalCount, 21);
    expect(page.canManage, isTrue);
    expect(page.items.single.kind, RoutineEntryKind.application);
  });

  test('save model sends ordered sections fields options and conditions atomically', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({'id': 'model-1'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    const model = RoutineModel(
      id: 'model-1',
      name: ' Modelo ',
      description: ' Descrição ',
      version: 2,
      expectedVersion: 2,
      status: RoutineModelStatus.draft,
      originScope: RoutineModelOriginScope.institution,
      institutionId: '00000000-0000-4000-8000-000000000001',
      sections: [
        RoutineSection(
          id: 'section-1',
          name: ' Chegada ',
          sortOrder: 4,
          fields: [
            RoutineField(
              id: 'choice',
              label: ' Humor ',
              kind: RoutineFieldKind.singleChoice,
              sortOrder: 7,
              initialValue: 'calm',
              options: [
                RoutineFieldOption(id: 'calm', label: ' Calmo ', sortOrder: 2),
                RoutineFieldOption(id: 'happy', label: ' Feliz ', sortOrder: 5),
              ],
            ),
            RoutineField(
              id: 'detail',
              label: 'Detalhe',
              kind: RoutineFieldKind.shortText,
              sortOrder: 8,
              conditions: [
                RoutineCondition(
                  id: 'condition-1',
                  parentFieldId: 'choice',
                  targetFieldId: 'detail',
                  optionId: 'happy',
                  depth: 1,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    expect(
      await SupabaseRoutineRepository(client).saveModel(model, requestId: 'request-1'),
      'model-1',
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_routine_save_model'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(body['p_expected_version'], 2);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['name'], 'Modelo');
    expect(payload['origin_scope_kind'], 'institution');
    expect(payload['institution_id'], '00000000-0000-4000-8000-000000000001');
    expect(payload['origin_unit_id'], isNull);
    final section = (payload['sections'] as List).single as Map<String, dynamic>;
    expect(section['order'], 4);
    final fields = section['fields'] as List;
    expect((fields.first as Map<String, dynamic>)['order'], 7);
    final options = (fields.first as Map<String, dynamic>)['options'] as List;
    expect((options.first as Map<String, dynamic>)['order'], 2);
    expect((options.first as Map<String, dynamic>)['label'], 'Calmo');
    final conditions = payload['conditions'] as List;
    expect((conditions.single as Map<String, dynamic>)['boolean_value'], isNull);
  });

  test('model detail rejects an unsupported platform scope from the server', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        return Response(
          jsonEncode([
            {
              'id': 'model-1',
              'name': 'Modelo',
              'description': '',
              'current_version': 1,
              'management_version': 1,
              'status': 'draft',
              'can_manage': true,
              'origin_scope_kind': 'platform',
              'sections': <Object?>[],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseRoutineRepository(client).fetchModel('model-1'),
      throwsA(isA<ArgumentError>()),
    );
  });
  test('correction validates reason before making a privileged request', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests++;
        return Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseRoutineRepository(client).correctLaunch(
        launchId: 'launch-1',
        expectedVersion: 1,
        reason: 'curto',
        requestId: 'request-1',
        corrections: const [],
      ),
      throwsFormatException,
    );
    expect(requests, 0);
  });

  test('not-found detail fails closed without a fallback entity', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async =>
            Response('[]', 200, headers: {'content-type': 'application/json'}, request: request),
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseRoutineRepository(client).fetchApplication('foreign-id'),
      throwsA(isA<RoutineNotFoundException>()),
    );
  });
  test(
    'model detail maps the SQL current version required fields and top-level conditions',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({
              'id': '00000000-0000-4000-8000-000000000001',
              'name': 'Modelo real',
              'description': 'Contrato SQL',
              'status': 'active',
              'origin_scope_kind': 'institution',
              'institution_id': '00000000-0000-4000-8000-000000000001',
              'current_version': 4,
              'management_version': 7,
              'can_manage': true,
              'definition': {
                'sections': [
                  {
                    'id': '00000000-0000-4000-8000-000000000002',
                    'name': 'Chegada',
                    'order': 0,
                    'fields': [
                      {
                        'id': '00000000-0000-4000-8000-000000000003',
                        'label': 'Dormiu bem',
                        'kind': 'boolean',
                        'required': true,
                        'order': 0,
                        'options': <Object?>[],
                      },
                      {
                        'id': '00000000-0000-4000-8000-000000000004',
                        'label': 'Detalhes',
                        'kind': 'short_text',
                        'required': false,
                        'order': 1,
                        'options': <Object?>[],
                      },
                    ],
                  },
                ],
                'conditions': [
                  {
                    'source_field_id': '00000000-0000-4000-8000-000000000003',
                    'boolean_value': true,
                    'target_field_id': '00000000-0000-4000-8000-000000000004',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);

      final model = await SupabaseRoutineRepository(
        client,
      ).fetchModel('00000000-0000-4000-8000-000000000001');

      expect(model.version, 4);
      expect(model.expectedVersion, 7);
      expect(model.canManage, isTrue);
      expect(model.sections.first.fields.first.isRequired, isTrue);
      final condition = model.sections.first.fields.last.conditions.single;
      expect(condition.parentFieldId, '00000000-0000-4000-8000-000000000003');
      expect(condition.targetFieldId, '00000000-0000-4000-8000-000000000004');
    },
  );

  test('application detail maps revision assignees and archived status', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'id': '00000000-0000-4000-8000-000000000010',
            'institution_id': '00000000-0000-4000-8000-000000000011',
            'unit_id': '00000000-0000-4000-8000-000000000012',
            'activity_id': '00000000-0000-4000-8000-000000000016',
            'starts_at': '08:00:00',
            'ends_at': '12:00:00',
            'source_model_version_id': '00000000-0000-4000-8000-000000000013',
            'status': 'archived',
            'inheritance_mode': 'customized',
            'management_version': 9,
            'can_manage': false,
            'visibility': 'staff_only',
            'revision': {
              'revision_no': 5,
              'source_model_version_id': '00000000-0000-4000-8000-000000000014',
            },
            'assignees': [
              {
                'membership_id': '00000000-0000-4000-8000-000000000015',
                'responsibility': 'publish',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final application = await SupabaseRoutineRepository(
      client,
    ).fetchApplication('00000000-0000-4000-8000-000000000010');

    expect(application.status, RoutineApplicationStatus.archived);
    expect(application.canManage, isFalse);
    expect(application.modelVersionId, '00000000-0000-4000-8000-000000000014');
    expect(application.effectiveVersion, 5);
    expect(application.activityId, '00000000-0000-4000-8000-000000000016');
    expect(application.startsAt, '08:00');
    expect(application.endsAt, '12:00');
    expect(application.assignees.single.membershipId, '00000000-0000-4000-8000-000000000015');
    expect(application.assignees.single.responsibility, RoutineApplicationResponsibility.publish);
  });

  test('save application preserves schedule activity and assignee responsibility', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({'id': 'application-1'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseRoutineRepository(client).saveApplication(
      const RoutineApplication(
        id: '00000000-0000-4000-8000-000000000010',
        modelVersionId: '00000000-0000-4000-8000-000000000011',
        institutionId: '00000000-0000-4000-8000-000000000012',
        activityId: '00000000-0000-4000-8000-000000000013',
        status: RoutineApplicationStatus.active,
        inheritanceMode: RoutineInheritanceMode.customized,
        effectiveVersion: 2,
        expectedVersion: 4,
        startsAt: '08:30',
        endsAt: '12:15',
        assignees: <RoutineApplicationAssignee>[
          RoutineApplicationAssignee(
            membershipId: '00000000-0000-4000-8000-000000000014',
            responsibility: RoutineApplicationResponsibility.review,
          ),
        ],
      ),
      requestId: 'request-application',
    );

    final payload = jsonDecode(captured!.body)['p_payload'] as Map<String, dynamic>;
    expect(payload['activity_id'], '00000000-0000-4000-8000-000000000013');
    expect(payload['starts_at'], '08:30');
    expect(payload['ends_at'], '12:15');
    expect(payload['assignees'], [
      {'membership_id': '00000000-0000-4000-8000-000000000014', 'responsibility': 'review'},
    ]);
  });
  test('launch detail maps child entries and answer drafts from the SQL aggregate', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'id': '00000000-0000-4000-8000-000000000020',
            'application_id': '00000000-0000-4000-8000-000000000021',
            'application_revision_id': '00000000-0000-4000-8000-000000000022',
            'institution_id': '00000000-0000-4000-8000-000000000023',
            'unit_id': '00000000-0000-4000-8000-000000000024',
            'group_id': '00000000-0000-4000-8000-000000000025',
            'author_membership_id': '00000000-0000-4000-8000-000000000026',
            'service_date': '2026-08-11',
            'status': 'draft',
            'management_version': 2,
            'children': [
              {
                'id': '00000000-0000-4000-8000-000000000027',
                'child_context_id': '00000000-0000-4000-8000-000000000028',
                'child_group_link_id': '00000000-0000-4000-8000-000000000029',
                'status': 'draft',
                'answers': [
                  {'field_id': '00000000-0000-4000-8000-000000000030', 'value_json': 'Calmo'},
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final launch = await SupabaseRoutineRepository(
      client,
    ).fetchLaunch('00000000-0000-4000-8000-000000000020');

    expect(launch.children.single.entryId, '00000000-0000-4000-8000-000000000027');
    expect(launch.children.single.answers.single.fieldId, '00000000-0000-4000-8000-000000000030');
    expect(launch.children.single.answers.single.value, 'Calmo');
  });
}
