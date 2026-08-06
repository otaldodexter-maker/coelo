import 'dart:ui' show CheckedState, SemanticsAction;

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_directory_page.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_form_page.dart';
import 'package:coelo_superadmin/features/plans/presentation/widgets/plan_capability_matrix.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('directory uses cards, table, status filters and pagination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository();

    await tester.pumpWidget(_app(PlanDirectoryPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Arquivados'), findsOneWidget);
    expect(find.byType(SuperadminDirectoryViewToggle<PlanDirectoryView>), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);

    var pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.pageSize, 11);
    pagination.onPageSizeChanged!(20);
    await tester.pumpAndSettle();
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.pageSize, 20);

    await tester.tap(find.byKey(const Key('plan-directory-table-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-table')), findsOneWidget);
    expect(tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).pageSize, 8);
  });

  testWidgets('directory cards use the expandable semantic status indicator', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanDirectoryPage(repository: _repository())));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsNWidgets(4));
    expect(find.text('coelo-essential · Ativo'), findsNothing);
  });

  testWidgets(
    'archive confirmation keeps its required reason visible and mutates only when confirmed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _repository();

      await tester.pumpWidget(_app(PlanDirectoryPage(repository: repository)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações de Coelo Essencial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivar plano'));
      await tester.pumpAndSettle();

      expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
      await tester.tap(find.text('Arquivar'));
      await tester.pumpAndSettle();
      expect(find.text('Motivo obrigatório'), findsOneWidget);
      expect(repository.findById('coelo-essential')!.status, PlanStatus.active);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.findById('coelo-essential')!.status, PlanStatus.active);
    },
  );

  testWidgets('create uses four steps and only saves from review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.text('Identificação'), findsWidgets);
    expect(find.text('Salvar plano'), findsNothing);
    expect(find.text('Novo plano'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-form-content-column')),
        matching: find.byType(SuperadminFormActionFooter),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('plan-name-field')), 'Plano Local');
    await tester.enterText(find.byKey(const Key('plan-code-field')), 'plano-local');
    await tester.enterText(find.byKey(const Key('plan-description-field')), 'Descrição local.');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Capacidades incluídas'), findsWidgets);
  });

  testWidgets('capability matrix has canonical columns and individual and group selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();
    await _openCreateCapabilities(tester);

    expect(find.text('Capacidade'), findsOneWidget);
    expect(find.text('Incluído no plano'), findsOneWidget);
    expect(find.byType(CoeloAdminInteractiveCard), findsNothing);
    final matrix = find.byType(PlanCapabilityMatrix);
    expect(find.descendant(of: matrix, matching: find.text('Principal')), findsOneWidget);
    for (final action in const ['Ver', 'Editar', 'Excluir']) {
      expect(find.descendant(of: matrix, matching: find.text(action)), findsNothing);
    }
    expect(find.descendant(of: matrix, matching: find.text('Selecionar todas')), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const Key('plan-capability-column-capability'))).width,
      greaterThan(tester.getSize(find.byKey(const Key('plan-capability-column-inclusion'))).width),
    );

    final communicationRow = find.byKey(const Key('plan-capability-row-communication'));
    final adminGroup = find.byKey(const Key('plan-capability-group-admin-toggle'));
    final principalGroup = find.byKey(const Key('plan-capability-group-principal-toggle'));
    expect(communicationRow, findsOneWidget);
    expect(tester.widget<Checkbox>(adminGroup).value, isFalse);
    var principalSemantics = tester.getSemantics(
      find.byKey(const Key('plan-capability-group-principal-semantics')),
    );
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      principalSemantics.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(tester.widget<Checkbox>(principalGroup).value, isTrue);
    principalSemantics = tester.getSemantics(
      find.byKey(const Key('plan-capability-group-principal-semantics')),
    );
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      principalSemantics.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(tester.widget<Checkbox>(principalGroup).value, isFalse);
    var semantics = tester.getSemantics(communicationRow);
    expect(semantics.label, 'Comunicação, disponibilidade no plano');
    expect(semantics.flagsCollection.isChecked, CheckedState.isFalse);

    await tester.tap(communicationRow);
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.descendant(of: communicationRow, matching: find.byType(Checkbox)))
          .value,
      isTrue,
    );
    expect(tester.widget<Checkbox>(adminGroup).value, isNull);
    semantics = tester.getSemantics(communicationRow);
    expect(semantics.label, 'Comunicação, disponibilidade no plano');
    expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    expect(find.bySemanticsLabel('Comunicação, disponibilidade no plano'), findsOneWidget);
    var groupSemantics = tester.getSemantics(
      find.byKey(const Key('plan-capability-group-admin-semantics')),
    );
    expect(groupSemantics.label, 'Admin, seleção parcial. Selecionar todas');
    expect(groupSemantics.flagsCollection.isChecked, CheckedState.mixed);

    await tester.tap(adminGroup);
    await tester.pump();
    expect(tester.widget<Checkbox>(adminGroup).value, isTrue);
    expect(find.textContaining('de 6 incluídas'), findsOneWidget);
    groupSemantics = tester.getSemantics(
      find.byKey(const Key('plan-capability-group-admin-semantics')),
    );
    expect(groupSemantics.label, 'Admin, todas incluídas. Limpar grupo');
    expect(groupSemantics.flagsCollection.isChecked, CheckedState.isTrue);

    await tester.tap(adminGroup);
    await tester.pump();
    expect(tester.widget<Checkbox>(adminGroup).value, isFalse);
    groupSemantics = tester.getSemantics(
      find.byKey(const Key('plan-capability-group-admin-semantics')),
    );
    expect(groupSemantics.label, 'Admin, nenhuma incluída. Selecionar todas');
    expect(groupSemantics.flagsCollection.isChecked, CheckedState.isFalse);
    semanticsHandle.dispose();
  });

  testWidgets('capability row toggles with Space and Enter from its own focus node', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();
    await _openCreateCapabilities(tester);

    final focusTarget = find.byKey(const Key('plan-capability-row-communication-focus'));
    final detector = tester.widget<FocusableActionDetector>(focusTarget);
    detector.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    final row = find.byKey(const Key('plan-capability-row-communication'));
    expect(
      tester.widget<Checkbox>(find.descendant(of: row, matching: find.byType(Checkbox))).value,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<Checkbox>(find.descendant(of: row, matching: find.byType(Checkbox))).value,
      isFalse,
    );
  });

  testWidgets('capability matrix filters catalog and shows a no-results state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();
    await _openCreateCapabilities(tester);

    await tester.enterText(find.byKey(const Key('plan-capability-search')), 'Agenda');
    await tester.pump();
    expect(find.byKey(const Key('plan-capability-row-agenda')), findsOneWidget);
    expect(find.text('Comunicação'), findsNothing);

    await tester.enterText(find.byKey(const Key('plan-capability-search')), 'não existe');
    await tester.pump();
    expect(find.text('Nenhuma capacidade encontrada'), findsOneWidget);
    expect(find.text('Revise o termo pesquisado.'), findsOneWidget);
  });

  testWidgets('capability validation persists and future steps remain disabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();

    var navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps.map((step) => step.enabled), [true, false, false, false]);

    await _openCreateCapabilities(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('Selecione ao menos uma capacidade.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps[1].status, SuperadminFormStepStatus.error);
    expect(navigation.steps.map((step) => step.enabled), [true, true, false, false]);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Selecione ao menos uma capacidade.'), findsOneWidget);
    expect(find.text('Limites'), findsOneWidget);
    expect(find.byKey(const Key('plan-units-field')), findsNothing);
  });

  testWidgets('edit has linked institutions and a read-only stable code', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository();

    await tester.pumpWidget(
      _app(PlanFormPage(repository: repository, planId: repository.plans.first.id)),
    );
    await tester.pumpAndSettle();

    final code = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('plan-code-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(code.enabled, isFalse);
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<PlanStatus>>(
            find.byType(CoeloAdminSingleSelectField<PlanStatus>),
          )
          .enabled,
      isFalse,
    );
    expect(find.text('Instituições vinculadas'), findsOneWidget);
  });

  testWidgets('compact layout supports text at 200 percent without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: PlanFormPage(repository: _repository())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
  });

  testWidgets('directory distinguishes empty, no-results, error and unauthorized states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(PlanDirectoryPage(repository: _repository(state: PlanDataState.loading))),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_app(PlanDirectoryPage(repository: _repository(plans: const []))));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano cadastrado'), findsOneWidget);

    await tester.pumpWidget(_app(PlanDirectoryPage(repository: _repository())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'não existe');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano encontrado'), findsOneWidget);

    await tester.pumpWidget(
      _app(PlanDirectoryPage(repository: _repository(state: PlanDataState.error))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os planos'), findsOneWidget);

    await tester.pumpWidget(
      _app(PlanDirectoryPage(repository: _repository(state: PlanDataState.unauthorized))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  testWidgets('create completes review with an audit reason and saves once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository();
    var saved = 0;

    await tester.pumpWidget(_app(PlanFormPage(repository: repository, onSaved: () => saved += 1)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-name-field')), 'Plano Local');
    await tester.enterText(find.byKey(const Key('plan-code-field')), 'plano-local');
    await tester.enterText(find.byKey(const Key('plan-description-field')), 'Descrição local.');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Revisão'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('plan-audit-reason-field')),
      'Catálogo aprovado para demonstração.',
    );
    await tester.tap(find.text('Salvar plano'));
    await tester.pumpAndSettle();

    expect(saved, 1);
    expect(repository.findById('plano-local'), isNotNull);
  });

  testWidgets('review keeps an empty audit reason error until the field changes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();
    await _openCreateCapabilities(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar plano'));
    await tester.pump();

    expect(find.text('Informe o motivo de auditoria.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    var navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps.last.status, SuperadminFormStepStatus.error);

    await tester.enterText(
      find.byKey(const Key('plan-audit-reason-field')),
      'Catálogo revisado e aprovado.',
    );
    await tester.pump();

    expect(find.text('Informe o motivo de auditoria.'), findsNothing);
    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps.last.status, SuperadminFormStepStatus.current);
  });

  testWidgets('review revalidates identity and blocks an invalid save', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository();
    var saved = 0;

    await tester.pumpWidget(
      _app(
        PlanFormPage(
          repository: repository,
          planId: repository.plans.first.id,
          onSaved: () => saved += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Editar').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-name-field')), '');
    await tester.tap(find.byKey(const Key('step-revis-o')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-audit-reason-field')), 'Tentativa inválida.');
    await tester.tap(find.text('Salvar plano'));
    await tester.pumpAndSettle();

    expect(saved, 0);
    expect(find.byKey(const Key('plan-name-field')), findsOneWidget);
    expect(find.text('Campo obrigatório'), findsOneWidget);
  });

  testWidgets('capability matrix stacks at 375 with text at 200 percent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _repository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: PlanFormPage(repository: repository, planId: repository.plans.first.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Capacidades incluídas'), findsWidgets);
    final matrix = find.byType(PlanCapabilityMatrix);
    final communicationRow = find.byKey(const Key('plan-capability-row-communication'));
    expect(tester.getSize(communicationRow).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(find.descendant(of: communicationRow, matching: find.byType(Column)), findsWidgets);
    expect(
      find.descendant(
        of: matrix,
        matching: find.byWidgetPredicate(
          (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );
  });
}

FakePlanCatalogRepository _repository({
  PlanDataState state = PlanDataState.ready,
  List<PlanCatalog>? plans,
}) {
  final activity = SuperadminActivityController();
  return FakePlanCatalogRepository(
    store: SuperadminPrototypeStore(activityController: activity),
    state: state,
    plans: plans,
  );
}

Widget _app(Widget home) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: Scaffold(body: home),
);

Future<void> _openCreateCapabilities(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('plan-name-field')), 'Plano Local');
  await tester.enterText(find.byKey(const Key('plan-code-field')), 'plano-local');
  await tester.enterText(find.byKey(const Key('plan-description-field')), 'Descrição local.');
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}
