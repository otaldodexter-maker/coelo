import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/circular.dart';
import '../domain/circular_repository.dart';

final class SupabaseCircularResponseRepository implements CircularResponseRepository {
  const SupabaseCircularResponseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'save_circular_response_draft',
        params: {
          'p_request_id': requestId,
          'p_revision_id': revisionId,
          'p_answers': {
            'child_context_id': childContextId,
            'answers': [
              for (final entry in answers.entries)
                {'question_id': entry.key, 'option_ids': entry.value},
            ],
          },
          'p_expected_version': expectedVersion,
        },
      );
      return _responseResult(response);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  }) async {
    try {
      final response = await _client.rpc<Map<String, dynamic>>(
        'submit_circular_response',
        params: {
          'p_request_id': requestId,
          'p_session_id': sessionId,
          'p_expected_version': expectedVersion,
        },
      );
      return _responseResult(response);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }
}

final class SupabaseCircularMediaRepository implements CircularMediaRepository {
  const SupabaseCircularMediaRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CircularMediaUploadIntent> prepare({
    required String requestId,
    required String institutionId,
    required String circularId,
    required String name,
    required String mimeType,
    required int byteSize,
  }) async {
    final data = await _invoke({
      'action': 'prepare',
      'request_id': requestId,
      'institution_id': institutionId,
      'circular_id': circularId,
      'name': name,
      'mime_type': mimeType,
      'size_bytes': byteSize,
      'display_order': 0,
    });
    final alreadyUploaded = data['already_uploaded'] == true;
    final uri = alreadyUploaded ? null : Uri.tryParse(_text(data, 'upload_url'));
    final expiresAt = alreadyUploaded
        ? DateTime.now().toUtc()
        : DateTime.tryParse(_text(data, 'expires_at'));
    if ((!alreadyUploaded && uri == null) || expiresAt == null) {
      throw const CircularUnavailable();
    }
    return CircularMediaUploadIntent(
      assetId: _text(data, 'asset_id'),
      uploadUrl: uri,
      requiredHeaders: Map<String, String>.from((data['required_headers'] as Map?) ?? const {}),
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> finalize({
    required String requestId,
    required String finalizeRequestId,
    required String institutionId,
    required String circularId,
    required CircularMediaUploadIntent intent,
    required String name,
    required String mimeType,
    required int byteSize,
    required int displayOrder,
    String? checksumSha256,
  }) async {
    await _invoke({
      'action': 'finalize',
      'request_id': requestId,
      'finalize_request_id': finalizeRequestId,
      'institution_id': institutionId,
      'circular_id': circularId,
      'asset_id': intent.assetId,
      'name': name,
      'mime_type': mimeType,
      'size_bytes': byteSize,
      'display_order': displayOrder,
      'checksum_sha256': checksumSha256,
    });
  }

  @override
  Future<Uri> resolveRead(String assetId) async {
    final data = await _invoke({'action': 'read', 'asset_id': assetId});
    final uri = Uri.tryParse(_text(data, 'signed_url'));
    if (uri == null || uri.scheme != 'https') throw const CircularUnavailable();
    return uri;
  }

  @override
  Future<void> remove(String assetId) async {
    await _invoke({'action': 'delete', 'asset_id': assetId});
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke('circular-media', body: body);
      if (response.status == 401 || response.status == 403) {
        throw const CircularUnauthorized();
      }
      if (response.status != 200 || response.data is! Map) {
        final data = response.data;
        final code = data is Map ? data['error']?.toString() : null;
        throw code == null ? const CircularUnavailable() : CircularInvalid(code);
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on CircularFailure {
      rethrow;
    } on Object {
      throw const CircularUnavailable();
    }
  }
}

CircularResponseSaveResult _responseResult(Map<String, dynamic> json) {
  final version = json['version'];
  if (version is! num) throw const CircularUnavailable();
  return CircularResponseSaveResult(
    sessionId: _text(json, 'session_id'),
    version: version.toInt(),
    state: switch (json['status']) {
      'partial' => CircularResponseState.partial,
      'submitted' || 'answered' => CircularResponseState.answered,
      _ => CircularResponseState.unanswered,
    },
  );
}

CircularFailure _mapFailure(Object error) {
  if (error is CircularFailure) return error;
  if (error is PostgrestException) {
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const CircularUnauthorized();
    }
    if (error.code == '40001' || error.message.contains('expected_version_conflict')) {
      return const CircularVersionConflict();
    }
    return CircularInvalid(error.message);
  }
  return const CircularUnavailable();
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) throw const CircularUnavailable();
  return value;
}
