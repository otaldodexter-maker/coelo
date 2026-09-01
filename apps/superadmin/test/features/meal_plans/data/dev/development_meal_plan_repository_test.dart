import 'package:coelo_superadmin/features/meal_plans/data/dev/development_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships coherent realistic fixtures with useful pagination and relationships', () async {
    final repository = DevelopmentMealPlanRepository();

    final firstPage = await repository.fetchPage(const MealPlanListFilter(pageSize: 5));
    final therapy = await repository.fetchPage(
      const MealPlanListFilter(search: 'terapia ocupacional'),
    );
    final templates = await repository.fetchTemplatePage(const MealPlanListFilter());
    final audience = await repository.fetchAudienceOptions();

    expect(firstPage.total, greaterThanOrEqualTo(12));
    expect(firstPage.items, hasLength(5));
    expect(therapy.items.single.name, contains('Terapia ocupacional'));
    expect(therapy.items.single.personId, isNotNull);
    expect(templates.total, greaterThanOrEqualTo(5));
    expect(audience.institutions.map((item) => item.label), contains('Instituto Horizonte'));
    expect(audience.groups.map((item) => item.label), contains('Turma Girassol'));
  });

  test('provides dev-only audience data and keeps a locally saved draft', () async {
    final repository = DevelopmentMealPlanRepository();

    expect((await repository.fetchAudienceOptions()).institutions, isNotEmpty);

    final saved = await repository.createOrUpdateDraft(
      MealPlanDraft(
        requestId: 'create-draft',
        tenantId: 'dev-tenant',
        name: 'Cardápio de teste',
        sourceType: MealPlanSourceType.institution,
        scopeLevel: MealPlanScopeLevel.institution,
        scopeId: 'dev-institution',
        startDate: DateTime(2026, 8, 24),
        endDate: DateTime(2026, 8, 28),
        recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.weekly),
        menu: [MealPlanMenuEntry.empty()],
        priority: 0,
        expectedRevision: 0,
      ),
    );

    expect(saved.name, 'Cardápio de teste');
    expect((await repository.getById(saved.id)).name, 'Cardápio de teste');
    expect(
      (await repository.fetchPage(const MealPlanListFilter(pageSize: 100))).items,
      contains(saved),
    );
  });

  test('keeps templates separate from meal plans', () async {
    final repository = DevelopmentMealPlanRepository();
    final initialTotal = (await repository.fetchTemplatePage(const MealPlanListFilter())).total;
    final template = await repository.saveTemplate(
      const MealPlanTemplateDraft(
        requestId: 'create-template',
        name: 'Modelo local',
        planVariant: MealPlanPlanVariant.complete,
        audienceSegment: MealPlanAudienceSegment.students,
        payload: {},
      ),
      publish: false,
    );

    expect(template.status, 'draft');
    expect(await repository.getTemplateById(template.id), same(template));
    expect(
      (await repository.fetchTemplatePage(const MealPlanListFilter())).total,
      initialTotal + 1,
    );
  });

  test('deduplicates request ids and rejects stale revisions in the dev preview', () async {
    final repository = DevelopmentMealPlanRepository();
    final original = await repository.getById('dev-meal-plan');

    final published = await repository.publish(original.id, 'publish-once', original.revision);
    final duplicate = await repository.publish(original.id, 'publish-once', original.revision);

    expect(duplicate, same(published));
    expect(
      () => repository.submitForReview(original.id, 'stale-request', original.revision),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('save, review and publish require distinct global request ids', () async {
    final repository = DevelopmentMealPlanRepository();
    final saved = await repository.createOrUpdateDraft(
      MealPlanDraft(
        requestId: 'save-request',
        mealPlanId: 'dev-meal-plan',
        tenantId: 'dev-tenant',
        name: 'Cardápio revisado',
        sourceType: MealPlanSourceType.institution,
        scopeLevel: MealPlanScopeLevel.unit,
        scopeId: 'dev-unit',
        startDate: DateTime(2026, 8, 24),
        endDate: DateTime(2026, 8, 28),
        recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.weekly),
        menu: [MealPlanMenuEntry.empty()],
        priority: 0,
        expectedRevision: 1,
      ),
    );
    expect(
      () => repository.submitForReview(saved.id, 'save-request', saved.revision),
      throwsA(isA<MealPlanConflictException>()),
    );
    final reviewed = await repository.submitForReview(saved.id, 'review-request', saved.revision);
    final reviewedAgain = await repository.submitForReview(
      saved.id,
      'review-request',
      saved.revision,
    );
    final published = await repository.publish(reviewed.id, 'publish-request', reviewed.revision);
    final publishedAgain = await repository.publish(
      reviewed.id,
      'publish-request',
      reviewed.revision,
    );

    expect(reviewed.status, MealPlanStatus.inReview);
    expect(reviewedAgain, same(reviewed));
    expect(published.status, MealPlanStatus.published);
    expect(publishedAgain, same(published));
  });

  test('rejects stale template writes', () async {
    final repository = DevelopmentMealPlanRepository();

    expect(
      () => repository.saveTemplate(
        const MealPlanTemplateDraft(
          requestId: 'stale-template',
          id: 'dev-template',
          name: 'Versão stale',
          planVariant: MealPlanPlanVariant.complete,
          audienceSegment: MealPlanAudienceSegment.students,
          payload: {},
          expectedVersion: 0,
        ),
        publish: false,
      ),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('deduplicates template retries and rejects changed payloads', () async {
    final repository = DevelopmentMealPlanRepository();
    const draft = MealPlanTemplateDraft(
      requestId: 'template-retry',
      name: 'Modelo idempotente',
      planVariant: MealPlanPlanVariant.complete,
      audienceSegment: MealPlanAudienceSegment.students,
      payload: {},
    );
    final saved = await repository.saveTemplate(draft, publish: false);
    final retry = await repository.saveTemplate(draft, publish: false);

    expect(retry, same(saved));
    expect(
      () => repository.saveTemplate(
        const MealPlanTemplateDraft(
          requestId: 'template-retry',
          name: 'Payload diferente',
          planVariant: MealPlanPlanVariant.complete,
          audienceSegment: MealPlanAudienceSegment.students,
          payload: {},
        ),
        publish: false,
      ),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('rejects reusing a template request id for a meal plan', () async {
    final repository = DevelopmentMealPlanRepository();
    const requestId = 'template-then-plan';
    await repository.saveTemplate(
      const MealPlanTemplateDraft(
        requestId: requestId,
        name: 'Modelo local',
        planVariant: MealPlanPlanVariant.complete,
        audienceSegment: MealPlanAudienceSegment.students,
        payload: {},
      ),
      publish: false,
    );

    expect(
      () => repository.createOrUpdateDraft(
        _draft(requestId: requestId, name: 'Cardápio com intenção reutilizada'),
      ),
      throwsA(isA<MealPlanConflictException>()),
    );

    final reverseRepository = DevelopmentMealPlanRepository();
    await reverseRepository.createOrUpdateDraft(
      _draft(requestId: 'plan-then-template', name: 'Cardápio local'),
    );
    expect(
      () => reverseRepository.saveTemplate(
        const MealPlanTemplateDraft(
          requestId: 'plan-then-template',
          name: 'Modelo com intenção reutilizada',
          planVariant: MealPlanPlanVariant.complete,
          audienceSegment: MealPlanAudienceSegment.students,
          payload: {},
        ),
        publish: false,
      ),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('requires distinct request ids to save and publish a template', () async {
    final repository = DevelopmentMealPlanRepository();
    const draft = MealPlanTemplateDraft(
      requestId: 'template-save-and-publish',
      name: 'Modelo local',
      planVariant: MealPlanPlanVariant.complete,
      audienceSegment: MealPlanAudienceSegment.students,
      payload: {},
    );
    await repository.saveTemplate(draft, publish: false);

    expect(
      () => repository.saveTemplate(draft, publish: true),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('rejects reusing one save request id with another payload', () async {
    final repository = DevelopmentMealPlanRepository();
    await repository.createOrUpdateDraft(_draft(requestId: 'save-command', name: 'Primeiro'));

    expect(
      () =>
          repository.createOrUpdateDraft(_draft(requestId: 'save-command', name: 'Outro conteúdo')),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('detects overlapping meals and blocks review', () async {
    final repository = DevelopmentMealPlanRepository();
    final conflicts = await repository.checkConflicts(
      scopeLevel: MealPlanScopeLevel.unit.name,
      scopeId: 'dev-unit',
      startDate: DateTime(2026, 8, 24),
      endDate: DateTime(2026, 8, 28),
      recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.weekly),
      menu: [MealPlanMenuEntry(mealType: 'lunch')],
    );
    final saved = await repository.createOrUpdateDraft(
      _draft(requestId: 'conflicting-save', name: 'Cardápio conflitante', scopeId: 'dev-unit'),
    );

    expect(conflicts, hasLength(1));
    expect(saved.conflictState, isTrue);
    expect(
      () => repository.submitForReview(saved.id, 'blocked-review', saved.revision),
      throwsA(isA<MealPlanConflictException>()),
    );
  });

  test('rejects missing intent ids and updates for unknown resources', () async {
    final repository = DevelopmentMealPlanRepository();

    expect(
      () => repository.createOrUpdateDraft(_draft(requestId: '', name: 'Sem intenção')),
      throwsA(isA<MealPlanValidationException>()),
    );
    expect(
      () => repository.createOrUpdateDraft(_draft(requestId: null, name: 'Sem intenção')),
      throwsA(isA<MealPlanValidationException>()),
    );
    expect(
      () => repository.createOrUpdateDraft(
        MealPlanDraft(
          requestId: 'unknown-update',
          mealPlanId: 'missing-plan',
          tenantId: 'dev-tenant',
          name: 'Inexistente',
          sourceType: MealPlanSourceType.institution,
          scopeLevel: MealPlanScopeLevel.institution,
          scopeId: 'dev-institution',
          startDate: DateTime(2026, 8, 24),
          endDate: DateTime(2026, 8, 28),
          recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.weekly),
          menu: [MealPlanMenuEntry.empty()],
          priority: 0,
          expectedRevision: 0,
        ),
      ),
      throwsA(isA<MealPlanNotFoundException>()),
    );
    expect(
      () => repository.publish('dev-meal-plan', '', 1),
      throwsA(isA<MealPlanValidationException>()),
    );
  });
}

MealPlanDraft _draft({
  required String? requestId,
  required String name,
  String scopeId = 'dev-institution',
}) => MealPlanDraft(
  requestId: requestId,
  tenantId: 'dev-tenant',
  name: name,
  sourceType: MealPlanSourceType.institution,
  scopeLevel: scopeId == 'dev-unit' ? MealPlanScopeLevel.unit : MealPlanScopeLevel.institution,
  scopeId: scopeId,
  startDate: DateTime(2026, 8, 24),
  endDate: DateTime(2026, 8, 28),
  recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.weekly),
  menu: [MealPlanMenuEntry(mealType: 'lunch')],
  priority: 0,
  expectedRevision: 0,
);
