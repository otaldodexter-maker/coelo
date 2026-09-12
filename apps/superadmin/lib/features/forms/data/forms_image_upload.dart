import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// One selected image, one authorized form target, and one media lifetime.
/// An uncertain transfer retains its asset ID for finalize/discard; it never
/// invents success, repeats the PUT or deletes a possibly completed upload.
final class FormsImageUpload {
  FormsImageUpload({
    required this.api,
    required this.session,
    required this.occurrenceId,
    required this.itemId,
    required this.requestId,
    required this.finalizeRequestId,
    this.editSecret,
    http.Client Function()? createClient,
    DateTime Function()? now,
  }) : assert(api != null),
       questionApi = null,
       questionTarget = null,
       _createClient = createClient ?? http.Client.new,
       _now = now ?? DateTime.now;

  FormsImageUpload.questionImage({
    required FormsQuestionImageApi api,
    required FormQuestionImageTarget target,
    required this.session,
    required this.requestId,
    required this.finalizeRequestId,
    http.Client Function()? createClient,
    DateTime Function()? now,
  }) : api = null,
       questionApi = api,
       questionTarget = target,
       itemId = target.itemId,
       occurrenceId = '',
       editSecret = null,
       _createClient = createClient ?? http.Client.new,
       _now = now ?? DateTime.now;

  final FormsApi? api;
  final FormsQuestionImageApi? questionApi;
  final FormQuestionImageTarget? questionTarget;
  final MediaSession session;
  final String occurrenceId;
  final String itemId;
  final String requestId;
  final String finalizeRequestId;
  final String? editSecret;
  final http.Client Function() _createClient;
  final DateTime Function() _now;
  final _abort = Completer<void>();
  String? assetId;
  bool _cancelled = false;
  bool _started = false;
  String? _sourceMime;
  int? _sourceLength;

  void cancel() {
    _cancelled = true;
    if (!_abort.isCompleted) _abort.complete();
  }

  Future<FormAsset> upload(Uint8List bytes) async {
    if (_started || _cancelled || session.isInvalidated) {
      bytes.fillRange(0, bytes.length, 0);
      throw const FormsImageUploadException();
    }
    _started = true;
    final mime = formsImageMime(bytes);
    final maxBytes = questionApi == null ? 10 * 1024 * 1024 : 4 * 1024 * 1024;
    if (mime == null || bytes.isEmpty || bytes.length > maxBytes) {
      bytes.fillRange(0, bytes.length, 0);
      throw FormsImageUploadException(
        'Escolha uma imagem JPEG, PNG ou WebP de até ${maxBytes ~/ (1024 * 1024)} MB.',
      );
    }
    _sourceMime = mime;
    _sourceLength = bytes.length;
    http.Client? client;
    http.AbortableRequest? request;
    final unregister = session.registerPurge(() {
      cancel();
      bytes.fillRange(0, bytes.length, 0);
      client?.close();
      final body = request?.bodyBytes;
      body?.fillRange(0, body.length, 0);
    });
    try {
      final ticket = await session.run(
        () => questionApi != null
            ? questionApi!.prepareQuestionImage(
                questionTarget!,
                requestId: requestId,
                sourceMetadata: MediaUploadMetadata(
                  mimeType: mime,
                  byteLength: bytes.length,
                  checksumSha256: sha256.convert(bytes).toString(),
                ),
              )
            : api!.prepareAssetUpload(
                FormCommand(
                  requestId: requestId,
                  expectedVersion: 0,
                  payload: FormAssetUploadPayload(
                    occurrenceId: occurrenceId,
                    itemId: itemId,
                    mimeType: mime,
                    byteLength: bytes.length,
                    checksum: sha256.convert(bytes).toString(),
                    editSecret: editSecret,
                  ),
                ),
              ),
      );
      assetId = ticket.assetId;
      if (_cancelled) throw const FormsImageUploadException();
      final capability = MediaReadResult.fromJson({
        'asset_id': ticket.assetId,
        'state': 'available',
        'ticket': {
          'url': ticket.uploadUrl.toString(),
          'headers': ticket.requiredHeaders,
          'expires_at': ticket.expiresAt.toUtc().toIso8601String(),
        },
      }).ticket!;
      final names = ticket.requiredHeaders.keys.map((name) => name.toLowerCase()).toList();
      // R2 tickets use Content-Type; no Supabase authorization is copied to PUT.
      if (names.toSet().length != names.length ||
          names.any((name) => name != 'content-type' && name != 'x-amz-checksum-sha256') ||
          !ticket.requiredHeaders.entries.any(
            (entry) => entry.key.toLowerCase() == 'content-type' && entry.value == mime,
          ) ||
          !capability.expiresAt.isAfter(_now().toUtc()) ||
          capability.expiresAt.difference(_now().toUtc()) > const Duration(minutes: 5)) {
        throw const FormsImageUploadException('O envio expirou ou não pôde ser autorizado.');
      }
      client = _createClient();
      request = http.AbortableRequest('PUT', capability.url, abortTrigger: _abort.future)
        ..followRedirects = false
        ..headers.addAll(ticket.requiredHeaders)
        ..bodyBytes = bytes;
      final response = await session.run(() => client!.send(request!));
      await session.run(() => response.stream.drain<void>());
      if (_cancelled || response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormsImageUploadException();
      }
      return await finalize();
    } on FormsImageUploadException {
      rethrow;
    } on Object {
      // HTTP exceptions can contain the signed URL. Only safe UI text escapes.
      throw const FormsImageUploadException();
    } finally {
      unregister();
      client?.close();
      final body = request?.bodyBytes;
      body?.fillRange(0, body.length, 0);
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<FormAsset> finalize() async {
    final id = assetId;
    if (id == null) throw const FormsImageUploadException();
    try {
      final result = await session.run(
        () => questionApi != null
            ? questionApi!.finalizeQuestionImage(
                questionTarget!,
                FormCommand(
                  requestId: finalizeRequestId,
                  expectedVersion: 0,
                  payload: FormAssetIdPayload(id),
                ),
              )
            : api!.finalizeAssetUpload(
                FormCommand(
                  requestId: finalizeRequestId,
                  expectedVersion: 0,
                  payload: FormAssetIdPayload(id, editSecret: editSecret),
                ),
              ),
      );
      if (result.id != id ||
          result.itemId != itemId ||
          result.mimeType != _sourceMime ||
          result.byteLength != _sourceLength) {
        throw const FormsImageUploadException();
      }
      return result;
    } on Object {
      throw const FormsImageUploadException(
        'Não foi possível confirmar a imagem. Verifique o envio ou descarte-o.',
      );
    }
  }

  Future<void> discard(String discardRequestId) async {
    final id = assetId;
    if (id == null) return;
    try {
      await session.run(
        () => questionApi != null
            ? questionApi!.deleteQuestionImage(
                FormCommand(
                  requestId: discardRequestId,
                  expectedVersion: 0,
                  payload: FormAssetIdPayload(id),
                ),
              )
            : api!.discardAsset(
                FormCommand(
                  requestId: discardRequestId,
                  expectedVersion: 0,
                  payload: FormAssetIdPayload(id, editSecret: editSecret),
                ),
              ),
      );
    } on Object {
      throw const FormsImageUploadException(
        'Não foi possível descartar a imagem. Tente novamente.',
      );
    }
  }
}

String? formsImageMime(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

final class FormsImageUploadException implements Exception {
  const FormsImageUploadException([
    this.message = 'Não foi possível concluir o envio. Verifique ou descarte a imagem.',
  ]);
  final String message;
  @override
  String toString() => message;
}
