import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../../principal_circulars/domain/circular_serialization.dart';
import '../domain/superadmin_circular_repository.dart';

final class SupabaseSuperadminCircularRepository implements SuperadminCircularRepository {
  SupabaseSuperadminCircularRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SuperadminCircularDirectoryPage> fetchDirectory(
    SuperadminCircularDirectoryQuery query,
  ) async {
    final data = _map(
      await _rpc('superadmin_circular_directory_v2', {
        'p_institution_id': _nullable(query.institutionId),
        'p_search': _nullable(query.search),
        'p_statuses': query.statuses.isEmpty ? null : query.statuses.map((v) => v.name).toList(),
        'p_cursor_updated_at': query.cursorUpdatedAt?.toUtc().toIso8601String(),
        'p_cursor_id': _nullable(query.cursorId),
        'p_limit': query.limit.clamp(1, 100),
      }),
    );
    return SuperadminCircularDirectoryPage(
      items: _list(data['items']).map(_map).map(_directoryItem).toList(growable: false),
      nextCursorUpdatedAt: _date(data['next_cursor_updated_at']),
      nextCursorId: _nullable(data['next_cursor_id']),
    );
  }

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async {
    final raw = await _rpc('superadmin_circular_load_draft_v2', {
      'p_institution_id': scope.institutionId,
      'p_unit_id': scope.unitId,
      'p_group_id': scope.groupId,
      'p_activity_id': scope.activityId,
    });
    if (raw == null) return null;
    return CircularDraftCodec.fromJson(_map(raw));
  }

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async => _saveResult(
    await _rpc('superadmin_circular_save_draft_v2', {
      'p_request_id': requestId,
      'p_institution_id': scope.institutionId,
      'p_unit_id': scope.unitId,
      'p_group_id': scope.groupId,
      'p_activity_id': scope.activityId,
      'p_payload': CircularDraftCodec.toJson(draft),
    }),
  );

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async => _saveResult(
    await _rpc('superadmin_circular_publish_v2', {
      'p_request_id': requestId,
      'p_circular_id': circularId,
      'p_expected_version': expectedVersion,
      'p_publish_at': publishAt?.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) async => _saveResult(
    await _rpc('superadmin_circular_close_v2', {
      'p_request_id': requestId,
      'p_circular_id': circularId,
      'p_expected_version': expectedVersion,
    }),
  );

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    final data = await _detail(circularId);
    final draft = CircularDraftCodec.fromJson(_map(data['draft']));
    return CircularDetail(
      id: draft.id,
      revisionId: _string(data['revision_id']),
      title: draft.title,
      authorName: _string(data['author_name'], fallback: 'Equipe Coelo'),
      contextLabel: _string(data['context_label'], fallback: 'Instituição'),
      publishedAt:
          _date(data['effective_at']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      revisedAt: _date(data['revised_at']),
      responsesCloseAt: draft.responsesCloseAt,
      blocks: draft.blocks,
      status: draft.status,
      responseState: CircularResponseState.unanswered,
    );
  }

  @override
  Future<SuperadminCircularEditableDraft> loadDraftById(String circularId) async {
    final data = await _detail(circularId);
    return SuperadminCircularEditableDraft(
      draft: CircularDraftCodec.fromJson(_map(data['draft'])),
      scope: CircularScope(
        institutionId: _string(data['institution_id']),
        unitId: _nullable(data['unit_id']),
        groupId: _nullable(data['group_id']),
        activityId: _nullable(data['activity_id']),
      ),
    );
  }

  Future<Map<String, dynamic>> _detail(String circularId) async =>
      _map(await _rpc('superadmin_circular_detail_v2', {'p_circular_id': circularId}));

  @override
  Future<SuperadminCircularResponseSummary> fetchResponseSummary(String circularId) async {
    final data = _map(
      await _rpc('superadmin_circular_response_summary_v2', {'p_circular_id': circularId}),
    );
    return SuperadminCircularResponseSummary(
      responseCount: _integer(data['response_count']),
      submittedCount: _integer(data['submitted_count']),
      partialCount: _integer(data['partial_count']),
      closed: data['closed'] == true,
    );
  }

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async {
    final page = await fetchDirectory(
      SuperadminCircularDirectoryQuery(
        institutionId: scope.institutionId,
        statuses: const {CircularStatus.published},
        cursorUpdatedAt: cursor?.publishedAt,
        cursorId: cursor?.itemId,
        limit: limit,
      ),
    );
    return PrincipalCursorPage(
      items: page.items
          .map(
            (item) => CircularSummary(
              id: item.id,
              title: item.title,
              excerpt: item.excerpt,
              authorName: item.authorName,
              contextLabel: item.contextLabel,
              publishedAt: item.effectiveAt,
              attachmentCount: item.attachmentCount,
              questionCount: item.questionCount,
              responseState: CircularResponseState.unanswered,
            ),
          )
          .toList(growable: false),
      nextCursor: page.nextCursorUpdatedAt == null || page.nextCursorId == null
          ? null
          : CircularCursor(publishedAt: page.nextCursorUpdatedAt!, itemId: page.nextCursorId!),
    );
  }

  Future<Object?> _rpc(String name, Map<String, Object?> params) async {
    try {
      return _unwrap(await _client.rpc(name, params: params));
    } on PostgrestException catch (error) {
      throw _postgrestError(error);
    } on ClientException {
      throw const CircularUnavailable();
    }
  }
}

SuperadminCircularDirectoryItem _directoryItem(Map<String, dynamic> value) =>
    SuperadminCircularDirectoryItem(
      id: _string(value['id']),
      institutionId: _string(value['institution_id']),
      title: _string(value['title']),
      excerpt: _string(value['excerpt']),
      authorName: _string(value['author_name'], fallback: 'Equipe Coelo'),
      contextLabel: _string(value['context_label'], fallback: 'Instituição'),
      status: _status(value['status']),
      effectiveAt: _date(value['effective_at'])!,
      updatedAt: _date(value['updated_at'])!,
      attachmentCount: _integer(value['attachment_count']),
      questionCount: _integer(value['question_count']),
      responseCount: _integer(value['response_count']),
      managementVersion: _integer(value['management_version']),
    );

CircularSaveResult _saveResult(Object? raw) {
  final value = _map(raw);
  return CircularSaveResult(
    id: _string(value['id']),
    revisionId: _string(value['revision_id']),
    version: _integer(value['version']),
    status: _status(value['status']),
  );
}

Object? _unwrap(Object? raw) {
  final envelope = _map(raw);
  if (envelope['ok'] == true && envelope.containsKey('data')) return envelope['data'];
  if (envelope['ok'] == false) {
    throw _domainError(_string(_map(envelope['error'])['code']));
  }
  throw const CircularUnavailable();
}

Exception _domainError(String code) => switch (code) {
  'SAI_AUTH_REQUIRED' ||
  'SAI_SESSION_INVALID' ||
  'SAI_INTERNAL_CONTEXT_DENIED' ||
  'SAI_MEMBERSHIP_SUSPENDED' ||
  'SAI_MEMBERSHIP_REVOKED' ||
  'SAI_PERMISSION_DENIED' ||
  'SAI_MFA_REQUIRED' => const CircularUnauthorized(),
  'CIRCULAR_NOT_FOUND' => const CircularNotAvailable(),
  'CIRCULAR_CONFLICT' => const CircularVersionConflict(),
  'CIRCULAR_INVALID_INPUT' ||
  'CIRCULAR_INVALID_STATE' ||
  'CIRCULAR_MEDIA_BLOCKED' => CircularInvalid(code),
  _ => const CircularUnavailable(),
};

Exception _postgrestError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' || 'PGRST302' => const CircularUnauthorized(),
  'PGRST116' || 'P0002' => const CircularNotAvailable(),
  '23505' || '40001' || 'P0003' => const CircularVersionConflict(),
  '22023' || '23502' || '23503' || '23514' || 'P0001' => CircularInvalid(error.code ?? 'invalid'),
  _ => const CircularUnavailable(),
};

CircularStatus _status(Object? value) => switch (_string(value)) {
  'draft' => CircularStatus.draft,
  'scheduled' => CircularStatus.scheduled,
  'published' => CircularStatus.published,
  'closed' => CircularStatus.closed,
  'archived' => CircularStatus.archived,
  _ => throw const CircularUnavailable(),
};

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.length == 1 && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return const {};
}

List<dynamic> _list(Object? raw) => raw is List ? raw : const [];
String _string(Object? value, {String fallback = ''}) => _nullable(value) ?? fallback;
String? _nullable(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(Object? value) => DateTime.tryParse(_string(value))?.toUtc();
int _integer(Object? value) => value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;
