import 'dart:convert';

import 'package:coelo_superadmin/features/activities/data/supabase_activity_command_repository.dart';
import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// spec 052 (ADR 0041 B1, owner.r12-02): Arquivar/Restaurar modelo de
/// atividade pelos comandos v1 e leitura do diretório v1 (todos os status,
/// `management_version`).
void main() {
  const templateId = '8b200000-0000-4000-8000-000000000601';
  const requestId = '8b200000-0000-4000-8000-000000000901';

  SupabaseClient client({
    required Map<String, Object?> Function(Request request) respond,
    int status = 200,
  }) => SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    httpClient: MockClient(
      (request) async => Response(
        jsonEncode(respond(request)),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );

  test('archive calls superadmin_activity_template_archive_v1 with expected_version', () async {
    Request? captured;
    final supabase = client(
      respond: (request) {
        captured = request;
        return {'id': templateId, 'status': 'archived', 'management_version': 3};
      },
    );
    addTearDown(supabase.dispose);

    final result = await SupabaseActivityCommandRepository(supabase).archiveTemplate(
      const ActivityTemplateLifecycleCommand(
        requestId: requestId,
        templateId: templateId,
        expectedVersion: 2,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_archive_v1'));
    expect(jsonDecode(captured!.body), {
      'p_template_id': templateId,
      'p_expected_version': 2,
      'p_idempotency_key': requestId,
    });
    expect(result.status, ActivityStatus.archived);
    expect(result.managementVersion, 3);
  });

  test('restore calls superadmin_activity_template_restore_v1', () async {
    Request? captured;
    final supabase = client(
      respond: (request) {
        captured = request;
        return {'id': templateId, 'status': 'active', 'management_version': 4};
      },
    );
    addTearDown(supabase.dispose);

    final result = await SupabaseActivityCommandRepository(supabase).restoreTemplate(
      const ActivityTemplateLifecycleCommand(
        requestId: requestId,
        templateId: templateId,
        expectedVersion: 3,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_restore_v1'));
    expect(result.status, ActivityStatus.active);
    expect(result.managementVersion, 4);
  });

  test('PT409, 55000, P0002 and 42501 map to their own failures', () async {
    for (final (code, matcher) in <(String, TypeMatcher<Object>)>[
      ('PT409', isA<ActivityCommandConflictException>()),
      ('55000', isA<ActivityCommandInvalidStateException>()),
      ('P0002', isA<ActivityCommandNotFoundException>()),
      ('42501', isA<ActivityCommandUnauthorizedException>()),
      ('XX000', isA<ActivityCommandUnavailableException>()),
    ]) {
      final supabase = client(
        status: 409,
        respond: (_) => {'code': code, 'message': 'recusado', 'details': null, 'hint': null},
      );
      addTearDown(supabase.dispose);
      await expectLater(
        SupabaseActivityCommandRepository(supabase).archiveTemplate(
          const ActivityTemplateLifecycleCommand(
            requestId: requestId,
            templateId: templateId,
            expectedVersion: 1,
          ),
        ),
        throwsA(matcher),
        reason: 'código $code',
      );
    }
  });

  test('a mismatched id in the response fails closed', () async {
    final supabase = client(
      respond: (_) => {'id': 'outro', 'status': 'archived', 'management_version': 1},
    );
    addTearDown(supabase.dispose);
    await expectLater(
      SupabaseActivityCommandRepository(supabase).archiveTemplate(
        const ActivityTemplateLifecycleCommand(
          requestId: requestId,
          templateId: templateId,
          expectedVersion: 0,
        ),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
  });

  test('the directory reader v1 returns archived templates with management_version', () async {
    Request? captured;
    final supabase = client(
      respond: (request) {
        captured = request;
        return {
          'institutions': [
            {'id': 'inst-1', 'name': 'Instituto'},
          ],
          'units': <Object?>[],
          'taxonomy': <Object?>[],
          'templates': [
            {
              'id': templateId,
              'name': 'Modelo arquivado',
              'description': null,
              'scope_kind': 'institution',
              'institution_id': 'inst-1',
              'unit_id': null,
              'governance_kind': 'optional',
              'taxonomy_id': 'tax-1',
              'subtype_id': 'sub-1',
              'status': 'archived',
              'management_version': 5,
            },
          ],
        };
      },
    );
    addTearDown(supabase.dispose);

    final options = await SupabaseActivityDirectoryRepository(
      supabase,
    ).fetchTemplateDirectory(institutionId: 'inst-1');

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_directory_v1'));
    expect(jsonDecode(captured!.body), {'p_institution_id': 'inst-1'});
    final template = options.templates.single;
    expect(template.isArchived, isTrue);
    expect(template.managementVersion, 5);
  });

  test('the options reader keeps its RPC and defaults management_version to 0', () async {
    Request? captured;
    final supabase = client(
      respond: (request) {
        captured = request;
        return {
          'institutions': <Object?>[],
          'units': <Object?>[],
          'taxonomy': <Object?>[],
          'templates': [
            {
              'id': templateId,
              'name': 'Modelo ativo',
              'scope_kind': 'platform',
              'governance_kind': 'optional',
              'taxonomy_id': 'tax-1',
              'status': 'active',
            },
          ],
        };
      },
    );
    addTearDown(supabase.dispose);

    final options = await SupabaseActivityDirectoryRepository(supabase).fetchTemplateOptions();

    expect(captured!.url.path, endsWith('/rpc/superadmin_activity_template_options'));
    expect(options.templates.single.managementVersion, 0);
    expect(options.templates.single.isArchived, isFalse);
  });
}
