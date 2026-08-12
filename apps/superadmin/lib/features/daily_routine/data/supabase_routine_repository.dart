import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/routine_contract.dart';

final class SupabaseRoutineRepository implements RoutineRepository {
  const SupabaseRoutineRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async {
    final payload = await _client.rpc<Object?>(
      'superadmin_routine_directory',
      params: {
        'p_kind': query.kind.name,
        'p_search': query.search.trim(),
        'p_status': query.status,
        'p_institution_id': query.institutionId,
        'p_unit_id': query.unitId,
        'p_group_id': query.groupId,
        'p_limit': query.pageSize,
        'p_offset': (query.page - 1) * query.pageSize,
      },
    );
    final response = payload is Map
        ? Map<String, Object?>.from(payload)
        : const <String, Object?>{};
    final rows = _rows(response['items']);
    final totalCount = response['total_count'] == null ? 0 : _integer(response['total_count']);
    return RoutineDirectoryPage(
      items: rows.map(_directoryItem).toList(growable: false),
      page: query.page,
      pageSize: query.pageSize,
      totalCount: totalCount,
      canManage: response['can_manage'] == true,
    );
  }

  @override
  Future<RoutineModel> fetchModel(String id) async {
    final value = await _singleRpc('superadmin_routine_model_detail', {'p_model_id': id});
    return _model(value);
  }

  @override
  Future<RoutineApplication> fetchApplication(String id) async {
    final value = await _singleRpc('superadmin_routine_application_detail', {
      'p_application_id': id,
    });
    return _application(value);
  }

  @override
  Future<RoutineLaunch> fetchLaunch(String id) async {
    final value = await _singleRpc('superadmin_routine_launch_detail', {'p_launch_id': id});
    return _launch(value);
  }

  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async {
    model.validate();
    final value = await _singleRpc('superadmin_routine_save_model', {
      'p_request_id': _stableUuid(requestId),
      'p_model_id': model.id.isEmpty ? null : model.id,
      'p_expected_version': model.expectedVersion,
      'p_payload': _modelPayload(model),
    });
    return _string(value['id']);
  }

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async {
    application.validate();
    final value = await _singleRpc('superadmin_routine_save_application', {
      'p_request_id': _stableUuid(requestId),
      'p_application_id': application.id.isEmpty ? null : application.id,
      'p_expected_version': application.expectedVersion,
      'p_payload': _applicationPayload(application),
    });
    return _string(value['id']);
  }

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    final value = await _singleRpc('superadmin_routine_revert_application', {
      'p_application_id': applicationId,
      'p_expected_version': expectedVersion,
      'p_request_id': _stableUuid(requestId),
    });
    return _string(value['id']);
  }

  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async {
    final value = await _singleRpc('superadmin_routine_save_launch_draft', {
      'p_request_id': _stableUuid(requestId),
      'p_launch_id': launch.id.isEmpty ? null : launch.id,
      'p_expected_version': launch.expectedVersion,
      'p_payload': _launchPayload(launch),
    });
    return _string(value['id']);
  }

  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async {
    await _client.rpc<Object?>(
      'superadmin_routine_publish_launch',
      params: {
        'p_launch_id': launchId,
        'p_expected_version': expectedVersion,
        'p_request_id': _stableUuid(requestId),
      },
    );
  }

  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 10 || normalizedReason.length > 500) {
      throw const FormatException('Informe um motivo entre 10 e 500 caracteres.');
    }
    await _client.rpc<Object?>(
      'superadmin_routine_correct_launch',
      params: {
        'p_launch_id': launchId,
        'p_expected_version': expectedVersion,
        'p_reason': normalizedReason,
        'p_request_id': _stableUuid(requestId),
        'p_payload': [
          for (final correction in corrections)
            {'answer_id': correction.answerId, 'value': correction.value},
        ],
      },
    );
  }

  Future<Map<String, Object?>> _singleRpc(String function, Map<String, Object?> params) async {
    final payload = await _client.rpc<Object?>(function, params: params);
    final rows = _rows(payload);
    if (rows.isEmpty) throw const RoutineNotFoundException();
    return rows.first;
  }
}

