import 'dart:convert';

import 'package:coelo_superadmin/features/health_care/data/supabase_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/data/supabase_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Um servidor de mentira que responde por nome de RPC e guarda o que recebeu.
final class _Backend {
  _Backend(this.responses);

  final Map<String, Object?> responses;
  final calls = <String, List<Map<String, Object?>>>{};
  final errors = <String, ({int status, String code})>{};

  String? get lastFunction => calls.keys.isEmpty ? null : calls.keys.last;

  Map<String, Object?> paramsOf(String function) => calls[function]!.last;

  MockClient get client => MockClient((request) async {
    final function = request.url.path.split('/rpc/').last;
    final body = jsonDecode(request.body) as Map<String, Object?>;
    (calls[function] ??= <Map<String, Object?>>[]).add(body);
    final failure = errors[function];
    if (failure != null) {
      return Response(
        jsonEncode({'code': failure.code, 'message': 'recusado'}),
        failure.status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return Response(
      jsonEncode(responses[function]),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });
}

SupabaseClient _clientFor(_Backend backend) =>
    SupabaseClient('https://example.supabase.co', 'publishable-key', httpClient: backend.client);

final _actor = HealthCareActor(id: 'actor-1', profile: HealthCareAccessProfile.owner);

const _profileDetail = {
  'id': 'profile-1',
  'institution_id': 'institution-1',
  'child_context_id': 'context-1',
  'child_person_id': 'person-1',
  'display_name': 'Criança Um',
  'operational_status': 'active',
  'important_signs': 'sinais',
  'adaptations': 'adaptacoes',
  'management_version': 4,
  'can_manage': true,
  'items': [
    {'catalog_item_id': 'autism', 'other_text': null},
  ],
  'allergies': [
    {
      'id': 'allergy-1',
      'label': 'Amendoim',
      'allergy_type': 'food',
      'status': 'active',
      'active': true,
      'last_episode_at': null,
      'episode_severity': null,
      'observed_reaction': '',
      'guidance': '',
      'notes': '',
      'inactivated_at': null,
    },
  ],
  'revisions': <Object?>[],
};

void main() {
  group('Perfis de cuidado', () {
    test('o diretório manda filtro e paginação para o servidor', () async {
      final backend = _Backend({
        'superadmin_health_care_directory': {
          'items': [
            {
              'id': 'profile-1',
              'child_person_id': 'person-1',
              'display_name': 'Criança Um',
              'operational_status': 'implementation',
              'medication_count': 2,
              'active_allergy_count': 1,
            },
          ],
          'total': 37,
          'limit': 25,
          'offset': 50,
        },
      });
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      final page = await SupabaseHealthCareRepository(client).fetchDirectory(
        const HealthCareDirectoryQuery(
          search: '  Ana  ',
          operationalStatuses: {
            HealthCareOperationalStatus.active,
            HealthCareOperationalStatus.inactive,
          },
          page: 2,
          pageSize: 25,
        ),
        actor: _actor,
      );

      final params = backend.paramsOf('superadmin_health_care_directory');
      expect(params['search'], 'Ana', reason: 'a busca vai aparada, não com espaços');
      expect((params['statuses']! as List).toSet(), {'active', 'inactive'});
      expect(params['page_limit'], 25);
      expect(params['page_offset'], 50);
      expect(page.totalCount, 37, reason: 'o total é o do servidor, não o da página');
      expect(page.items.single.personId, 'person-1');
      expect(page.items.single.medicationCount, 2);
    });

    test('escrever lê a versão atual antes, para conflito não virar sobrescrita', () async {
      final backend = _Backend({
        'superadmin_health_care_profile_detail': _profileDetail,
        'superadmin_health_care_save_profile': {'id': 'profile-1', 'revision': 5},
      });
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      await SupabaseHealthCareRepository(client).updateCareProfile(
        childId: 'profile-1',
        items: [HealthCareProfileItem(catalogItemId: 'autism')],
        justification: 'Revisão anual.',
        actor: _actor,
      );

      final params = backend.paramsOf('superadmin_health_care_save_profile');
      expect(params['expected_version'], 4);
      final payload = params['payload']! as Map<String, Object?>;
      expect(payload['justification'], 'Revisão anual.');
      expect(payload['subject'], 'care_profile');
    });

    test('alergia sem data de episódio vai sem gravidade (severity_check do servidor)', () async {
      final backend = _Backend({
        'superadmin_health_care_save_profile': {'id': 'profile-9', 'revision': 1},
      });
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      await SupabaseHealthCareRepository(client).createCareProfile(
        HealthCareProfileDraft(
          childId: 'person-1',
          observedReaction: 'Urticaria leve',
          justification: 'Cadastro inicial.',
        ),
      );

      final payload =
          backend.paramsOf('superadmin_health_care_save_profile')['payload']! as Map<String, Object?>;
      final allergy = (payload['allergies']! as List).single as Map<String, Object?>;
      expect(allergy.containsKey('last_episode_at'), isFalse);
      // O formulario nasce com "Moderada" selecionada; sem episodio o servidor
      // recusaria com 23514 (health_care_allergies_severity_check).
      expect(allergy['episode_severity'], isNull);
    });

    test('perfil fora do escopo volta como ausente, sem confirmar existência', () async {
      final backend = _Backend({})
        ..errors['superadmin_health_care_profile_detail'] = (status: 403, code: '42501');
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      expect(
        await SupabaseHealthCareRepository(client).findChild('profile-1', actor: _actor),
        isNull,
      );
    });

    test('medicação pelo perfil falha fechada, com o motivo', () async {
      final backend = _Backend({});
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      await expectLater(
        SupabaseHealthCareRepository(client).createMedication(
          childId: 'profile-1',
          name: 'Dipirona',
          dose: '1',
          doseUnit: 'ml',
          route: 'oral',
          startsAt: DateTime(2026, 9, 1),
          endsAt: DateTime(2026, 9, 30),
          schedules: const [],
          actor: _actor,
        ),
        throwsA(isA<StateError>()),
      );
      expect(backend.calls, isEmpty, reason: 'não se escreve num caminho que não existe');
    });
  });

  group('Planos de medicação', () {
    test('a lista pede só os status escolhidos', () async {
      final backend = _Backend({
        'superadmin_medication_plan_directory': {
          'items': [
            {
              'id': 'plan-1',
              'child_person_id': 'person-1',
              'status': 'active',
              'version': 3,
              'medication_name': 'Dipirona',
              'dose_amount': 2.5,
              'dose_unit': 'ml',
              'administration_route': 'oral',
              'valid_from': '2026-09-01',
              'valid_until': null,
            },
          ],
          'total': 1,
          'limit': 25,
          'offset': 0,
        },
      });
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      final page = await SupabaseMedicationPlanRepository(client).fetchPage(
        const MedicationPlanQuery(statuses: {MedicationPlanStatus.active}),
      );

      expect(backend.paramsOf('superadmin_medication_plan_directory')['statuses'], ['active']);
      expect(page.items.single.status, MedicationPlanStatus.active);
      expect(page.items.single.doseAmount, 2.5);
      expect(page.items.single.validUntil, isNull);
    });

    test('salvar manda a pessoa e relê o detalhe pela leitura autorizada', () async {
      final backend = _Backend({
        'superadmin_medication_plan_save': {'id': 'plan-1', 'management_version': 1},
        'superadmin_medication_plan_detail': {
          'id': 'plan-1',
          'child_person_id': 'person-1',
          'status': 'active',
          'management_version': 1,
          'current_version': {
            'version': 1,
            'medication_name': 'Dipirona',
            'dose_amount': 2.5,
            'dose_unit': 'ml',
            'administration_route': 'oral',
            'valid_from': '2026-09-01',
            'valid_until': null,
            'timezone': 'America/Sao_Paulo',
            'route_details': null,
            'instructions': null,
          },
          'schedules': [
            {
              'time_of_day': '08:30:00',
              'weekdays': [1, 3, 5],
              'timezone': 'America/Sao_Paulo',
              'frequency_kind': 'weekly',
              'start_date': null,
              'end_date': null,
              'max_occurrences_per_day': null,
            },
          ],
          'evidence': <Object?>[],
        },
      });
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      final detail = await SupabaseMedicationPlanRepository(client).save(
        MedicationPlanSaveCommand(
          requestId: 'request-1',
          childPersonId: 'person-1',
          expectedVersion: 0,
          medicationName: 'Dipirona',
          doseAmount: 2.5,
          doseUnit: 'ml',
          administrationRoute: 'oral',
          validFrom: DateTime(2026, 9),
          reason: 'Prescrição médica.',
          scopeKind: 'institution',
          timezone: 'America/Sao_Paulo',
          schedules: [
            MedicationScheduleDraft(
              timeOfDay: '08:30',
              weekdays: const {1, 3, 5},
              timezone: 'America/Sao_Paulo',
            ),
          ],
        ),
      );

      final payload =
          backend.paramsOf('superadmin_medication_plan_save')['payload']! as Map<String, Object?>;
      expect(
        payload['child_person_id'],
        'person-1',
        reason: 'o cliente identifica a criança pela pessoa; o banco resolve o contexto',
      );
      expect(payload['valid_from'], '2026-09-01');
      expect((payload['schedules']! as List).single, containsPair('weekdays', [1, 3, 5]));
      expect(
        backend.lastFunction,
        'superadmin_medication_plan_detail',
        reason: 'a tela mostra o que uma nova leitura autorizada confirma',
      );
      // Postgres devolve `time` com segundos; o domínio só aceita HH:MM.
      expect(detail.schedules.single.timeOfDay, '08:30');
    });

    test('registrar dose manda o desfecho ao servidor e o detalhe lê os registros', () async {
      final backend = _Backend({
        'superadmin_medication_plan_record_evidence': {'id': 'evidence-1', 'plan_id': 'plan-1'},
      });
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      final saved = await SupabaseMedicationPlanRepository(client).recordEvidence(
        MedicationEvidenceCommand(
          requestId: 'request-9',
          planId: 'plan-1',
          outcome: MedicationEvidenceOutcome.refused,
          reason: 'Criança recusou',
        ),
      );
      final params = backend.paramsOf('superadmin_medication_plan_record_evidence');
      expect(params['plan_id'], 'plan-1');
      expect(params['payload'], containsPair('outcome', 'refused'));
      expect(params['payload'], containsPair('reason', 'Criança recusou'));
      expect(saved.id, 'evidence-1');
      expect(
        () => MedicationEvidenceCommand(
          requestId: 'r',
          planId: 'plan-1',
          outcome: MedicationEvidenceOutcome.notAdministered,
        ),
        throwsArgumentError,
        reason: 'o servidor exige motivo quando a dose não foi administrada',
      );
    });

    test('cada recusa do servidor vira o erro certo do domínio', () async {
      for (final (code, matcher) in <(String, Matcher)>[
        ('42501', isA<MedicationPlanUnauthorizedException>()),
        ('P0002', isA<MedicationPlanNotFoundException>()),
        ('40001', isA<MedicationPlanConflictException>()),
        ('22023', isA<MedicationPlanInvalidInputException>()),
        ('XX000', isA<MedicationPlanUnavailableException>()),
      ]) {
        final backend = _Backend({})
          ..errors['superadmin_medication_plan_detail'] = (status: 400, code: code);
        final client = _clientFor(backend);
        addTearDown(client.dispose);

        await expectLater(
          SupabaseMedicationPlanRepository(client).fetchDetail('plan-1'),
          throwsA(matcher),
          reason: 'código $code',
        );
      }
    });
  });
}
