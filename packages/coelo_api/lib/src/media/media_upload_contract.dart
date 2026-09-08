import 'dart:typed_data';

import 'media_read_contract.dart';

/// Correlation only. The domain adapter binds the real entity/context, and the
/// server must derive authorization, ownership and purpose independently.
final class MediaUploadTarget {
  MediaUploadTarget({
    required String institutionId,
    required String resourceId,
    required String domain,
    required String purpose,
  }) : institutionId = mediaUploadId(institutionId),
       resourceId = mediaUploadId(resourceId),
       domain = _label(domain),
       purpose = _label(purpose);

  factory MediaUploadTarget.fromJson(Object? raw) {
    final value = _object(raw);
    return MediaUploadTarget(
      institutionId: mediaUploadId(value['institution_id']),
      resourceId: mediaUploadId(value['resource_id']),
      domain: _label(value['domain']),
      purpose: _label(value['purpose']),
    );
  }
  final String institutionId;
  final String resourceId;
  final String domain;
  final String purpose;
  Map<String, Object?> toJson() => {
    'institution_id': institutionId,
    'resource_id': resourceId,
    'domain': domain,
    'purpose': purpose,
  };
  @override
  bool operator ==(Object other) =>
      other is MediaUploadTarget &&
      institutionId == other.institutionId &&
      resourceId == other.resourceId &&
      domain == other.domain &&
      purpose == other.purpose;
  @override
  int get hashCode => Object.hash(institutionId, resourceId, domain, purpose);
}

/// Declared source metadata, never a substitute for server measurement/decoding.
final class MediaUploadMetadata {
  MediaUploadMetadata({
    required String mimeType,
    required int byteLength,
    required String checksumSha256,
  }) : mimeType = _mime(mimeType),
       byteLength = _length(byteLength),
       checksumSha256 = _checksum(checksumSha256);
  final String mimeType;
  final int byteLength;
  final String checksumSha256;
  Map<String, Object?> toJson() => {
    'mime_type': mimeType,
    'byte_length': byteLength,
    'checksum_sha256': checksumSha256,
  };
}

/// An owned copy of the selected source. The picker/consumer must also purge its
/// own original buffer on context invalidation. Call [clear] when no retry needs
/// this source; an uploader clears it on session invalidation during upload.
final class MediaUploadSource {
  MediaUploadSource({
    required Uint8List bytes,
    required String mimeType,
    required String checksumSha256,
  }) : metadata = MediaUploadMetadata(
         mimeType: mimeType,
         byteLength: bytes.length,
         checksumSha256: checksumSha256,
       ),
       _bytes = Uint8List.fromList(bytes);
  final MediaUploadMetadata metadata;
  final Uint8List _bytes;
  bool _cleared = false;
  Uint8List copyBytes() {
    if (_cleared) throw const MediaProtocolException();
    return Uint8List.fromList(_bytes);
  }

  void clear() {
    _bytes.fillRange(0, _bytes.length, 0);
    _cleared = true;
  }
}

/// Produced only after the server validates actual bytes, real MIME, checksum,
/// applicable dimensions/limits, ownership and binding. Source and master may
/// differ after normalization; the client must not invent this receipt.
final class MediaUploadReceipt {
  MediaUploadReceipt._(this.mimeType, this.byteLength, this.checksumSha256);
  static MediaUploadReceipt _parse(Object? raw) {
    final value = _object(raw);
    return MediaUploadReceipt._(
      _mime(value['mime_type']),
      _length(value['byte_length']),
      _checksum(value['checksum_sha256']),
    );
  }

  final String mimeType;
  final int byteLength;
  final String checksumSha256;
}

enum MediaUploadState { ready, processing, expired, unavailable }

