import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// meal_plan_create_or_update_draft itera scopeRules com jsonb_array_elements:
// um objeto derruba a RPC ("cannot extract elements from an object", medido na
// rota real em 11/09). O cliente envia a lista e le lista ou mapa.
void main() {
  test('scopeRules vai como lista de regras por escopo', () {
    final rules = mealPlanScopeRulesList({
      'institutionIds': ['inst-1'],
      'unitIds': ['unit-1'],
      'groupIds': ['group-1'],
      'activityIds': <String>[],
      'includedPersonIds': ['person-1'],
      'excludedPersonIds': ['person-2'],
      'dynamicFutureMembership': true,
    }, institutionId: 'inst-1');

    expect(rules, [
      {'scopeLevel': 'institution', 'scopeId': 'inst-1', 'institutionId': 'inst-1', 'institutionId': 'inst-1'},
      {'scopeLevel': 'unit', 'scopeId': 'unit-1', 'institutionId': 'inst-1', 'unitId': 'unit-1'},
      {'scopeLevel': 'classLevel', 'scopeId': 'group-1', 'institutionId': 'inst-1', 'classId': 'group-1'},
      {'scopeLevel': 'person', 'scopeId': 'person-1', 'institutionId': 'inst-1', 'personId': 'person-1'},
    ]);
  });

  test('leitura aceita a lista gravada e o mapa antigo', () {
    final fromList = mealPlanScopeRulesMap([
      {'scopeLevel': 'institution', 'scopeId': 'inst-1', 'institutionId': 'inst-1'},
      {'scopeLevel': 'classLevel', 'scopeId': 'group-1', 'classId': 'group-1'},
    ]);
    expect(fromList['institutionIds'], ['inst-1']);
    expect(fromList['groupIds'], ['group-1']);
    expect(fromList['unitIds'], isEmpty);

    expect(mealPlanScopeRulesMap({'unitIds': ['u']}), {'unitIds': ['u']});
    expect(mealPlanScopeRulesMap(null), isEmpty);
  });
}
