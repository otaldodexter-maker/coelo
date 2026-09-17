import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// R15 (owner.r12-38): `meal_plan_get` devolve a imagem simples em
// `simpleImageMeta` (`{}` sem imagem) e `meal_plan_create_or_update_draft`
// persiste `simpleImageMeta`; o front nao pode depender apenas de `simpleImage`.
void main() {
  test('meal plan read maps simpleImageMeta from the backend', () {
    final plan = MealPlan.fromJson(const {
      'id': 'meal-plan-1',
      'status': 'draft',
      'simpleImageMeta': {'kind': 'image', 'title': 'capa.png', 'reference': 'asset-1'},
    });
    expect(plan.simpleImage?.reference, 'asset-1');
    expect(plan.simpleImage?.title, 'capa.png');
  });

  test('empty simpleImageMeta means no image', () {
    expect(
      MealPlan.fromJson(const {'id': 'meal-plan-1', 'status': 'draft', 'simpleImageMeta': {}}).simpleImage,
      isNull,
    );
    expect(
      MealPlan.fromJson(const {
        'id': 'meal-plan-1',
        'status': 'draft',
        'simpleImageMeta': {'kind': 'image', 'title': '', 'reference': ''},
      }).simpleImage,
      isNull,
    );
  });

  test('legacy simpleImage key still decodes', () {
    final plan = MealPlan.fromJson(const {
      'id': 'meal-plan-1',
      'status': 'draft',
      'simpleImage': {'kind': 'image', 'title': 'capa.png', 'reference': 'asset-2'},
    });
    expect(plan.simpleImage?.reference, 'asset-2');
  });

  test('draft payload carries simpleImageMeta for the backend and {} when removed', () {
    MealPlanDraft draft({MealPlanAttachmentMeta? image}) => MealPlanDraft(
      requestId: 'req',
      tenantId: 'tenant',
      name: 'Cardápio',
      sourceType: MealPlanSourceType.institution,
      scopeLevel: MealPlanScopeLevel.institution,
      scopeId: 'institution',
      startDate: DateTime(2026, 9, 17),
      endDate: DateTime(2026, 9, 23),
      recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.weekly),
      menu: const [],
      priority: 0,
      expectedRevision: 1,
      simpleImage: image,
    );

    final withImage = draft(
      image: const MealPlanAttachmentMeta(kind: 'image', title: 'capa.png', reference: 'asset-1'),
    ).toJson();
    expect(withImage['simpleImageMeta'], {'kind': 'image', 'title': 'capa.png', 'reference': 'asset-1'});
    expect(withImage['simpleImage'], withImage['simpleImageMeta']);

    final withoutImage = draft().toJson();
    expect(withoutImage['simpleImageMeta'], isEmpty);
    expect(withoutImage['simpleImage'], isNull);
  });
}
