import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses exact server pagination, stable ordering and real filters', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({'items': <Object?>[], 'total_count': 0}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final page = await SupabaseActivityDirectoryRepository(client).fetchPage(
      ActivityDirectoryQuery(
        search: 'música',
        institutionIds: {'institution-1'},
        unitIds: {'unit-1'},
        groupIds: {'group-1'},
        statuses: {ActivityStatus.active, ActivityStatus.draft},
        origins: {ActivityOrigin.unit},
        page: 2,
        pageSize: 20,
        sortAscending: false,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_directory'));
    final parameters = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(parameters['p_offset'], 40);
    expect(parameters['p_limit'], 20);
    expect(parameters['p_sort'], 'name');
    expect(parameters['p_sort_ascending'], isFalse);
    expect(parameters['p_institution_ids'], ['institution-1']);
    expect(parameters['p_unit_ids'], ['unit-1']);
    expect(parameters['p_group_ids'], ['group-1']);
    expect(parameters['p_statuses'], containsAll(['active', 'draft']));
    expect(parameters['p_origins'], ['unit']);
    expect(page.totalCount, 0);
  });

  test('maps the complete editable detail without private image bytes', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final body = switch (table) {
          'superadmin_activity_detail' => {
            'id': 'activity-1',
            'institution_id': 'institution-1',
            'name': 'Música',
            'handle_stem': 'musica',
            'canonical_handle': 'musica.casa-nuvem',
            'description': 'Expressão sonora',
            'origin_scope_kind': 'unit',
            'origin_unit_id': 'unit-1',
            'status': 'active',
            'distribution_scope': 'unit_local',
            'governance_kind': 'optional',
            'taxonomy_id': 'taxonomy-1',
            'subtype_id': 'subtype-1',
            'template_id': 'template-1',
            'taxonomy_other_description': 'Outro valor',
            'identity_mode': 'photo',
            'identity_storage_bucket': 'coelo-identities',
            'identity_storage_path': 'activities/activity-1/profile.webp',
            'identity_initials': 'MU',
            'identity_color': '#123456',
            'identity_icon': 'music',
            'created_at': '2026-07-01T10:00:00Z',
            'updated_at': '2026-07-29T10:00:00Z',
            'archived_at': null,
            'institutions': {'name': 'Casa Nuvem'},
            'activity_unit_links': [
              {
                'id': 'link-unit-1',
                'unit_id': 'unit-1',
                'status': 'active',
                'starts_at': '2026-07-01T10:00:00Z',
                'ends_at': null,
                'units': {'name': 'Unidade Centro'},
              },
            ],
            'activity_group_links': [
              {
                'id': 'link-group-1',
                'group_id': 'group-1',
                'unit_id': 'unit-1',
                'status': 'active',
                'participation_mode': 'selected',
                'groups': {'name': 'Grupo Azul'},
                'units': {'name': 'Unidade Centro'},
                'activity_group_assignments': [
                  {'id': 'assignment-1', 'status': 'active'},
                ],
                'activity_group_participants': [
                  {'id': 'participant-1', 'status': 'active'},
                  {'id': 'participant-2', 'status': 'active'},
                ],
              },
            ],
            'participants': [
              {
                'activity_group_link_id': 'link-group-1',
                'child_group_link_id': 'child-group-link-1',
                'status': 'active',
              },
            ],
            'professional_assignments': [
              {
                'group_id': 'group-1',
                'membership_id': 'membership-1',
                'role': 'instructor',
                'capabilities': {'chat': 'view', 'attendance': 'edit'},
              },
            ],
            'activity_admins': [
              {
                'membership_id': 'membership-2',
                'role': 'activity_admin',
                'capabilities': {'chat': 'both'},
              },
            ],
          },
          _ => null,
        };
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final detail = await SupabaseActivityDirectoryRepository(client).fetchById('activity-1');

    expect(detail?.originUnitName, 'Unidade Centro');
    expect(detail?.groups.single.name, 'Grupo Azul');
    expect(detail?.groups.single.assigneeCount, 1);
    expect(detail?.groups.single.participantCount, 2);
    expect(detail?.taxonomyId, 'taxonomy-1');
    expect(detail?.subtypeId, 'subtype-1');
    expect(detail?.templateId, 'template-1');
    expect(detail?.item.handleStem, 'musica');
    expect(detail?.item.canonicalHandle, 'musica.casa-nuvem');
    expect(detail?.taxonomyOtherDescription, 'Outro valor');
    expect(detail?.identity.kind, ActivityDetailIdentityKind.photo);
    expect(detail?.identity.initials, 'MU');
    expect(detail?.identity.color, '#123456');
    expect(detail?.identity.icon, 'music');
    expect(detail?.identity.storageRef?.bucket, 'coelo-identities');
    expect(detail?.identity.storageRef?.path, 'activities/activity-1/profile.webp');
    expect(detail?.participants.single.groupId, 'group-1');
    expect(detail?.participants.single.childGroupLinkId, 'child-group-link-1');
    expect(detail?.participants.single.belongs, isTrue);
    expect(detail?.professionalAssignments, hasLength(2));
    expect(detail?.professionalAssignments.first.groupId, 'group-1');
    expect(detail?.professionalAssignments.first.membershipId, 'membership-1');
    expect(detail?.professionalAssignments.first.role, ActivityDetailProfessionalRole.instructor);
    expect(detail?.professionalAssignments.first.capabilities['chat'], 'view');
    expect(detail?.professionalAssignments.last.groupId, isNull);
    expect(detail?.professionalAssignments.last.role, ActivityDetailProfessionalRole.activityAdmin);
  });

  test('maps students by child-group link for explicit participation', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'institutions': <Object?>[],
            'units': <Object?>[],
            'locations': <Object?>[],
            'groups': <Object?>[],
            'professionals': <Object?>[],
            'students': [
              {
                'child_group_link_id': 'child-group-link-1',
                'child_id': 'child-1',
                'group_id': 'group-1',
                'name': 'Ana Silva',
                'age': 9,
                'gender': 'Feminino',
              },
            ],
            'taxonomy': <Object?>[],
            'templates': <Object?>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final options = await SupabaseActivityDirectoryRepository(
      client,
    ).fetchFormOptions(institutionId: 'institution-1');

    expect(
      options.students.single,
      isA<ActivityFormStudentOption>()
          .having((item) => item.childGroupLinkId, 'childGroupLinkId', 'child-group-link-1')
          .having((item) => item.id, 'id', 'child-1')
          .having((item) => item.groupId, 'groupId', 'group-1')
          .having((item) => item.age, 'age', 9)
          .having((item) => item.gender, 'gender', 'Feminino'),
    );
  });

  test('lists real templates in the requested institution scope', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'institutions': <Object?>[],
            'taxonomy': <Object?>[],
            'templates': [
              {
                'id': 'template-robotics',
                'name': 'Robótica',
                'taxonomy_id': 'taxonomy-science',
                'subtype_id': 'subtype-robotics',
                'description': 'Modelo Coelo de robótica.',
                'scope_kind': 'institution',
                'institution_id': 'institution-1',
                'governance_kind': 'mandatory',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final options = await SupabaseActivityDirectoryRepository(
      client,
    ).fetchTemplateOptions(institutionId: 'institution-1');

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_options'));
    expect(body['p_institution_id'], 'institution-1');
    expect(
      options.templates.single,
      isA<ActivityTemplateOption>()
          .having((item) => item.id, 'id', 'template-robotics')
          .having((item) => item.name, 'name', 'Robótica')
          .having((item) => item.taxonomyId, 'taxonomyId', 'taxonomy-science')
          .having((item) => item.subtypeId, 'subtypeId', 'subtype-robotics')
          .having((item) => item.description, 'description', 'Modelo Coelo de robótica.')
          .having((item) => item.scopeKind, 'scopeKind', ActivityTemplateScopeKind.institution)
          .having((item) => item.institutionId, 'institutionId', 'institution-1')
          .having((item) => item.governance, 'governance', ActivityGovernance.mandatory),
    );
  });

  test('loads the global catalog through the relation-free template RPC', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'institutions': <Object?>[],
            'taxonomy': <Object?>[],
            'templates': [
              {
                'id': 'template-platform',
                'name': 'Inglês',
                'description': 'Modelo Coelo.',
                'scope_kind': 'platform',
                'institution_id': null,
                'governance_kind': 'optional',
                'taxonomy_id': 'taxonomy-languages',
                'subtype_id': null,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final options = await SupabaseActivityDirectoryRepository(client).fetchTemplateOptions();

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_options'));
    expect(body['p_institution_id'], isNull);
    expect(options.templates.single.scopeKind, ActivityTemplateScopeKind.platform);
    expect(options.templates.single.institutionId, isNull);
  });

  test('maps PostgREST authorization errors', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          '{"code":"42501","message":"permission denied","details":null,"hint":null}',
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseActivityDirectoryRepository(client).fetchFilterOptions(),
      throwsA(isA<ActivityDirectoryUnauthorizedException>()),
    );
  });

  test('searches professionals by bound query without returning contact PII', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'items': [
              {
                'membership_id': 'membership-1',
                'person_id': 'person-1',
                'name': 'Marina Costa',
                'role': 'teacher',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityDirectoryRepository(
      client,
    ).searchProfessionals(institutionId: 'institution-1', query: '@marina OR cpf', limit: 100);

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(captured!.url.path, endsWith('/rpc/superadmin_search_activity_professionals'));
    expect(body['p_institution_id'], 'institution-1');
    expect(body['p_query'], '@marina OR cpf');
    expect(body['p_limit'], 20);
    expect(result.single.id, 'membership-1');
    expect(result.single.name, 'Marina Costa');
    expect(result.single.role, 'teacher');
  });

  test('maps unsupported professional lookup to unavailable', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'code': '0A000',
            'message': 'lookup unavailable',
            'details': null,
            'hint': null,
          }),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseActivityDirectoryRepository(
        client,
      ).searchProfessionals(institutionId: 'institution-1', query: '123'),
      throwsA(isA<ActivityDirectoryUnavailableException>()),
    );
  });
}
