import 'dart:convert';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('serializes generated request id and calendar dates exactly', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode({'id': 'meal-plan-1'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final before = DateTime.now().microsecondsSinceEpoch;
    final draft = _draft();
    await SupabaseMealPlanRepository(client).createOrUpdateDraft(draft);
    final after = DateTime.now().microsecondsSinceEpoch;

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final requestId = body['p_request_id'] as String;
    final compact = requestId.replaceAll('-', '');
    expect(
      requestId,
      '${compact.substring(0, 8)}-${compact.substring(8, 12)}-'
      '${compact.substring(12, 16)}-${compact.substring(16, 20)}-'
      '${compact.substring(20, 32)}',
    );
    final generatedAt = int.parse(compact, radix: 16);
    expect(generatedAt, inInclusiveRange(before, after));

    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['startDate'], '2026-08-06');
    expect(payload['endDate'], '2026-08-31');
    expect(payload['recurrence'], {
      'kind': 'specificDates',
      'intervalWeeks': null,
      'singleWeekStart': '2026-08-07',
      'singleWeekEnd': '2026-08-30',
      'cycleWeeks': null,
      'weekdays': <int>[],
      'specificDates': ['2026-08-08'],
      'excludedDates': ['2026-08-09'],
    });
  });
}

MealPlanDraft _draft() => MealPlanDraft(
  tenantId: 'tenant-1',
  name: 'Cardápio de agosto',
  sourceType: MealPlanSourceType.institution,
  scopeLevel: MealPlanScopeLevel.institution,
  scopeId: 'institution-1',
  startDate: DateTime.utc(2026, 8, 6, 23, 59, 58),
  endDate: DateTime.utc(2026, 8, 31, 1, 2, 3),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.specificDates,
    singleWeekStart: DateTime.utc(2026, 8, 7, 12),
    singleWeekEnd: DateTime.utc(2026, 8, 30, 12),
    specificDates: [DateTime.utc(2026, 8, 8, 12)],
    excludedDates: [DateTime.utc(2026, 8, 9, 12)],
  ),
  menu: const [],
  priority: 0,
  expectedRevision: 0,
);