final class MediaUploadResult {
  MediaUploadResult._(this.target, this.assetId, this.state, this.receipt);
  factory MediaUploadResult.fromJson(Object? raw) {
    final value = _object(raw);
    final state = switch (value['state']) {
      'ready' => MediaUploadState.ready,
      'processing' => MediaUploadState.processing,
      'expired' => MediaUploadState.expired,
      'unavailable' => MediaUploadState.unavailable,
      _ => throw const MediaProtocolException(),
    };
    if (value['ticket'] != null || (state != MediaUploadState.ready && value['receipt'] != null)) {
      throw const MediaProtocolException();
    }
    return MediaUploadResult._(
      MediaUploadTarget.fromJson(value['target']),
      mediaUploadId(value['asset_id']),
      state,
      state == MediaUploadState.ready ? MediaUploadReceipt._parse(value['receipt']) : null,
    );
  }
  final MediaUploadTarget target;
  final String assetId;
  final MediaUploadState state;
  final MediaUploadReceipt? receipt;
}

/// Temporary PUT capability. Never log/persist URL or headers. The transport
/// must use exactly these headers, no session credentials/cookies or redirects.
final class MediaUploadTicket {
  MediaUploadTicket._(this.url, this.expiresAt, this.headers);
  static MediaUploadTicket _parse(Object? raw, String assetId) {
    // Reuse the shared HTTPS, absolute timestamp and header syntax validation.
    final parsed = MediaReadResult.fromJson({
      'asset_id': assetId,
      'state': 'available',
      'ticket': raw,
    }).ticket!;
    final names = <String>{};
    for (final name in parsed.headers.keys) {
      final normalized = name.toLowerCase();
      if (!names.add(normalized) ||
          _forbiddenHeaders.contains(normalized) ||
          normalized.startsWith('sec-') ||
          normalized.startsWith('proxy-')) {
        throw const MediaProtocolException();
      }
    }
    return MediaUploadTicket._(parsed.url, parsed.expiresAt, parsed.headers);
  }

  final Uri url;
  final DateTime expiresAt;
  final Map<String, String> headers;
  @override
  String toString() => 'Temporary media upload capability.';
}

/// uploadRequired is the only preparation state carrying a ticket. Every other
/// state uses the ordinary result contract; legacy already_uploaded is not READY.
final class MediaUploadPreparation {
  MediaUploadPreparation._(this.requestId, this.result, this.ticket);
  factory MediaUploadPreparation.fromJson(Object? raw) {
    final value = _object(raw);
    final requestId = mediaUploadId(value['request_id']);
    if (value['state'] != 'uploadRequired') {
      return MediaUploadPreparation._(requestId, MediaUploadResult.fromJson(value), null);
    }
    if (value['receipt'] != null) throw const MediaProtocolException();
    final result = MediaUploadResult.fromJson({...value, 'state': 'processing', 'ticket': null});
    return MediaUploadPreparation._(
      requestId,
      result,
      MediaUploadTicket._parse(value['ticket'], result.assetId),
    );
  }
  final String requestId;
  final MediaUploadResult result;
  final MediaUploadTicket? ticket;
  MediaUploadTarget get target => result.target;
  String get assetId => result.assetId;
}

/// Shared identifier validation for the uploader; this grants no authority.
String mediaUploadId(Object? value) {
  if (value is! String || !_uuid.hasMatch(value)) throw const MediaProtocolException();
  return value.toLowerCase();
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _mimePattern = RegExp(r'^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$');
final _checksumPattern = RegExp(r'^[0-9a-f]{64}$');
final _labelPattern = RegExp(r'^[a-z][a-z0-9_-]{0,63}$');
const _forbiddenHeaders = {
  'authorization',
  'cookie',
  'cookie2',
  'apikey',
  'x-api-key',
  'host',
  'connection',
  'content-length',
  'transfer-encoding',
  'origin',
  'referer',
  'set-cookie',
};
Map<String, Object?> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const MediaProtocolException();
  }
  return Map<String, Object?>.from(value);
}

String _label(Object? value) {
  if (value is! String || !_labelPattern.hasMatch(value)) throw const MediaProtocolException();
  return value;
}

String _mime(Object? value) {
  if (value is! String || !_mimePattern.hasMatch(value)) throw const MediaProtocolException();
  return value;
}

String _checksum(Object? value) {
  if (value is! String || !_checksumPattern.hasMatch(value)) throw const MediaProtocolException();
  return value;
}

int _length(Object? value) {
  if (value is! int || value <= 0) throw const MediaProtocolException();
  return value;
}
