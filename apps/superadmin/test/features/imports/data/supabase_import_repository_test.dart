import 'dart:convert';

import 'package:coelo_superadmin/features/imports/data/supabase_import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lists jobs through the guarded server-side import-export hub RPC', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode(<String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'job_id': '1d4553c8-854e-4a7b-b981-ae3257f334ee',
                'domain': 'units',
                'direction': 'import',
                'format': 'csv',
                'state': 'PENDENTE',
                'created_at': '2026-08-12T12:00:00Z',
                'summary': const <String, Object?>{},
                'result': const <String, Object?>{},
              },
            ],
            'next_cursor': <String, String>{
              'created_at': '2026-08-12T12:00:00Z',
              'job_id': '1d4553c8-854e-4a7b-b981-ae3257f334ee',
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final page = await SupabaseImportRepository(client).fetchPage(
      const ImportJobQuery(pageSize: 100),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_list_import_export_jobs'));
    expect(jsonDecode(captured!.body), <String, Object?>{
      'p_domains': const <String>[],
      'p_states': const <String>[],
      'p_formats': const <String>[],
      'p_search': null,
      'p_created_from': null,
      'p_created_to': null,
      'p_before_created_at': null,
      'p_before_job_id': null,
      'p_page_size': 100,
    });
    expect(page.items.single.entity, ImportEntity.units);
    expect(
      jsonDecode(page.nextCursor!),
      <String, Object?>{
        'created_at': '2026-08-12T12:00:00Z',
        'job_id': '1d4553c8-854e-4a7b-b981-ae3257f334ee',
      },
    );
  });

  test('passes an opaque cursor back only as guarded keyset fields', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode(<String, Object?>{'items': const <Object?>[], 'next_cursor': null}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseImportRepository(client).fetchPage(
      const ImportJobQuery(
        cursor: '{"created_at":"2026-08-12T12:00:00Z","job_id":"1d4553c8-854e-4a7b-b981-ae3257f334ee"}',
      ),
    );

    expect(jsonDecode(captured!.body), containsPair('p_before_created_at', '2026-08-12T12:00:00Z'));
    expect(jsonDecode(captured!.body), containsPair('p_before_job_id', '1d4553c8-854e-4a7b-b981-ae3257f334ee'));
    expect(jsonDecode(captured!.body), isNot(contains('p_cursor')));
  });

  test('rejects unsupported domains before creating a job', () async {
    final client = SupabaseClient('https://example.supabase.co', 'publishable-key');
    addTearDown(client.dispose);
    await expectLater(
      SupabaseImportRepository(
        client,
      ).createDraft(entity: ImportEntity.institutions, strategy: ImportStrategy.createOnly),
      throwsA(isA<ImportRepositoryUnavailableException>()),
    );
  });
}
