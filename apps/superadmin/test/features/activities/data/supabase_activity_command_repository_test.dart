import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_pedagogical_configuration_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('saves an activity snapshot through one aggregate v2 RPC', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'ok': true,
            'data': {
              'activity_id': 'activity-created-1',
              'management_version': 6,
              'status': 'draft',
              'correlation_id': 'correlation-1',
              'replayed': false,
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).save(_saveCommand);

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_save_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], '8b200000-0000-4000-8000-000000000901');
    expect(body['p_activity_id'], isNull);
    expect(body['p_expected_version'], 0);
    expect(body['p_publish'], isFalse);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['institution_id'], 'institution-1');
    expect(payload['unit_ids'], ['unit-1']);
    expect(payload['group_ids'], <Object?>[]);
    expect(payload['capability_policies'], {
      'attendance': null,
      'chat': null,
      'happens': null,
      'moments': null,
      'now': null,
    });
    expect(result.activityId, 'activity-created-1');
    expect(result.managementVersion, 6);
    expect(result.status, ActivityStatus.draft);
  });

  test('accepts the disabled pedagogical draft emitted by the real form mapper', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'ok': true,
            'data': {
              'activity_id': 'activity-created-1',
              'management_version': 6,
              'status': 'draft',
              'correlation_id': 'correlation-1',
              'replayed': false,
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final command = _saveCommandWithPedagogical(
      const ActivityPedagogicalConfigurationDraft.disabled().toJson(),
    );

    await SupabaseActivityCommandRepository(client).save(command);

    expect(captured, isNotNull);
    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_save_v2'));
  });

  test('preserves explicit group participation and omits links for all mode', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'ok': true,
            'data': {
              'activity_id': 'activity-created-1',
              'management_version': 6,
              'status': 'draft',
              'correlation_id': 'correlation-1',
              'replayed': false,
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseActivityCommandRepository(client).save(_saveCommandWithParticipation);

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['group_participation'], {'group-all': 'all', 'group-selected': 'selected'});
    expect(payload['participants'], [
      {'group_id': 'group-selected', 'child_group_link_id': 'child-selected', 'belongs': true},
    ]);
  });

  test('fails closed when a selected group has no explicit participation mode', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requestCount++;
        return Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).save(_saveCommandMissingParticipation),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    expect(requestCount, 0);
  });

  test('rejects an edit response bound to another activity id', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'ok': true,
            'data': {
              'activity_id': 'activity-tampered',
              'management_version': 7,
              'status': 'draft',
              'correlation_id': 'correlation-tampered',
              'replayed': false,
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).save(_editSaveCommand),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
  });

  test('unsupported activity save variants fail closed before HTTP', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requestCount++;
        return Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseActivityCommandRepository(client);

    await expectLater(
      repository.save(_unsupportedSaveCommand),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      repository.copyTemplate(
        const ActivityTemplateCopyCommand(
          requestId: 'copy-1',
          templateId: 'template-1',
          institutionId: 'institution-1',
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      repository.createLocations(
        const ActivityLocationCommand(
          requestId: 'locations-1',
          institutionId: 'institution-1',
          unitIds: {'unit-1'},
          name: 'Piscina',
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    await expectLater(
      repository.requestExport(ActivityDirectoryQuery(), format: ActivityCommandExportFormat.csv),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );

    expect(requestCount, 0);
  });

  test('maps aggregate concurrency envelope without a second request', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requestCount++;
        return Response(
          jsonEncode({
            'ok': false,
            'data': null,
            'error': {
              'code': 'SAI_CONCURRENT_CHANGE',
              'message': 'O estado mudou.',
              'http_status': 409,
              'correlation_id': 'correlation-2',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).save(_saveCommand),
      throwsA(isA<ActivityCommandConflictException>()),
    );
    expect(requestCount, 1);
  });

  test('creates a unit-scoped model through the internal gateway', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'id': 'template-created-1',
            'institution_id': 'institution-1',
            'unit_id': 'unit-1',
            'name': 'Física',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).createTemplate(
      const ActivityTemplateCreateCommand(
        requestId: 'template-create-request-1',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        name: ' Física ',
        description: ' Ciências exatas ',
        taxonomyId: 'taxonomy-exact-sciences',
        governance: ActivityGovernance.mandatory,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_create_scoped_activity_template'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_unit_id'], 'unit-1');
    expect(body['p_name'], 'Física');
    expect(body['p_description'], 'Ciências exatas');
    expect(result.unitId, 'unit-1');
  });

  test('rejects a model response bound to another institution', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({
            'id': 'template-created-1',
            'institution_id': 'institution-tampered',
            'unit_id': 'unit-1',
            'name': 'Física',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseActivityCommandRepository(client).createTemplate(
        const ActivityTemplateCreateCommand(
          requestId: 'template-create-request-2',
          institutionId: 'institution-1',
          unitId: 'unit-1',
          name: 'Física',
          description: 'Ciências exatas',
          taxonomyId: 'taxonomy-exact-sciences',
          governance: ActivityGovernance.mandatory,
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
  });

  test('maps internal model authorization denial', () async {
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

    await expectLater(
      SupabaseActivityCommandRepository(client).createTemplate(
        const ActivityTemplateCreateCommand(
          requestId: 'create-1',
          institutionId: 'institution-1',
          name: 'Física',
          description: '',
          taxonomyId: 'taxonomy-1',
          governance: ActivityGovernance.optional,
        ),
      ),
      throwsA(isA<ActivityCommandUnauthorizedException>()),
    );
  });
}

const _saveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000901',
  intent: ActivityCommandIntent.saveDraft,
  name: 'Natação',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _unsupportedSaveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000902',
  intent: ActivityCommandIntent.saveDraft,
  name: 'Natacao',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.mandatory,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _saveCommandWithParticipation = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000904',
  intent: ActivityCommandIntent.saveDraft,
  name: 'Natacao',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {'group-selected', 'group-all'},
  groupParticipation: {
    'group-selected': ActivityParticipation.selected,
    'group-all': ActivityParticipation.all,
  },
  participants: [
    ActivityCommandParticipant(groupId: 'group-all', childGroupLinkId: 'child-all', belongs: true),
    ActivityCommandParticipant(
      groupId: 'group-selected',
      childGroupLinkId: 'child-selected',
      belongs: true,
    ),
  ],
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _saveCommandMissingParticipation = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000905',
  intent: ActivityCommandIntent.saveDraft,
  name: 'Natacao',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {'group-1'},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

const _editSaveCommand = ActivitySaveCommand(
  requestId: '8b200000-0000-4000-8000-000000000903',
  intent: ActivityCommandIntent.saveDraft,
  activityId: 'activity-expected',
  expectedVersion: 6,
  name: 'Natação',
  description: '',
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
  identity: ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'NA',
    color: '#D63C00',
    icon: 'activity',
  ),
);

ActivitySaveCommand _saveCommandWithPedagogical(Map<String, Object?> pedagogicalConfiguration) =>
    ActivitySaveCommand(
      requestId: _saveCommand.requestId,
      intent: _saveCommand.intent,
      name: _saveCommand.name,
      description: _saveCommand.description,
      taxonomyId: _saveCommand.taxonomyId,
      taxonomyOtherDescription: _saveCommand.taxonomyOtherDescription,
      governance: _saveCommand.governance,
      institutionId: _saveCommand.institutionId,
      unitIds: _saveCommand.unitIds,
      groupIds: _saveCommand.groupIds,
      assignments: _saveCommand.assignments,
      identity: _saveCommand.identity,
      pedagogicalConfiguration: pedagogicalConfiguration,
    );
