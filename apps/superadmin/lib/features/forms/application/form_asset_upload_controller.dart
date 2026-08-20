import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:crypto/crypto.dart';

typedef FormUploadBytes = Future<void> Function({
  required FormAssetUploadTicket ticket,
  required Uint8List bytes,
  required String mimeType,
  void Function(double progress)? onProgress,
});

final class FormAssetUploadFlowException implements Exception {
  const FormAssetUploadFlowException(this.message);

  final String message;

  @override
  String toString() => 'FormAssetUploadFlowException: $message';
}

final class FormAssetUploadController {
  const FormAssetUploadController({
    required FormsApi api,
    required FormUploadBytes uploadBytes,
    required String Function() requestIdFactory,
  }) : _api = api,
       _uploadBytes = uploadBytes,
       _requestIdFactory = requestIdFactory;

  final FormsApi _api;
  final FormUploadBytes _uploadBytes;
  final String Function() _requestIdFactory;

  Future<FormAsset> upload({
    required String occurrenceId,
    required String itemId,
    required Uint8List bytes,
    required String mimeType,
    String? editSecret,
    void Function(double progress)? onProgress,
  }) async {
    FormAssetUploadTicket? ticket;
    try {
      ticket = await _api.prepareAssetUpload(
        FormCommand(
          requestId: _requestIdFactory(),
          expectedVersion: 0,
          payload: FormAssetUploadPayload(
            occurrenceId: occurrenceId,
            itemId: itemId,
            mimeType: mimeType,
            byteLength: bytes.length,
            checksum: sha256.convert(bytes).toString(),
            editSecret: editSecret,
          ),
        ),
      );
      await _uploadBytes(
        ticket: ticket,
        bytes: bytes,
        mimeType: mimeType,
        onProgress: onProgress,
      );
      return await _api.finalizeAssetUpload(
        FormCommand(
          requestId: _requestIdFactory(),
          expectedVersion: 0,
          payload: FormAssetIdPayload(ticket.assetId, editSecret: editSecret),
        ),
      );
    } catch (_) {
      if (ticket != null) {
        try {
          await _api.discardAsset(
            FormCommand(
              requestId: _requestIdFactory(),
              expectedVersion: 0,
              payload: FormAssetIdPayload(ticket.assetId, editSecret: editSecret),
            ),
          );
        } catch (_) {
          // Cleanup is best effort; the backend also expires abandoned uploads.
        }
      }
      throw const FormAssetUploadFlowException('Não foi possível concluir o envio da imagem.');
    }
  }
}