final class RoutineNotFoundException implements Exception {
  const RoutineNotFoundException();
}

List<Map<String, Object?>> _rows(Object? value) {
  if (value is List) {
    return value.map((row) => Map<String, Object?>.from(row as Map)).toList(growable: false);
  }
  if (value is Map) return [Map<String, Object?>.from(value)];
  return const [];
}

RoutineDirectoryItem _directoryItem(Map<String, Object?> row) => RoutineDirectoryItem(
  id: _string(row['id']),
  kind: RoutineEntryKind.values.byName(_string(row['kind'])),
  name: _string(row['name']),
  status: _string(row['status']),
  version: _integer(row['version']),
  originLabel: row['origin_label'] as String?,
  effectiveLabel: row['effective_label'] as String?,
);

RoutineModel _model(Map<String, Object?> row) {
  final definition = _map(row['definition']);
  return RoutineModel(
    id: _string(row['id']),
    name: _string(row['name']),
    description: row['description'] as String? ?? '',
    version: _integer(row['current_version'] ?? row['version']),
    expectedVersion: _integer(row['management_version']),
    status: RoutineModelStatus.values.byName(_string(row['status'])),
    canManage: row['can_manage'] == true,
    originScope: RoutineModelOriginScope.values.byName(_string(row['origin_scope_kind'])),
    institutionId: row['institution_id'] as String?,
    originUnitId: row['origin_unit_id'] as String?,
    sections: _sectionRows(
      definition?['sections'] ?? row['sections'],
      conditions: definition?['conditions'] ?? row['conditions'],
    ),
  );
}

RoutineApplication _application(Map<String, Object?> row) {
  final revision = _map(row['revision']);
  return RoutineApplication(
    id: _string(row['id']),
    modelVersionId: _string(revision?['source_model_version_id'] ?? row['source_model_version_id']),
    institutionId: _string(row['institution_id']),
    unitId: row['unit_id'] as String?,
    groupId: row['group_id'] as String?,
    parentApplicationId: row['parent_application_id'] as String?,
    activityId: row['activity_id'] as String?,
    status: RoutineApplicationStatus.values.byName(_string(row['status'])),
    inheritanceMode: RoutineInheritanceMode.values.byName(_string(row['inheritance_mode'])),
    effectiveVersion: _integer(revision?['revision_no'] ?? row['effective_version']),
    expectedVersion: _integer(row['management_version']),
    validFrom: _date(row['valid_from']),
    validUntil: _date(row['valid_until']),
    startsAt: _clockTime(row['starts_at']),
    endsAt: _clockTime(row['ends_at']),
    visibility: row['visibility'] as String? ?? 'authorized_guardians',
    canManage: row['can_manage'] == true,
    assignees: _assignees(row['assignees'] ?? row['assignee_membership_ids']),
  );
}

RoutineLaunch _launch(Map<String, Object?> row) => RoutineLaunch(
  id: _string(row['id']),
  applicationId: _string(row['application_id']),
  applicationRevisionId: _string(row['application_revision_id']),
  institutionId: _string(row['institution_id']),
  unitId: _string(row['unit_id']),
  groupId: _string(row['group_id']),
  activityId: row['activity_id'] as String?,
  authorMembershipId: _string(row['author_membership_id']),
  serviceDate: DateTime.parse(_string(row['service_date'])),
  status: RoutineLaunchStatus.values.byName(_string(row['status'])),
  expectedVersion: _integer(row['management_version']),
  children: _childEntries(row['children']),
  canManage: row['can_manage'] == true,
);

List<RoutineChildEntryDraft> _childEntries(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        final row = Map<String, Object?>.from(item as Map);
        return RoutineChildEntryDraft(
          entryId: row['id'] as String?,
          childContextId: _string(row['child_context_id']),
          childGroupLinkId: _string(row['child_group_link_id']),
          status: row['status'] as String? ?? 'draft',
          answers: _answerDrafts(row['answers']),
        );
      })
      .toList(growable: false);
}

