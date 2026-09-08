import 'media_read_contract.dart';
import 'media_session.dart';

/// Read operation of the shared gateway. Implementations must reauthorize the
/// actor, entity, purpose and rendition on the server for every request.
abstract interface class MediaReader {
  Future<MediaReadResult> read(MediaReadRequest request);
}

/// Correlation and session boundary for a gateway reader, not an HTTP adapter,
/// cache, or authorization mechanism. No implicit retry or background polling.
final class SessionMediaReader implements MediaReader {
  SessionMediaReader({
    required MediaReader delegate,
    required MediaSession session,
    DateTime Function()? now,
  }) : _delegate = delegate,
       _session = session,
       _now = now ?? DateTime.now;

  final MediaReader _delegate;
  final MediaSession _session;
  final DateTime Function() _now;

  @override
  Future<MediaReadResult> read(MediaReadRequest request) => _session.run(() async {
    final result = await _delegate.read(request);
    if (result.assetId != request.assetId) throw const MediaProtocolException();
    final ticket = result.ticket;
    if (ticket != null && !ticket.expiresAt.isAfter(_now().toUtc())) {
      throw const MediaTicketExpiredException();
    }
    return result;
  });
}
