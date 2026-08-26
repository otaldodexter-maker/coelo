import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/units/data/supabase_unit_backend_commands_gateway.dart';
import 'package:coelo_superadmin/features/units/domain/unit_backend_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps command RPCs and requires explicit transfer confirmation', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final name = request.url.pathSegments.last;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        switch (name) {
          case 'request_unit_type_for_superadmin':
            expect(body['p_description'], 'Laboratorio Maker');
            expect(body['p_context'], {'source': 'settings'});
            return _jsonResponse(request, {
              'request_id': body['p_request_id'],
              'institution_id': '11111111-1111-4111-8111-111111111111',
              'unit_id': body['p_unit_id'],
              'requested_description': body['p_description'],
              'context_json': body['p_context'],
              'status': 'pending',
            });
          case 'change_unit_handle_for_superadmin':
            expect(body['p_handle'], 'nova-unidade');
            expect(body['p_expected_version'], 4);
            return _jsonResponse(request, _unitPayload(handle: 'nova-unidade', version: 5));
          case 'preview_unit_institution_transfer_for_superadmin':
            expect(body['p_destination_institution_id'], '99999999-9999-4999-8999-999999999999');
            return _jsonResponse(request, {
              'unit_id': body['p_unit_id'],
              'source_institution_id': '11111111-1111-4111-8111-111111111111',
              'destination_institution_id': body['p_destination_institution_id'],
              'dependencies': {'groups': 2, 'invitations': 0},
              'incompatible_dependencies': ['groups'],
              'can_transfer': false,
            });
          case 'transfer_unit_institution_for_superadmin':
            expect(body['p_confirmed'], isTrue);
            expect(body['p_expected_version'], 5);
            return _jsonResponse(request, _unitPayload(handle: 'nova-unidade', version: 6));
          default:
            return _jsonResponse(request, {'message': 'unexpected RPC $name'}, statusCode: 500);
        }
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseUnitBackendCommandsGateway(client);

    final typeRequest = await gateway.requestUnitType(
      UnitTypeRequestCommand(
        requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        unitId: '22222222-2222-4222-8222-222222222222',
        description: 'Laboratorio Maker',
        context: const {'source': 'settings'},
      ),
    );
    expect(typeRequest.status, UnitTypeRequestStatus.pending);
    expect(typeRequest.context['source'], 'settings');

    final handleReceipt = await gateway.changeHandle(
      UnitHandleChangeCommand(
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        unitId: '22222222-2222-4222-8222-222222222222',
        expectedVersion: 4,
        requestedHandle: '@Nova-Unidade',
      ),
    );
    expect(handleReceipt.handle, 'nova-unidade');
    expect(handleReceipt.managementVersion, 5);

    final preview = await gateway.previewTransfer(
      UnitTransferPreviewRequest(
        unitId: '22222222-2222-4222-8222-222222222222',
        destinationInstitutionId: '99999999-9999-4999-8999-999999999999',
      ),
    );
    expect(preview.canTransfer, isFalse);
    expect(preview.dependencies['groups'], 2);

    await expectLater(
      gateway.transferInstitution(
        UnitTransferCommand(
          requestId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          unitId: '22222222-2222-4222-8222-222222222222',
          destinationInstitutionId: '99999999-9999-4999-8999-999999999999',
          expectedVersion: 5,
          confirmed: false,
        ),
      ),
      throwsA(
        isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.validation,
        ),
      ),
    );

    final transfer = await gateway.transferInstitution(
      UnitTransferCommand(
        requestId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        unitId: '22222222-2222-4222-8222-222222222222',
        destinationInstitutionId: '99999999-9999-4999-8999-999999999999',
        expectedVersion: 5,
        confirmed: true,
      ),
    );
    expect(transfer.institutionId, '11111111-1111-4111-8111-111111111111');
    expect(transfer.managementVersion, 6);
    expect(requests, hasLength(4));
  });

  test('maps identity intents and signed URL descriptors', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final name = request.url.pathSegments.last;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        switch (name) {
          case 'superadmin_prepare_unit_identity_upload':
            expect(body['p_kind'], 'profile');
            expect(body['p_mime_type'], 'image/png');
            expect(body['p_size_bytes'], 2048);
            return _jsonResponse(request, {
              'media_id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
              'bucket': unitIdentityStorageBucket,
              'upload_path':
                  'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.png',
              'expires_at': '2026-08-11T12:00:00Z',
            });
          case 'superadmin_finalize_unit_identity_upload':
            expect(
              body['p_checksum_sha256'],
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            );
            expect(body['p_replace_id'], 'ffffffff-ffff-4fff-8fff-ffffffffffff');
            return _jsonResponse(request, {
              'id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
              'institution_id': '11111111-1111-4111-8111-111111111111',
              'unit_id': '22222222-2222-4222-8222-222222222222',
              'media_kind': 'profile',
              'status': 'active',
              'storage_path':
                  'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.png',
              'mime_type': 'image/png',
              'size_bytes': 2048,
              'checksum_sha256': body['p_checksum_sha256'],
              'replaced_media_id': body['p_replace_id'],
              'activated_at': '2026-08-11T12:00:10Z',
              'cleanup_media_id': body['p_replace_id'],
              'cleanup_path':
                  'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/ffffffff-ffff-4fff-8fff-ffffffffffff.png',
            });
          case 'superadmin_request_unit_identity_delete':
            expect(body['p_media_id'], 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
            return _jsonResponse(request, {
              'media_id': body['p_media_id'],
              'bucket': unitIdentityStorageBucket,
              'delete_path':
                  'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.png',
            });
          case 'superadmin_confirm_unit_identity_delete':
            expect(body['p_media_id'], 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
            return _jsonResponse(request, {
              'id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
              'institution_id': '11111111-1111-4111-8111-111111111111',
              'unit_id': '22222222-2222-4222-8222-222222222222',
              'storage_path':
                  'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.png',
              'mime_type': 'image/png',
              'size_bytes': 2048,
              'status': 'deleted',
              'deleted_at': '2026-08-11T12:01:00Z',
            });
          case 'superadmin_unit_identity_download_descriptor':
            expect(body['p_media_id'], 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
            return _jsonResponse(request, {
              'media_id': body['p_media_id'],
              'bucket': unitIdentityStorageBucket,
              'path':
                  'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.png',
              'signed_url_ttl_seconds': 300,
            });
          default:
            return _jsonResponse(request, {'message': 'unexpected RPC $name'}, statusCode: 500);
        }
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseUnitBackendCommandsGateway(client);

    final prepared = await gateway.prepareIdentityUpload(
      UnitIdentityUploadIntentCommand(
        requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        unitId: '22222222-2222-4222-8222-222222222222',
        kind: UnitIdentityMediaKind.profile,
        mimeType: 'image/png',
        sizeBytes: 2048,
      ),
    );
    expect(prepared.bucket, unitIdentityStorageBucket);
    expect(prepared.path.kind, UnitIdentityMediaKind.profile);

    final finalized = await gateway.finalizeIdentityUpload(
      UnitIdentityFinalizeUploadCommand(
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        checksumSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        replaceMediaId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      ),
    );
    expect(finalized.status, UnitIdentityMediaStatus.active);
    expect(finalized.cleanupPath?.kind, UnitIdentityMediaKind.profile);

    final deleteRequest = await gateway.requestIdentityDelete(
      UnitIdentityDeleteCommand(
        requestId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        mediaId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      ),
    );
    expect(deleteRequest.path.kind, UnitIdentityMediaKind.profile);

    final deleted = await gateway.confirmIdentityDelete(
      mediaId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    );
    expect(deleted.status, UnitIdentityMediaStatus.deleted);

    final descriptor = await gateway.fetchIdentityDownloadDescriptor(
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    );
    expect(descriptor.signedUrlTtlSeconds, 300);
    expect(descriptor.path.kind, UnitIdentityMediaKind.profile);
  });

  test('uses authenticated Edge Functions for media and file operations', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final name = request.url.pathSegments.last;
        if (name == 'unit-identity') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['action'], anyOf('upload', 'delete'));
          return _jsonResponse(request, {
            'id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            'institution_id': '11111111-1111-4111-8111-111111111111',
            'unit_id': '22222222-2222-4222-8222-222222222222',
            'media_kind': 'profile',
            'status': body['action'] == 'delete' ? 'deleted' : 'active',
            'storage_path':
                'institutions/11111111-1111-4111-8111-111111111111/units/22222222-2222-4222-8222-222222222222/profile/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee.png',
            'mime_type': 'image/png',
            'size_bytes': 24,
            'checksum_sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'activated_at': '2026-08-11T12:00:10Z',
            'deleted_at': body['action'] == 'delete' ? '2026-08-11T12:01:00Z' : null,
          });
        }
        if (name == 'unit-import') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['action'], 'template');
          return _jsonResponse(request, {
            'file_name': 'modelo-unidades.csv',
            'mime_type': 'text/csv',
            'content_base64': base64Encode(utf8.encode('institution_id,name')),
          });
        }
        if (name == 'import-export-jobs') {
          if (request.headers['x-coelo-import-action'] == 'upload') {
            expect(
              request.headers['x-coelo-import-job-id'],
              '11111111-1111-4111-8111-111111111111',
            );
            expect(request.headers['content-type'], 'text/csv');
            expect(request.bodyBytes, utf8.encode('institution_id,name\n1,Centro'));
            return _jsonResponse(
              request,
              _unitFileJobPayload(
                jobId: '11111111-1111-4111-8111-111111111111',
                domain: 'units',
                format: 'csv',
                state: 'PROCESSANDO',
                summary: {'phase': 'preview', 'valid_count': 1, 'rejected_count': 0},
              ),
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['action'] == 'request_export') {
            expect(body['domain'], 'units');
            expect(body, isNot(contains('direction')));
            expect(body['idempotency_key'], 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
            return _jsonResponse(request, {
              'job_id': '22222222-2222-4222-8222-222222222222',
              'domain': 'units',
              'direction': 'export',
              'format': 'xlsx',
              'state': 'SUCESSO',
              'created_at': '2026-08-11T12:00:00Z',
              'started_at': '2026-08-11T12:00:05Z',
              'finished_at': '2026-08-11T12:00:30Z',
              'summary': {'phase': 'complete'},
            });
          }
          if (body['action'] == 'status') {
            expect(body['job_id'], '22222222-2222-4222-8222-222222222222');
            return _jsonResponse(request, {
              'job_id': '22222222-2222-4222-8222-222222222222',
              'domain': 'units',
              'direction': 'export',
              'format': 'xlsx',
              'state': 'SUCESSO',
              'created_at': '2026-08-11T12:00:00Z',
              'started_at': '2026-08-11T12:00:05Z',
              'finished_at': '2026-08-11T12:00:30Z',
              'summary': {'phase': 'complete'},
            });
          }
          if (body['action'] == 'download') {
            expect(body['job_id'], '22222222-2222-4222-8222-222222222222');
            return _jsonResponse(request, {
              'job_id': '22222222-2222-4222-8222-222222222222',
              'domain': 'units',
              'direction': 'export',
              'format': 'xlsx',
              'state': 'SUCESSO',
              'created_at': '2026-08-11T12:00:00Z',
              'started_at': '2026-08-11T12:00:05Z',
              'finished_at': '2026-08-11T12:00:30Z',
              'summary': {'phase': 'complete'},
              'download_url':
                  'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.xlsx?token=signed-token',
              'expires_in': 300,
            });
          }
          expect(body['action'], 'create_import');
          expect(body['idempotency_key'], 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
          return _jsonResponse(
            request,
            _unitFileJobPayload(
              jobId: '11111111-1111-4111-8111-111111111111',
              domain: 'units',
              format: 'csv',
              state: 'PENDENTE',
              summary: {'phase': 'created'},
            ),
          );
        }
        return _jsonResponse(request, {'message': 'unexpected endpoint'}, statusCode: 500);
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseUnitBackendCommandsGateway(client);

    final png = Uint8List.fromList(<int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      1,
      64,
      0,
      0,
      1,
      64,
    ]);
    final uploaded = await gateway.uploadIdentityMedia(
      command: UnitIdentityUploadIntentCommand(
        requestId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        unitId: '22222222-2222-4222-8222-222222222222',
        kind: UnitIdentityMediaKind.profile,
        mimeType: 'image/png',
        sizeBytes: png.length,
      ),
      bytes: png,
    );
    expect(uploaded.status, UnitIdentityMediaStatus.active);

    final deleted = await gateway.deleteIdentityMedia(
      command: const UnitIdentityDeleteCommand(
        requestId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        mediaId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      ),
    );
    expect(deleted.status, UnitIdentityMediaStatus.deleted);

    final template = await gateway.downloadImportTemplate(UnitFileFormat.csv);
    expect(utf8.decode(template.bytes), 'institution_id,name');

    final preview = await gateway.uploadImportPreview(
      requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      fileName: 'unidades.csv',
      mimeType: 'text/csv',
      bytes: Uint8List.fromList(utf8.encode('institution_id,name\n1,Centro')),
    );
    expect(preview.status, UnitFileJobStatus.processing);

    final download = await gateway.generateExport(
      UnitExportRequest(
        format: UnitFileFormat.xlsx,
        filters: const UnitExportFilters(),
        currentView: const UnitExportCurrentView(
          sort: UnitExportSortField.name,
          sortAscending: true,
          groupByInstitution: false,
          columns: ['name', 'unit_status'],
        ),
        idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ),
    );
    expect(download.job.status, UnitFileJobStatus.success);
    expect(download.url.host, 'example.supabase.co');

    expect(requests.where((request) => request.url.pathSegments.contains('functions')).length, 8);
  });

  test('uploads a unit import through canonical create and binary Edge calls', () async {
    final requests = <Request>[];
    final bytes = Uint8List.fromList(utf8.encode('institution_id,name\n1,Centro'));
    const requestId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const jobId = '11111111-1111-4111-8111-111111111111';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.url.pathSegments.last, 'import-export-jobs');
        if (requests.length == 1) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['action'], 'create_import');
          expect(body['domain'], 'units');
          expect(body['file_name'], 'unidades.csv');
          expect(body['mime_type'], 'text/csv');
          expect(body['source_format'], 'csv');
          expect(body['idempotency_key'], requestId);
          expect(body, isNot(contains('content_base64')));
          expect(body, isNot(containsValue('upload_preview')));
          return _jsonResponse(
            request,
            _unitFileJobPayload(
              jobId: jobId,
              domain: 'units',
              format: 'csv',
              state: 'PENDENTE',
              summary: const {'phase': 'created'},
            ),
          );
        }
        expect(request.headers['content-type'], 'text/csv');
        expect(request.headers['x-coelo-import-action'], 'upload');
        expect(request.headers['x-coelo-import-job-id'], jobId);
        expect(request.bodyBytes, bytes);
        return _jsonResponse(
          request,
          _unitFileJobPayload(
            jobId: jobId,
            domain: 'units',
            format: 'csv',
            state: 'PROCESSANDO',
            summary: const {'phase': 'preview', 'valid_count': 1, 'rejected_count': 0},
          ),
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseUnitBackendCommandsGateway(client).uploadImportPreview(
      requestId: requestId,
      fileName: ' unidades.csv ',
      mimeType: ' TEXT/CSV ',
      bytes: bytes,
      mapping: const {'name': 'name'},
    );

    expect(result.id, jobId);
    expect(result.status, UnitFileJobStatus.processing);
    expect(requests, hasLength(2));
  });

  test('does not upload when canonical import job creation fails', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return _jsonResponse(request, {'error': 'job_create_failed'}, statusCode: 500);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseUnitBackendCommandsGateway(client).uploadImportPreview(
        requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        fileName: 'unidades.csv',
        mimeType: 'text/csv',
        bytes: Uint8List.fromList(utf8.encode('institution_id,name\n1,Centro')),
      ),
      throwsA(
        isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.unavailable,
        ),
      ),
    );
    expect(requests, hasLength(1));
    expect(requests.single.url.pathSegments.last, 'import-export-jobs');
    expect((jsonDecode(requests.single.body) as Map<String, dynamic>)['action'], 'create_import');
  });

  test('maps a canonical binary upload failure to a safe gateway error', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return _jsonResponse(
            request,
            _unitFileJobPayload(
              jobId: '11111111-1111-4111-8111-111111111111',
              domain: 'units',
              format: 'csv',
              state: 'PENDENTE',
              summary: const {'phase': 'created'},
            ),
          );
        }
        return _jsonResponse(request, {'error': 'upload_failed'}, statusCode: 500);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseUnitBackendCommandsGateway(client).uploadImportPreview(
        requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        fileName: 'unidades.csv',
        mimeType: 'text/csv',
        bytes: Uint8List.fromList(utf8.encode('institution_id,name\n1,Centro')),
      ),
      throwsA(
        isA<UnitGatewayException>()
            .having((error) => error.code, 'code', UnitGatewayErrorCode.unavailable)
            .having((error) => error.operation, 'operation', 'import-export-jobs'),
      ),
    );
    expect(requests, hasLength(2));
  });

  test('rejects empty and oversized unit imports without network calls', () async {
    var requestCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requestCount += 1;
        return _jsonResponse(request, const <String, Object?>{});
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseUnitBackendCommandsGateway(client);

    for (final bytes in [Uint8List(0), Uint8List(unitIdentityMaxBytes + 1)]) {
      await expectLater(
        gateway.uploadImportPreview(
          requestId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          fileName: 'unidades.csv',
          mimeType: 'text/csv',
          bytes: bytes,
        ),
        throwsA(
          isA<UnitGatewayException>()
              .having((error) => error.code, 'code', UnitGatewayErrorCode.validation)
              .having((error) => error.operation, 'operation', 'import-export-jobs.upload'),
        ),
      );
    }
    expect(requestCount, 0);
  });

  group('hardens generated unit export downloads', () {
    test('requests export through the canonical import-export hub contract', () async {
      final captured = <Request>[];
      final gateway = _exportGateway(
        onRequest: captured.add,
        downloadUrl:
            'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
      );

      final download = await gateway.generateExport(_exportRequest());

      expect(captured, hasLength(3));
      expect(
        captured.map((request) => request.url.path),
        everyElement('/functions/v1/import-export-jobs'),
      );
      final requestBody = jsonDecode(captured.first.body) as Map<String, dynamic>;
      expect(requestBody, {
        'action': 'request_export',
        'domain': 'units',
        'idempotency_key': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'format': 'csv',
        'filters': _exportRequest().filters.toRpc(),
        'current_view': _exportRequest().currentView.toRpc(),
      });
      expect(
        requestBody['current_view'],
        containsPair('columns', const [
          'institution_name',
          'institution_type_name',
          'name',
          'unit_type_name',
          'unit_status',
          'effective_plan_name',
        ]),
      );
      expect(jsonEncode(requestBody), isNot(contains('storage_path')));
      expect(jsonEncode(requestBody), isNot(contains('checksum')));
      expect(jsonDecode(captured[1].body), {
        'action': 'status',
        'job_id': '22222222-2222-4222-8222-222222222222',
      });
      expect(jsonDecode(captured.last.body), {
        'action': 'download',
        'job_id': '22222222-2222-4222-8222-222222222222',
      });
      expect(download.job.status, UnitFileJobStatus.success);
      expect(download.expiresInSeconds, 300);
      expect(download.expiresAt, DateTime.utc(2026, 8, 26, 12, 5));
      expect(download.url.queryParameters['token'], 'signed-token');
    });

    test('rejects non-canonical export columns before any network call', () async {
      for (final column in <String>['status', 'unknown_column']) {
        var requestCount = 0;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          httpClient: MockClient((request) async {
            requestCount += 1;
            return _jsonResponse(request, const <String, Object?>{});
          }),
        );
        addTearDown(client.dispose);

        await expectLater(
          SupabaseUnitBackendCommandsGateway(
            client,
          ).generateExport(_exportRequest(columns: ['name', column])),
          throwsA(
            isA<UnitGatewayException>().having(
              (error) => error.code,
              'code',
              UnitGatewayErrorCode.validation,
            ),
          ),
          reason: column,
        );
        expect(requestCount, 0, reason: column);
      }
    });

    test('rejects unsafe or non-canonical export URLs', () async {
      const invalidUrls = <String>[
        'javascript:alert(1)',
        'file:///tmp/units.csv',
        'http://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://attacker.example/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://example.supabase.co:444/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://user@example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token#fragment',
        'https://example.supabase.co/storage/v1/object/sign/other/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/%2e%2e/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/99999999-9999-4999-8999-999999999999/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/not-an-artifact.csv?token=signed-token',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.xlsx?token=signed-token',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=one&token=two',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token&other=1',
        'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token&download=1&download=2',
      ];

      for (final downloadUrl in invalidUrls) {
        await expectLater(
          _exportGateway(downloadUrl: downloadUrl).generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.invalidDownloadUrl,
            ),
          ),
          reason: downloadUrl,
        );
      }
    });

    test('accepts one optional download query parameter', () async {
      final download = await _exportGateway(
        downloadUrl:
            'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token&download=units.csv',
      ).generateExport(_exportRequest());

      expect(download.url.queryParameters['download'], 'units.csv');
    });

    test('rejects response storage path or checksum fields instead of trusting them', () async {
      await expectLater(
        _exportGateway(
          responseOverrides: const {
            'storage_path': '../../other-tenant.csv',
            'checksum_sha256': 'not-a-checksum',
          },
        ).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.invalidResponse,
          ),
        ),
      );
    });

    test('does not request a download while the export job is not ready', () async {
      final captured = <Request>[];

      await expectLater(
        _exportGateway(
          state: 'PROCESSANDO',
          onRequest: captured.add,
        ).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.notReady,
          ),
        ),
      );

      expect(captured, hasLength(1));
      expect(jsonDecode(captured.single.body), containsPair('action', 'request_export'));
    });

    test('rejects an artifact returned during request_export', () async {
      await expectLater(
        _exportGateway(requestIncludesArtifact: true).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.invalidResponse,
          ),
        ),
      );
    });

    test('rejects a download response for a different job', () async {
      await expectLater(
        _exportGateway(
          downloadJobId: '99999999-9999-4999-8999-999999999999',
        ).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.invalidResponse,
          ),
        ),
      );
    });

    test('rejects a status response for a different job before download', () async {
      final captured = <Request>[];

      await expectLater(
        _exportGateway(
          statusJobId: '99999999-9999-4999-8999-999999999999',
          onRequest: captured.add,
        ).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.invalidResponse,
          ),
        ),
      );

      expect(captured, hasLength(2));
      expect(jsonDecode(captured.last.body), containsPair('action', 'status'));
    });

    test('rejects a download artifact leaked by the status response', () async {
      await expectLater(
        _exportGateway(statusIncludesArtifact: true).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.invalidResponse,
          ),
        ),
      );
    });

    test('does not download while the status response is not ready', () async {
      final captured = <Request>[];

      await expectLater(
        _exportGateway(
          statusState: 'PROCESSANDO',
          onRequest: captured.add,
        ).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.notReady,
          ),
        ),
      );

      expect(captured, hasLength(2));
      expect(jsonDecode(captured.last.body), containsPair('action', 'status'));
    });

    test('requires export TTL to be an exact integer from 1 to 300 seconds', () async {
      for (final expiresIn in <Object?>[null, 0, -1, 301, 1.5, '300']) {
        await expectLater(
          _exportGateway(expiresIn: expiresIn).generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.expired,
            ),
          ),
        );
      }
    });

    test('separates non-terminal and failed terminal export jobs', () async {
      for (final state in <String>['PENDENTE', 'PROCESSANDO']) {
        await expectLater(
          _exportGateway(state: state).generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.notReady,
            ),
          ),
          reason: state,
        );
      }
      for (final state in <String>['REJEICAO', 'ERRO']) {
        await expectLater(
          _exportGateway(state: state).generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.terminal,
            ),
          ),
          reason: state,
        );
      }
    });

    test('requires strict export job metadata before parsing the shared DTO', () async {
      final invalidCases = <SupabaseUnitBackendCommandsGateway>[
        _exportGateway(jobId: 'not-a-job-id'),
        _exportGateway(domain: 'units_export'),
        _exportGateway(direction: 'import'),
        _exportGateway(format: 'xlsx'),
        _exportGateway(state: 'UNKNOWN'),
        _exportGateway(createdAt: null),
        _exportGateway(createdAt: 'not-a-date'),
        _exportGateway(createdAt: '2026-08-26T09:00:00-03:00'),
      ];
      for (final gateway in invalidCases) {
        await expectLater(
          gateway.generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.invalidResponse,
            ),
          ),
        );
      }
    });

    test('maps malformed nested export job DTOs to invalidResponse', () async {
      const invalidNestedPayloads = <Map<String, Object?>>[
        {'summary': <Object?>[]},
        {'result': <String, Object?>{}},
        {'errors': <Object?>[]},
      ];

      for (final responseOverrides in invalidNestedPayloads) {
        await expectLater(
          _exportGateway(responseOverrides: responseOverrides).generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.invalidResponse,
            ),
          ),
          reason: '$responseOverrides',
        );
      }
    });

    test('maps export HTTP failures without changing import error handling', () async {
      final expectations = <int, Matcher>{
        400: isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.validation,
        ),
        401: isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.unauthorized,
        ),
        403: isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.unauthorized,
        ),
        404: isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.notFound,
        ),
        409: isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.conflict,
        ),
        410: isA<UnitExportException>().having(
          (error) => error.code,
          'code',
          UnitExportFailureCode.expired,
        ),
        422: isA<UnitGatewayException>().having(
          (error) => error.code,
          'code',
          UnitGatewayErrorCode.validation,
        ),
        503: isA<UnitGatewayException>()
            .having((error) => error.code, 'code', UnitGatewayErrorCode.unavailable)
            .having((error) => error.retriable, 'retriable', isTrue),
      };
      for (final MapEntry(key: status, value: matcher) in expectations.entries) {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          httpClient: MockClient(
            (request) async => _jsonResponse(request, {'error': 'denied'}, statusCode: status),
          ),
        );
        addTearDown(client.dispose);

        await expectLater(
          SupabaseUnitBackendCommandsGateway(client).generateExport(_exportRequest()),
          throwsA(matcher),
          reason: '$status',
        );
      }
    });

    test('maps malformed successful responses to typed invalidResponse', () async {
      for (final body in <Object?>[
        null,
        true,
        42,
        'scalar',
        const <Object?>[],
        {'error': 'malformed'},
        {'job_id': 1},
      ]) {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          httpClient: MockClient((request) async => _jsonResponse(request, body)),
        );
        addTearDown(client.dispose);

        await expectLater(
          SupabaseUnitBackendCommandsGateway(client).generateExport(_exportRequest()),
          throwsA(
            isA<UnitExportException>().having(
              (error) => error.code,
              'code',
              UnitExportFailureCode.invalidResponse,
            ),
          ),
        );
      }

      final malformedJsonClient = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            '{',
            200,
            headers: const {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(malformedJsonClient.dispose);
      await expectLater(
        SupabaseUnitBackendCommandsGateway(malformedJsonClient).generateExport(_exportRequest()),
        throwsA(
          isA<UnitExportException>().having(
            (error) => error.code,
            'code',
            UnitExportFailureCode.invalidResponse,
          ),
        ),
      );
    });
  });
}

