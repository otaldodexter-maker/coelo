import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class FormExportDownloadGateway {
  Future<Object?> resolve(String jobId);
}

final class SupabaseFormExportDownloadGateway implements FormExportDownloadGateway {
  const SupabaseFormExportDownloadGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<Object?> resolve(String jobId) async {
    final response = await _client.functions.invoke(
      'form-export-download',
      body: {'job_id': jobId},
    );
    if (response.status < 200 || response.status >= 300) throw StateError('export unavailable');
    return response.data;
  }
}

final class FormExportDownloadTicket {
  const FormExportDownloadTicket({required this.downloadUrl, required this.expiresAt});
  final Uri downloadUrl;
  final DateTime expiresAt;
}

final class FormExportDownloadUnavailable implements Exception {
  const FormExportDownloadUnavailable();
}

final class FormExportDownloadResolver {
  FormExportDownloadResolver({required FormExportDownloadGateway gateway, DateTime Function()? now})
    : _gateway = gateway,
      _now = now ?? DateTime.now;
  final FormExportDownloadGateway _gateway;
  final DateTime Function() _now;

  Future<FormExportDownloadTicket> resolve(String jobId) async {
    try {
      final raw = await _gateway.resolve(jobId);
      if (raw is! Map) throw const FormatException();
      final payload = Map<String, Object?>.from(raw);
      final url = Uri.tryParse(payload['download_url']?.toString() ?? '');
      final expiresAt = DateTime.tryParse(payload['expires_at']?.toString() ?? '')?.toUtc();
      if (url == null ||
          url.scheme != 'https' ||
          expiresAt == null ||
          !expiresAt.isAfter(_now().toUtc())) {
        throw const FormatException();
      }
      return FormExportDownloadTicket(downloadUrl: url, expiresAt: expiresAt);
    } catch (_) {
      throw const FormExportDownloadUnavailable();
    }
  }
}
