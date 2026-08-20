import 'package:supabase_flutter/supabase_flutter.dart';

final class FormsBackendFailure implements Exception {
  const FormsBackendFailure({required this.code, required this.message});

  final String code;
  final String message;
}

abstract interface class FormsBackendGateway {
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters);

  Future<Object?> media(Map<String, Object?> envelope);
}

final class SupabaseFormsBackendGateway implements FormsBackendGateway {
  const SupabaseFormsBackendGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    try {
      return await _client.rpc<Object?>(functionName, params: parameters);
    } on PostgrestException catch (error) {
      throw FormsBackendFailure(code: error.code ?? 'unknown', message: error.message);
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
        message: error.reasonPhrase ?? 'Form media request unavailable.',
      );
    }
  }
}
