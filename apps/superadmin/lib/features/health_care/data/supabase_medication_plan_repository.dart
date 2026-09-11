import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/medication_plan_repository.dart';

/// Planos de medicação contra o Supabase real.
///
/// Toda leitura e escrita passa por RPC: as tabelas expostas usam RLS
/// deny-by-default e o cliente não tem grant de escrita nenhum, então não há
/// caminho por PostgREST direto nem por engano. Filtro, ordenação e paginação
/// acontecem no servidor; o cliente só descreve o que quer.
///
/// A criança é identificada pela pessoa, e é o banco que resolve qual contexto
/// infantil aquilo significa. Se a pessoa tiver vínculo em mais de uma
/// instituição e o comando não disser qual, o servidor recusa em vez de
/// adivinhar — escrever dado de saúde no lugar errado é pior do que falhar.
final class SupabaseMedicationPlanRepository implements MedicationPlanRepository {
  const SupabaseMedicationPlanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async {
    final payload = _map(
      await _rpc('superadmin_medication_plan_directory', {
        'search': null,
        'statuses': query.statuses.isEmpty
            ? null
            : query.statuses.map(_statusToDatabase).toList(growable: false),
        'institution_id': null,
        'unit_id': null,
        'group_id': null,
        'page_limit': query.pageSize,
        'page_offset': query.offset,
      }),
    );
    return MedicationPlanPage(
      items: _rows(payload['items']).map(_summary).toList(growable: false),
      total: _asInt(payload['total']),
      limit: _asInt(payload['limit']),
      offset: _asInt(payload['offset']),
    );
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async =>
      _detail(_map(await _rpc('superadmin_medication_plan_detail', {'plan_id': planId})));

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async {
    final saved = _map(
      await _rpc('superadmin_medication_plan_save', {
        'request_id': command.requestId,
        'plan_id': command.planId,
        'expected_version': command.expectedVersion,
        'payload': {
          // Na criação a criança chega pelo contexto infantil; um id vazio
          // precisa virar nulo, senão o servidor tenta convertê-lo em uuid.
          'child_person_id': command.childPersonId.isEmpty ? null : command.childPersonId,
          'child_context_id': command.childContextId,
          'institution_id': command.institutionId,
          'unit_id': command.unitId,
          'group_id': command.groupId,
          'scope_kind': command.scopeKind,
          'medication_name': command.medicationName,
          'dose_amount': command.doseAmount,
          'dose_unit': command.doseUnit,
          'administration_route': command.administrationRoute,
          'route_details': command.routeDetails,
          'instructions': command.instructions,
          'reason': command.reason,
          'valid_from': _dateOnly(command.validFrom),
          'valid_until': command.validUntil == null ? null : _dateOnly(command.validUntil!),
          'timezone': command.timezone,
          'schedules': command.schedules.map(_scheduleJson).toList(growable: false),
        },
      }),
    );
    // O comando devolve apenas identidade e versão; o detalhe volta pela mesma
    // leitura autorizada de sempre, para a tela nunca renderizar um estado que
    // o servidor não confirmaria numa nova leitura.
    return fetchDetail(saved['id']! as String);
  }

  @override
  Future<MedicationEvidence> recordEvidence(MedicationEvidenceCommand command) async {
    final saved = _map(
      await _rpc('superadmin_medication_plan_record_evidence', {
        'request_id': command.requestId,
        'plan_id': command.planId,
        'payload': {
          'outcome': _outcomeToDatabase(command.outcome),
          'reason': command.reason,
          'note': command.note,
          'occurred_at': command.occurredAt?.toUtc().toIso8601String(),
        },
      }),
    );
    return MedicationEvidence(
      id: saved['id']! as String,
      occurredAt: command.occurredAt ?? DateTime.now(),
      outcome: command.outcome,
      reason: command.reason,
      note: command.note,
    );
  }

  Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      throw _translate(error);
    }
  }

  MedicationPlanException _translate(PostgrestException error) {
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const MedicationPlanUnauthorizedException();
    }
    // `no_data_found` é a negativa opaca do servidor: ele responde a mesma
    // coisa para um plano que não existe e para um que existe fora do escopo,
    // porque distinguir os dois confirmaria a existência do segundo.
    if (error.code == 'P0002' || error.code == 'PGRST116') {
      return const MedicationPlanNotFoundException();
    }
    if (error.code == '40001' || error.code == '55P03') {
      return const MedicationPlanConflictException();
    }
    if (error.code == '22023' || error.code == '23514' || error.code == '23502') {
      return const MedicationPlanInvalidInputException();
    }
    return const MedicationPlanUnavailableException();
  }
}

Map<String, Object?> _scheduleJson(MedicationScheduleDraft schedule) => {
  'time_of_day': schedule.timeOfDay,
  'weekdays': schedule.weekdays.toList(growable: false)..sort(),
  'timezone': schedule.timezone,
  'frequency_kind': schedule.frequencyKind,
  'start_date': schedule.startDate == null ? null : _dateOnly(schedule.startDate!),
  'end_date': schedule.endDate == null ? null : _dateOnly(schedule.endDate!),
  'max_occurrences_per_day': schedule.maxOccurrencesPerDay,
};

