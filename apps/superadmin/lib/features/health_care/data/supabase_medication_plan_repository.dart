import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/medication_plan_repository.dart';

final class SupabaseMedicationPlanRepository implements MedicationPlanRepository {
  const SupabaseMedicationPlanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async {
    final data = await _rpc('superadmin_medication_plan_directory_v2', {
      'p_statuses': query.statuses.map((status) => status.name).toList(growable: false),
      'p_offset': query.offset,
      'p_limit': query.pageSize,
    });
    final rows = data['items'] as List<dynamic>? ?? const [];
    return MedicationPlanPage(
      items: rows.map((row) => _summary(Map<String, dynamic>.from(row as Map))).toList(),
      total: (data['total'] as num?)?.toInt() ?? rows.length,
      limit: (data['limit'] as num?)?.toInt() ?? query.pageSize,
      offset: (data['offset'] as num?)?.toInt() ?? query.offset,
    );
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async =>
      _detail(await _rpc('superadmin_medication_plan_detail_v2', {'p_plan_id': planId}));

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async {
    final data = await _rpc(
      command.planId == null
          ? 'superadmin_create_medication_plan_v2'
          : 'superadmin_edit_medication_plan_v2',
      {
        'p_request_id': command.requestId,
        'p_plan_id': ?command.planId,
        'p_expected_version': command.expectedVersion,
        'p_payload': {
          'child_person_id': command.childPersonId,
          'medication_name': command.medicationName.trim(),
          'dose_amount': command.doseAmount,
          'dose_unit': command.doseUnit.trim(),
          'administration_route': command.administrationRoute.trim(),
          'route_details': command.routeDetails?.trim(),
          'instructions': command.instructions?.trim(),
          'valid_from': command.validFrom.toIso8601String(),
          'valid_until': command.validUntil?.toIso8601String(),
          'reason': command.reason.trim(),
          'scope_kind': command.scopeKind,
          'institution_id': command.institutionId,
          'unit_id': command.unitId,
          'group_id': command.groupId,
          'child_context_id': command.childContextId,
          'timezone': command.timezone,
          'schedules': [
            for (final schedule in command.schedules)
              {
                'time_of_day': schedule.timeOfDay,
                'weekdays': schedule.weekdays.toList()..sort(),
                'timezone': schedule.timezone,
                'frequency_kind': schedule.frequencyKind,
                'start_date': schedule.startDate?.toIso8601String(),
                'end_date': schedule.endDate?.toIso8601String(),
                'max_occurrences_per_day': schedule.maxOccurrencesPerDay,
              },
          ],
        },
      },
    );
    return _detail(Map<String, dynamic>.from(data['plan'] as Map? ?? data));
  }

  Future<Map<String, dynamic>> _rpc(String function, Map<String, Object?> params) async {
    try {
      final response = await _client.rpc<Object?>(function, params: params);
      final envelope = Map<String, dynamic>.from(response as Map);
      if (envelope['ok'] != true) throw _exception(envelope['error']);
      return Map<String, dynamic>.from(envelope['data'] as Map);
    } on PostgrestException catch (error) {
      throw error.code == '42501'
          ? const MedicationPlanUnauthorizedException()
          : const MedicationPlanUnavailableException();
    }
  }

  Exception _exception(Object? raw) {
    final error = Map<String, dynamic>.from(raw as Map? ?? const {});
    return switch (error['code']) {
      'SAI_PERMISSION_DENIED' || 'SAI_MFA_REQUIRED' => const MedicationPlanUnauthorizedException(),
      'SAI_CONCURRENT_CHANGE' || 'SAI_REQUEST_REUSED' => const MedicationPlanConflictException(),
      'SAI_INVALID_ARGUMENT' => const MedicationPlanInvalidInputException(),
      _ => const MedicationPlanUnavailableException(),
    };
  }

  MedicationPlanSummary _summary(Map<String, dynamic> row) => MedicationPlanSummary(
    id: row['id'] as String,
    childPersonId: row['child_person_id'] as String,
    status: _status(row['status'] as String),
    version: (row['current_version'] as num).toInt(),
    medicationName: row['medication_name'] as String,
    doseAmount: row['dose_amount'] as num,
    doseUnit: row['dose_unit'] as String,
    route: row['administration_route'] as String,
    validFrom: DateTime.parse(row['valid_from'] as String),
    validUntil: row['valid_until'] == null ? null : DateTime.parse(row['valid_until'] as String),
  );

  MedicationPlanDetail _detail(Map<String, dynamic> row) => MedicationPlanDetail(
    id: row['id'] as String,
    childPersonId: row['child_person_id'] as String,
    status: _status(row['status'] as String),
    currentVersion: (row['current_version'] as num).toInt(),
    medicationName: row['medication_name'] as String,
    doseAmount: row['dose_amount'] as num,
    doseUnit: row['dose_unit'] as String,
    administrationRoute: row['administration_route'] as String,
    routeDetails: row['route_details'] as String?,
    instructions: row['instructions'] as String?,
    validFrom: DateTime.parse(row['valid_from'] as String),
    validUntil: row['valid_until'] == null ? null : DateTime.parse(row['valid_until'] as String),
    timezone: row['timezone'] as String,
    schedules: (row['schedules'] as List<dynamic>? ?? const [])
        .map((raw) {
          final schedule = Map<String, dynamic>.from(raw as Map);
          return MedicationScheduleDraft(
            timeOfDay: schedule['time_of_day'] as String,
            weekdays: (schedule['weekdays'] as List<dynamic>)
                .cast<num>()
                .map((day) => day.toInt())
                .toSet(),
            timezone: schedule['timezone'] as String,
            frequencyKind: schedule['frequency_kind'] as String? ?? 'weekly',
            startDate: schedule['start_date'] == null
                ? null
                : DateTime.parse(schedule['start_date'] as String),
            endDate: schedule['end_date'] == null
                ? null
                : DateTime.parse(schedule['end_date'] as String),
            maxOccurrencesPerDay: (schedule['max_occurrences_per_day'] as num?)?.toInt(),
          );
        })
        .toList(growable: false),
  );

  MedicationPlanStatus _status(String value) => switch (value) {
    'draft' => MedicationPlanStatus.draft,
    'suspended' => MedicationPlanStatus.suspended,
    'ended' => MedicationPlanStatus.ended,
    _ => MedicationPlanStatus.active,
  };
}
