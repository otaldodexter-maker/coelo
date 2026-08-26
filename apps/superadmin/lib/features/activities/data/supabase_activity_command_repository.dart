import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_command.dart';
import '../domain/activity_directory.dart';

final class SupabaseActivityCommandRepository implements ActivityCommandRepository {
  const SupabaseActivityCommandRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ActivityTemplateCreateResult> createTemplate(ActivityTemplateCreateCommand command) async {
    try {
      final response = _asMap(
        await _client.rpc<Object?>(
          'superadmin_create_activity_template',
          params: {
            'p_institution_id': command.institutionId,
            'p_name': command.name.trim(),
            'p_description': command.description.trim(),
            'p_taxonomy_id': command.taxonomyId,
            'p_governance_kind': command.governance.databaseValue,
            'p_idempotency_key': _normalizeRequestId(command.requestId),
          },
        ),
      );
      return ActivityTemplateCreateResult(
        id: response['id'] as String,
        institutionId: response['institution_id'] as String,
        name: response['name'] as String,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityTemplateCopyResult> copyTemplate(ActivityTemplateCopyCommand command) async {
    try {
      final response = _asMap(
        await _client.rpc<Object?>(
          'superadmin_copy_activity_template',
          params: {
            'p_template_id': command.templateId,
            'p_institution_id': command.institutionId,
            'p_idempotency_key': _normalizeRequestId(command.requestId),
          },
        ),
      );
      return ActivityTemplateCopyResult(
        id: response['id'] as String,
        institutionId: response['institution_id'] as String,
        name: response['name'] as String,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivitySaveResult> save(ActivitySaveCommand command) async {
    try {
      final activityId = command.activityId ?? _uuidV4();
      final response = _asMap(
        await _client.rpc<Object?>(
          'superadmin_upsert_activity',
          params: {
            'p_payload': _savePayload(command, activityId),
            'p_idempotency_key': _normalizeRequestId(command.requestId),
          },
        ),
      );
      final result = _saveResult(response);
      await _uploadIdentityIfNeeded(command, result.activityId);
      return result;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<ActivityLocationResult>> createLocations(ActivityLocationCommand command) async {
    try {
      final payload = await _client.rpc<Object?>(
        'superadmin_create_activity_locations',
        params: {
          'p_institution_id': command.institutionId,
          'p_unit_ids': command.unitIds.toList(growable: false),
          'p_name': command.name.trim(),
          'p_idempotency_key': _normalizeRequestId(command.requestId),
        },
      );
      if (payload is! List) throw const ActivityCommandUnavailableException();
      final rows = payload;
      return rows
          .map(_asMap)
          .map(
            (row) => ActivityLocationResult(
              id: row['id'] as String,
              unitId: row['unit_id'] as String,
              name: row['name'] as String,
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ActivityExportResult> requestExport(
    ActivityDirectoryQuery query, {
    required ActivityCommandExportFormat format,
  }) async {
    try {
      final payload = _asMap(
        await _client.rpc<Object?>(
          'superadmin_request_activity_export',
          params: {
            'p_format': format.name,
            'p_filters': {
              'search': query.search,
              'institution_ids': query.institutionIds.toList(growable: false),
              'unit_ids': query.unitIds.toList(growable: false),
              'group_ids': query.groupIds.toList(growable: false),
              'statuses': query.statuses
                  .map((status) => status.databaseValue)
                  .toList(growable: false),
              'origins': query.origins
                  .map((origin) => origin.databaseValue)
                  .toList(growable: false),
            },
            'p_idempotency_key': _uuidV4(),
          },
        ),
      );
      final jobId = payload['job_id'] as String;
      final response = await _client.functions.invoke(
        'group-files',
        body: {'action': 'export', 'entity': 'activities', 'job_id': jobId},
      );
      final downloadUrl = _asMap(response.data)['download_url']?.toString();
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw const ActivityCommandUnavailableException();
      }
      return ActivityExportResult(jobId: jobId, downloadUrl: downloadUrl);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
}

ActivitySaveResult _saveResult(Map<String, dynamic> response) {
  final payload = response['activity'] is Map ? _asMap(response['activity']) : response;
  return ActivitySaveResult(
    activityId: payload['id'] as String,
    managementVersion: (payload['management_version'] as num?)?.toInt() ?? 1,
    status: ActivityStatus.fromDatabase(payload['status'] as String),
  );
}

Map<String, Object?> _savePayload(ActivitySaveCommand command, String activityId) => {
  'id': activityId,
  'expected_version': command.expectedVersion,
  'institution_id': command.institutionId,
  if (command.activityId == null && command.templateId != null) 'template_id': command.templateId,
  'name': command.name.trim(),
  'description': command.description.trim(),
  if (command.handleStem?.trim().isNotEmpty == true) 'handle_stem': command.handleStem!.trim(),
  'origin_scope_kind': 'institution',
  'origin_unit_id': null,
  'taxonomy_id': command.taxonomyId,
  'taxonomy_other_description': command.taxonomyOtherDescription.trim().isEmpty
      ? null
      : command.taxonomyOtherDescription.trim(),
  'governance_kind': command.governance.databaseValue,
  'status': command.intent == ActivityCommandIntent.saveDraft ? 'draft' : 'active',
  'unit_ids': command.unitIds.toList(growable: false),
  'group_ids': command.groupIds.toList(growable: false),
  'participants': [
    for (final participant in command.participants)
      {
        'group_id': participant.groupId,
        'child_group_link_id': participant.childGroupLinkId,
        'belongs': participant.belongs,
      },
  ],
  'professional_assignments': [
    for (final assignment in command.assignments)
      {
        'group_id': assignment.groupId,
        'membership_id': assignment.membershipId,
        'role': assignment.role.databaseValue,
        'capabilities': assignment.permissions.map(
          (capability, level) => MapEntry(capability, level.databaseValue),
        ),
      },
  ],
  if (!command.identity.preserveExisting) ...{
    'identity_mode': command.identity.kind == ActivityIdentityKind.image
        ? command.identity.initials.trim().isNotEmpty
              ? 'initials'
              : 'icon'
        : command.identity.kind.name,
    'identity_initials': command.identity.initials.trim(),
    'identity_color': command.identity.color,
    'identity_icon': command.identity.icon,
  },
};

extension on SupabaseActivityCommandRepository {
  Future<void> _uploadIdentityIfNeeded(ActivitySaveCommand command, String activityId) async {
    final bytes = command.identity.imageBytes;
    final fileName = command.identity.imageName;
    if (bytes == null || fileName == null) return;
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw const ActivityCommandUnavailableException();
    }
    final mimeType = _identityMimeType(fileName);
    final prepareRequestId = _normalizeRequestId('${command.requestId}-identity-prepare');
    final finalizeRequestId = _normalizeRequestId('${command.requestId}-identity-finalize');
    final prepared = _asMap(
      await _client.rpc<Object?>(
        'superadmin_prepare_activity_identity_upload',
        params: {
          'p_activity_id': activityId,
          'p_file_name': fileName,
          'p_mime_type': mimeType,
          'p_size_bytes': bytes.length,
          'p_idempotency_key': prepareRequestId,
        },
      ),
    );
    final bucket = prepared['bucket'] as String;
    final path = prepared['path'] as String;
    final storage = _client.storage.from(bucket);
    final signed = await storage.createSignedUploadUrl(path);
    await storage.uploadBinaryToSignedUrl(
      path,
      signed.token,
      bytes,
      FileOptions(contentType: mimeType, upsert: false),
    );
    await _client.rpc<Object?>(
      'superadmin_finalize_activity_identity_upload',
      params: {
        'p_activity_id': activityId,
        'p_storage_path': path,
        'p_mime_type': mimeType,
        'p_size_bytes': bytes.length,
        'p_checksum_sha256': sha256.convert(bytes).toString(),
        'p_idempotency_key': finalizeRequestId,
      },
    );
  }
}

String _identityMimeType(String fileName) {
  final normalized = fileName.trim().toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) return 'image/jpeg';
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.webp')) return 'image/webp';
  throw const ActivityCommandUnavailableException();
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
  return _formatUuid(values);
}

String _uuidV4() {
  final random = math.Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  return _formatUuid(values);
}

String _formatUuid(List<int> values) {
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
