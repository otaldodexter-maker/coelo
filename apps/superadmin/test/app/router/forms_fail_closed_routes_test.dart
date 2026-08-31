import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const productionPaths = [
    '/forms/new',
    '/forms/form-1/edit',
    '/forms/form-1/test',
    '/forms/form-1/monitor',
    '/forms/form-1/occurrences/occurrence-1/respond',
    '/forms/form-1/responses',
    '/forms/form-1/responses/response-1',
  ];
  const developmentOperationPaths = [
    '/dev/forms/form-1/test',
    '/dev/forms/form-1/monitor',
    '/dev/forms/form-1/occurrences/occurrence-1/respond',
    '/dev/forms/form-1/responses',
    '/dev/forms/form-1/responses/response-1',
  ];
  const redirectedProductionPaths = <String>{};

  testWidgets('production routes preserve composition and remain fail-closed with zero API calls', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in productionPaths) {
      router.go(path);
      await tester.pumpAndSettle();

      if (redirectedProductionPaths.contains(path)) {
        expect(
          router.routeInformationProvider.value.uri.path,
          '/errors/mutation-capability-unavailable',
          reason: path,
        );
        expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      } else {
        expect(router.routeInformationProvider.value.uri.path, path, reason: path);
        expect(find.byType(SuperadminErrorScreen), findsNothing, reason: path);
        expect(find.textContaining('indisponível'), findsWidgets, reason: path);
      }
      expect(api.calls, 0, reason: path);
    }
  });

  testWidgets('development operation routes expose deterministic Flutter fixtures', (tester) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in developmentOperationPaths) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path, reason: path);
      expect(find.byType(SuperadminErrorScreen), findsNothing, reason: path);
      expect(find.byKey(const Key('forms-operations-unavailable')), findsNothing, reason: path);
      expect(api.calls, 0, reason: path);
    }
  });

  testWidgets('development create and edit routes open the isolated local editor', (tester) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in const ['/dev/forms/new', '/dev/forms/form-1/edit']) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, path, reason: path);
      expect(find.byType(FormsEditorPage), findsOneWidget, reason: path);
      expect(find.byKey(const Key('forms-editor-section-list')), findsOneWidget, reason: path);
      expect(find.byType(SuperadminErrorScreen), findsNothing, reason: path);
      expect(api.calls, 0, reason: path);
    }
  });

  testWidgets('development create route keeps the canonical wizard inside one responsive shell', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      router.go('/dev/forms/new');
      await tester.pumpWidget(
        MaterialApp.router(
          key: ValueKey(width),
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      final content = find.byKey(const Key('superadmin-content-transition'));
      expect(
        find.byKey(const Key('superadmin-persistent-shell')),
        findsOneWidget,
        reason: '$width',
      );
      expect(content, findsOneWidget, reason: '$width');
      expect(
        find.descendant(of: content, matching: find.byType(FormsEditorPage)),
        findsOneWidget,
        reason: '$width',
      );
      expect(find.byType(SuperadminFormFrame), findsOneWidget, reason: '$width');
      expect(find.byKey(const Key('forms-editor-section-list')), findsOneWidget, reason: '$width');
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget, reason: '$width');
      await _expectInputsInsideViewport(tester, width, reason: '$width');
      expect(tester.takeException(), isNull, reason: '$width');
      expect(api.calls, 0, reason: '$width');
    }
  });

  testWidgets('development directory and overview never read the production API', (tester) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in const ['/dev/forms', '/dev/forms/form-1']) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, path, reason: path);
      expect(api.calls, 0, reason: path);
      if (path.endsWith('form-1')) {
        expect(find.text('Fixture local · sem persistência remota'), findsOneWidget);
      } else {
        expect(find.textContaining('não est'), findsWidgets, reason: path);
      }
    }
  });

  testWidgets('development Forms routes remain guarded when preview is disabled', (tester) async {
    final session = SuperadminSession()..signIn();
    final api = _TripwireFormsApi();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: api,
      allowDevelopmentPreview: false,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/dev/forms/new');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, isNot('/dev/forms/new'));
    expect(api.calls, 0);
  });

  testWidgets('production directory reaches schedule dialog without faking integration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      formsApi: _DirectoryFormsApi(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/forms');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();
    expect(find.text('Agendamentos'), findsWidgets);
    expect(find.text('Duplicar'), findsNothing);

    await tester.tap(find.text('Agendamentos').last);
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    expect(
      find.text('A integração de agendamentos não está disponível neste ambiente.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar')).onPressed,
      isNull,
    );
  });
}

Future<void> _expectInputsInsideViewport(
  WidgetTester tester,
  double viewportWidth, {
  required String reason,
}) async {
  final inputWidgets = [
    ...find.byType(InputDecorator).evaluate().map((element) => element.widget),
    ...find.byType(EditableText).evaluate().map((element) => element.widget),
  ];
  expect(inputWidgets, isNotEmpty, reason: reason);
  for (final inputWidget in inputWidgets) {
    final input = find.byWidget(inputWidget);
    await tester.ensureVisible(input);
    await tester.pump();
    final rect = tester.getRect(input);
    expect(rect.width, greaterThan(0), reason: reason);
    expect(rect.height, greaterThan(0), reason: reason);
    expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
    expect(rect.right, lessThanOrEqualTo(viewportWidth), reason: reason);
    expect(rect.top, greaterThanOrEqualTo(0), reason: reason);
    expect(rect.bottom, lessThanOrEqualTo(1000), reason: reason);
  }
}

final class _TripwireFormsApi implements FormsApi {
  var calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls += 1;
    throw StateError('FormsApi must stay unused on fail-closed routes.');
  }
}

final class _DirectoryFormsApi implements FormsApi {
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async =>
      FormCursorPage(
        items: [
          FormDirectoryItem(
            id: 'form-1',
            title: 'Pesquisa das famílias',
            kind: FormKind.form,
            status: FormStatus.published,
            operationalStatus: FormOperationalStatus.scheduled,
            identityMode: FormIdentityMode.identified,
            audienceLabel: 'Famílias',
            scheduleCount: 1,
            updatedAt: DateTime(2026, 8, 31),
            managementVersion: 1,
          ),
        ],
        nextCursor: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
