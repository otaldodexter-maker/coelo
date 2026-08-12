import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('upsert sends typed contextual relationships and optimistic version', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'activity': {'id': 'activity-1', 'management_version': 4, 'status': 'active'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).save(
      ActivitySaveCommand(
        requestId: 'save-1',
        intent: ActivityCommandIntent.publish,
        activityId: 'activity-1',
        expectedVersion: 3,
        name: 'Natação',
        description: 'Treino',
        handleStem: 'natacao',
        taxonomyId: '11111111-1111-4111-8111-111111111111',
        taxonomyOtherDescription: '',
        governance: ActivityGovernance.optional,
        institutionId: 'institution-1',
        unitIds: const {'unit-1'},
        groupIds: const {'group-1'},
        participants: const [
          ActivityCommandParticipant(
            groupId: 'group-1',
            childGroupLinkId: 'child-group-link-1',
            belongs: true,
          ),
        ],
        assignments: const [
          ActivityCommandAssignment(
            groupId: 'group-1',
            membershipId: 'membership-1',
            role: ActivityCommandProfessionalRole.instructor,
            permissions: {
              'chat': ActivityProfessionalAccessLevel.both,
              'attendance': ActivityProfessionalAccessLevel.view,
            },
          ),
        ],
        identity: const ActivityCommandIdentity(
          kind: ActivityIdentityKind.initials,
          initials: 'NA',
          color: '#D63C00',
          icon: 'activity',
          preserveExisting: true,
        ),
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_upsert_activity'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['expected_version'], 3);
    expect(payload['group_ids'], ['group-1']);
    expect(payload['handle_stem'], 'natacao');
    expect(payload['participants'], [
      {'group_id': 'group-1', 'child_group_link_id': 'child-group-link-1', 'belongs': true},
    ]);
    expect(payload['professional_assignments'], [
      {
        'group_id': 'group-1',
        'membership_id': 'membership-1',
        'role': 'instructor',
        'capabilities': {'chat': 'both', 'attendance': 'view'},
      },
    ]);
    expect(payload, isNot(contains('assignments')));
    expect(payload, isNot(contains('location_id')));
    expect(payload, isNot(contains('group_participation')));
    expect(payload, isNot(contains('identity_storage_bucket')));
    expect(payload, isNot(contains('identity_storage_path')));
    expect(payload, isNot(contains('identity_mode')));
    expect(payload, isNot(contains('identity_initials')));
    expect(payload, isNot(contains('identity_color')));
    expect(payload, isNot(contains('identity_icon')));
    expect(result.managementVersion, 4);
  });

  test('creates locations for an explicitly authorized unit set', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode([
            {'id': 'location-1', 'unit_id': 'unit-1', 'name': 'Piscina'},
            {'id': 'location-2', 'unit_id': 'unit-2', 'name': 'Piscina'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).createLocations(
      const ActivityLocationCommand(
        requestId: 'locations-1',
        institutionId: 'institution-1',
        unitIds: {'unit-1', 'unit-2'},
        name: 'Piscina',
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_create_activity_locations'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_institution_id'], 'institution-1');
    expect(body['p_unit_ids'], containsAll(['unit-1', 'unit-2']));
    expect(result.map((item) => item.unitId), ['unit-1', 'unit-2']);
  });

  test('creates from a template in the same idempotent upsert', () async {
    Request? captured;
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        requestCount++;
        return Response(
          jsonEncode({
            'activity': {
              'id': 'activity-from-template',
              'management_version': 1,
              'status': 'draft',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).save(
      const ActivitySaveCommand(
        requestId: 'template-create-1',
        intent: ActivityCommandIntent.saveDraft,
        templateId: 'template-1',
        name: 'Robótica',
        description: '',
        taxonomyId: 'taxonomy-1',
        taxonomyOtherDescription: '',
        governance: ActivityGovernance.optional,
        institutionId: 'institution-1',
        unitIds: {'unit-1'},
        groupIds: {},
        assignments: [],
        identity: ActivityCommandIdentity(
          kind: ActivityIdentityKind.icon,
          initials: '',
          color: '#D63C00',
          icon: 'smart_toy',
        ),
      ),
    );

    expect(requestCount, 1);
    expect(captured!.url.path, endsWith('/rpc/superadmin_upsert_activity'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['template_id'], 'template-1');
    expect(payload['institution_id'], 'institution-1');
    expect(body['p_idempotency_key'], isA<String>());
    expect(result.activityId, 'activity-from-template');
  });

  test('copies a model into an authorized institution scope', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({
            'id': 'template-copy-1',
            'institution_id': 'institution-1',
            'name': 'Robótica (cópia)',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).copyTemplate(
      const ActivityTemplateCopyCommand(
        requestId: 'template-copy-request-1',
        templateId: 'template-1',
        institutionId: 'institution-1',
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_copy_activity_template'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_template_id'], 'template-1');
    expect(body['p_institution_id'], 'institution-1');
    expect(body['p_idempotency_key'], isA<String>());
    expect(result.id, 'template-copy-1');
    expect(result.institutionId, 'institution-1');
    expect(result.name, 'Robótica (cópia)');
  });

  test('persists before preparing and finalizing a private identity upload', () async {
    final calls = <String>[];
    Map<String, dynamic>? prepareBody;
    Map<String, dynamic>? finalizeBody;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/rpc/superadmin_upsert_activity')) {
          return Response(
            jsonEncode({
              'activity': {'id': 'activity-1', 'management_version': 1, 'status': 'draft'},
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/rpc/superadmin_prepare_activity_identity_upload')) {
          prepareBody = jsonDecode(request.body) as Map<String, dynamic>;
          return Response(
            jsonEncode({'bucket': 'coelo-identities', 'path': 'activities/activity-1/request.png'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'POST' && request.url.path.contains('/object/upload/sign/')) {
          return Response(
            jsonEncode({
              'url':
                  '/object/upload/sign/coelo-identities/activities/activity-1/request.png'
                  '?token=upload-token',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'PUT' && request.url.path.contains('/object/upload/sign/')) {
          return Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/rpc/superadmin_finalize_activity_identity_upload')) {
          finalizeBody = jsonDecode(request.body) as Map<String, dynamic>;
          return Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return Response('not found', 404, request: request);
      }),
    );
    addTearDown(client.dispose);

    await SupabaseActivityCommandRepository(client).save(
      ActivitySaveCommand(
        requestId: 'photo-save',
        intent: ActivityCommandIntent.saveDraft,
        name: 'Música',
        description: '',
        taxonomyId: '11111111-1111-4111-8111-111111111111',
        taxonomyOtherDescription: '',
        governance: ActivityGovernance.optional,
        institutionId: 'institution-1',
        unitIds: const {'unit-1'},
        groupIds: const {},
        assignments: const [],
        identity: ActivityCommandIdentity(
          kind: ActivityIdentityKind.image,
          initials: 'MU',
          color: '#D63C00',
          icon: 'music',
          imageName: 'music.png',
          imageBytes: Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );

    expect(calls[0], contains('superadmin_upsert_activity'));
    expect(calls[1], contains('superadmin_prepare_activity_identity_upload'));
    expect(calls.last, contains('superadmin_finalize_activity_identity_upload'));
    expect(finalizeBody!['p_checksum_sha256'], hasLength(64));
    expect(finalizeBody!['p_storage_path'], 'activities/activity-1/request.png');
    expect(finalizeBody!['p_mime_type'], 'image/png');
    expect(finalizeBody!['p_idempotency_key'], isNot(prepareBody!['p_idempotency_key']));
    expect(finalizeBody, isNot(contains('p_bucket')));
    expect(finalizeBody, isNot(contains('p_path')));
  });

  test('uses job_id and the exact export filter allowlist', () async {
    Request? rpcRequest;
    Request? workerRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/rpc/superadmin_request_activity_export')) {
          rpcRequest = request;
          return Response(
            jsonEncode({'job_id': 'job-1', 'state': 'PENDENTE'}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        workerRequest = request;
        return Response(
          jsonEncode({'download_url': 'https://download.example/activity.csv'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseActivityCommandRepository(client).requestExport(
      ActivityDirectoryQuery(
        search: 'música',
        institutionIds: {'institution-1'},
        unitIds: {'unit-1'},
        groupIds: {'group-1'},
      ),
      format: ActivityCommandExportFormat.csv,
    );

    final rpcBody = jsonDecode(rpcRequest!.body) as Map<String, dynamic>;
    expect(rpcBody['p_format'], 'csv');
    expect(rpcBody['p_filters'], {
      'search': 'música',
      'institution_ids': ['institution-1'],
      'unit_ids': ['unit-1'],
      'group_ids': ['group-1'],
      'statuses': <Object?>[],
      'origins': <Object?>[],
    });
    final workerBody = jsonDecode(workerRequest!.body) as Map<String, dynamic>;
    expect(workerBody, {'action': 'export', 'entity': 'activities', 'job_id': 'job-1'});
    expect(result.jobId, 'job-1');
  });

  test('unavailable repository fails closed for every mutation', () async {
    const repository = UnavailableActivityCommandRepository();
    expect(
      repository.copyTemplate(
        const ActivityTemplateCopyCommand(
          requestId: 'copy-1',
          templateId: 'template-1',
          institutionId: 'institution-1',
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    expect(
      repository.requestExport(ActivityDirectoryQuery(), format: ActivityCommandExportFormat.csv),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
  });
}
