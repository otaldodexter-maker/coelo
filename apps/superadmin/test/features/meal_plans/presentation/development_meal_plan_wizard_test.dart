import 'dart:async';

import 'package:coelo_superadmin/features/meal_plans/data/dev/development_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_wizard_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isTemplate in [false, true]) {
    testWidgets('dev ${isTemplate ? 'model' : 'meal plan'} opens in the canonical wizard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: DevelopmentMealPlanRepository(),
              imageRepository: const UnavailableMealPlanImageRepository(),
              tenantId: 'dev-tenant',
              imageSelectionEnabled: false,
              isTemplate: isTemplate,
              onSaved: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperadminFormFrame), findsOneWidget);
      expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
      expect(find.text('Revise esta etapa'), findsNothing);
      expect(
        tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage)).tenantId,
        'dev-tenant',
      );
      expect(
        tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage)).imageSelectionEnabled,
        isFalse,
      );
      expect(find.text(isTemplate ? 'Novo modelo de cardápio' : 'Novo cardápio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dev meal plan navigates back and persists review then publish locally', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DevelopmentMealPlanRepository();
    var savedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: repository,
            imageRepository: const UnavailableMealPlanImageRepository(),
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () => savedCount++,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Cardápio da primavera');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Colégio Coelo'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Arroz, feijão e salada');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Anterior'));
    await tester.pump();
    expect(find.text('Refeição 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
    await tester.pumpAndSettle();

    expect(savedCount, 1);
    final created = (await repository.fetchPage(
      const MealPlanListFilter(),
    )).items.singleWhere((item) => item.name == 'Cardápio da primavera');
    expect(created.status, MealPlanStatus.published);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal time picker follows dish name and details are multiline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: DevelopmentMealPlanRepository(),
            imageRepository: const UnavailableMealPlanImageRepository(),
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Cardápio com horário');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Colégio Coelo'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.text('Definir horário de início e fim'));
    await tester.pump();

    expect(find.byType(CoeloTimeField), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byType(CoeloTimeField).first).dy,
      greaterThan(tester.getTopLeft(find.byType(TextFormField).first).dy),
    );
    final details = tester.widget<CoeloFormTextField>(
      find.byWidgetPredicate(
        (widget) => widget is CoeloFormTextField && widget.labelText == 'Detalhes do prato',
      ),
    );
    expect(details.maxLines, greaterThan(1));

    await tester.tap(find.text('Selecionar hora').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsOneWidget);
  });

  testWidgets('route A cannot overwrite route B when meal plans load out of order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OrderedMealPlanRepository();

    Widget page(String id) => MaterialApp(
      home: Scaffold(
        body: MealPlanWizardPage(
          repository: repository,
          imageRepository: const UnavailableMealPlanImageRepository(),
          mealPlanId: id,
          tenantId: 'dev-tenant',
          imageSelectionEnabled: false,
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.pumpWidget(page('meal-a'));
    await tester.pump();
    await tester.pumpWidget(page('meal-b'));
    await tester.pump();

    expect(repository.requests.keys, contains('meal-b'));
    repository.requests['meal-b']!.complete(_plan('meal-b', 'Cardápio B'));
    await tester.pump();
    expect(find.text('Cardápio B'), findsOneWidget);

    repository.requests['meal-a']!.complete(_plan('meal-a', 'Cardápio A'));
    await tester.pump();
    expect(find.text('Cardápio B'), findsOneWidget);
    expect(find.text('Cardápio A'), findsNothing);
  });

  testWidgets('a pending save from route A cannot complete after swapping to route B', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _PendingMealPlanRepository();
    var savedCount = 0;

    Widget page(String? id) => MaterialApp(
      home: Scaffold(
        body: MealPlanWizardPage(
          repository: repository,
          imageRepository: const UnavailableMealPlanImageRepository(),
          mealPlanId: id,
          tenantId: 'dev-tenant',
          imageSelectionEnabled: false,
          onSaved: () => savedCount++,
          onCancel: () {},
        ),
      ),
    );

    await tester.pumpWidget(page(null));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cardápio A');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Colégio Coelo'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
    await tester.pump();

    await tester.pumpWidget(page('meal-b'));
    await tester.pump();
    repository.requests['meal-b']!.complete(_plan('meal-b', 'Cardápio B'));
    await tester.pump();
    repository.pendingSave.complete(_plan('meal-a', 'Cardápio A'));
    await tester.pump();

    expect(savedCount, 0);
    expect(repository.reviewCalls, 0);
    expect(repository.publishCalls, 0);
    expect(find.text('Cardápio B'), findsOneWidget);
    expect(find.text('Cardápio A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load fails closed when repository returns another meal plan id', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OrderedMealPlanRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: repository,
            imageRepository: const UnavailableMealPlanImageRepository(),
            mealPlanId: 'meal-a',
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    repository.requests['meal-a']!.complete(_plan('meal-b', 'Cardápio incorreto'));
    await tester.pump();

    expect(find.text('O cardápio solicitado não pôde ser validado.'), findsOneWidget);
    expect(find.text('Cardápio incorreto'), findsNothing);
  });
}

MealPlan _plan(String id, String name) => MealPlan(
  id: id,
  tenantId: 'dev-tenant',
  name: name,
  status: MealPlanStatus.draft,
  sourceType: MealPlanSourceType.global,
  scopeLevel: MealPlanScopeLevel.global,
  scopeId: 'dev-tenant',
  startDate: DateTime(2026, 8, 24),
  endDate: DateTime(2026, 8, 30),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.weekly,
    weekdays: const {1, 2, 3, 4, 5},
  ),
  menu: [MealPlanMenuEntry.empty()],
  allergens: const [],
  alerts: const [],
  attachments: const [],
  priority: 0,
  conflictState: false,
  revision: 1,
  isDraft: true,
  requiresReview: false,
  createdBy: 'dev',
  updatedBy: 'dev',
);

class _OrderedMealPlanRepository implements MealPlanRepository {
  final _delegate = DevelopmentMealPlanRepository();
  final requests = <String, Completer<MealPlan>>{};

  @override
  Future<MealPlan> getById(String id) => (requests[id] = Completer<MealPlan>()).future;

  @override
  Future<MealPlanAudienceOptions> fetchAudienceOptions() => _delegate.fetchAudienceOptions();

  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) =>
      _delegate.fetchTemplatePage(filter);

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) => _delegate.fetchPage(filter);

  @override
  Future<MealPlanTemplate> getTemplateById(String id) => _delegate.getTemplateById(id);

  @override
  Future<MealPlanTemplate> saveTemplate(MealPlanTemplateDraft draft, {required bool publish}) =>
      _delegate.saveTemplate(draft, publish: publish);

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) => _delegate.createOrUpdateDraft(draft);

  @override
  Future<MealPlan> submitForReview(String mealPlanId, String requestId, int expectedRevision) =>
      _delegate.submitForReview(mealPlanId, requestId, expectedRevision);

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) =>
      _delegate.publish(mealPlanId, requestId, expectedRevision);

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) => _delegate.checkConflicts(
    scopeLevel: scopeLevel,
    scopeId: scopeId,
    startDate: startDate,
    endDate: endDate,
    recurrence: recurrence,
    menu: menu,
  );

  @override
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft draft) =>
      _delegate.fetchEffectiveSnapshot(draft);
}

final class _PendingMealPlanRepository extends _OrderedMealPlanRepository {
  final pendingSave = Completer<MealPlan>();
  int reviewCalls = 0;
  int publishCalls = 0;

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) => pendingSave.future;

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async => const [];

  @override
  Future<MealPlan> submitForReview(
    String mealPlanId,
    String requestId,
    int expectedRevision,
  ) async {
    reviewCalls++;
    return _plan(mealPlanId, 'Cardápio A');
  }

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) async {
    publishCalls++;
    return _plan(mealPlanId, 'Cardápio A');
  }
}
