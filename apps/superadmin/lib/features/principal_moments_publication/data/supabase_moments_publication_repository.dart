import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/moments_publication.dart';
import '../../../shared/data/edge_media_bytes.dart';

final class SupabaseMomentsPublicationRepository implements MomentsPublicationRepository {
  /// [httpClient] fica só por compatibilidade: os bytes vão pela Edge
  /// (`uploadBytesThroughEdge`), sem PUT direto ao R2.
  SupabaseMomentsPublicationRepository(
    this._client, {
    // ignore: avoid_unused_constructor_parameters
    http.Client? httpClient,
    String Function()? requestIdFactory,
  }) : _requestIdFactory = requestIdFactory ?? _uuid;

  final SupabaseClient _client;
  final String Function() _requestIdFactory;
  final Map<String, String> _requestIds = {};
  final Set<String> _uploadedMedia = {};

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async {
    try {
      final data = await _client.rpc<Object?>(
        'load_moments_draft',
        params: {
          'p_institution_id': context.institutionId,
          'p_unit_id': context.unitId,
          'p_group_id': context.groupId,
        },
      );
      if (data == null) return null;
      final json = Map<String, dynamic>.from(data as Map);
      final media = <MomentsMediaDraft>[];
      for (final raw in json['media'] as List? ?? const []) {
        final item = Map<String, dynamic>.from(raw as Map);
        final assetId = item['asset_id'] as String;
        // Bytes pela Edge (sem URL assinada no navegador); URL local para a prévia.
        final bytes = await readBytesThroughEdge(_client, 'moments-media', {
          'action': 'read',
          'asset_id': assetId,
        }, failure: 'moments_media_read_failed');
        final mimeType = item['mime_type'] as String;
        media.add(
          MomentsMediaDraft(
            localId: assetId,
            name: item['name'] as String,
            mimeType: mimeType,
            durationMilliseconds: (item['duration_milliseconds'] as num?)?.toInt(),
            remoteAssetId: assetId,
            remoteUrl: mediaObjectUrl(bytes, mimeType),
          ),
        );
      }
      return MomentsDraft(
        id: json['id'] as String?,
        caption: json['caption'] as String? ?? '',
        audiences: (json['audiences'] as List? ?? const []).map(
          (value) => _audience(value.toString()),
        ),
        media: media,
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) =>
      _saveDraft(context, draft, retainRequestId: false);

  Future<MomentsDraft> _saveDraft(
    MomentsPublicationContext context,
    MomentsDraft draft, {
    required bool retainRequestId,
  }) async {
    final operationKey = _saveOperationKey(context, draft);
    final requestId = _requestIds.putIfAbsent(operationKey, _requestIdFactory);
    try {
      final data = await _client.rpc<Object>(
        'save_moments_draft',
        params: {
          'p_request_id': requestId,
          'p_draft': {
            'institution_id': context.institutionId,
            'unit_id': context.unitId,
            'group_id': context.groupId,
            'caption': draft.caption,
            'audiences': draft.audiences.map(_audienceWire).toList()..sort(),
          },
          'p_publication_id': draft.id,
          'p_expected_version': draft.version,
        },
      );
      final json = Map<String, dynamic>.from(data as Map);
      if (!retainRequestId) _requestIds.remove(operationKey);
      return draft.copyWith(id: json['id'] as String, version: (json['version'] as num).toInt());
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) async {
    final saveKey = _saveOperationKey(context, draft);
    final saved = await _saveDraft(context, draft, retainRequestId: true);
    for (var index = 0; index < saved.media.length; index++) {
      final media = saved.media[index];
      final uploadedKey = '${saved.id}:${media.localId}';
      if (media.remoteAssetId == null && !_uploadedMedia.contains(uploadedKey)) {
        await _upload(context, saved.id!, media, index);
      }
    }
    final publishKey = 'publish:${saved.id}:${saved.version}';
    final publishRequestId = _requestIds.putIfAbsent(publishKey, _requestIdFactory);
    try {
      final data = await _client.rpc<Object>(
        'publish_moment',
        params: {
          'p_request_id': publishRequestId,
          'p_publication_id': saved.id,
          'p_expected_version': saved.version,
        },
      );
      final json = Map<String, dynamic>.from(data as Map);
      _requestIds
        ..remove(saveKey)
        ..remove(publishKey);
      _uploadedMedia.removeWhere((key) => key.startsWith('${saved.id}:'));
      return MomentsPublication(
        id: json['publication_id'] as String,
        status: MomentsStatus.values.byName(json['status'] as String),
      );
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }

  /// Soft withdrawal of a published moment. Authorship, tenant, scope and the
  /// `moments.publications.remove` permission are enforced by the backend.

  Future<void> _upload(
    MomentsPublicationContext context,
    String publicationId,
    MomentsMediaDraft media,
    int displayOrder,
  ) async {
    if (media.bytes.isEmpty) throw StateError('moments_media_bytes_required');
    final operationKey = 'upload:$publicationId:${media.localId}';
    final finalizeKey = 'finalize:$publicationId:${media.localId}';
    final requestId = _requestIds.putIfAbsent(operationKey, _requestIdFactory);
    final finalizeRequestId = _requestIds.putIfAbsent(finalizeKey, _requestIdFactory);
    final envelope = <String, dynamic>{
      'request_id': requestId,
      'institution_id': context.institutionId,
      'publication_id': publicationId,
      'name': media.name,
      'mime_type': media.mimeType,
      'size_bytes': media.bytes.length,
      'duration_milliseconds': media.durationMilliseconds,
      'display_order': displayOrder,
    };
    // Upload binário pela Edge: ela prepara, grava no R2 e finaliza; o
    // navegador nunca fala com o R2 (CORS do bucket fora da conta).
    await uploadBytesThroughEdge(
      _client,
      'moments-media',
      envelope: {...envelope, 'finalize_request_id': finalizeRequestId},
      bytes: media.bytes,
      failure: 'moments_media_upload_failed',
    );
    _requestIds
      ..remove(operationKey)
      ..remove(finalizeKey);
    _uploadedMedia.add('$publicationId:${media.localId}');
  }
}

String _draftFingerprint(MomentsDraft draft) {
  final audiences = draft.audiences.map(_audienceWire).toList()..sort();
  return jsonEncode({
    'id': draft.id,
    'version': draft.version,
    'caption': draft.caption,
    'audiences': audiences,
  });
}

String _saveOperationKey(MomentsPublicationContext context, MomentsDraft draft) =>
    'save:${context.institutionId}:${context.unitId}:${context.groupId}:${_draftFingerprint(draft)}';

MomentsAudienceKind _audience(String value) => switch (value) {
  'families' => MomentsAudienceKind.families,
  'students' => MomentsAudienceKind.students,
  'school_staff' => MomentsAudienceKind.schoolStaff,
  'guardians_only' => MomentsAudienceKind.guardiansOnly,
  _ => throw FormatException('unknown_moments_audience'),
};

String _audienceWire(MomentsAudienceKind value) => switch (value) {
  MomentsAudienceKind.families => 'families',
  MomentsAudienceKind.students => 'students',
  MomentsAudienceKind.schoolStaff => 'school_staff',
  MomentsAudienceKind.guardiansOnly => 'guardians_only',
};

Exception _map(PostgrestException error) {
  if (error.message.contains('expected_version')) return MomentsPublicationConflict();
  if (error.code == '42501') return MomentsPublicationUnauthorized();
  return Exception('moments_backend_failure');
}

String _uuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
