import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_now_feed_repository.dart';

typedef PrincipalNowClock = DateTime Function();

final class SupabasePrincipalNowFeedRepository implements PrincipalNowFeedRepository {
  SupabasePrincipalNowFeedRepository(this._client, {PrincipalNowClock? now})
    : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final PrincipalNowClock _now;
  final _ticketIssuedAt = <String, DateTime>{};

  static const _ticketLifetime = Duration(minutes: 2);

  @override
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope) async {
    try {
      final response = await _client.rpc<List<dynamic>>(
        'list_visible_now_publications',
        params: {
          'p_institution_id': scope.institutionId,
          'p_unit_id': scope.unitId,
          'p_group_id': scope.groupId,
          'p_limit': scope.limit,
        },
      );
      final current = _now().toUtc();
      _ticketIssuedAt.removeWhere(
        (_, issuedAt) => !current.isBefore(issuedAt.add(_ticketLifetime)),
      );
      final items = response
          .map((value) => _itemFromJson(Map<String, dynamic>.from(value as Map), current))
          .where((item) => item.expiresAt.toUtc().isAfter(current))
          .toList(growable: false);
      for (final item in items) {
        _ticketIssuedAt[item.media.readTicket] = current;
        final audio = item.audio;
        if (audio != null) _ticketIssuedAt[audio.readTicket] = current;
      }
      return items;
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const PrincipalNowFeedUnauthorized();
      }
      throw const PrincipalNowFeedUnavailable();
    } on PrincipalNowFeedFailure {
      rethrow;
    } on Object {
      throw const PrincipalNowFeedUnavailable();
    }
  }

  @override
  Future<PrincipalNowMediaRead> resolveMedia({
    required PrincipalNowFeedScope scope,
    required String publicationId,
    required PrincipalNowMediaDescriptor media,
  }) async {
    var candidate = media;
    var renewed = false;
    final issuedAt = _ticketIssuedAt[candidate.readTicket];
    if (issuedAt != null && !_now().toUtc().isBefore(issuedAt.add(_ticketLifetime))) {
      candidate = await _renewDescriptor(scope, publicationId, candidate.kind);
      renewed = true;
    }
    try {
      return await _redeem(candidate);
    } on _PrincipalNowTicketRejected {
      if (renewed) throw const PrincipalNowFeedUnauthorized();
      candidate = await _renewDescriptor(scope, publicationId, candidate.kind);
      return _redeemRenewed(candidate);
    } on PrincipalNowFeedUnavailable {
      if (renewed) rethrow;
      candidate = await _renewDescriptor(scope, publicationId, candidate.kind);
      return _redeemRenewed(candidate);
    }
  }

  Future<PrincipalNowMediaDescriptor> _renewDescriptor(
    PrincipalNowFeedScope scope,
    String publicationId,
    PrincipalNowMediaKind kind,
  ) async {
    final items = await listVisibleStories(scope);
    final matches = items.where((item) => item.publicationId == publicationId);
    if (matches.length != 1) throw const PrincipalNowFeedUnavailable();
    final item = matches.single;
    return switch (kind) {
      PrincipalNowMediaKind.media => item.media,
      PrincipalNowMediaKind.audio => item.audio ?? (throw const PrincipalNowFeedUnavailable()),
    };
  }

  Future<PrincipalNowMediaRead> _redeemRenewed(PrincipalNowMediaDescriptor media) async {
    try {
      return await _redeem(media);
    } on _PrincipalNowTicketRejected {
      throw const PrincipalNowFeedUnauthorized();
    }
  }

  Future<PrincipalNowMediaRead> _redeem(PrincipalNowMediaDescriptor media) async {
    try {
      final response = await _client.functions.invoke(
        'now-media',
        body: {'action': 'read', 'read_ticket': media.readTicket},
      );
      if (response.status == 401) {
        throw const PrincipalNowFeedUnauthorized();
      }
      if (response.status == 403) throw const _PrincipalNowTicketRejected();
      if (response.status < 200 || response.status >= 300 || response.data is! Map) {
        throw const PrincipalNowFeedUnavailable();
      }
      final json = Map<String, dynamic>.from(response.data as Map);
      final signedUrl = Uri.tryParse(json['signed_url']?.toString() ?? '');
      final mimeType = _requiredText(json, 'mime_type');
      final expiresIn = json['expires_in'] as num?;
      if (signedUrl == null ||
          signedUrl.scheme != 'https' ||
          signedUrl.host.isEmpty ||
          signedUrl.userInfo.isNotEmpty ||
          expiresIn == null ||
          expiresIn <= 0 ||
          mimeType != media.mimeType) {
        throw const PrincipalNowFeedUnavailable();
      }
      return PrincipalNowMediaRead(
        signedUrl: signedUrl.toString(),
        mimeType: mimeType,
        kind: media.kind,
        expiresIn: Duration(seconds: expiresIn.toInt()),
      );
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw const PrincipalNowFeedUnauthorized();
      }
      if (error.status == 403) throw const _PrincipalNowTicketRejected();
      throw const PrincipalNowFeedUnavailable();
    } on _PrincipalNowTicketRejected {
      rethrow;
    } on PrincipalNowFeedFailure {
      rethrow;
    } on Object {
      throw const PrincipalNowFeedUnavailable();
    }
  }
}

