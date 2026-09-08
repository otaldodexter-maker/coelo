import 'package:coelo_api/coelo_api.dart';
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
  FormExportDownloadTicket._({
    required Uri downloadUrl,
    required this.expiresAt,
    required MediaSession session,
    required DateTime Function() now,
  }) : _downloadUrl = downloadUrl,
       _session = session,
       _now = now {
    _unregister = session.registerPurge(dispose);
  }
  Uri? _downloadUrl;
  final DateTime expiresAt;
  final MediaSession _session;
  final DateTime Function() _now;
  void Function()? _unregister;

  Uri get downloadUrl {
    final url = _downloadUrl;
    if (url == null || _session.isInvalidated || !expiresAt.isAfter(_now().toUtc())) {
      dispose();
      throw const FormExportDownloadUnavailable();
    }
    return url;
  }

  void dispose() {
    _downloadUrl = null;
    _unregister?.call();
    _unregister = null;
  }

  @override
  String toString() => 'Temporary form export download capability.';
}

final class FormExportDownloadUnavailable implements Exception {
  const FormExportDownloadUnavailable();
}

final class FormExportDownloadResolver {
  FormExportDownloadResolver({
    required FormExportDownloadGateway gateway,
    required MediaSession session,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _session = session,
       _now = now ?? DateTime.now;
  final FormExportDownloadGateway _gateway;
  final MediaSession _session;
  final DateTime Function() _now;

  Future<FormExportDownloadTicket> resolve(String jobId) async {
    try {
      if (!_jobId.hasMatch(jobId)) throw const FormatException();
      final requestedId = jobId.toLowerCase();
      final raw = await _session.run(() => _gateway.resolve(requestedId));
      if (raw is! Map) throw const FormatException();
      final payload = Map<String, Object?>.from(raw);
      final receiptId = payload['job_id'];
      if (receiptId is! String || receiptId.toLowerCase() != requestedId) {
        throw const FormatException();
      }
      final rawUrl = payload['download_url'];
      final rawExpiry = payload['expires_at'];
      if (rawUrl is! String ||
          rawUrl.codeUnits.any((unit) => unit <= 32 || unit == 127) ||
          rawExpiry is! String ||
          !_utcExpiry.hasMatch(rawExpiry)) {
        throw const FormatException();
      }
      final url = Uri.tryParse(rawUrl);
      final expiresAt = DateTime.tryParse(rawExpiry)?.toUtc();
      final now = _now().toUtc();
      if (url == null ||
          url.scheme != 'https' ||
          !url.hasAuthority ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          url.hasFragment ||
          expiresAt == null ||
          expiresAt.toIso8601String().substring(0, 19) != rawExpiry.substring(0, 19) ||
          !expiresAt.isAfter(now) ||
          expiresAt.difference(now) > const Duration(minutes: 5)) {
        throw const FormatException();
      }
      return FormExportDownloadTicket._(
        downloadUrl: url,
        expiresAt: expiresAt,
        session: _session,
        now: _now,
      );
    } catch (_) {
      throw const FormExportDownloadUnavailable();
    }
  }
}

final _jobId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
// The download handler emits an absolute UTC ISO timestamp and a maximum 300s ticket.
final _utcExpiry = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$');
