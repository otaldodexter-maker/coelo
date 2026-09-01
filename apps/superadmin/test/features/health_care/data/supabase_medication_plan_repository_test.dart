import 'dart:convert';

import 'package:coelo_superadmin/features/health_care/data/supabase_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('directory sends pagination and maps a minimized plan summary', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, {
        'items': [_plan()],
        'total': 32,
        'limit': 10,
        'offset': 10,
      });
    });
    addTearDown(client.dispose);
    final repository = SupabaseMedicationPlanRepository(client);

    final page = await repository.fetchPage(
      const MedicationPlanQuery(statuses: {MedicationPlanStatus.active}, page: 1, pageSize: 10),
    );

    expect(page.total, 32);
    expect(page.items.single.medicationName, 'Budesonida');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_offset'], 10);
    expect(body['p_statuses'], ['active']);
  });

  test('save sends versioned schedules and maps the returned aggregate', () async {
    late Request captured;
    final client = _client((request) async {
      captured = request;
      return _ok(request, {'plan': _plan()});
    });
    addTearDown(client.dispose);
    final repository = SupabaseMedicationPlanRepository(client);

    final saved = await repository.save(_command());

    expect(saved.currentVersion, 2);
    expect(captured.url.pathSegments.last, 'superadmin_edit_medication_plan_v2');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['p_expected_version'], 1);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect((payload['schedules'] as List).single, containsPair('weekdays', [1, 3, 5]));
    expect(payload, isNot(contains('actor_id')));
  });

  test('semantic conflict maps to the domain conflict', () async {
    final client = _client((request) async => _error(request, 'SAI_CONCURRENT_CHANGE'));
    addTearDown(client.dispose);
    final repository = SupabaseMedicationPlanRepository(client);

    await expectLater(repository.save(_command()), throwsA(isA<MedicationPlanConflictException>()));
  });
}

MedicationPlanSaveCommand _command() => MedicationPlanSaveCommand(
  requestId: '10000000-0000-4000-8000-000000000001',
  planId: '20000000-0000-4000-8000-000000000001',
  childPersonId: '30000000-0000-4000-8000-000000000001',
  expectedVersion: 1,
  medicationName: 'Budesonida',
  doseAmount: 1,
  doseUnit: 'jato',
  administrationRoute: 'Inalatória',
  validFrom: DateTime.utc(2026, 9),
  reason: 'Atualização da prescrição',
  scopeKind: 'institution',
  timezone: 'America/Sao_Paulo',
  schedules: [
    MedicationScheduleDraft(timeOfDay: '08:00', weekdays: {1, 3, 5}, timezone: 'America/Sao_Paulo'),
  ],
);

Map<String, dynamic> _plan() => {
  'id': '20000000-0000-4000-8000-000000000001',
  'child_person_id': '30000000-0000-4000-8000-000000000001',
  'status': 'active',
  'current_version': 2,
  'medication_name': 'Budesonida',
  'dose_amount': 1,
  'dose_unit': 'jato',
  'administration_route': 'Inalatória',
  'route_details': null,
  'instructions': 'Agitar antes de usar',
  'valid_from': '2026-09-01T00:00:00.000Z',
  'valid_until': null,
  'timezone': 'America/Sao_Paulo',
  'schedules': [
    {
      'time_of_day': '08:00',
      'weekdays': [1, 3, 5],
      'timezone': 'America/Sao_Paulo',
      'frequency_kind': 'weekly',
    },
  ],
};

SupabaseClient _client(Future<Response> Function(Request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _ok(Request request, Map<String, dynamic> data) => Response(
  jsonEncode({'ok': true, 'data': data, 'error': null}),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);

Response _error(Request request, String code) => Response(
  jsonEncode({
    'ok': false,
    'data': null,
    'error': {'code': code},
  }),
  200,
  request: request,
  headers: {'content-type': 'application/json'},
);
