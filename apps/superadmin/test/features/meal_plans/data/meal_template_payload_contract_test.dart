import 'dart:convert';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// RED candidate: mocks reproduce SQL 20260820160000 storing p_payload whole.
// No SQL or network is executed; no authorization or persistence is proved.
void main() {
  for (final entry in <String, Map<String, Object?>>{
    'mixed empty current': {'menu': <Object?>[], 'payload': _content},
    'mixed identical': {..._content, 'payload': _content},
    'colliding unknown': {'futureField': 'outer', 'payload': _content},
    'recursive': {
      'payload': {'payload': _content},
    },
    'recursive with recognized content': {
      'payload': {..._content, 'payload': _content},
    },
    'null wrapper': {'payload': null},
    'equal unknown collision': {'futureField': _content['futureField'], 'payload': _content},
    'non object': {'payload': 'invalid'},
    'unrecognized wrapper': {
      'payload': {'unknownOnly': true},
    },
  }.entries) {
    test('template refuses ambiguous stored payload: ${entry.key}', () {
      expect(
        () => MealPlanTemplate.fromJson({'id': 'template-a', 'payload': entry.value}),
        throwsA(isA<MealPlanUnavailableException>()),
      );
    });
  }

  test('empty flat template payload stays empty', () {
    expect(MealPlanTemplate.fromJson({'id': 'template-a', 'payload': {}}).payload, isEmpty);
  });

  test('content cannot replace RPC resource id or expected revision', () async {
    final client = SupabaseClient(
      'https://meal-plans.invalid',
      'test-anon-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['p_template_id'], 'template-a');
        expect(body['p_expected_version'], 2);
        expect(body['p_publish'], isFalse);
        expect(body['p_payload']['id'], 'template-a');
        expect(body['p_payload']['tenantId'], 'institution-a');
        return Response(
          jsonEncode({'id': 'template-a', 'payload': body['p_payload']}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await SupabaseMealPlanRepository(client).saveTemplate(
      MealPlanTemplateDraft(
        id: 'template-a',
        tenantId: 'institution-a',
        institutionId: 'institution-a',
        name: 'Modelo sintético',
        planVariant: MealPlanPlanVariant.complete,
        audienceSegment: MealPlanAudienceSegment.staff,
        expectedVersion: 2,
        payload: {
          ..._content,
          'id': 'template-b',
          'tenantId': 'institution-b',
          'p_template_id': 'template-b',
          'p_expected_version': 999,
          'expectedVersion': 999,
          'p_publish': true,
        },
      ),
      publish: false,
    );
  });

  test('command explicit metadata wins over content metadata', () {
    final command = MealPlanTemplateDraft(
      requestId: 'request-a',
      id: 'template-a',
      tenantId: 'institution-a',
      institutionId: 'institution-a',
      name: 'Nome autorizado',
      planVariant: MealPlanPlanVariant.complete,
      audienceSegment: MealPlanAudienceSegment.staff,
      payload: {
        ..._content,
        'requestId': 'stale-request',
        'id': 'untrusted-id',
        'tenantId': 'institution-b',
        'institutionId': 'institution-b',
        'name': 'Nome antigo',
        'planVariant': 'simple',
        'audienceSegment': 'students',
      },
    ).toJson();
    expect(command['requestId'], 'request-a');
    expect(command['id'], 'template-a');
    expect(command['tenantId'], 'institution-a');
    expect(command['institutionId'], 'institution-a');
    expect(command['name'], 'Nome autorizado');
    expect(command['planVariant'], 'complete');
    expect(command['audienceSegment'], 'staff');
    expect(command['futureField'], {'preserve': true});
  });

  test('historical payload retains unknown fields without overriding envelope identity', () {
    final template = MealPlanTemplate.fromJson({
      'id': 'template-a',
      'institutionId': 'institution-a',
      'payload': {
        'outerUnknown': {'retain': 'outer'},
        'payload': {..._content, 'institutionId': 'untrusted-nested-id'},
      },
    });
    expect(template.institutionId, 'institution-a');
    expect(template.payload['menu'], _content['menu']);
    expect(template.payload['outerUnknown'], {'retain': 'outer'});
    expect(template.payload['futureField'], {'preserve': true});
  });
  test('template command places content alongside metadata for canonical SQL storage', () {
    final command = _draft().toJson();
    expect(command['menu'], _content['menu']);
    expect(command['simpleNotes'], _content['simpleNotes']);
    expect(command.containsKey('payload'), isFalse);
    expect(command['tenantId'], 'institution-a');
  });

  for (final operation in ['list', 'get', 'save']) {
    for (final historical in operation == 'save' ? [false] : [false, true]) {
      test('template $operation roundtrip preserves content historical=$historical', () async {
        final client = SupabaseClient(
          'https://meal-plans.invalid',
          'test-anon-key',
          httpClient: MockClient((request) async {
            expect(request.url.pathSegments.last, 'meal_plan_template_$operation');
            final storedPayload = operation == 'save'
                ? (jsonDecode(request.body) as Map<String, dynamic>)['p_payload']
                : historical
                ? {'name': 'Modelo sintético', 'payload': _content}
                : _content;
            final row = <String, Object?>{
              'id': 'template-a',
              'name': 'Modelo sintético',
              'tenantId': 'institution-a',
              'institutionId': 'institution-a',
              'planVariant': 'complete',
              'audienceSegment': 'staff',
              'status': 'published',
              'version': 1,
              'createdAt': '2026-09-01T00:00:00Z',
              'updatedAt': '2026-09-02T00:00:00Z',
              'payload': storedPayload,
            };
            return Response(
              jsonEncode(
                operation == 'list'
                    ? {
                        'items': [row],
                        'total': 1,
                      }
                    : row,
              ),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseMealPlanRepository(client);
        final MealPlan item;
        if (operation == 'list') {
          item = (await repository.fetchTemplatePage(const MealPlanListFilter())).items.single;
        } else {
          final template = operation == 'get'
              ? await repository.getTemplateById('template-a')
              : await repository.saveTemplate(_draft(), publish: true);
          expect(template.payload['menu'], _content['menu']);
          expect(template.payload['futureField'], {'preserve': true});
          item = template.toDirectoryItem();
        }
        expect(item.menu, hasLength(1));
        expect(item.menu.single.dishName, 'Prato sintético');
        expect(item.simpleNotes, 'Notas sintéticas');
        expect(item.simpleImageAlt, 'Descrição sintética');
        expect(item.tenantId, 'institution-a');
      });
    }
  }
}

final _content = <String, Object?>{
  'menu': [
    {...MealPlanMenuEntry.empty().toJson(), 'dishName': 'Prato sintético'},
  ],
  'simpleImage': null,
  'simpleImageAlt': 'Descrição sintética',
  'simpleNotes': 'Notas sintéticas',
  'futureField': {'preserve': true},
};

MealPlanTemplateDraft _draft() => MealPlanTemplateDraft(
  requestId: 'request-a',
  tenantId: 'institution-a',
  institutionId: 'institution-a',
  name: 'Modelo sintético',
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.staff,
  payload: _content,
);
