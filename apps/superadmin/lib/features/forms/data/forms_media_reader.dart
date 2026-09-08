import 'package:coelo_api/coelo_api.dart';

import 'forms_backend_gateway.dart';

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
