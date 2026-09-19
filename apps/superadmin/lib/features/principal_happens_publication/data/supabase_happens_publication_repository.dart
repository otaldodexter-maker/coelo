import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/happens_publication_controller.dart';
import '../domain/happens_publication.dart';
import '../../../shared/data/edge_media_bytes.dart';

final class SupabaseHappensPublicationRepository implements HappensPublicationRepository {
  /// [httpClient] fica só por compatibilidade: os bytes vão pela Edge
  /// (`uploadBytesThroughEdge`), sem PUT direto ao R2 nem ao Storage.
  // ignore: avoid_unused_constructor_parameters
  SupabaseHappensPublicationRepository(this._client, {http.Client? httpClient});
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
        media: [
          for (final value in json['media'] as List? ?? const [])
            await _draftMedia(context, Map<String, dynamic>.from(value as Map)),
        ],
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

  /// Transfere os bytes para o destino que o SERVIDOR anunciou.
  ///
  /// No provedor legado o caminho e o mesmo de sempre. No R2 o servidor emite
  /// uma janela PUT curta e os cabecalhos exigidos, e nem bucket nem chave
  /// chegam ao cliente.
  /// Mídia já gravada do rascunho: bytes pela Edge (`read-draft`, regra do
  /// autor no servidor) viram URL local para a prévia; sem leitura, fica sem
  /// prévia mas o rascunho continua íntegro.
  Future<HappensMediaDraft> _draftMedia(
    HappensPublicationContext context,
    Map<String, dynamic> media,
  ) async {
    final assetId = media['asset_id'] as String;
    final mimeType = media['mime_type'] as String;
    String? remoteUrl;
    try {
      final bytes = await readBytesThroughEdge(_client, 'happens-media', {
        'action': 'read-draft',
        'institution_id': context.institutionId,
        'asset_id': assetId,
      });
      remoteUrl = mediaObjectUrl(bytes, sniffMediaMimeType(bytes, fallback: mimeType));
    } on EdgeMediaException {
      remoteUrl = null;
    }
    return HappensMediaDraft(
      localId: assetId,
      name: media['name'] as String,
      mimeType: mimeType,
      bytes: Uint8List(0),
      assetId: assetId,
      objectKey: media['object_key'] as String,
      remoteUrl: remoteUrl,
    );
  }

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) async {
    // Bytes pela Edge: não há janela assinada a pedir. A intenção só carrega
    // o envelope; a Edge prepara (idempotente pelo request_id), grava e
    // finaliza no `finalizeMedia`.
    return HappensUploadIntent(
      assetId: '',
      institutionId: context.institutionId,
      postId: postId,
      requestId: media.localId,
      displayOrder: displayOrder,
      storageProvider: 'edge',
    );
  }

  @override
  Future<HappensMediaDraft> finalizeMedia(
    HappensUploadIntent intent,
    HappensMediaDraft media,
  ) async {
    // Upload binário pela Edge (ADR 0032): ela prepara, grava (R2 ou bucket
    // legado, decisão do servidor) e finaliza; o navegador nunca fala com o R2.
    final json = await uploadBytesThroughEdge(
      _client,
      'happens-media',
      envelope: {
        'institution_id': intent.institutionId,
        'post_id': intent.postId,
        'request_id': intent.requestId,
        'name': media.name,
        'mime_type': media.mimeType,
        'size_bytes': media.bytes.length,
        'display_order': intent.displayOrder,
      },
      bytes: media.bytes,
      failure: 'media_upload_failed',
    );
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
    try {
      final response = await _client.functions.invoke(
        'happens-media',
        body: {'action': 'delete', 'request_id': _uuid(), 'asset_id': media.assetId},
      );
      if (response.status != 200) throw Exception('media_remove_failed');
    } on FunctionException catch (error) {
      // The legacy 422 envelope also wraps operational RPC failures.
      if (error.status == 401 || error.status == 403) {
        throw HappensPublicationUnauthorized();
      }
      rethrow;
    }
  }

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft, {
    required String requestId,
  }) async {
    final saved = draft.id == null ? await saveDraft(context, draft) : draft;
    try {
      final data = await _client.rpc<Object>(
        'publish_happens_post',
        params: {
          'p_request_id': requestId,
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
