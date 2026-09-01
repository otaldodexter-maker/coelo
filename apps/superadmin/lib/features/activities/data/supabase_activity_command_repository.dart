import 'dart:convert';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_command.dart';
import '../domain/activity_directory.dart';

/// Production mutations stay closed unless one Flutter command maps to one
/// approved internal transaction. Template creation has that equivalence.
final class SupabaseActivityCommandRepository implements ActivityCommandRepository {
  const SupabaseActivityCommandRepository(this._client);

  final SupabaseClient _client;

  Future<T> _unavailable<T>() => Future.error(const ActivityCommandUnavailableException());

  @override
  Future<ActivitySaveResult> save(ActivitySaveCommand command) => _unavailable();

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
      return ActivityTemplateCreateResult(
        id: response['id'] as String,
        institutionId: response['institution_id'] as String,
        unitId: response['unit_id'] as String?,
        name: response['name'] as String,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }
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
  final hex = values.map((item) => item.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
