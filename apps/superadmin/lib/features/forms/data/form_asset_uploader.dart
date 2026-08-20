import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:http/http.dart' as http;

typedef FormAssetUploadProgress = void Function(double progress);

final class FormAssetUploadException implements Exception {
  const FormAssetUploadException(this.message);

  final String message;

  @override
  String toString() => 'FormAssetUploadException: $message';
}

/// Uploads an image directly to the short-lived URL authorized by the backend.
///
/// The request deliberately has no Supabase session or service-role header. The
/// signed URL is the only upload capability and must never be logged.
final class FormAssetUploader {
  FormAssetUploader({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const maximumBytes = 10 * 1024 * 1024;
  static const allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  final http.Client _client;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<void> upload({
    required FormAssetUploadTicket ticket,
    required Uint8List bytes,
    required String mimeType,
    DateTime? now,
    FormAssetUploadProgress? onProgress,
  }) async {
    if (!allowedMimeTypes.contains(mimeType)) {
      throw const FormAssetUploadException('Formato de imagem não permitido.');
    }
    if (bytes.isEmpty || bytes.length > maximumBytes) {
      throw const FormAssetUploadException('A imagem deve ter no máximo 10 MB.');
    }
    if (!(now ?? DateTime.now()).isBefore(ticket.expiresAt)) {
      throw const FormAssetUploadException('A autorização de upload expirou.');
    }

    final request = http.Request('PUT', ticket.signedUploadUrl)
      ..headers['content-type'] = mimeType
      ..bodyBytes = bytes;
    onProgress?.call(0);

    late http.StreamedResponse response;
    try {
      response = await _client.send(request);
      await response.stream.drain<void>();
    } catch (_) {
      throw const FormAssetUploadException('Não foi possível enviar a imagem.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormAssetUploadException('O armazenamento recusou a imagem.');
    }
    onProgress?.call(1);
  }
}
