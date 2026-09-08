/// Explicit rendition request. The server resolves policy and authorization;
/// an asset identifier or rendition never grants access by itself.
enum MediaReadRendition { original, preview }

enum MediaReadState { available, processing, expired, unavailable }

final class MediaReadRequest {
  MediaReadRequest({required String assetId, required this.rendition})
    : assetId = _assetId(assetId);

  final String assetId;
  final MediaReadRendition rendition;

  Map<String, Object?> toJson() => {'asset_id': assetId, 'rendition': rendition.name};
}

/// Temporary bearer capability, not a permanent URL or storage identifier.
/// Consumers must not log or persist its URL/headers, and must purge retained
/// capabilities/bytes on session invalidation. This DTO is not a revocation API.
final class MediaReadTicket {
  MediaReadTicket._(this.url, this.expiresAt, Map<String, String> headers)
    : headers = Map.unmodifiable(headers);

  final Uri url;
  final DateTime expiresAt;
  final Map<String, String> headers;

  static MediaReadTicket _parse(Object? raw) {
    final value = _object(raw);
    final urlText = value['url'];
    if (urlText is! String || urlText.codeUnits.any((unit) => unit <= 32 || unit == 127)) {
      throw const MediaProtocolException();
    }
    final url = Uri.tryParse(urlText);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        urlText.contains('#')) {
      throw const MediaProtocolException();
    }
    final headers = <String, String>{};
    for (final entry in _object(value['headers']).entries) {
      final header = entry.value;
      if (!_headerName.hasMatch(entry.key) ||
          header is! String ||
          header.codeUnits.any((unit) => unit < 32 || unit == 127)) {
        throw const MediaProtocolException();
      }
      headers[entry.key] = header;
    }
    return MediaReadTicket._(url, _timestamp(value['expires_at']), headers);
  }

  @override
  String toString() => 'Temporary media read capability.';
}

final class MediaReadResult {
  const MediaReadResult._({required this.assetId, required this.state, this.ticket});

  factory MediaReadResult.fromJson(Object? raw) {
    final value = _object(raw);
    final id = _assetId(value['asset_id']);
    final state = switch (value['state']) {
      'available' => MediaReadState.available,
      'processing' => MediaReadState.processing,
      'expired' => MediaReadState.expired,
      'unavailable' => MediaReadState.unavailable,
      _ => throw const MediaProtocolException(),
    };
    if (state != MediaReadState.available) {
      if (value['ticket'] != null) throw const MediaProtocolException();
      return MediaReadResult._(assetId: id, state: state);
    }
    return MediaReadResult._(
      assetId: id,
      state: state,
      ticket: MediaReadTicket._parse(value['ticket']),
    );
  }

  final String assetId;
  final MediaReadState state;
  final MediaReadTicket? ticket;
}

final class MediaProtocolException implements Exception {
  const MediaProtocolException();
  @override
  String toString() => 'Invalid media response.';
}

final class MediaTicketExpiredException implements Exception {
  const MediaTicketExpiredException();
  @override
  String toString() => 'Media read capability expired.';
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _headerName = RegExp(r"^[!#$%&'*+.^_`|~0-9a-zA-Z-]+$");
final _absoluteTimestamp = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
);

String _assetId(Object? value) {
  if (value is! String || !_uuid.hasMatch(value)) throw const MediaProtocolException();
  return value.toLowerCase();
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const MediaProtocolException();
  }
  return Map<String, Object?>.from(value);
}

DateTime _timestamp(Object? raw) {
  if (raw is! String) throw const MediaProtocolException();
  final match = _absoluteTimestamp.firstMatch(raw);
  if (match == null) throw const MediaProtocolException();
  final parts = [for (var index = 1; index <= 6; index++) int.parse(match.group(index)!)];
  final calendar = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  if (calendar.year != parts[0] ||
      calendar.month != parts[1] ||
      calendar.day != parts[2] ||
      calendar.hour != parts[3] ||
      calendar.minute != parts[4] ||
      calendar.second != parts[5]) {
    throw const MediaProtocolException();
  }
  if (!raw.endsWith('Z')) {
    final offset = raw.substring(raw.length - 5).split(':');
    if (int.parse(offset[0]) > 23 || int.parse(offset[1]) > 59) {
      throw const MediaProtocolException();
    }
  }
  final value = DateTime.tryParse(raw);
  if (value == null) throw const MediaProtocolException();
  return value.toUtc();
}
