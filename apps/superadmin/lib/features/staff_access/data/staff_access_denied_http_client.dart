import 'package:http/http.dart' as http;

import '../domain/staff_access_denied.dart';

/// Cliente HTTP do Supabase que observa respostas 403 do PostgREST: quando o
/// corpo traz `STAFF_ACCESS_DENIED`, publica a negação em [staffAccessDenied]
/// e devolve a resposta intacta (a RPC continua falhando para quem chamou).
/// Um ponto só, em vez de tratar o código em cada repositório.
final class StaffAccessDeniedHttpClient extends http.BaseClient {
  StaffAccessDeniedHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode != 403) return response;
    final buffered = await http.Response.fromStream(response);
    final denial = StaffAccessDenial.fromPostgrestBody(buffered.body);
    if (denial != null) staffAccessDenied.value = denial;
    return http.StreamedResponse(
      Stream.value(buffered.bodyBytes),
      buffered.statusCode,
      contentLength: buffered.bodyBytes.length,
      request: request,
      headers: buffered.headers,
      isRedirect: buffered.isRedirect,
      persistentConnection: buffered.persistentConnection,
      reasonPhrase: buffered.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
