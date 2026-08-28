import 'dart:convert';

import '../../domain/activity_command.dart';
import '../../domain/activity_directory.dart';
import 'dev_activity_session_store.dart';

final class DevActivityCommandRepository implements ActivityCommandRepository {
  DevActivityCommandRepository({required DevActivitySessionStore store}) : _store = store;

  final DevActivitySessionStore _store;
  final Map<String, ActivitySaveResult> _requests = {};
  final Map<String, String> _requestFingerprints = {};
  final Map<String, int> _versions = {};
  var _nextId = 1;
  var _nextTemplateId = 1;
  var _nextLocationId = 1;

  @override
  Future<ActivitySaveResult> save(ActivitySaveCommand command) async {
    _store.guardCommand();
    final fingerprint = jsonEncode(_canonicalize(_commandPayload(command)));
    final previous = _requests[command.requestId];
    if (previous != null) {
      if (_requestFingerprints[command.requestId] != fingerprint) {
        throw const ActivityCommandConflictException();
      }
      return previous;
    }
    final id = command.activityId ?? 'dev-activity-${_nextId++}';
    final currentVersion = _versions[id] ?? _store.detail(id)?.item.managementVersion ?? 0;
    if (command.activityId != null && command.expectedVersion != currentVersion) {
      throw const ActivityCommandConflictException();
    }
    final result = ActivitySaveResult(
      activityId: id,
      managementVersion: currentVersion + 1,
      status: command.intent == ActivityCommandIntent.publish
          ? ActivityStatus.active
          : ActivityStatus.draft,
    );
    _versions[id] = result.managementVersion;
    _requests[command.requestId] = result;
    _requestFingerprints[command.requestId] = fingerprint;
    _store.upsert(command, result);
    return result;
  }

  @override
  Future<ActivityTemplateCreateResult> createTemplate(
    ActivityTemplateCreateCommand command,
  ) async => ActivityTemplateCreateResult(
    id: 'dev-template-${_nextTemplateId++}',
    institutionId: command.institutionId,
    name: command.name,
  );

  @override
  Future<ActivityTemplateCopyResult> copyTemplate(ActivityTemplateCopyCommand command) async =>
      ActivityTemplateCopyResult(
        id: 'dev-template-${_nextTemplateId++}',
        institutionId: command.institutionId,
        name: 'Cópia de ${command.templateId}',
      );

  @override
  Future<List<ActivityLocationResult>> createLocations(ActivityLocationCommand command) async => [
    for (final unitId in command.unitIds)
      ActivityLocationResult(
        id: 'dev-location-${_nextLocationId++}',
        unitId: unitId,
        name: command.name,
      ),
  ];

  @override
  Future<ActivityExportResult> requestExport(
    ActivityDirectoryQuery query, {
    required ActivityCommandExportFormat format,
  }) async => throw const ActivityCommandUnavailableException();

  Map<String, Object?> _commandPayload(ActivitySaveCommand command) => {
    'activity_id': command.activityId,
    'intent': command.intent.name,
    'expected_version': command.expectedVersion,
    'expected_assessment_version': command.expectedAssessmentVersion,
    'assessment_change_justification': command.assessmentChangeJustification,
    'pedagogical_configuration': command.pedagogicalConfiguration,
    'name': command.name,
    'description': command.description,
    'institution_id': command.institutionId,
    'taxonomy_id': command.taxonomyId,
    'taxonomy_other_description': command.taxonomyOtherDescription,
    'governance': command.governance.name,
    'handle_stem': command.handleStem,
    'template_id': command.templateId,
    'identity': {
      'kind': command.identity.kind.name,
      'initials': command.identity.initials,
      'color': command.identity.color,
      'icon': command.identity.icon,
      'preserve_existing': command.identity.preserveExisting,
      'image_name': command.identity.imageName,
      'image_bytes': command.identity.imageBytes == null
          ? null
          : base64Encode(command.identity.imageBytes!),
    },
    'unit_ids': command.unitIds.toList()..sort(),
    'group_ids': command.groupIds.toList()..sort(),
    'assignments': [
      for (final assignment in command.assignments)
        {
          'group_id': assignment.groupId,
          'membership_id': assignment.membershipId,
          'role': assignment.role.name,
          'permissions': {
            for (final entry in assignment.permissions.entries) entry.key: entry.value.name,
          },
        },
    ],
    'participants': [
      for (final participant in command.participants)
        {
          'group_id': participant.groupId,
          'child_group_link_id': participant.childGroupLinkId,
          'belongs': participant.belongs,
        },
    ],
  };

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((left, right) => left.key.toString().compareTo(right.key.toString()));
      return {for (final entry in entries) entry.key: _canonicalize(entry.value)};
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }
}
