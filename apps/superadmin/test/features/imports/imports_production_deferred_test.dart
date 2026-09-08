import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('configured production scope cannot call the legacy import backend', () async {
    var backendCalls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      httpClient: MockClient((request) async {
        backendCalls++;
        return http.Response('{}', 500, request: request);
      }),
    );
    addTearDown(client.dispose);

    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'publishable-test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          client,
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              const UnavailableCoeloAuthGateway(),
    );
    addTearDown(scope.session.dispose);

    expect(scope.importRepository, isA<UnavailableImportRepository>());
    await expectLater(
      scope.importRepository.fetchPage(const ImportJobQuery()),
      throwsA(isA<ImportRepositoryUnavailableException>()),
    );
    expect(backendCalls, 0);
  });

  testWidgets('deferred import controls stay visible without reading or creating jobs', (
    tester,
  ) async {
    final repository = _DeferredImportRepository();
    var createCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(repository: repository, onNewImport: (_) => createCalls++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 0);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.text('Disponível depois do MVP'), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);

    await tester.tap(find.byType(CoeloAdminCreateAction));
    await tester.pumpAndSettle();

    expect(find.text('Disponível depois do MVP'), findsWidgets);
    expect(find.byKey(const Key('import-new-dialog')), findsNothing);
    expect(repository.calls, 0);
    expect(createCalls, 0);
  });
}

final class _DeferredImportRepository implements ImportRepository, ImportExecutionCapabilities {
  var calls = 0;

  @override
  Set<ImportEntity> get supportedImportEntities => const <ImportEntity>{};

  Never _unexpected() {
    calls++;
    throw StateError('Deferred imports must not call jobs or files.');
  }

  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) => _unexpected();

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) => _unexpected();

  @override
  Future<List<ImportJob>> fetchJobs() => _unexpected();

  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) => _unexpected();

  @override
  Future<ImportJob> update(ImportJob job) => _unexpected();
}
