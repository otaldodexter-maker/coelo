import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/now_publication.dart';

final class SupabaseNowPublicationRepository implements NowPublicationRepository {
  const SupabaseNowPublicationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async {
    try {
      final data = await _client.rpc<Object?>(
        'load_now_draft',
        params: {
          'p_institution_id': context.institutionId,
          'p_unit_id': context.unitId,
          'p_group_id': context.groupId,
        },
      );
      if (data == null) return null;
      final json = Map<String, dynamic>.from(data as Map);
      final mediaJson = json['media'] == null
          ? null
          : Map<String, dynamic>.from(json['media'] as Map);
      final audioJson = json['audio'] == null
          ? null
          : Map<String, dynamic>.from(json['audio'] as Map);
      final mediaAssetId = mediaJson?['asset_id'] as String?;
      return NowPublicationDraft(
        id: json['id'] as String?,
        version: (json['version'] as num?)?.toInt() ?? 0,
        caption: json['caption'] as String? ?? '',
        overlayText: json['overlay_text'] as String? ?? '',
        audiences: (json['audiences'] as List? ?? const [])
            .map((value) => _audience(value.toString()))
            .toSet(),
        publishAt: DateTime.tryParse(json['publish_at']?.toString() ?? ''),
        media: mediaJson == null || mediaAssetId == null
            ? null
            : NowMediaDraft(
                localId: mediaAssetId,
                name: mediaJson['name'] as String,
                mimeType: mediaJson['mime_type'] as String,
                bytes: Uint8List(0),
                duration: mediaJson['duration_seconds'] == null
                    ? null
                    : Duration(
                        milliseconds: ((mediaJson['duration_seconds'] as num) * 1000).round(),
                      ),
                remoteAssetId: mediaAssetId,
                remoteUrl: await _assetUrl(context, mediaAssetId),
              ),
        audio: audioJson == null
            ? null
            : NowAudioDraft(
                localId: audioJson['asset_id'] as String,
                name: audioJson['name'] as String,
                mimeType: audioJson['mime_type'] as String,
                bytes: Uint8List(0),
                rightsConfirmed: audioJson['rights_confirmed'] as bool? ?? false,
                remoteAssetId: audioJson['asset_id'] as String,
              ),
      );
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }

  Future<String> _assetUrl(NowPublicationContext context, String assetId) async {
    final response = await _client.functions.invoke(
      'now-media',
      body: {
        'action': 'read',
        'institution_id': context.institutionId,
        'asset_id': assetId,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('now_media_read_failed');
    }
    return (response.data as Map)['signed_url'] as String;
  }

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async {
    try {
      final media = draft.media;
      final data = await _client.rpc<Object>(
        'save_now_draft',
        params: {
          'p_request_id': _uuid(),
          'p_draft': {
            'institution_id': context.institutionId,
            'unit_id': context.unitId,
            'group_id': context.groupId,
            'caption': draft.caption,
            'overlay_text': draft.overlayText,
            'crop_scale': media?.cropScale ?? 1,
            'crop_x': media?.cropX ?? 0,
            'crop_y': media?.cropY ?? 0,
            'cover_position': media?.coverPosition ?? 0,
            'audiences': draft.audiences.map(_audienceWire).toList(),
            'publish_at': draft.publishAt?.toUtc().toIso8601String(),
          },
          'p_publication_id': draft.id,
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
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) async {
    final json = await _upload(
      context: context,
      publicationId: publicationId,
      kind: 'media',
      name: media.name,
      mimeType: media.mimeType,
      bytes: media.bytes,
      durationSeconds: media.duration?.inMilliseconds == null
          ? null
          : media.duration!.inMilliseconds / 1000,
      rightsConfirmed: false,
    );
    return media.copyWith(remoteAssetId: json['asset_id'] as String);
  }

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) async {
    final json = await _upload(
      context: context,
      publicationId: publicationId,
      kind: 'audio',
      name: audio.name,
      mimeType: audio.mimeType,
      bytes: audio.bytes,
      rightsConfirmed: audio.rightsConfirmed,
    );
    return audio.copyWith(remoteAssetId: json['asset_id'] as String);
  }

  Future<Map<String, dynamic>> _upload({
    required NowPublicationContext context,
    required String publicationId,
    required String kind,
    required String name,
    required String mimeType,
    required List<int> bytes,
    required bool rightsConfirmed,
    double? durationSeconds,
  }) async {
    final response = await _client.functions.invoke(
      'now-media',
      body: {
        'action': 'upload',
        'request_id': _uuid(),
        'publication_id': publicationId,
        'institution_id': context.institutionId,
        'unit_id': context.unitId,
        'group_id': context.groupId,
        'kind': kind,
        'name': name,
        'mime_type': mimeType,
        'size_bytes': bytes.length,
        'duration_seconds': durationSeconds,
        'rights_confirmed': rightsConfirmed,
        'content_base64': base64Encode(bytes),
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('now_media_upload_failed');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async {
    final saved = draft.id == null ? await saveDraft(context, draft) : draft;
    try {
      final data = await _client.rpc<Object>(
        'publish_now',
        params: {
          'p_request_id': _uuid(),
          'p_publication_id': saved.id,
          'p_expected_version': saved.version,
          'p_publish_at': saved.publishAt?.toUtc().toIso8601String(),
        },
      );
      final json = Map<String, dynamic>.from(data as Map);
      return NowPublication(
        id: json['id'] as String,
        publishAt: DateTime.tryParse(json['publish_at']?.toString() ?? ''),
      );
    } on PostgrestException catch (error) {
      throw _map(error);
    }
  }
}

NowAudience _audience(String value) => switch (value) {
  'families' => NowAudience.families,
  'students' => NowAudience.students,
  'school_staff' => NowAudience.schoolStaff,
  'guardians_only' => NowAudience.guardiansOnly,
  _ => throw FormatException('unknown_now_audience'),
};

String _audienceWire(NowAudience value) => switch (value) {
  NowAudience.families => 'families',
  NowAudience.students => 'students',
  NowAudience.schoolStaff => 'school_staff',
  NowAudience.guardiansOnly => 'guardians_only',
};

Exception _map(PostgrestException error) {
  if (error.message.contains('expected_version')) return NowPublicationConflict();
  if (error.code == '42501') return NowPublicationUnauthorized();
  return Exception('now_backend_failure');
}

String _uuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