SupabaseUnitBackendCommandsGateway _exportGateway({
  String downloadUrl =
      'https://example.supabase.co/storage/v1/object/sign/coelo-operations/exports/units/22222222-2222-4222-8222-222222222222/33333333-3333-4333-8333-333333333333.csv?token=signed-token',
  Object? expiresIn = 300,
  String state = 'SUCESSO',
  String? statusState,
  String jobId = '22222222-2222-4222-8222-222222222222',
  String? statusJobId,
  String domain = 'units',
  String direction = 'export',
  String format = 'csv',
  Object? createdAt = '2026-08-11T12:00:00Z',
  Map<String, Object?> responseOverrides = const {},
  bool requestIncludesArtifact = false,
  bool statusIncludesArtifact = false,
  String? downloadJobId,
  void Function(Request request)? onRequest,
}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient((request) async {
      onRequest?.call(request);
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      final isDownload = requestBody['action'] == 'download';
      final isStatus = requestBody['action'] == 'status';
      final responseState = isStatus ? (statusState ?? state) : state;
      final payload = <String, Object?>{
        'job_id': isDownload
            ? (downloadJobId ?? jobId)
            : isStatus
            ? (statusJobId ?? jobId)
            : jobId,
        'domain': domain,
        'direction': direction,
        'format': format,
        'state': responseState,
        'summary': const {'phase': 'complete'},
        'created_at': createdAt,
        'started_at': '2026-08-11T12:00:05Z',
        'finished_at': responseState == 'PENDENTE' || responseState == 'PROCESSANDO'
            ? null
            : '2026-08-11T12:00:30Z',
        ...responseOverrides,
      };
      if (isDownload ||
          (!isStatus && requestIncludesArtifact) ||
          (isStatus && statusIncludesArtifact)) {
        payload['download_url'] = downloadUrl;
        if (expiresIn != null) payload['expires_in'] = expiresIn;
      }
      return _jsonResponse(request, payload);
    }),
  );
  addTearDown(client.dispose);
  return SupabaseUnitBackendCommandsGateway(client, now: () => DateTime.utc(2026, 8, 26, 12));
}

