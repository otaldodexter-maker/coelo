import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/forms/data/forms_directory_reader.dart';
import 'package:coelo_superadmin/features/forms/data/forms_editor_context.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_lifecycle_actions.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final path in ['/forms/new', '/forms/form-1/edit', '/forms/form-1']) {
    testWidgets('$path preserves the legacy boundary without directory reader calls', (
      tester,
    ) async {
      final session = SuperadminSession()..signInForTesting();
      final reader = _Reader();
      final legacy = _Legacy();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        formsApi: legacy,
        formsDirectoryReader: reader,
        onThemeModeChanged: (_) {},
      );
      addTearDown(session.dispose);
      addTearDown(router.dispose);
      router.go(path);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      if (path == '/forms/form-1') {
        expect(tester.widget<FormsOverviewPage>(find.byType(FormsOverviewPage)).api, same(legacy));
        expect(legacy.calls, contains('legacy-overview'));
      } else {
        expect(tester.widget<FormsEditorPage>(find.byType(FormsEditorPage)).api, same(legacy));
      }
      expect(reader.calls, 0);
      expect(legacy.calls, isNot(contains('legacy-list')));
      expect(tester.takeException(), isNull);
    });
  }
  for (final path in ['/forms', '/dev/forms']) {
    testWidgets('$path uses only its designated data source', (tester) async {
      final session = SuperadminSession()..signInForTesting();
      final reader = _Reader();
      final legacy = _Legacy();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        formsApi: legacy,
        formsDirectoryReader: reader,
        allowDevelopmentPreview: true,
        onThemeModeChanged: (_) {},
      );
      addTearDown(session.dispose);
      addTearDown(router.dispose);
      router.go(path);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      final directory = tester.widget<FormsDirectoryPage>(find.byType(FormsDirectoryPage));
      if (path == '/forms') {
        expect(directory.api, isNull);
        expect(directory.reader, same(reader));
        expect(find.text('Diretório interno sintético'), findsWidgets);
        expect(reader.calls, 1);
        for (final actions in tester.widgetList<FormsLifecycleActions>(
          find.byType(FormsLifecycleActions),
        )) {
          expect(actions.api, isNull);
          expect(actions.onManageSchedules, isNull);
          expect(actions.canManage, isFalse);
        }
      } else {
        expect(directory.reader, isNull);
        expect(directory.api, isNotNull);
        expect(reader.calls, 0);
        expect(find.text('Pesquisa anual das famílias'), findsWidgets);
      }
      expect(legacy.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing internal reader does not activate legacy list or People context', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final legacy = _Legacy();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: legacy,
      onThemeModeChanged: (_) {},
    );
    addTearDown(session.dispose);
    addTearDown(router.dispose);
    router.go('/forms');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(legacy.calls, isEmpty);
    expect(
      find.text('O serviço de Formulários não está disponível neste ambiente.'),
      findsOneWidget,
    );
  });

  testWidgets('unauthenticated deep link never reaches the reader', (tester) async {
    final session = SuperadminSession();
    final reader = _Reader();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsDirectoryReader: reader,
      onThemeModeChanged: (_) {},
    );
    addTearDown(session.dispose);
    addTearDown(router.dispose);
    router.go('/forms');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(FormsDirectoryPage), findsNothing);
    expect(reader.calls, 0);
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });

  testWidgets('SuperadminApp passes the reader to its normal router and reloads on reentry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = SuperadminSession()..signInForTesting();
    final reader = _Reader();
    final legacy = _Legacy();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      SuperadminApp(session: session, formsApi: legacy, formsDirectoryReader: reader),
    );
    await tester.pumpAndSettle();
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    router.go('/forms');
    await tester.pumpAndSettle();
    expect(find.text('Diretório interno sintético'), findsWidgets);
    router.go('/');
    await tester.pumpAndSettle();
    router.go('/forms');
    await tester.pumpAndSettle();
    expect(reader.calls, 2);
    expect(legacy.calls, isEmpty);
  });
}

final class _Reader implements FormsDirectoryReader {
  int calls = 0;
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    calls++;
    return FormCursorPage(
      items: [
        FormDirectoryItem(
          id: 'e0000000-0000-4000-8000-000000000001',
          title: 'Diretório interno sintético',
          kind: FormKind.form,
          status: FormStatus.draft,
          operationalStatus: FormOperationalStatus.draft,
          identityMode: FormIdentityMode.identified,
          updatedAt: DateTime(2026, 9, 7),
          managementVersion: 1,
        ),
      ],
      nextCursor: null,
    );
  }
}

final class _Legacy implements FormsApi, FormsEditorContextApi {
  final calls = <String>[];
  @override
  Future<FormEditorProjection> getEditor(String formId) async {
    calls.add('legacy-editor');
    throw const FormApiException(FormApiFailureKind.unavailable, 'Contrato legado preservado');
  }

  @override
  Future<FormOverview> getOverview(String formId) async {
    calls.add('legacy-overview');
    throw const FormApiException(FormApiFailureKind.unavailable, 'Contrato legado preservado');
  }

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    calls.add('legacy-list');
    return FormCursorPage(items: [], nextCursor: null);
  }

  @override
  Future<FormsEditorContext> getEditorContext() async {
    calls.add('People-context');
    return const FormsEditorContext(institutions: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
