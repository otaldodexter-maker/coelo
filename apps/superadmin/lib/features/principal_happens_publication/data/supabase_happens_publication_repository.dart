import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/happens_publication_controller.dart';
import '../domain/happens_publication.dart';

final class SupabaseHappensPublicationRepository implements HappensPublicationRepository {
  const SupabaseHappensPublicationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async {
    try {
      final data = await _client.rpc<Object?>(
        'load_happens_draft',
        params: {
          'p_institution_id': context.institutionId,
          'p_unit_id': context.unitId,
          'p_group_id': context.groupId,
        },
      );
      if (data == null) return null;
      final json = Map<String, dynamic>.from(data as Map);
      return HappensPostDraft(
        id: json['id'] as String?,
        caption: json['caption'] as String? ?? '',
        audiences: (json['audiences'] as List? ?? const []).map(
          (value) => _audience(value.toString()),
        ),
        publishAt: DateTime.tryParse(json['publish_at']?.toString() ?? ''),
        media: (json['media'] as List? ?? const []).map((value) {
          final media = Map<String, dynamic>.from(value as Map);
          return HappensMediaDraft(
            localId: media['asset_id'] as String,
            name: media['name'] as String,
            mimeType: media['mime_type'] as String,
            bytes: Uint8List(0),
            assetId: media['asset_id'] as String,
            objectKey: media['object_key'] as String,
            remoteUrl: media['signed_url'] as String?,
          );
        }),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<HappensPostDraft> saveDraft(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    try {
      final data = await _client.rpc<Object>(
        'save_happens_draft',
        params: {
          'p_request_id': _uuid(),
          'p_draft': {
            'institution_id': context.institutionId,
            'unit_id': context.unitId,
            'group_id': context.groupId,
            'caption': draft.caption,
            'audiences': draft.audiences.map(_audienceWire).toList(),
            'publish_at': draft.publishAt?.toUtc().toIso8601String(),
          },
          'p_post_id': draft.id,
          'p_expected_version': draft.version,
        },
      );
      final json = Map<String, dynamic>.from(data as Map);
      return draft.copyWith(id: json['id'] as String, version: (json['version'] as num).toInt());
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) async {
    final response = await _client.functions.invoke(
      'happens-media',
      body: {
        'action': 'prepare',
        'request_id': media.localId,
        'institution_id': context.institutionId,
        'post_id': postId,
        'name': media.name,
        'mime_type': media.mimeType,
        'size_bytes': media.bytes.length,
      },
    );
    if (response.status != 200) throw Exception('media_prepare_failed');
    final json = Map<String, dynamic>.from(response.data as Map);
    return HappensUploadIntent(
      assetId: json['asset_id'] as String,
      institutionId: context.institutionId,
      postId: postId,
      requestId: media.localId,
      objectKey: json['object_key'] as String,
      token: json['upload_token'] as String,
      displayOrder: displayOrder,
    );
  }

  @override
  Future<HappensMediaDraft> finalizeMedia(
    HappensUploadIntent intent,
    HappensMediaDraft media,
  ) async {
    await _client.storage
        .from('coelo-happens-mvp')
        .uploadBinaryToSignedUrl(
          intent.objectKey,
          intent.token,
          media.bytes,
          FileOptions(contentType: media.mimeType, upsert: true),
        );
    final response = await _client.functions.invoke(
      'happens-media',
      body: {
        'action': 'finalize',
        'asset_id': intent.assetId,
        'institution_id': intent.institutionId,
        'post_id': intent.postId,
        'request_id': intent.requestId,
        'name': media.name,
        'mime_type': media.mimeType,
        'size_bytes': media.bytes.length,
        'display_order': intent.displayOrder,
      },
    );
    if (response.status != 200) throw Exception('media_upload_failed');
    final json = Map<String, dynamic>.from(response.data as Map);
    return HappensMediaDraft(
      localId: media.localId,
      name: media.name,
      mimeType: media.mimeType,
      bytes: media.bytes,
      assetId: json['asset_id'] as String,
      objectKey: json['object_key'] as String,
      remoteUrl: media.remoteUrl,
    );
  }

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) async {
    if (media.assetId == null) return;
    final response = await _client.functions.invoke(
      'happens-media',
      body: {'action': 'delete', 'request_id': _uuid(), 'asset_id': media.assetId},
    );
    if (response.status != 200) throw Exception('media_remove_failed');
  }

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    final saved = draft.id == null ? await saveDraft(context, draft) : draft;
    try {
      final data = await _client.rpc<Object>(
        'publish_happens_post',
        params: {
          'p_request_id': _uuid(),
          'p_post_id': saved.id,
          'p_expected_version': saved.version,
          'p_publish_at': saved.publishAt?.toUtc().toIso8601String(),
        },
      );
      final json = Map<String, dynamic>.from(data as Map);
      return HappensPublication(
        id: json['id'] as String,
        status: HappensPostStatus.values.byName(json['status'] as String),
        publishAt: DateTime.parse(json['publish_at'] as String),
      );
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }
}

HappensAudienceKind _audience(String value) => switch (value) {
  'families' => HappensAudienceKind.families,
  'students' => HappensAudienceKind.students,
  'school_staff' => HappensAudienceKind.schoolStaff,
  'guardians_only' => HappensAudienceKind.guardiansOnly,
  _ => throw FormatException('unknown_audience'),
};

String _audienceWire(HappensAudienceKind value) => switch (value) {
  HappensAudienceKind.families => 'families',
  HappensAudienceKind.students => 'students',
  HappensAudienceKind.schoolStaff => 'school_staff',
  HappensAudienceKind.guardiansOnly => 'guardians_only',
};

Exception _map(PostgrestException error) {
  if (error.message.contains('expected_version')) return HappensPublicationConflict();
  if (error.code == '42501') return HappensPublicationUnauthorized();
  return Exception('happens_backend_failure');
}

String _uuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