MedicationPlanSummary _summary(Map<String, Object?> row) => MedicationPlanSummary(
  id: row['id']! as String,
  childPersonId: row['child_person_id'] as String? ?? '',
  status: _statusFromDatabase(row['status'] as String?),
  version: _asInt(row['version']),
  medicationName: row['medication_name'] as String? ?? '',
  doseAmount: (row['dose_amount'] as num?) ?? 0,
  doseUnit: row['dose_unit'] as String? ?? '',
  route: row['administration_route'] as String? ?? '',
  validFrom: _date(row['valid_from']),
  validUntil: _optionalDate(row['valid_until']),
  childContextId: row['child_context_id'] as String?,
  childDisplayName: row['display_name'] as String? ?? '',
);

MedicationPlanDetail _detail(Map<String, Object?> payload) {
  final version = _map(payload['current_version']);
  return MedicationPlanDetail(
    id: payload['id']! as String,
    childPersonId: payload['child_person_id'] as String? ?? '',
    status: _statusFromDatabase(payload['status'] as String?),
    // A versão esperada pelo comando é a do agregado (management_version),
    // não o número da versão clínica.
    currentVersion: _asInt(payload['management_version']),
    medicationName: version['medication_name'] as String? ?? '',
    doseAmount: (version['dose_amount'] as num?) ?? 0,
    doseUnit: version['dose_unit'] as String? ?? '',
    administrationRoute: version['administration_route'] as String? ?? '',
    validFrom: _date(version['valid_from']),
    validUntil: _optionalDate(version['valid_until']),
    timezone: version['timezone'] as String? ?? '',
    routeDetails: version['route_details'] as String?,
    instructions: version['instructions'] as String?,
    schedules: _rows(payload['schedules']).map(_schedule).toList(growable: false),
    childContextId: payload['child_context_id'] as String?,
    institutionId: payload['institution_id'] as String?,
    unitId: payload['unit_id'] as String?,
    groupId: payload['group_id'] as String?,
    scopeKind: payload['scope_kind'] as String?,
    childDisplayName: payload['display_name'] as String? ?? '',
    evidence: _rows(payload['evidence']).map(_evidence).toList(growable: false),
  );
}

MedicationEvidence _evidence(Map<String, Object?> row) => MedicationEvidence(
  id: row['id']! as String,
  occurredAt: _date(row['occurred_at']),
  outcome: _outcomeFromDatabase(row['outcome'] as String?),
  reason: row['reason'] as String?,
  note: row['note'] as String?,
);

String _outcomeToDatabase(MedicationEvidenceOutcome outcome) => switch (outcome) {
  MedicationEvidenceOutcome.administered => 'administered',
  MedicationEvidenceOutcome.notAdministered => 'not_administered',
  MedicationEvidenceOutcome.refused => 'refused',
};

MedicationEvidenceOutcome _outcomeFromDatabase(String? value) => switch (value) {
  'not_administered' => MedicationEvidenceOutcome.notAdministered,
  'refused' => MedicationEvidenceOutcome.refused,
  _ => MedicationEvidenceOutcome.administered,
};

MedicationScheduleDraft _schedule(Map<String, Object?> row) => MedicationScheduleDraft(
  timeOfDay: _timeOfDay(row['time_of_day'] as String? ?? '00:00'),
  weekdays: {for (final day in (row['weekdays'] as List<Object?>? ?? const [])) _asInt(day)},
  timezone: row['timezone'] as String? ?? 'America/Sao_Paulo',
  frequencyKind: row['frequency_kind'] as String? ?? 'weekly',
  startDate: _optionalDate(row['start_date']),
  endDate: _optionalDate(row['end_date']),
  maxOccurrencesPerDay: row['max_occurrences_per_day'] == null
      ? null
      : _asInt(row['max_occurrences_per_day']),
);

/// Postgres devolve `time` como `HH:MM:SS`; o domínio só aceita `HH:MM`.
String _timeOfDay(String value) => value.length >= 5 ? value.substring(0, 5) : value;

String _statusToDatabase(MedicationPlanStatus status) => switch (status) {
  MedicationPlanStatus.draft => 'draft',
  MedicationPlanStatus.active => 'active',
  MedicationPlanStatus.suspended => 'suspended',
  MedicationPlanStatus.ended => 'ended',
};

MedicationPlanStatus _statusFromDatabase(String? value) => switch (value) {
  'active' => MedicationPlanStatus.active,
  'suspended' => MedicationPlanStatus.suspended,
  'ended' => MedicationPlanStatus.ended,
  _ => MedicationPlanStatus.draft,
};

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

List<Map<String, Object?>> _rows(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().map(_map).toList(growable: false)
    : const <Map<String, Object?>>[];

int _asInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

DateTime _date(Object? value) => _optionalDate(value) ?? DateTime.utc(1970);

DateTime? _optionalDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
