import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/circular.dart';
import '../domain/circular_repository.dart';
import '../domain/circular_serialization.dart';

final class SupabaseCircularRepository implements CircularRepository {
  const SupabaseCircularRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async {
    try {
      final response = await _client.rpc<Object?>(
        'load_circular_draft',
        params: _scopeParams(scope),
      );
      if (response == null) return null;
      return CircularDraftCodec.fromJson(Map<String, dynamic>.from(response as Map));
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    final issues = draft.validate();
    if (issues.isNotEmpty) throw CircularInvalid(issues.first.code.name);
    final payload = CircularDraftCodec.toJson(draft)
      ..addAll({
        'institution_id': scope.institutionId,
        'unit_id': scope.unitId,
        'group_id': scope.groupId,
        'activity_id': scope.activityId,
        'audiences': [for (final audience in draft.audiences) _audienceRule(audience, scope)],
      });
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'save_circular_draft',
        params: {
          'p_request_id': requestId,
          'p_draft': payload,
          'p_circular_id': draft.id.isEmpty ? null : draft.id,
          'p_expected_version': draft.expectedVersion,
        },
      );
      return _saveResult(response);
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'publish_circular',
        params: {
          'p_request_id': requestId,
          'p_circular_id': circularId,
          'p_expected_version': expectedVersion,
          'p_publish_at': publishAt?.toUtc().toIso8601String(),
        },
      );
      return _saveResult(response);
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_visible_profile_circulars',
        params: {
          ..._scopeParams(scope),
          'p_before_at': cursor?.publishedAt.toUtc().toIso8601String(),
          'p_before_id': cursor?.itemId,
          'p_limit': limit,
        },
      );
      final items = response
          .map((row) => _summary(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      final last = items.lastOrNull;
      return PrincipalCursorPage(
        items: items,
        nextCursor: items.length < limit || last == null
            ? null
            : CircularCursor(publishedAt: last.publishedAt, itemId: last.id),
      );
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'get_visible_circular',
        params: {'p_circular_id': circularId, 'p_child_context_id': childContextId},
      );
      final draftJson = <String, dynamic>{
        ...response,
        'version': 1,
        'response_policy': response['response_policy'] ?? 'per_person',
      };
      final draft = CircularDraftCodec.fromJson(draftJson);
      return CircularDetail(
        id: _text(response, 'id'),
        revisionId: _text(response, 'revision_id'),
        title: draft.title,
        authorName: response['author_name'] as String? ?? '',
        contextLabel: response['context_label'] as String? ?? '',
        publishedAt: _date(response, 'published_at'),
        revisedAt: _optionalDate(response['revised_at']),
        responsesCloseAt: _optionalDate(response['responses_close_at']),
        blocks: draft.blocks,
        status: _status(response['status']),
        responseState: _responseState(response['response_state']),
        initialAnswers: _answers(response['answers']),
        responseSessionId: response['response_session_id'] as String?,
        responseVersion: response['response_version'] is num
            ? (response['response_version'] as num).toInt()
            : 0,
      );
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'close_circular_responses',
        params: {
          'p_request_id': requestId,
          'p_circular_id': circularId,
          'p_expected_version': expectedVersion,
        },
      );
      return CircularSaveResult(
        id: _text(response, 'id'),
        revisionId: response['revision_id'] as String? ?? '',
        version: _integer(response, 'version'),
        status: _status(response['status']),
      );
    } on Object catch (error) {
      throw _failure(error);
    }
  }

  Future<CircularSaveResult> delete({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'delete_circular',
        params: {
          'p_request_id': requestId,
          'p_circular_id': circularId,
          'p_expected_version': expectedVersion,
        },
      );
      return CircularSaveResult(
        id: _text(response, 'id'),
        revisionId: response['revision_id'] as String? ?? '',
        version: _integer(response, 'version'),
        status: _status(response['status']),
      );
    } on Object catch (error) {
      throw _failure(error);
    }
  }
}

Map<String, List<String>> _answers(Object? value) {
  if (value == null) return const {};
  if (value is! Map) throw const FormatException('invalid_answers');
  return {
    for (final entry in value.entries)
      entry.key.toString(): switch (entry.value) {
        final List<dynamic> options => options.map((option) => option.toString()).toList(),
        _ => throw const FormatException('invalid_answer_options'),
      },
  };
}

Map<String, dynamic> _scopeParams(CircularScope scope) => {
  'p_institution_id': scope.institutionId,
  'p_unit_id': scope.unitId,
  'p_group_id': scope.groupId,
  'p_activity_id': scope.activityId,
};

Map<String, dynamic> _audienceRule(CircularAudienceKind audience, CircularScope scope) {
  final scopeKind = scope.activityId != null
      ? 'activity'
      : scope.groupId != null
      ? 'group'
      : scope.unitId != null
      ? 'unit'
      : 'institution';
  return {
    'kind': switch (audience) {
      CircularAudienceKind.families => 'families',
      CircularAudienceKind.students => 'students',
      CircularAudienceKind.schoolStaff => 'school_staff',
      CircularAudienceKind.guardiansOnly => 'guardians_only',
    },
    'scope': scopeKind,
    'unit_id': scopeKind == 'unit' || scopeKind == 'group' ? scope.unitId : null,
    'group_id': scopeKind == 'group' ? scope.groupId : null,
    'activity_id': scopeKind == 'activity' ? scope.activityId : null,
  };
}

CircularSaveResult _saveResult(Map<String, dynamic> json) => CircularSaveResult(
  id: _text(json, 'id'),
  revisionId: _text(json, 'revision_id'),
  version: _integer(json, 'version'),
  status: _status(json['status']),
);

CircularSummary _summary(Map<String, dynamic> json) => CircularSummary(
  id: _text(json, 'item_id'),
  title: _text(json, 'title'),
  excerpt: json['excerpt'] as String? ?? '',
  authorName: _text(json, 'author_name'),
  contextLabel: _text(json, 'context_label'),
  publishedAt: _date(json, 'effective_published_at'),
  revisedAt: _optionalDate(json['revised_at']),
  attachmentCount: _integer(json, 'attachment_count'),
  questionCount: _integer(json, 'question_count'),
  responseState: _responseState(json['response_state']),
);

CircularFailure _failure(Object error) {
  if (error is CircularFailure) return error;
  if (error is PostgrestException) {
    if (error.message.contains('circular_not_available')) {
      return const CircularNotAvailable();
    }
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const CircularUnauthorized();
    }
    if (error.code == '40001' || error.message.contains('expected_version_conflict')) {
      return const CircularVersionConflict();
    }
    if (error.code == '23514' || error.code == 'P0001') {
      return CircularInvalid(error.message);
    }
  }
  return const CircularUnavailable();
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('invalid_$key');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('invalid_$key');
  return value;
}

DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

CircularStatus _status(Object? value) => switch (value) {
  'scheduled' => CircularStatus.scheduled,
  'published' => CircularStatus.published,
  'closed' => CircularStatus.closed,
  'archived' => CircularStatus.archived,
  _ => CircularStatus.draft,
};

CircularResponseState _responseState(Object? value) => switch (value) {
  'partial' => CircularResponseState.partial,
  'answered' || 'submitted' => CircularResponseState.answered,
  _ => CircularResponseState.unanswered,
};
