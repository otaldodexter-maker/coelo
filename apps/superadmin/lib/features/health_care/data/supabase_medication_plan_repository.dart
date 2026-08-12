import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/medication_plan_repository.dart';

final class SupabaseMedicationPlanRepository implements MedicationPlanRepository {
  const SupabaseMedicationPlanRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async {
    try {
      var request = _client.from('medication_plan_directory').select();
      if (query.statuses.isNotEmpty) {
        request = request.inFilter('status', query.statuses.map((s) => s.name).toList());
      }
      final rows = List<Map<String, Object?>>.from(
        await request.range(query.offset, query.offset + query.pageSize - 1),
      );
      return MedicationPlanPage(
        items: rows.map(_summary).toList(),
        total: rows.length,
        limit: query.pageSize,
        offset: query.offset,
      );
    } on PostgrestException catch (error) {
      throw _safe(error);
    }
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async =>
      _detail(await _rpc('medication_plan_detail', {'p_plan_id': planId}));

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async {
    final payload = <String, Object?>{
      'child_person_id': command.childPersonId,
      'scope_kind': command.scopeKind,
      'institution_id': command.institutionId,
      'unit_id': command.unitId,
      'group_id': command.groupId,
      'child_context_id': command.childContextId,
      'medication_name': command.medicationName.trim(),
      'dose_amount': command.doseAmount,
      'dose_unit': command.doseUnit.trim(),
      'administration_route': command.administrationRoute.trim(),
      'route_details': command.routeDetails?.trim(),
      'valid_from': _date(command.validFrom),
      'valid_until': command.validUntil == null ? null : _date(command.validUntil!),
      'timezone': command.timezone,
      'instructions': command.instructions?.trim(),
      'change_reason': command.reason.trim(),
      'schedules': command.schedules
          .map(
            (s) => <String, Object?>{
              'time_of_day': s.timeOfDay,
              'frequency_kind': s.frequencyKind,
              'start_date': _date(s.startDate ?? command.validFrom),
              'end_date': s.endDate == null ? null : _date(s.endDate!),
              'max_occurrences_per_day': s.maxOccurrencesPerDay,
              'weekdays': s.weekdays.toList()..sort(),
            },
          )
          .toList(),
    };
    final result = command.planId == null
        ? await _rpc('create_medication_plan', {
            'p_request_id': command.requestId,
            'p_payload': payload,
          })
        : await _rpc('update_medication_plan', {
            'p_request_id': command.requestId,
            'p_plan_id': command.planId,
            'p_expected_version': command.expectedVersion,
            'p_payload': payload,
          });
    return fetchDetail((_map(result)['id'] as String?) ?? command.planId!);
  }

  Future<Object?> _rpc(String name, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(name, params: params);
    } on PostgrestException catch (error) {
      throw _safe(error);
    }
  }

  MedicationPlanException _safe(PostgrestException error) => switch (error.code) {
    '42501' || 'PGRST301' => const MedicationPlanUnauthorizedException(),
    'P0002' || 'PGRST116' => const MedicationPlanNotFoundException(),
    '40001' => const MedicationPlanConflictException(),
    '22023' || '23502' || '23514' => const MedicationPlanInvalidInputException(),
    _ => const MedicationPlanUnavailableException(),
  };

  MedicationPlanSummary _summary(Map<String, Object?> row) => MedicationPlanSummary(
    id: row['id'] as String,
    childPersonId: row['child_person_id'] as String,
    status: _status(row['status'] as String),
    version: (row['current_version'] as num).toInt(),
    medicationName: row['medication_name'] as String,
    doseAmount: row['dose_amount'] as num,
    doseUnit: row['dose_unit'] as String,
    route: row['administration_route'] as String,
    validFrom: DateTime.parse(row['valid_from'] as String),
    validUntil: _optionalDate(row['valid_until']),
  );

  MedicationPlanDetail _detail(Object? value) {
    final json = _map(value), version = _map(_map(value)['version']);
    return MedicationPlanDetail(
      id: json['id'] as String,
      childPersonId: json['child_person_id'] as String,
      status: _status(json['status'] as String),
      currentVersion: (json['current_version'] as num).toInt(),
      medicationName: version['medication_name'] as String,
      doseAmount: version['dose_amount'] as num,
      doseUnit: version['dose_unit'] as String,
      administrationRoute: version['administration_route'] as String,
      routeDetails: version['route_details'] as String?,
      validFrom: DateTime.parse(version['valid_from'] as String),
      validUntil: _optionalDate(version['valid_until']),
      timezone: version['timezone'] as String,
      instructions: version['instructions'] as String?,
      schedules: _list(json['schedules']).map((item) {
        final row = _map(item);
        return MedicationScheduleDraft(
          timeOfDay: (row['time_of_day'] as String).substring(0, 5),
          weekdays: _list(row['weekdays']).map((d) => (d as num).toInt()).toSet(),
          timezone: version['timezone'] as String,
          frequencyKind: row['frequency_kind'] as String,
          startDate: _optionalDate(row['start_date']),
          endDate: _optionalDate(row['end_date']),
          maxOccurrencesPerDay: (row['max_occurrences_per_day'] as num?)?.toInt(),
        );
      }).toList(),
    );
  }
}

Map<String, Object?> _map(Object? value) => Map<String, Object?>.from(value as Map);
List<Object?> _list(Object? value) => List<Object?>.from(value as List? ?? const []);
DateTime? _optionalDate(Object? value) => value == null ? null : DateTime.parse(value as String);
String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
MedicationPlanStatus _status(String value) =>
    MedicationPlanStatus.values.firstWhere((s) => s.name == value);
