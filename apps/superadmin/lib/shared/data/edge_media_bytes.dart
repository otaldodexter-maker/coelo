import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_object_url_stub.dart'
    if (dart.library.html) 'media_object_url_web.dart'
    as object_url;

/// Bytes de mídia pela Edge (mesmo desenho do entity-media): o navegador nunca
/// fala com o R2, então o CORS do bucket não entra na conta.
///
/// Upload: POST binário com o envelope (os mesmos campos de prepare/finalize)
/// em base64url no cabeçalho `x-coelo-media-envelope`; a Edge prepara, grava e
/// finaliza. Leitura: `inline: true` devolve os bytes em vez de URL assinada.
const edgeMediaEnvelopeHeader = 'x-coelo-media-envelope';

final class EdgeMediaException implements Exception {
  const EdgeMediaException(this.code, {this.status});

  /// Código devolvido pela Edge (`error`) ou o motivo local.
  final String code;

  /// Status HTTP quando a Edge respondeu; null em falha de transporte/contrato.
  final int? status;

  bool get isDenied => status == 401 || status == 403;

  @override
  String toString() => code;
}

String encodeEdgeMediaEnvelope(Map<String, Object?> envelope) =>
    base64Url.encode(utf8.encode(jsonEncode(envelope))).replaceAll('=', '');

Future<Map<String, dynamic>> uploadBytesThroughEdge(
  SupabaseClient client,
  String function, {
  required Map<String, Object?> envelope,
  required Uint8List bytes,
  String failure = 'media_upload_failed',
}) async {
  final response = await _invoke(
    client,
    function,
    body: bytes,
    headers: {edgeMediaEnvelopeHeader: encodeEdgeMediaEnvelope(envelope)},
    failure: failure,
  );
  if (response.data is! Map) throw EdgeMediaException(failure);
  return Map<String, dynamic>.from(response.data as Map);
}

Future<Uint8List> readBytesThroughEdge(
  SupabaseClient client,
  String function,
  Map<String, Object?> body, {
  String failure = 'media_read_failed',
}) async {
  final response = await _invoke(
    client,
    function,
    body: {...body, 'inline': true},
    failure: failure,
  );
  final data = response.data;
  if (data is! Uint8List || data.isEmpty) throw EdgeMediaException(failure);
  return data;
}

Future<FunctionResponse> _invoke(
  SupabaseClient client,
  String function, {
  required Object body,
  Map<String, String>? headers,
  required String failure,
}) async {
  try {
    final response = await client.functions.invoke(function, body: body, headers: headers);
    if (response.status < 200 || response.status >= 300) {
      throw EdgeMediaException(failure, status: response.status);
    }
    return response;
  } on FunctionException catch (error) {
    final details = error.details;
    throw EdgeMediaException(
      details is Map && details['error'] is String ? details['error'] as String : failure,
      status: error.status,
    );
  }
}

/// URL local para `Image.network`/`VideoPlayer` a partir dos bytes lidos pela
/// Edge: `blob:` no navegador, `data:` fora dele (testes).
String mediaObjectUrl(Uint8List bytes, String mimeType) =>
    object_url.createMediaObjectUrl(bytes, mimeType);

/// MIME real pelos primeiros bytes (as mesmas assinaturas que a Edge confere);
/// [fallback] quando não reconhece.
String sniffMediaMimeType(Uint8List bytes, {String fallback = 'application/octet-stream'}) {
  if (bytes.length < 12) return fallback;
  String text(int start, int end) => String.fromCharCodes(bytes.sublist(start, end));
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
  if (bytes[0] == 0x89 && text(1, 4) == 'PNG') return 'image/png';
  if (text(0, 4) == 'RIFF' && text(8, 12) == 'WEBP') return 'image/webp';
  if (text(0, 4) == 'RIFF' && text(8, 12) == 'WAVE') return 'audio/wav';
  if (text(4, 8) == 'ftyp') return fallback.startsWith('audio/') ? fallback : 'video/mp4';
  if (text(0, 5) == '%PDF-') return 'application/pdf';
  if (text(0, 3) == 'ID3' || (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) return 'audio/mpeg';
  return fallback;
}
