import 'dart:convert';

import 'package:coelo_superadmin/features/imports/data/supabase_import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lists jobs through the guarded import-export hub RPC', () async {
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
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final jobs = await SupabaseImportRepository(client).fetchJobs();

    expect(captured!.url.path, endsWith('/rpc/superadmin_list_import_export_jobs'));
    expect(jsonDecode(captured!.body), {'p_page_size': 100});
    expect(jobs.single.entity, ImportEntity.units);
    expect(jobs.single.status, ImportJobStatus.draft);
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
