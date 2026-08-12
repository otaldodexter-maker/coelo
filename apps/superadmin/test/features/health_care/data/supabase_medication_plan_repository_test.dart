import 'dart:convert';
import 'package:coelo_superadmin/features/health_care/data/supabase_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('create sends canonical numeric dose, explicit timezone and schedules', () async {
    final requests = <Request>[];
    final repository = SupabaseMedicationPlanRepository(
      _client((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/create_medication_plan')) {
          return _json(request, {'id': 'plan-a'});
        }
        return _json(request, _detail());
      }),
    );
    await repository.save(
      MedicationPlanSaveCommand(
        requestId: 'request-a',
        childPersonId: 'child-a',
        expectedVersion: 0,
        medicationName: ' Dipirona ',
        doseAmount: 5,
        doseUnit: ' mL ',
        administrationRoute: ' oral ',
        validFrom: DateTime(2026, 8, 12),
        reason: 'Cadastro',
        scopeKind: 'child',
        timezone: 'America/Sao_Paulo',
        schedules: [
          MedicationScheduleDraft(
            timeOfDay: '08:30',
            weekdays: {5, 1, 3},
            timezone: 'America/Sao_Paulo',
          ),
        ],
      ),
    );
    expect(requests.first.url.path, endsWith('/rpc/create_medication_plan'));
    final body = Map<String, Object?>.from(jsonDecode(requests.first.body) as Map);
    final payload = Map<String, Object?>.from(body['p_payload'] as Map);
    expect(payload, containsPair('dose_amount', 5));
    expect(payload, containsPair('timezone', 'America/Sao_Paulo'));
    expect((payload['schedules'] as List).single, containsPair('weekdays', [1, 3, 5]));
    expect(requests.last.url.path, endsWith('/rpc/medication_plan_detail'));
  });

  test('update uses optimistic version and maps stale writes safely', () async {
    Request? captured;
    final repository = SupabaseMedicationPlanRepository(
      _client((request) async {
        captured = request;
        return Response(
          jsonEncode({'code': '40001', 'message': 'internal'}),
          409,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final command = MedicationPlanSaveCommand(
      requestId: 'request-a',
      planId: 'plan-a',
      childPersonId: 'child-a',
      expectedVersion: 4,
      medicationName: 'A',
      doseAmount: 1,
      doseUnit: 'mg',
      administrationRoute: 'oral',
      validFrom: DateTime(2026, 8, 12),
      reason: 'Ajuste',
      scopeKind: 'child',
      timezone: 'America/Sao_Paulo',
      schedules: [
        MedicationScheduleDraft(timeOfDay: '08:00', weekdays: {1}, timezone: 'America/Sao_Paulo'),
      ],
    );
    await expectLater(repository.save(command), throwsA(isA<MedicationPlanConflictException>()));
    expect(jsonDecode(captured!.body), containsPair('p_expected_version', 4));
  });

  test('unavailable adapter fails closed', () async {
    await expectLater(
      const UnavailableMedicationPlanRepository().fetchPage(const MedicationPlanQuery()),
      throwsA(isA<MedicationPlanUnavailableException>()),
    );
  });
}

SupabaseClient _client(Future<Response> Function(Request) handler) => SupabaseClient(
  'https://project.supabase.co',
  'sb_publishable_test',
  httpClient: MockClient(handler),
);
Response _json(Request request, Object value) => Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);
Map<String, Object?> _detail() => {
  'id': 'plan-a',
  'child_person_id': 'child-a',
  'status': 'draft',
  'current_version': 1,
  'version': {
    'medication_name': 'Dipirona',
    'dose_amount': 5,
    'dose_unit': 'mL',
    'administration_route': 'oral',
    'route_details': null,
    'valid_from': '2026-08-12',
    'valid_until': null,
    'timezone': 'America/Sao_Paulo',
    'instructions': null,
  },
  'schedules': [
    {
      'time_of_day': '08:30:00',
      'frequency_kind': 'weekly',
      'start_date': '2026-08-12',
      'end_date': null,
      'max_occurrences_per_day': 1,
      'weekdays': [1, 3, 5],
    },
  ],
};
