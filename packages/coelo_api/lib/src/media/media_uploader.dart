import 'dart:async';
import 'dart:typed_data';

import 'media_read_contract.dart';
import 'media_session.dart';
import 'media_upload_contract.dart';

/// Domain adapter bound to one immutable target and authorized session/context.
/// Every operation must reauthorize server-side. Keep domain versioning, parent
/// IDs and anonymous edit secrets in that adapter; never in R2 PUT headers.
abstract interface class MediaUploadGateway {
  MediaUploadTarget get target;
  Future<MediaUploadPreparation> prepare({
    required String requestId,
    required MediaUploadMetadata sourceMetadata,
  });
  Future<MediaUploadResult> finalize({required String requestId, required String assetId});
  Future<MediaUploadResult> reconcile({required String assetId});

  /// Explicit authorized detach/delete command, preserving audit history.
  Future<void> discard({required String requestId, required String assetId});
}

/// One PUT, without redirects, cookies, auth interceptors or implicit retry.
/// Return only after a successful full upload; throw on any HTTP/network error.
/// Observe [MediaUploadTransfer.cancelled] to abort/release the request promptly.
typedef MediaUploadPut = Future<void> Function(MediaUploadTransfer transfer);

/// In-memory capability/body, valid only during the injected PUT call.
/// Cancellation clears the buffer and drops the capability. A transport must
/// also release its own copied bytes and HTTP request on cancellation.
final class MediaUploadTransfer {
  MediaUploadTransfer._(MediaUploadTicket ticket, this._bytes) : _ticket = ticket;
  MediaUploadTicket? _ticket;
  final Uint8List _bytes;
  final _cancelled = Completer<void>();
  Uri get url => _activeTicket.url;
  Map<String, String> get headers => _activeTicket.headers;
  DateTime get expiresAt => _activeTicket.expiresAt;
  Uint8List get bytes => _bytes.asUnmodifiableView();
  Future<void> get cancelled => _cancelled.future;
  bool get isCancelled => _cancelled.isCompleted;
  MediaUploadTicket get _activeTicket => _ticket ?? (throw const MediaUploadException());
  void _cancel() {
    _ticket = null;
    _bytes.fillRange(0, _bytes.length, 0);
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  @override
  String toString() => 'Temporary private media transfer.';
}

/// Client orchestration only. It does not sign, decode, authorize or implement
/// an HTTP endpoint. Ambiguous PUT/finalize gets one explicit reconciliation,
/// never an automatic DELETE/retry. Consumers retain command IDs for retries.
final class SessionMediaUploader {
  SessionMediaUploader({
    required MediaUploadGateway gateway,
    required MediaSession session,
    required MediaUploadPut put,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _target = gateway.target,
       _session = session,
       _put = put,
       _now = now ?? DateTime.now;
  final MediaUploadGateway _gateway;
  final MediaUploadTarget _target;
  final MediaSession _session;
  final MediaUploadPut _put;
  final DateTime Function() _now;

  Future<MediaUploadResult> upload({
    required String requestId,
    required String finalizeRequestId,
    required MediaUploadSource source,
  }) async {
    requestId = mediaUploadId(requestId);
    finalizeRequestId = mediaUploadId(finalizeRequestId);
    _checkContext();
    final bytes = source.copyBytes();
    MediaUploadTransfer? transfer;
    final unregister = _session.registerPurge(() {
      transfer?._cancel();
      bytes.fillRange(0, bytes.length, 0);
      source.clear();
    });
    try {
      final prepared = await _run(
        () => _gateway.prepare(requestId: requestId, sourceMetadata: source.metadata),
      );
      if (prepared.requestId != requestId || prepared.target != _target) {
        throw const MediaProtocolException();
      }
      final ticket = prepared.ticket;
      if (ticket == null) return prepared.result;
      if (!ticket.expiresAt.isAfter(_now().toUtc())) throw const MediaTicketExpiredException();
      for (final header in ticket.headers.entries) {
        if (header.key.toLowerCase() == 'content-type' &&
            header.value != source.metadata.mimeType) {
          throw const MediaProtocolException();
        }
      }
      transfer = MediaUploadTransfer._(ticket, bytes);
      try {
        await _run(() => _put(transfer!));
      } on MediaSessionInvalidatedException {
        rethrow;
      } catch (_) {
        transfer._cancel();
        return await reconcile(assetId: prepared.assetId);
      }
      transfer._cancel();
      MediaUploadResult result;
      try {
        result = await _run(
          () => _gateway.finalize(requestId: finalizeRequestId, assetId: prepared.assetId),
        );
      } on MediaSessionInvalidatedException {
        rethrow;
      } catch (_) {
        return await reconcile(assetId: prepared.assetId);
      }
      return _correlate(result, prepared.assetId);
    } finally {
      unregister();
      transfer?._cancel();
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<MediaUploadResult> reconcile({required String assetId}) async {
    assetId = mediaUploadId(assetId);
    try {
      return _correlate(await _run(() => _gateway.reconcile(assetId: assetId)), assetId);
    } on MediaSessionInvalidatedException {
      rethrow;
    } on MediaProtocolException {
      rethrow;
    } catch (_) {
      throw MediaUploadUncertainException(assetId);
    }
  }

  Future<void> discard({required String requestId, required String assetId}) {
    requestId = mediaUploadId(requestId);
    assetId = mediaUploadId(assetId);
    return _run(() => _gateway.discard(requestId: requestId, assetId: assetId));
  }

  MediaUploadResult _correlate(MediaUploadResult result, String assetId) {
    if (result.assetId != assetId || result.target != _target) throw const MediaProtocolException();
    return result;
  }

  void _checkContext() {
    if (_session.isInvalidated) throw const MediaSessionInvalidatedException();
    if (_gateway.target != _target) throw const MediaProtocolException();
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    _checkContext();
    try {
      final result = await _session.run(operation);
      _checkContext();
      return result;
    } catch (error) {
      _checkContext();
      if (error is MediaProtocolException) rethrow;
      throw const MediaUploadException();
    }
  }
}

final class MediaUploadException implements Exception {
  const MediaUploadException();
  @override
  String toString() => 'Private media upload failed.';
}

final class MediaUploadUncertainException implements Exception {
  const MediaUploadUncertainException(this.assetId);
  final String assetId;
  @override
  String toString() => 'Media upload outcome requires reconciliation.';
}
