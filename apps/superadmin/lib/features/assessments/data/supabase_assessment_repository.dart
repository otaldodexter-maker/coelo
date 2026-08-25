import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../assessment.dart';

final class SupabaseAssessmentRepository implements AssessmentRepository {
  SupabaseAssessmentRepository(this._client);
  final SupabaseClient _client;
  @override
  Future<AssessmentContextOptions> fetchContextOptions() async {
    final json = _map(await _rpc('superadmin_assessment_context_options'));
    return AssessmentContextOptions(
      assignments: _rows(json['assignments']).map((row) => _context(row, null)).toList(),
      periods: _rows(json['periods'])
          .map(
            (row) => AssessmentPeriodOption(
              id: _string(row['id']),
              name: _string(row['name']),
              status: _string(row['status']),
              institutionId: row['institution_id'] as String?,
              unitId: row['unit_id'] as String?,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) async {
    final value = await _rpc('superadmin_assessment_configuration_read', {
      'target_activity': activityId,
      'target_unit': unitId,
    });
    return value == null ? null : _configuration(_map(value));
  }

  @override
  Future<AssessmentGradebook> createOrResumeGradebook(
    AssessmentContext context,
    AssessmentConfiguration configuration,
  ) async {
    final draft = AssessmentGradebook(
      id: '',
      version: 0,
      status: AssessmentGradebookStatus.draft,
      context: context,
      configuration: configuration,
      students: const [],
    );
    final result = _map(
      await _rpc('superadmin_assessment_save_gradebook', {
        'request_id': _uuid(),
        'gradebook_id': null,
        'expected_version': 0,
        'payload': draft.toPayload(),
        'reason': null,
      }),
    );
    return (await fetchGradebook(_string(result['id'])))!;
  }

  @override
  Future<AssessmentGradebook?> fetchGradebook(String id) async {
    final value = await _rpc('superadmin_assessment_gradebook_read', {'target_gradebook': id});
    return value == null ? null : _gradebook(_map(value));
  }

  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() async =>
      _rows(await _rpc('superadmin_assessment_closing_queue'))
          .map(
            (row) => AssessmentClosingItem(
              id: _string(row['id']),
              status: _bookStatus(row['status']),
              version: _int(row['version']),
              institutionName: _string(row['institution_name']),
              unitName: _string(row['unit_name']),
              groupName: _string(row['group_name']),
              activityName: _string(row['activity_name']),
              periodName: _string(row['period_name']),
              pendingCount: _int(row['pending_count']),
            ),
          )
          .toList();
  @override
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value) async {
    final competenciesByCategory = <String, List<AssessmentCompetency>>{};
    for (final competency in value.competencies) {
      competenciesByCategory.putIfAbsent(competency.category, () => []).add(competency);
    }
    final result = _map(
      await _rpc('superadmin_assessment_save_configuration', {
        'request_id': _uuid(),
        'configuration_id': value.id.isEmpty || value.isActive ? null : value.id,
        'expected_version': value.isActive ? 0 : value.version,
        'payload': {
          'activity_id': value.activityId,
          'institution_id': value.institutionId,
          'unit_id': value.unitId,
          'periodicity': value.periodicity,
          'result_scale_kind': _scale(value.scaleKind),
          'scale_options': {
            'step': value.numericStep,
            if (value.concepts.isNotEmpty) 'concepts': value.concepts,
          },
          'concepts': value.concepts.indexed
              .map((item) => {'code': item.$2, 'label': item.$2, 'sort_order': item.$1})
              .toList(),
          'periods': value.periods.map((item) => item.toJson()).toList(),
          'allow_final_override': value.allowFinalOverride,
          'instruments': value.instruments
              .map(
                (item) => {'name': item.name, 'weight': item.weight, 'sort_order': item.sortOrder},
              )
              .toList(),
          'categories': competenciesByCategory.entries
              .map(
                (entry) => {
                  'name': entry.key,
                  'competencies': entry.value.indexed
                      .map((item) => {'name': item.$2.name, 'sort_order': item.$1})
                      .toList(),
                },
              )
              .toList(),
        },
      }),
    );
    final saved = value.copyWith(
      id: _string(result['id']),
      version: _int(result['version']),
      status: _string(result['status']),
    );
    return await fetchConfiguration(saved.activityId, unitId: saved.unitId) ?? saved;
  }

  @override
  Future<AssessmentConfiguration> activateConfiguration(AssessmentConfiguration value) async {
    final result = _map(
      await _rpc('superadmin_assessment_activate_configuration', {
        'request_id': _uuid(),
        'configuration_id': value.id,
        'expected_version': value.version,
      }),
    );
    final activated = value.copyWith(
      version: _int(result['version']),
      status: _string(result['status']),
    );
    return await fetchConfiguration(activated.activityId, unitId: activated.unitId) ?? activated;
  }

  @override
  Future<AssessmentGradebook> saveGradebook(AssessmentGradebook value, {String? reason}) async {
    final result = _map(
      await _rpc('superadmin_assessment_save_gradebook', {
        'request_id': _uuid(),
        'gradebook_id': value.id.isEmpty ? null : value.id,
        'expected_version': value.version,
        'payload': value.toPayload(),
        'reason': reason,
      }),
    );
    final id = _string(result['id']).isEmpty ? value.id : _string(result['id']);
    final authoritative = await fetchGradebook(id);
    if (authoritative == null) throw const AssessmentOfflineException();
    return authoritative;
  }

  @override
  Future<AssessmentGradebook> submitGradebook(AssessmentGradebook value) async =>
      _transitionRpc(value, 'superadmin_assessment_submit_gradebook', 'Envio para fechamento');
  @override
  Future<AssessmentGradebook> transitionGradebook(
    AssessmentGradebook value,
    AssessmentClosingAction action,
    String reason,
  ) async => _transitionRpc(value, switch (action) {
    AssessmentClosingAction.review => 'superadmin_assessment_review_gradebook',
    AssessmentClosingAction.returnToTeacher => 'superadmin_assessment_return_gradebook',
    AssessmentClosingAction.publish => 'superadmin_assessment_publish_gradebook',
  }, reason);
  @override
  Future<AssessmentGradebook> schedulePublication(
    AssessmentGradebook value,
    DateTime publishAt,
    String reason,
  ) async {
    final result = _map(
      await _rpc('superadmin_assessment_schedule_publication', {
        'request_id': _uuid(),
        'gradebook_id': value.id,
        'expected_version': value.version,
        'publish_at': publishAt.toUtc().toIso8601String(),
        'reason': reason,
      }),
    );
    final id = _string(result['id']).isEmpty ? value.id : _string(result['id']);
    final authoritative = await fetchGradebook(id);
    if (authoritative == null) throw const AssessmentOfflineException();
    return authoritative;
  }

  Future<AssessmentGradebook> _transitionRpc(
    AssessmentGradebook value,
    String function,
    String reason,
  ) async {
    final result = _map(
      await _rpc(function, {
        'request_id': _uuid(),
        'gradebook_id': value.id,
        'expected_version': value.version,
        'reason': reason,
      }),
    );
    final id = _string(result['id']).isEmpty ? value.id : _string(result['id']);
    final authoritative = await fetchGradebook(id);
    if (authoritative == null) throw const AssessmentOfflineException();
    return authoritative;
  }

  Future<dynamic> _rpc(String function, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code == '40001') throw const AssessmentVersionConflictException();
      if (error.code == '42501') throw const AssessmentUnauthorizedException();
      rethrow;
    } on AuthException {
      throw const AssessmentUnauthorizedException();
    } on Exception {
      throw const AssessmentOfflineException();
    }
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> _rows(dynamic value) => (value as List? ?? const []).map(_map).toList();
String _string(dynamic value) => value?.toString() ?? '';
int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
double? _double(dynamic value) => (value as num?)?.toDouble();
DateTime? _dateTime(dynamic value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;
AssessmentContext _context(Map<String, dynamic> row, Map<String, dynamic>? period) =>
    AssessmentContext(
      activityGroupLinkId: _string(row['activity_group_link_id']),
      institutionId: _string(row['institution_id']),
      institutionName: _string(row['institution_name']),
      unitId: _string(row['unit_id']),
      unitName: _string(row['unit_name']),
      groupId: _string(row['group_id']),
      groupName: _string(row['group_name']),
      activityId: _string(row['activity_id']),
      activityName: _string(row['activity_name']),
      periodId: _string(period?['id'] ?? row['period_id']),
      periodName: _string(period?['name'] ?? row['period_name']),
    );
AssessmentConfiguration _configuration(Map<String, dynamic> envelope) {
  final row = _map(envelope['configuration']);
  final scaleOptions = _map(row['scale_options']);
  final configuredConcepts = _rows(
    envelope['concepts'],
  ).map((item) => _string(item['code'])).where((item) => item.isNotEmpty).toList();
  return AssessmentConfiguration(
    id: _string(row['id']),
    activityId: _string(row['activity_id']),
    institutionId: _string(row['institution_id']),
    unitId: row['unit_id'] as String?,
    periodicity: _string(row['periodicity']),
    scaleKind: _scaleKind(row['result_scale_kind']),
    version: _int(row['management_version']),
    status: _string(row['status']),
    allowFinalOverride: row['allow_final_override'] as bool? ?? false,
    concepts: configuredConcepts.isNotEmpty
        ? configuredConcepts
        : (scaleOptions['concepts'] as List? ?? const [])
              .map(_string)
              .where((item) => item.isNotEmpty)
              .toList(),
    numericStep: _double(scaleOptions['step']) ?? 0.01,
    instruments: _rows(envelope['instruments'])
        .map(
          (item) => AssessmentInstrument(
            id: _string(item['id']),
            name: _string(item['name']),
            weight: _double(item['weight']) ?? 0,
            sortOrder: _int(item['sort_order']),
          ),
        )
        .toList(),
    competencies: _rows(envelope['competencies'])
        .map(
          (item) => AssessmentCompetency(
            id: _string(item['id']),
            name: _string(item['name']),
            category: _string(item['category']),
          ),
        )
        .toList(),
    availableCompetencies: _rows(envelope['available_competencies'])
        .map(
          (item) => AssessmentCompetency(
            id: _string(item['id']),
            name: _string(item['name']),
            category: _string(item['category']),
          ),
        )
        .toList(),
    periods: _rows(envelope['periods'])
        .map(
          (item) => AssessmentConfiguredPeriod(
            id: _string(item['id']),
            name: _string(item['name']),
            ordinal: _int(item['ordinal']),
            academicYear: _int(item['academic_year']),
            startsOn: DateTime.parse(_string(item['starts_on'])),
            endsOn: DateTime.parse(_string(item['ends_on'])),
            entryClosesAt: DateTime.parse(_string(item['entry_closes_at'])),
            familyReleaseAt: DateTime.parse(_string(item['family_release_at'])),
            timezone: _string(item['timezone']),
            status: _string(item['status']),
          ),
        )
        .toList(),
  );
}

AssessmentGradebook _gradebook(Map<String, dynamic> envelope) {
  final row = _map(envelope['gradebook']);
  final context = AssessmentContext(
    activityGroupLinkId: _string(row['activity_group_link_id']),
    institutionId: _string(row['institution_id']),
    institutionName: _string(row['institution_name']),
    unitId: _string(row['unit_id']),
    unitName: _string(row['unit_name']),
    groupId: _string(row['group_id']),
    groupName: _string(row['group_name']),
    activityId: _string(row['activity_id']),
    activityName: _string(row['activity_name']),
    periodId: _string(row['period_id']),
    periodName: _string(row['period_name']),
  );
  return AssessmentGradebook(
    id: _string(row['id']),
    version: _int(row['management_version']),
    status: _bookStatus(row['status']),
    context: context,
    configuration: envelope['configuration'] == null
        ? null
        : _configuration(_map(envelope['configuration'])),
    familyReleaseAt: _dateTime(row['family_release_at']),
    publishScheduledAt: _dateTime(row['publish_scheduled_at']),
    publishedAt: _dateTime(row['published_at']),
    students: _rows(envelope['students'])
        .map(
          (item) => AssessmentStudentEntry(
            id: _string(item['id']),
            childContextId: _string(item['child_context_id']),
            name: _string(item['name']),
            state: _studentState(item['state']),
            suggestedScore: _double(item['suggested_numeric_value']),
            finalNumericValue: _double(item['final_numeric_value']),
            finalConceptCode: item['final_concept_code'] as String?,
            finalBooleanValue: item['final_boolean_value'] as bool?,
            overrideReason: _string(item['override_reason']),
            instruments: _rows(item['instruments'])
                .map(
                  (entry) => AssessmentInstrumentEntry(
                    instrumentId: _string(entry['instrument_id']),
                    numericValue: _double(entry['numeric_value']),
                    conceptCode: entry['concept_code'] as String?,
                    booleanValue: entry['boolean_value'] as bool?,
                    absent: entry['absent'] as bool? ?? false,
                  ),
                )
                .toList(),
            competencies: _rows(item['competencies'])
                .map(
                  (entry) => AssessmentCompetencyEntry(
                    competencyId: _string(entry['competency_id']),
                    score: _double(entry['score']) ?? 0,
                  ),
                )
                .toList(),
            familyComment: _string(item['family_comment']),
            internalNote: _string(item['internal_note']),
          ),
        )
        .toList(),
    events: _rows(envelope['events'])
        .map(
          (item) => AssessmentGradebookEvent(
            id: _string(item['id']),
            kind: _string(item['event_kind']),
            actorPersonId: _string(item['actor_person_id']),
            reason: _string(item['reason']),
            version: _int(item['version']),
            createdAt: _dateTime(item['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList(),
  );
}

AssessmentGradebookStatus _bookStatus(dynamic value) => AssessmentGradebookStatus.values.firstWhere(
  (item) => item.name == _string(value),
  orElse: () => AssessmentGradebookStatus.draft,
);
AssessmentStudentState _studentState(dynamic value) => switch (_string(value)) {
  'not_started' => AssessmentStudentState.notStarted,
  'pending' => AssessmentStudentState.pending,
  'complete' => AssessmentStudentState.complete,
  'absent' => AssessmentStudentState.absent,
  _ => AssessmentStudentState.notStarted,
};
AssessmentScaleKind _scaleKind(dynamic value) => switch (_string(value)) {
  'numeric_0_100' => AssessmentScaleKind.numeric0To100,
  'concept' => AssessmentScaleKind.concept,
  'numeric_1_5' => AssessmentScaleKind.numeric1To5,
  'binary' => AssessmentScaleKind.binary,
  'stars_0_5' => AssessmentScaleKind.stars0To5,
  _ => AssessmentScaleKind.numeric0To10,
};
String _scale(AssessmentScaleKind value) => switch (value) {
  AssessmentScaleKind.numeric0To10 => 'numeric_0_10',
  AssessmentScaleKind.numeric0To100 => 'numeric_0_100',
  AssessmentScaleKind.concept => 'concept',
  AssessmentScaleKind.numeric1To5 => 'numeric_1_5',
  AssessmentScaleKind.binary => 'binary',
  AssessmentScaleKind.stars0To5 => 'stars_0_5',
};
String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
