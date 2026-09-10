import 'dart:convert';
import 'dart:math' as math;

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_command.dart';
import '../domain/activity_directory.dart';

/// Production mutations stay closed unless one Flutter command maps to one
/// approved internal transaction. Template creation has that equivalence.
final class SupabaseActivityCommandRepository implements ActivityCommandRepository {
  const SupabaseActivityCommandRepository(
    this._client, {
    this.activityLocationCreateAvailable = false,
  });

  final SupabaseClient _client;

  /// Composition gate only; does not authorize an actor or deploy the candidate.
  final bool activityLocationCreateAvailable;

  Future<T> _unavailable<T>() => Future.error(const ActivityCommandUnavailableException());

  @override
  Future<ActivitySaveResult> save(ActivitySaveCommand command) async {
    if (!_supportsAggregateSave(command)) return _unavailable();
    if (command.locationSelection != null || command.reservation != null) {
      if (!activityLocationCreateAvailable || command.locationSelection == null) {
        return _unavailable();
      }
      return _saveWithCataloguedLocation(command);
    }
    try {
      final envelope = _asMap(
        await _client.rpc<Object?>(
          'superadmin_activity_save_v2',
          params: {
            'p_request_id': _normalizeRequestId(command.requestId),
            'p_activity_id': command.activityId,
            'p_expected_version': command.expectedVersion,
            'p_publish': command.intent == ActivityCommandIntent.publish,
            'p_payload': _activitySavePayload(command),
          },
        ),
      );
      if (envelope['ok'] != true) throw _mapEnvelopeError(envelope);
      final data = _asMap(envelope['data']);
      final activityId = data['activity_id'];
      final managementVersion = data['management_version'];
      final statusValue = data['status'];
      if (activityId is! String ||
          activityId.trim().isEmpty ||
          (command.activityId != null && activityId != command.activityId) ||
          managementVersion is! int ||
          managementVersion < 1 ||
          statusValue is! String) {
        throw const ActivityCommandUnavailableException();
      }
      final status = ActivityStatus.values
          .where((item) => item.databaseValue == statusValue)
          .firstOrNull;
      if (status == null || status != ActivityStatus.draft) {
        throw const ActivityCommandUnavailableException();
      }
      return ActivitySaveResult(
        activityId: activityId,
        managementVersion: managementVersion,
        status: ActivityStatus.draft,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ActivitySaveResult> _saveWithCataloguedLocation(ActivitySaveCommand command) async {
    try {
      final selection = command.locationSelection!.snapshot;
      final locationId = _atomicId(selection.id);
      final institutionId = _atomicId(command.institutionId);
      if (_atomicId(selection.scope.institutionId) != institutionId) _invalidAtomic();
      if (selection.scope case UnitLocationScope(:final unitId)) {
        if (!command.unitIds.map(_atomicId).contains(_atomicId(unitId))) _invalidAtomic();
      }
      final envelope = _atomicMap(
        await _client.rpc<Object?>(
          'superadmin_activity_location_create_v2',
          params: {
            'p_request_id': _atomicId(command.requestId),
            'p_location_id': locationId,
            'p_activity_payload': _activitySavePayload(command),
            'p_reservation': command.reservation?.toJson(),
          },
        ),
        const {'ok', 'data', 'error'},
      );
      if (envelope['ok'] is! bool) _invalidAtomic();
      if (envelope['ok'] == false) {
        if (envelope['data'] != null) _invalidAtomic();
        final error = _atomicMap(envelope['error'], const {
          'code',
          'message',
          'correlation_id',
          'http_status',
        });
        if (error['code'] is! String ||
            (error['code'] as String).trim().isEmpty ||
            error['message'] is! String ||
            error['http_status'] is! int ||
            (error['http_status'] as int) < 400 ||
            (error['http_status'] as int) > 599) {
          _invalidAtomic();
        }
        _atomicId(error['correlation_id']);
        throw _mapEnvelopeError(envelope);
      }
      if (envelope['error'] != null) _invalidAtomic();
      final data = _atomicMap(envelope['data'], const {
        'activity_id',
        'management_version',
        'status',
        'correlation_id',
        'replayed',
        'location_id',
        'reservation',
      });
      final activityId = _atomicId(data['activity_id']);
      _atomicId(data['correlation_id']);
      final version = data['management_version'];
      if (_atomicId(data['location_id']) != locationId ||
          data['status'] != 'draft' ||
          data['replayed'] is! bool ||
          version is! int ||
          version < 1 ||
          version > 9007199254740991 ||
          (command.reservation == null) != (data['reservation'] == null)) {
        _invalidAtomic();
      }
      final reservation = data['reservation'] == null
          ? null
          : decodeLocationReservationV2(
              data['reservation'],
              requestedLocationId: locationId,
              requestedConsumer: LocationReservationConsumer(
                kind: LocationReservationConsumerKind.activity,
                id: activityId,
              ),
            );
      if (reservation != null &&
          (reservation.state != LocationReservationState.active ||
              reservation.managementVersion > 9007199254740991)) {
        _invalidAtomic();
      }
      return ActivitySaveResult(
        activityId: activityId,
        managementVersion: version,
        status: ActivityStatus.draft,
        locationId: locationId,
        reservation: reservation,
      );
    } on ActivityCommandUnauthorizedException {
      rethrow;
    } on ActivityCommandConflictException {
      rethrow;
    } on ActivityCommandUnavailableException {
      rethrow;
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' || 'PGRST301' || 'PGRST302' => const ActivityCommandUnauthorizedException(),
        '40001' => const ActivityCommandConflictException(),
        _ => const ActivityCommandUnavailableException(),
      };
    } on Object {
      throw const ActivityCommandUnavailableException();
    }
  }

  @override
  Future<ActivityTemplateCopyResult> copyTemplate(ActivityTemplateCopyCommand command) =>
      _unavailable();

  @override
  Future<List<ActivityLocationResult>> createLocations(ActivityLocationCommand command) =>
      _unavailable();

  @override
  Future<ActivityExportResult> requestExport(
    ActivityDirectoryQuery query, {
    required ActivityCommandExportFormat format,
  }) => _unavailable();

  @override
  Future<ActivityTemplateCreateResult> createTemplate(ActivityTemplateCreateCommand command) async {
    try {
      final response = _asMap(
        await _client.rpc<Object?>(
          'superadmin_create_scoped_activity_template',
          params: {
            'p_institution_id': command.institutionId,
            'p_unit_id': command.unitId,
            'p_name': command.name.trim(),
            'p_description': command.description.trim(),
            'p_taxonomy_id': command.taxonomyId,
            'p_governance_kind': command.governance.databaseValue,
            'p_idempotency_key': _normalizeRequestId(command.requestId),
          },
        ),
      );
      final id = response['id'];
      final institutionId = response['institution_id'];
      final unitId = response['unit_id'];
      final name = response['name'];
      if (id is! String ||
          id.trim().isEmpty ||
          institutionId is! String ||
          institutionId != command.institutionId ||
          unitId != command.unitId ||
          name is! String) {
        throw const ActivityCommandUnavailableException();
      }
      return ActivityTemplateCreateResult(
        id: id,
        institutionId: institutionId,
        unitId: unitId as String?,
        name: name,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

const _activityCapabilities = ['attendance', 'chat', 'happens', 'moments', 'now'];

String _atomicId(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    _invalidAtomic();
  }
  return value.toLowerCase();
}

Map<String, dynamic> _atomicMap(Object? value, Set<String> keys) {
  if (value is! Map || value.length != keys.length || !keys.every(value.containsKey)) {
    _invalidAtomic();
  }
  return Map<String, dynamic>.from(value);
}

Never _invalidAtomic() => throw const ActivityCommandUnavailableException();

bool _supportsAggregateSave(ActivitySaveCommand command) {
  final pedagogical = command.pedagogicalConfiguration;
  return command.intent == ActivityCommandIntent.saveDraft &&
      command.activityId == null &&
      command.expectedVersion == 0 &&
      command.governance == ActivityGovernance.optional &&
      command.templateId == null &&
      command.unitId == null &&
      command.groupParticipation.length == command.groupIds.length &&
      command.groupIds.every(command.groupParticipation.containsKey) &&
      (command.handleStem == null || command.handleStem!.trim().isEmpty) &&
      command.taxonomyOtherDescription.trim().isEmpty &&
      pedagogical.length == 1 &&
      pedagogical['enabled'] == false &&
      command.expectedAssessmentVersion == null &&
      command.assessmentChangeJustification.trim().isEmpty &&
      command.identity.kind == ActivityIdentityKind.initials &&
      command.identity.initials.trim().isNotEmpty &&
      command.identity.initials.trim().length <= 2 &&
      command.identity.color.toUpperCase() == '#D63C00' &&
      !command.identity.preserveExisting &&
      command.identity.imageName == null &&
      command.identity.imageBytes == null;
}

Map<String, Object?> _activitySavePayload(ActivitySaveCommand command) {
  final groupIds = command.groupIds.toList()..sort();
  final unitIds = command.unitIds.toList()..sort();
  final participants = command.participants.toList()
    ..sort((left, right) {
      final groupOrder = left.groupId.compareTo(right.groupId);
      return groupOrder != 0 ? groupOrder : left.childGroupLinkId.compareTo(right.childGroupLinkId);
    });
  final assignments = command.assignments.toList()
    ..sort((left, right) {
      final groupOrder = (left.groupId ?? '').compareTo(right.groupId ?? '');
      if (groupOrder != 0) return groupOrder;
      final membershipOrder = left.membershipId.compareTo(right.membershipId);
      return membershipOrder != 0 ? membershipOrder : left.role.name.compareTo(right.role.name);
    });
  return {
    'institution_id': command.institutionId,
    'definition': {
      'name': command.name.trim(),
      'description': command.description.trim(),
      'taxonomy_id': command.taxonomyId,
      'icon_key': command.identity.icon.trim().isEmpty ? null : command.identity.icon.trim(),
      'initials': command.identity.initials.trim(),
    },
    'unit_ids': unitIds,
    'group_ids': groupIds,
    'group_participation': {
      for (final groupId in groupIds)
        groupId: (command.groupParticipation[groupId] ?? ActivityParticipation.all).databaseValue,
    },
    'participants': [
      for (final participant in participants)
        {
          'group_id': participant.groupId,
          'child_group_link_id': participant.childGroupLinkId,
          'belongs': participant.belongs,
        },
    ],
    'professional_assignments': [
      for (final assignment in assignments)
        {
          'membership_id': assignment.membershipId,
          'role': assignment.role.databaseValue,
          'group_id': assignment.role == ActivityCommandProfessionalRole.activityAdmin
              ? null
              : assignment.groupId,
        },
    ],
    'capability_policies': {for (final capability in _activityCapabilities) capability: null},
    'group_capability_settings': const <Object?>[],
    'professional_capability_actions': [
      for (final assignment in assignments)
        {
          'membership_id': assignment.membershipId,
          'role': assignment.role.databaseValue,
          'group_id': assignment.role == ActivityCommandProfessionalRole.activityAdmin
              ? null
              : assignment.groupId,
          'actions': {
            for (final capability in _activityCapabilities)
              capability:
                  (assignment.permissions[capability] ?? ActivityProfessionalAccessLevel.none)
                      .databaseValue,
          },
        },
    ],
  };
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const ActivityCommandUnavailableException();
}

Exception _mapError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' => const ActivityCommandUnauthorizedException(),
  '40001' || 'P0001' when error.message.toLowerCase().contains('version') =>
    const ActivityCommandConflictException(),
  _ => const ActivityCommandUnavailableException(),
};

Exception _mapEnvelopeError(Map<String, dynamic> envelope) {
  final error = envelope['error'];
  final code = error is Map ? error['code'] : null;
  return switch (code) {
    'SAI_CONCURRENT_CHANGE' => const ActivityCommandConflictException(),
    'SAI_AUTH_REQUIRED' ||
    'SAI_SESSION_INVALID' ||
    'SAI_INTERNAL_CONTEXT_DENIED' ||
    'SAI_MEMBERSHIP_SUSPENDED' ||
    'SAI_MEMBERSHIP_REVOKED' ||
    'SAI_PERMISSION_DENIED' ||
    'SAI_MFA_REQUIRED' => const ActivityCommandUnauthorizedException(),
    _ => const ActivityCommandUnavailableException(),
  };
}

String _normalizeRequestId(String value) {
  final candidate = value.trim().toLowerCase();
  final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
  return uuid.hasMatch(candidate) ? candidate : _uuidFromSeed(candidate);
}

String _uuidFromSeed(String seed) {
  final bytes = utf8.encode(seed.isEmpty ? 'coelo-activity-command' : seed);
  var first = 0x811c9dc5;
  var second = 0x9e3779b9;
  for (final byte in bytes) {
    first = ((first ^ byte) * 0x01000193) & 0xffffffff;
    second = ((second + byte) * 0x85ebca6b) & 0xffffffff;
  }
  final random = math.Random((first << 32) ^ second);
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((item) => item.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