final class _PrincipalNowTicketRejected implements Exception {
  const _PrincipalNowTicketRejected();
}

PrincipalNowFeedItem _itemFromJson(Map<String, dynamic> json, DateTime current) {
  final publishedAt = DateTime.tryParse(json['published_at']?.toString() ?? '');
  final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
  if (publishedAt == null || expiresAt == null) {
    throw const FormatException('invalid_now_period');
  }
  final descriptors = (json['media'] as List? ?? const [])
      .map((value) => Map<String, dynamic>.from(value as Map))
      .where((value) => value['kind'] == 'media' || value['kind'] == 'audio')
      .toList(growable: false);
  final mediaItems = descriptors.where((value) => value['kind'] == 'media').toList(growable: false);
  final audioItems = descriptors.where((value) => value['kind'] == 'audio').toList(growable: false);
  if (mediaItems.length != 1) throw const FormatException('invalid_now_media');
  if (audioItems.length > 1) throw const FormatException('invalid_now_audio');
  final media = mediaItems.single;
  final audio = audioItems.isEmpty ? null : audioItems.single;
  final overlay = (json['overlay_text'] as String?)?.trim() ?? '';
  final caption = (json['caption'] as String?)?.trim() ?? '';
  return PrincipalNowFeedItem(
    publicationId: _requiredText(json, 'publication_id'),
    author: _requiredText(json, 'author_name'),
    authorInitials: _requiredText(json, 'author_initials'),
    contextLabel: _requiredText(json, 'context_label'),
    timeLabel: _relativeTime(publishedAt, current),
    caption: overlay.isNotEmpty ? overlay : caption,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    cropScale: _requiredNumber(json, 'crop_scale', min: 1, max: 2),
    cropX: _requiredNumber(json, 'crop_x', min: -1, max: 1),
    cropY: _requiredNumber(json, 'crop_y', min: -1, max: 1),
    coverPosition: _requiredNumber(json, 'cover_position', min: 0, max: 1),
    media: PrincipalNowMediaDescriptor(
      readTicket: _requiredText(media, 'read_ticket'),
      mimeType: _requiredText(media, 'mime_type'),
      kind: PrincipalNowMediaKind.media,
    ),
    audio: audio == null
        ? null
        : PrincipalNowMediaDescriptor(
            readTicket: _requiredText(audio, 'read_ticket'),
            mimeType: _requiredText(audio, 'mime_type'),
            kind: PrincipalNowMediaKind.audio,
          ),
  );
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = (json[key] as String?)?.trim();
  if (value == null || value.isEmpty) throw FormatException('invalid_$key');
  return value;
}

double _requiredNumber(
  Map<String, dynamic> json,
  String key, {
  required double min,
  required double max,
}) {
  final value = (json[key] as num?)?.toDouble();
  if (value == null || !value.isFinite || value < min || value > max) {
    throw FormatException('invalid_$key');
  }
  return value;
}

String _relativeTime(DateTime publishedAt, DateTime current) {
  final difference = current.toUtc().difference(publishedAt.toUtc());
  if (difference.inMinutes < 1) return 'Agora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  return '${difference.inHours} h';
}
