import 'dart:math';

import 'package:coelo_api/coelo_api.dart';

import 'forms_backend_gateway.dart';

/// Uses the answer-image download endpoint, which reauthorizes the opaque
/// editing secret. The secret is only placed in the authenticated POST body.
final class FormsAnonymousImageReader implements MediaReader {
  FormsAnonymousImageReader({
    required FormsBackendGateway gateway,
    required String editSecret,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _editSecret = editSecret,
       _now = now ?? DateTime.now;

  final FormsBackendGateway _gateway;
  final String _editSecret;
  final DateTime Function() _now;

  @override
  Future<MediaReadResult> read(MediaReadRequest request) async {
    if (request.rendition != MediaReadRendition.original) {
      throw const MediaProtocolException();
    }
    try {
      final started = _now().toUtc();
      final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final requestId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      final raw = await _gateway.media({
        'action': 'download',
        'request_id': requestId,
        'expected_version': 0,
        'payload': {'asset_id': request.assetId, 'edit_secret': _editSecret},
      });
      if (raw is! Map || raw['expires_in'] is! int) throw const MediaProtocolException();
      final seconds = raw['expires_in'] as int;
      if (seconds < 1 || seconds > 60) throw const MediaProtocolException();
      // Count from dispatch, conservatively including network/authorization time.
      final expiry = started.add(Duration(seconds: seconds));
      if (!expiry.isAfter(_now().toUtc())) throw const MediaTicketExpiredException();
      return MediaReadResult.fromJson({
        'asset_id': request.assetId,
        'state': 'available',
        'ticket': {
          'url': raw['signed_url'],
          'expires_at': expiry.toIso8601String(),
          'headers': <String, String>{},
        },
      });
    } on MediaTicketExpiredException {
      rethrow;
    } on Object {
      throw const MediaProtocolException();
    }
  }
}

final class FormsQuestionImageReader implements MediaReader {
  FormsQuestionImageReader({required FormsBackendGateway gateway, DateTime Function()? now})
    : _gateway = gateway,
      _now = now ?? DateTime.now;
  final FormsBackendGateway _gateway;
  final DateTime Function() _now;

  @override
  Future<MediaReadResult> read(MediaReadRequest request) async {
    try {
      final raw = await _gateway.media({
        'action': 'resolve',
        'payload': {'purpose': 'question-image', 'asset_id': request.assetId},
      });
      if (raw is! Map || raw['asset_id'] != request.assetId) throw const MediaProtocolException();
      final result = MediaReadResult.fromJson({
        'asset_id': raw['asset_id'],
        'state': 'available',
        'ticket': {
          'url': raw['signed_url'],
          'headers': <String, String>{},
          'expires_at': raw['expires_at'],
        },
      });
      final expiry = result.ticket!.expiresAt;
      if (!expiry.isAfter(_now().toUtc()) ||
          expiry.difference(_now().toUtc()) > const Duration(minutes: 5)) {
        throw const MediaTicketExpiredException();
      }
      return result;
    } on MediaTicketExpiredException {
      rethrow;
    } on Object {
      throw const MediaProtocolException();
    }
  }
}

/// Adapter for the candidate Forms media read envelope. Endpoint support and
/// server authorization must be verified separately before production wiring.
/// The consumer supplies its existing session through [SessionMediaReader].
final class FormsMediaReader implements MediaReader {
  FormsMediaReader({required FormsBackendGateway gateway, DateTime Function()? now})
    : _gateway = gateway,
      _now = now ?? DateTime.now;

  final FormsBackendGateway _gateway;
  final DateTime Function() _now;

  @override
  Future<MediaReadResult> read(MediaReadRequest request) async {
    try {
      final raw = await _gateway.media({'action': 'read', 'payload': request.toJson()});
      final result = MediaReadResult.fromJson(raw);
      if (result.assetId != request.assetId) throw const MediaProtocolException();
      final ticket = result.ticket;
      if (ticket != null) {
        final now = _now().toUtc();
        if (!ticket.expiresAt.isAfter(now)) throw const MediaTicketExpiredException();
        if (ticket.expiresAt.difference(now) > const Duration(seconds: 300)) {
          throw const MediaProtocolException();
        }
      }
      return result;
    } on MediaTicketExpiredException {
      rethrow;
    } catch (_) {
      // Gateway errors can contain bearer capabilities; never retain or expose them.
      throw const MediaProtocolException();
    }
  }
}
