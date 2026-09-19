import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/edge_media_bytes.dart';
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

final class SupabaseCircularMediaRepository
    implements CircularMediaRepository, CircularMediaBytesUploader {
  const SupabaseCircularMediaRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CircularMediaUploadIntent> uploadBytes({
    required String requestId,
    required String finalizeRequestId,
    required String institutionId,
    required String circularId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    required int displayOrder,
  }) async {
    // Upload binário pela Edge (ADR 0032): ela prepara (idempotente pelo
    // request_id), grava e finaliza; o navegador nunca fala com o R2.
    final Map<String, dynamic> data;
    try {
      data = await uploadBytesThroughEdge(
        _client,
        'circular-media',
        envelope: {
          'request_id': requestId,
          'finalize_request_id': finalizeRequestId,
          'institution_id': institutionId,
          'circular_id': circularId,
          'name': name,
          'mime_type': mimeType,
          'size_bytes': bytes.length,
          'display_order': displayOrder,
        },
        bytes: bytes,
      );
    } on EdgeMediaException catch (error) {
      if (error.isDenied) throw const CircularUnauthorized();
      throw error.status == null ? const CircularUnavailable() : CircularInvalid(error.code);
    }
    return CircularMediaUploadIntent(
      assetId: _text(data, 'asset_id'),
      uploadUrl: null,
      requiredHeaders: const {},
      expiresAt: DateTime.now().toUtc(),
      storageProvider: 'edge',
    );
  }

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
    final provider = data['storage_provider']?.toString().trim();
    return CircularMediaUploadIntent(
      assetId: _text(data, 'asset_id'),
      uploadUrl: uri,
      requiredHeaders: Map<String, String>.from((data['required_headers'] as Map?) ?? const {}),
      expiresAt: expiresAt,
      storageProvider: provider == null || provider.isEmpty ? null : provider,
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
  Future<CircularMediaReadTicket> resolveRead(String assetId) async {
    // Bytes pela Edge (autorização no servidor); a "URL" é local (`blob:` no
    // navegador), nunca uma URL assinada do bucket.
    final Uint8List bytes;
    try {
      bytes = await readBytesThroughEdge(_client, 'circular-media', {
        'action': 'read',
        'asset_id': assetId,
      });
    } on EdgeMediaException catch (error) {
      if (error.isDenied) throw const CircularUnauthorized();
      throw const CircularUnavailable();
    }
    final mimeType = sniffMediaMimeType(bytes);
    if (mimeType == 'application/octet-stream') throw const CircularUnavailable();
    return CircularMediaReadTicket(
      assetId: assetId,
      url: Uri.parse(mediaObjectUrl(bytes, mimeType)),
      mimeType: mimeType,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      byteSize: bytes.length,
    );
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
    if (error.code == '40001' ||
        error.code == 'PT409' ||
        error.message.contains('expected_version_conflict')) {
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
