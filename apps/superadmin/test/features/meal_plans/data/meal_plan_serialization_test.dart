import 'dart:convert';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('template canonical camelCase metadata wins over conflicting legacy aliases', () {
    final template = MealPlanTemplate.fromJson({
      'id': 'template-1',
      'tenantId': 'tenant-a',
      'tenant_id': 'tenant-b',
      'institutionId': 'institution-a',
      'institution_id': 'institution-b',
      'planVariant': 'simple',
      'plan_variant': 'complete',
      'audienceSegment': 'all',
      'audience_segment': 'students',
      'createdAt': '2026-08-01T10:00:00Z',
      'created_at': '2020-01-01T00:00:00Z',
      'updatedAt': '2026-09-01T11:00:00Z',
      'updated_at': '2020-01-01T00:00:00Z',
    });
    expect(template.tenantId, 'tenant-a');
    expect(template.institutionId, 'institution-a');
    expect(template.planVariant, MealPlanPlanVariant.simple);
    expect(template.audienceSegment, MealPlanAudienceSegment.all);
    expect(template.createdAt, DateTime.utc(2026, 8, 1, 10));
    expect(template.updatedAt, DateTime.utc(2026, 9, 1, 11));
  });
  for (final operation in ['list', 'get', 'save']) {
    for (final camelCase in [true, false]) {
      test('template $operation preserves RPC metadata camelCase=$camelCase', () async {
        final payload = <String, Object?>{
          'id': 'template-1',
          'name': 'Modelo sintético',
          'status': 'published',
          'version': 3,
          camelCase ? 'tenantId' : 'tenant_id': 'tenant-a',
          camelCase ? 'institutionId' : 'institution_id': 'institution-a',
          camelCase ? 'planVariant' : 'plan_variant': 'simple',
          camelCase ? 'audienceSegment' : 'audience_segment': 'staff',
          camelCase ? 'createdAt' : 'created_at': '2026-08-01T10:00:00Z',
          camelCase ? 'updatedAt' : 'updated_at': '2026-09-01T11:00:00Z',
          'payload': <String, Object?>{},
        };
        final client = SupabaseClient(
          'https://meal-plans.invalid',
          'test-anon-key',
          httpClient: MockClient((request) async {
            expect(request.url.pathSegments.last, 'meal_plan_template_$operation');
            return Response(
              jsonEncode(
                operation == 'list'
                    ? {
                        'items': [payload],
                        'total': 1,
                      }
                    : payload,
              ),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseMealPlanRepository(client);
        if (operation == 'list') {
          final item = (await repository.fetchTemplatePage(
            const MealPlanListFilter(),
          )).items.single;
          expect(item.tenantId, 'tenant-a');
          expect(item.institutionId, 'institution-a');
          expect(item.planVariant, MealPlanPlanVariant.simple);
          expect(item.audienceSegment, MealPlanAudienceSegment.staff);
          expect(item.startDate, DateTime.utc(2026, 8, 1, 10));
          expect(item.endDate, DateTime.utc(2026, 9, 1, 11));
        } else {
          final item = operation == 'get'
              ? await repository.getTemplateById('template-1')
              : await repository.saveTemplate(
                  const MealPlanTemplateDraft(
                    id: 'template-1',
                    name: 'Modelo sintético',
                    planVariant: MealPlanPlanVariant.simple,
                    audienceSegment: MealPlanAudienceSegment.staff,
                    payload: {},
                  ),
                  publish: true,
                );
          expect(item.tenantId, 'tenant-a');
          expect(item.institutionId, 'institution-a');
          expect(item.planVariant, MealPlanPlanVariant.simple);
          expect(item.audienceSegment, MealPlanAudienceSegment.staff);
          expect(item.createdAt, DateTime.utc(2026, 8, 1, 10));
          expect(item.updatedAt, DateTime.utc(2026, 9, 1, 11));
        }
      });
    }
  }
  for (final entry in {
    'published': MealPlanStatus.published,
    'active': MealPlanStatus.published,
    'draft': MealPlanStatus.draft,
    'archived': MealPlanStatus.archived,
  }.entries) {
    test('template directory preserves ${entry.key} status from RPC', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({
              'items': [
                {'id': 'template-1', 'name': 'Modelo', 'status': entry.key},
              ],
              'total': 1,
              'limit': 20,
              'offset': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final page = await SupabaseMealPlanRepository(
        client,
      ).fetchTemplatePage(const MealPlanListFilter());
      expect(page.items.single.status, entry.value);
      expect(page.items.single.isDraft, entry.key == 'draft');
      expect(page.items.single.isTemplate, isTrue);
    });
  }
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
