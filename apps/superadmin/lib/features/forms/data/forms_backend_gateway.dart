import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/edge_media_bytes.dart';

final class FormsBackendFailure implements Exception {
  const FormsBackendFailure({required this.code, required this.message, this.detail});

  final String code;
  final String message;

  /// O `detail` do erro Postgres quando e um codigo estavel do Coelo
  /// (`FORMS_*`), nunca texto livre: o cliente traduz codigo, nao mensagem.
  final String? detail;
}

String? formsBackendStableDetail(Object? detail) =>
    detail is String && RegExp(r'^FORMS_[A-Z_]+$').hasMatch(detail) ? detail : null;

/// Code used when the request never reached the backend, so there is no
/// Postgres code and no response body to classify.
const formsBackendTransportCode = 'transport';

abstract interface class FormsBackendGateway {
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters);

  Future<Object?> media(Map<String, Object?> envelope);

  /// Upload binário pela Edge `form-media`: [envelope] é o corpo do `prepare`
  /// (+ `finalize_request_id`); a Edge prepara, grava no R2 e finaliza.
  /// Devolve o JSON do `finalize`.
  Future<Object?> mediaUpload(Map<String, Object?> envelope, Uint8List bytes);

  /// Leitura inline pela Edge (`inline: true`): bytes + MIME real, sem URL
  /// assinada no navegador.
  Future<FormsMediaBytes> mediaBytes(Map<String, Object?> envelope);
}

final class FormsMediaBytes {
  const FormsMediaBytes({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

final class SupabaseFormsBackendGateway implements FormsBackendGateway {
  const SupabaseFormsBackendGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    try {
      return await _client.rpc<Object?>(functionName, params: parameters);
    } on PostgrestException catch (error) {
      throw FormsBackendFailure(
        code: error.code ?? 'unknown',
        message: 'Forms backend request failed.',
        detail: formsBackendStableDetail(error.details),
      );
    } on Exception {
      // The request never reached the backend: socket, DNS, TLS or timeout.
      // The platform exception carries the address and the full URI, so it
      // must not travel further. Only Exception is converted; an Error is a
      // programming fault and keeps propagating.
      throw const FormsBackendFailure(
        code: formsBackendTransportCode,
        message: 'Forms backend unreachable.',
      );
    }
  }

  @override
  Future<Object?> media(Map<String, Object?> envelope) async {
    try {
      final response = await _client.functions.invoke('form-media', body: envelope);
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        final payload = data is Map ? Map<String, Object?>.from(data) : const <String, Object?>{};
        throw FormsBackendFailure(
          code: payload['error']?.toString() ?? response.status.toString(),
          message: 'Form media request failed.',
        );
      }
      return data;
    } on FormsBackendFailure {
      rethrow;
    } on FunctionException catch (error) {
      throw FormsBackendFailure(
        code: error.status.toString(),
        message: 'Form media request unavailable.',
      );
    } on Exception {
      throw const FormsBackendFailure(
        code: formsBackendTransportCode,
        message: 'Form media request unreachable.',
      );
    }
  }

  @override
  Future<Object?> mediaUpload(Map<String, Object?> envelope, Uint8List bytes) async {
    try {
      return await uploadBytesThroughEdge(
        _client,
        'form-media',
        envelope: envelope,
        bytes: bytes,
        failure: 'media_upload_failed',
      );
    } on EdgeMediaException catch (error) {
      throw FormsBackendFailure(
        code: error.status == null ? formsBackendTransportCode : error.code,
        message: 'Form media upload failed.',
      );
    }
  }

  @override
  Future<FormsMediaBytes> mediaBytes(Map<String, Object?> envelope) async {
    try {
      final bytes = await readBytesThroughEdge(_client, 'form-media', envelope);
      return FormsMediaBytes(bytes: bytes, mimeType: sniffMediaMimeType(bytes));
    } on EdgeMediaException catch (error) {
      throw FormsBackendFailure(
        code: error.status == null ? formsBackendTransportCode : error.code,
        message: 'Form media read failed.',
      );
    }
  }
}
