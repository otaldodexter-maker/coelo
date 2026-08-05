import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_directory_page.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
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

  testWidgets('create uses four steps and only saves from review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(PlanFormPage(repository: _repository())));
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.text('Identificação'), findsWidgets);
    expect(find.text('Salvar plano'), findsNothing);

    await tester.enterText(find.byKey(const Key('plan-name-field')), 'Plano Local');
    await tester.enterText(find.byKey(const Key('plan-code-field')), 'plano-local');
    await tester.enterText(find.byKey(const Key('plan-description-field')), 'Descrição local.');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Capacidades incluídas'), findsWidgets);
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
    await tester.enterText(find.byKey(const Key('plan-name-field')), '');
    await tester.tap(find.text('Revisão'));
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