List<RoutineAnswerDraft> _answerDrafts(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        final row = Map<String, Object?>.from(item as Map);
        return RoutineAnswerDraft(
          fieldId: _string(row['field_id']),
          value: row['value_json'] ?? row['value'],
        );
      })
      .toList(growable: false);
}

List<RoutineSection> _sectionRows(Object? raw, {Object? conditions}) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        final row = Map<String, Object?>.from(item as Map);
        return RoutineSection(
          id: _string(row['id']),
          name: _string(row['name']),
          sortOrder: _integer(row['order'] ?? row['sort_order']),
          fields: _fieldRows(row['fields'], conditions: conditions),
        );
      })
      .toList(growable: false);
}

List<RoutineField> _fieldRows(Object? raw, {Object? conditions}) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        final row = Map<String, Object?>.from(item as Map);
        return RoutineField(
          id: _string(row['id']),
          label: _string(row['label']),
          kind: _fieldKindFromDatabase(_string(row['kind'])),
          sortOrder: _integer(row['order'] ?? row['sort_order']),
          isRequired: (row['required'] ?? row['is_required']) == true,
          initialValue: row['initial_value'],
          minimumValue: (row['min_value'] ?? row['minimum_value']) as num?,
          maximumValue: (row['max_value'] ?? row['maximum_value']) as num?,
          options: _optionRows(row['options']),
          conditions: _conditionRows(
            row['conditions'] ?? conditions,
            targetFieldId: _string(row['id']),
          ),
        );
      })
      .toList(growable: false);
}

List<RoutineFieldOption> _optionRows(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        final row = Map<String, Object?>.from(item as Map);
        return RoutineFieldOption(
          id: _string(row['id']),
          label: _string(row['label']),
          sortOrder: _integer(row['order'] ?? row['sort_order']),
        );
      })
      .toList(growable: false);
}

List<RoutineCondition> _conditionRows(Object? raw, {required String targetFieldId}) {
  if (raw is! List) return const [];
  return raw
      .map((item) => Map<String, Object?>.from(item as Map))
      .where((row) => row['target_field_id'] == targetFieldId)
      .map((row) {
        final parentFieldId = _string(row['source_field_id'] ?? row['parent_field_id']);
        final optionId = (row['source_option_id'] ?? row['option_id']) as String?;
        final booleanValue = row['boolean_value'] as bool?;
        return RoutineCondition(
          id:
              row['id'] as String? ??
              [parentFieldId, targetFieldId, optionId ?? booleanValue].join(':'),
          parentFieldId: parentFieldId,
          targetFieldId: targetFieldId,
          optionId: optionId,
          booleanValue: booleanValue,
          depth: row['depth'] == null ? 1 : _integer(row['depth']),
        );
      })
      .toList(growable: false);
}

Map<String, Object?> _modelPayload(RoutineModel model) => {
  'name': model.name.trim(),
  'description': model.description.trim(),
  'status': model.status.name,
  'origin_scope_kind': model.originScope.name,
  'institution_id': model.institutionId,
  'origin_unit_id': model.originUnitId,
  'sections': [
    for (final section in model.sections)
      {
        'id': _stableUuid(section.id),
        'name': section.name.trim(),
        'order': section.sortOrder,
        'fields': [for (final field in section.fields) _fieldPayload(field)],
      },
  ],
  'conditions': [
    for (final field in model.sections.expand((section) => section.fields))
      for (final condition in field.conditions)
        {
          'source_field_id': _stableUuid(condition.parentFieldId),
          'target_field_id': _stableUuid(condition.targetFieldId),
          'source_option_id': condition.optionId == null ? null : _stableUuid(condition.optionId!),
          'boolean_value': condition.booleanValue,
        },
  ],
};

Map<String, Object?> _fieldPayload(RoutineField field) => {
  'id': _stableUuid(field.id),
  'label': field.label.trim(),
  'kind': _fieldKindToDatabase(field.kind),
  'order': field.sortOrder,
  'required': field.isRequired,
  'initial_value': field.initialValue,
  'min_value': field.minimumValue,
  'max_value': field.maximumValue,
  'options': [
    for (final option in field.options)
      {
        'id': _stableUuid(option.id),
        'label': option.label.trim(),
        'value': option.id,
        'order': option.sortOrder,
      },
  ],
};