UnitExportRequest _exportRequest({
  List<String> columns = const [
    'institution_name',
    'institution_type_name',
    'name',
    'unit_type_name',
    'unit_status',
    'effective_plan_name',
  ],
}) => UnitExportRequest(
  format: UnitFileFormat.csv,
  filters: const UnitExportFilters(),
  currentView: UnitExportCurrentView(
    sort: UnitExportSortField.name,
    sortAscending: true,
    groupByInstitution: false,
    columns: columns,
  ),
  idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
);

Response _jsonResponse(Request request, Object? body, {int statusCode = 200}) => Response(
  jsonEncode(body),
  statusCode,
  headers: const {'content-type': 'application/json'},
  request: request,
);

Map<String, dynamic> _unitPayload({required String handle, required int version}) => {
  'id': '22222222-2222-4222-8222-222222222222',
  'institution_id': '11111111-1111-4111-8111-111111111111',
  'institution_name': 'Instituicao Aurora',
  'name': 'Unidade Centro',
  'slug': 'unidade-centro',
  'unit_status': 'active',
  'institution_type': {'id': 'school', 'label': 'Escola'},
  'unit_type': {'id': 'campus', 'label': 'Campus', 'code': 'campus'},
  'address': const <String, Object?>{},
  'contact': const <String, Object?>{},
  'branding': const <String, Object?>{},
  'effective_plan': const <String, Object?>{},
  'inheritance': const <String, Object?>{},
  'public_profile': {
    'handle': handle,
    'discovery_enabled': true,
    'address_visible': false,
    'contact_visible': false,
  },
  'timezone': 'America/Sao_Paulo',
  'subtypes': const <Object?>[],
  'groups_count': 0,
  'activities_count': 0,
  'management_version': version,
};

Map<String, dynamic> _unitFileJobPayload({
  required String jobId,
  required String domain,
  required String format,
  required String state,
  required Map<String, Object?> summary,
  Map<String, Object?> result = const {
    'created_count': 0,
    'updated_count': 0,
    'ignored_count': 0,
    'rejected_count': 0,
  },
  List<Object?> errors = const [
    {
      'row_number': 1,
      'field': 'name',
      'code': 'invalid_identity',
      'message': 'Linha rejeitada pela validacao de Unidades.',
    },
  ],
}) => {
  'job_id': jobId,
  'institution_id': '11111111-1111-4111-8111-111111111111',
  'domain': domain,
  'format': format,
  'state': state,
  'summary': summary,
  'created_at': '2026-08-11T12:00:00Z',
  'started_at': '2026-08-11T12:00:05Z',
  'finished_at': state == 'PENDENTE' ? null : '2026-08-11T12:00:30Z',
  'result': result,
  'errors': errors,
};
