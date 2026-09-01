import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('non-equivalent activity mutations fail closed before any legacy RPC', () async {
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
      repository.save(_saveCommand),
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
  requestId: 'save-1',
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
