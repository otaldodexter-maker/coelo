import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares the clean health care route tree', () {
    expect(SuperadminRoutes.healthCareProfiles, '/health-care/profiles');
    expect(SuperadminRoutes.healthCareProfileCreate, '/health-care/profiles/new');
    expect(SuperadminRoutes.healthCareProfileDetail, '/health-care/profiles/:childId');
    expect(SuperadminRoutes.healthCareProfileEdit, '/health-care/profiles/:childId/edit');
    expect(SuperadminRoutes.healthMedicationPlans, '/health-care/medication-plans');
    expect(SuperadminRoutes.healthMedicationPlanCreate, '/health-care/medication-plans/new');
    expect(
      SuperadminRoutes.healthMedicationPlanDetail,
      '/health-care/medication-plans/:medicationId',
    );
    expect(
      SuperadminRoutes.healthMedicationPlanEdit,
      '/health-care/medication-plans/:medicationId/edit',
    );
  });

  testWidgets('exposes both Health and Care sibling destinations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'health-care-profiles',
          onDestinationSelected: selected.add,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sa\u00fade e Cuidado'), findsOneWidget);
    expect(find.text('Perfis de cuidado'), findsOneWidget);
    expect(find.text('Planos de medica\u00e7\u00e3o'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-navigation-health-medication-plans')));
    expect(selected, ['health-medication-plans']);
  });

  testWidgets('legacy production care profile detail fails closed before rendering a form', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go('/health-care/profiles/child-demo-a');
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/errors/mutation-capability-unavailable',
    );
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byType(HealthCareProfileFormPage), findsNothing);
  });

  testWidgets('medication plan production routes stay unavailable without repository calls', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingMedicationPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      medicationPlanRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final path in const [
      '/health-care/medication-plans',
      '/health-care/medication-plans/new',
      '/health-care/medication-plans/medication-demo-a',
      '/health-care/medication-plans/medication-demo-a/edit',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        path.endsWith('/new') || path.endsWith('/edit')
            ? '/errors/mutation-capability-unavailable'
            : path,
        reason: path,
      );
      expect(find.byType(SuperadminErrorScreen), findsOneWidget, reason: path);
      expect(
        tester.widget<SuperadminErrorScreen>(find.byType(SuperadminErrorScreen)).kind,
        SuperadminErrorKind.unavailable,
        reason: path,
      );
      expect(
        find.bySemanticsLabel('Erro 503. O Coelo está temporariamente indisponível.'),
        findsOneWidget,
        reason: path,
      );
      expect(find.byType(HealthMedicationPlanDirectoryPage), findsNothing, reason: path);
      expect(find.byType(HealthMedicationPlanFormPage), findsNothing, reason: path);
      expect(repository.calls, 0, reason: path);
    }
  });

  testWidgets('medication plan development routes remain demonstrative', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingMedicationPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      medicationPlanRepository: repository,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final routeCase in <({String path, String expectedPath, Type page})>[
      (
        path: '/dev/health-care/medication-plans',
        expectedPath: '/dev/health-care/medication-plans',
        page: HealthMedicationPlanDirectoryPage,
      ),
      (
        path: '/dev/health-care/medication-plans/new',
        expectedPath: '/dev/health-care/medication-plans/new',
        page: HealthMedicationPlanFormPage,
      ),
    ]) {
      router.go(routeCase.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        routeCase.expectedPath,
        reason: routeCase.path,
      );
      expect(find.byType(SuperadminErrorScreen), findsNothing, reason: routeCase.path);
      expect(find.byType(routeCase.page), findsOneWidget, reason: routeCase.path);
      expect(repository.calls, 0, reason: routeCase.path);
    }
  });

  testWidgets('development medication plan create persists locally without production calls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signIn();
    final productionTripwire = _TrackingMedicationPlanRepository();
    final developmentRepository = DevMedicationPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      medicationPlanRepository: productionTripwire,
      developmentMedicationPlanRepository: developmentRepository,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/dev/health-care/medication-plans/new');
    await tester.pumpAndSettle();

    expect(find.text('Criança Demo A'), findsOneWidget);
    FilledButton continueButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'));
    expect(continueButton().onPressed, isNull);
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(4);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar plano')).onPressed,
      isNull,
    );
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(0);
    await tester.pump();
    Finder field(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(TextFormField));
    await tester.enterText(field('Nome do medicamento'), 'Ibuprofeno');
    await tester.enterText(field('Dose'), '5');
    await tester.enterText(field('Unidade'), 'ml');
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
    for (var step = 0; step < 4; step++) {
      final continueButton = find.widgetWithText(FilledButton, 'Continuar');
      expect(continueButton, findsOneWidget, reason: 'step $step');
      await tester.tap(continueButton);
      await tester.pump();
    }
    expect(find.text('Revisão'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Criar plano'));
    await tester.pumpAndSettle();

    final saved = await developmentRepository.fetchPage(const MedicationPlanQuery());
    expect(saved.items, hasLength(1));
    expect(saved.items.single.childPersonId, 'child-demo-a');
    expect(saved.items.single.medicationName, 'Ibuprofeno');
    expect(saved.items.single.doseAmount, 5);
    expect(saved.items.single.doseUnit, 'ml');
    expect(saved.items.single.route, 'oral');
    expect(router.routeInformationProvider.value.uri.path, '/dev/health-care/medication-plans');
    expect(find.text('Ibuprofeno'), findsOneWidget);
    expect(find.textContaining('Contexto institucional indisponível'), findsOneWidget);
    expect(find.textContaining('Casa'), findsNothing);
    expect(find.text('Não foi possível carregar'), findsNothing);

    await tester.tap(find.text('Ibuprofeno').first);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/dev/health-care/medication-plans/${saved.items.single.id}/edit',
    );
    expect(find.byType(HealthMedicationPlanFormPage), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field('Nome do medicamento')).controller!.text,
      'Ibuprofeno',
    );
    expect(tester.widget<TextFormField>(field('Dose')).controller!.text, '5');
    expect(tester.widget<TextFormField>(field('Unidade')).controller!.text, 'ml');
    await tester.enterText(field('Nome do medicamento'), 'Ibuprofeno atualizado');
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(4);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();

    final updated = await developmentRepository.fetchPage(const MedicationPlanQuery());
    expect(updated.items, hasLength(1));
    expect(updated.items.single.version, 2);
    expect(updated.items.single.medicationName, 'Ibuprofeno atualizado');
    expect(router.routeInformationProvider.value.uri.path, '/dev/health-care/medication-plans');
    expect(find.text('Ibuprofeno atualizado'), findsOneWidget);
    expect(productionTripwire.calls, 0);
  });

  testWidgets('care profile fixtures are injected only by development routes', (tester) async {
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go('/health-care/profiles/new');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/errors/mutation-capability-unavailable',
    );
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('health-care-profile-form-unavailable')), findsNothing);

    router.go('/dev/health-care/profiles/new');
    await tester.pumpAndSettle();
    expect(find.byType(HealthCareProfileFormPage), findsOneWidget);
    expect(find.byKey(const Key('health-care-profile-form-unavailable')), findsNothing);
  });

  testWidgets('development create routes keep canonical wizards inside one responsive shell', (
    tester,
  ) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingMedicationPlanRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      medicationPlanRepository: repository,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final routeCase in <({String path, Type page})>[
      (path: '/dev/health-care/profiles/new', page: HealthCareProfileFormPage),
      (path: '/dev/health-care/medication-plans/new', page: HealthMedicationPlanFormPage),
    ]) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        router.go(routeCase.path);
        await tester.pumpWidget(
          MaterialApp.router(
            key: ValueKey('${routeCase.path}-$width'),
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
          reason: '$routeCase $width',
        );
        expect(content, findsOneWidget, reason: '$routeCase $width');
        expect(
          find.descendant(of: content, matching: find.byType(routeCase.page)),
          findsOneWidget,
          reason: '$routeCase $width',
        );
        expect(find.byType(SuperadminFormFrame), findsOneWidget, reason: '$routeCase $width');
        expect(
          find.byType(SuperadminFormStepNavigation),
          findsOneWidget,
          reason: '$routeCase $width',
        );
        expect(
          find.byType(SuperadminFormActionFooter),
          findsOneWidget,
          reason: '$routeCase $width',
        );
        await _expectInputsInsideViewport(tester, width, reason: '$routeCase $width');
        expect(tester.takeException(), isNull, reason: '$routeCase $width');
        expect(repository.calls, 0, reason: '$routeCase $width');
      }
    }
  });

  test('router source wires directories and forms without detail pages', () {
    final source = File('lib/app/router/superadmin_router.dart').readAsStringSync();

    for (final routeName in [
      'healthCareProfilesName',
      'healthCareProfileCreateName',
      'healthCareProfileDetailName',
      'healthCareProfileEditName',
      'healthMedicationPlansName',
      'healthMedicationPlanCreateName',
      'healthMedicationPlanDetailName',
      'healthMedicationPlanEditName',
    ]) {
      expect(source, contains('SuperadminRoutes.$routeName'));
    }
    for (final page in [
      'HealthCareProfileDirectoryPage',
      'HealthCareProfileFormPage',
      'HealthMedicationPlanDirectoryPage',
      'HealthMedicationPlanFormPage',
    ]) {
      expect(source, contains(page));
    }
    expect(source, isNot(contains('HealthCareProfileDetailPage')));
    expect(source, isNot(contains('HealthMedicationPlanDetailPage')));
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

final class _TrackingMedicationPlanRepository implements MedicationPlanRepository {
  var calls = 0;

  Never _unexpectedCall() {
    calls += 1;
    throw StateError('MedicationPlanRepository must stay unused while fail-closed.');
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async => _unexpectedCall();

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async => _unexpectedCall();

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async => _unexpectedCall();
}
