import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development import routes never use the production repository', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = _TripwireImportRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      importRepository: repository,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/dev/imports');
    await tester.pumpAndSettle();
    expect(repository.calls, 0);

    router.go('/dev/imports/new');
    await tester.pumpAndSettle();
    expect(find.text('Nova importação'), findsOneWidget);
    expect(repository.calls, 0);
  });
}

final class _TripwireImportRepository implements ImportRepository {
  var calls = 0;

  Future<T> _fail<T>() {
    calls++;
    return Future<T>.error(StateError('production import repository reached from /dev'));
  }

  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) => _fail();

  @override
  Future<List<ImportJob>> fetchJobs() => _fail();

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) => _fail();

  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) => _fail();

  @override
  Future<ImportJob> update(ImportJob job) => _fail();
}