Map<String, Object?> _applicationPayload(RoutineApplication value) => {
  'id': value.id,
  'source_model_version_id': value.modelVersionId,
  'scope_kind': value.groupId != null ? 'group' : (value.unitId != null ? 'unit' : 'institution'),
  'institution_id': value.institutionId,
  'unit_id': value.unitId,
  'group_id': value.groupId,
  'parent_application_id': value.parentApplicationId,
  'activity_id': value.activityId,
  'status': value.status.name,
  'inheritance_mode': value.inheritanceMode.name,
  'effective_version': value.effectiveVersion,
  'valid_from': value.validFrom?.toIso8601String(),
  'valid_until': value.validUntil?.toIso8601String(),
  'starts_at': value.startsAt,
  'ends_at': value.endsAt,
  'visibility': value.visibility,
  'assignees': [
    for (final assignee in value.assignees)
      {'membership_id': assignee.membershipId, 'responsibility': assignee.responsibility.name},
  ],
};

Map<String, Object?> _launchPayload(RoutineLaunch value) => {
  'application_id': value.applicationId,
  'application_revision_id': value.applicationRevisionId,
  'institution_id': value.institutionId,
  'unit_id': value.unitId,
  'group_id': value.groupId,
  'activity_id': value.activityId,
  'author_membership_id': value.authorMembershipId,
  'service_date': value.serviceDate.toIso8601String().substring(0, 10),
  'children': [
    for (final child in value.children)
      {
        'entry_id': child.entryId,
        'child_context_id': child.childContextId,
        'child_group_link_id': child.childGroupLinkId,
        'status': child.status,
        'answers': [
          for (final answer in child.answers) {'field_id': answer.fieldId, 'value': answer.value},
        ],
      },
  ],
};

String _stableUuid(String value) {
  if (RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    return value.toLowerCase();
  }
  final bytes = sha256.convert(utf8.encode(value)).bytes.take(16).toList(growable: false);
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-5${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
}

String _fieldKindToDatabase(RoutineFieldKind kind) => switch (kind) {
  RoutineFieldKind.shortText => 'short_text',
  RoutineFieldKind.longText => 'long_text',
  RoutineFieldKind.singleChoice => 'single_choice',
  RoutineFieldKind.multipleChoice => 'multiple_choice',
  RoutineFieldKind.number => 'number',
  RoutineFieldKind.boolean => 'boolean',
};

RoutineFieldKind _fieldKindFromDatabase(String value) => switch (value) {
  'short_text' => RoutineFieldKind.shortText,
  'long_text' => RoutineFieldKind.longText,
  'single_choice' => RoutineFieldKind.singleChoice,
  'multiple_choice' => RoutineFieldKind.multipleChoice,
  'number' => RoutineFieldKind.number,
  'boolean' => RoutineFieldKind.boolean,
  _ => throw const FormatException('Tipo de campo invalido.'),
};

String _string(Object? value) {
  if (value is! String || value.isEmpty) throw const FormatException('Resposta invalida.');
  return value;
}

int _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.parse(text),
  _ => throw const FormatException('Numero invalido.'),
};

DateTime? _date(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

String? _clockTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final match = RegExp(r'^(\d{2}:\d{2})').firstMatch(value);
  if (match == null) throw const FormatException('Horario invalido.');
  return match.group(1);
}

Map<String, Object?>? _map(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;

List<RoutineApplicationAssignee> _assignees(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => Map<String, Object?>.from(item))
      .map(
        (item) => RoutineApplicationAssignee(
          membershipId: _string(item['membership_id']),
          responsibility: RoutineApplicationResponsibility.values.byName(
            item['responsibility'] as String? ?? RoutineApplicationResponsibility.record.name,
          ),
        ),
      )
      .toList(growable: false);
}
