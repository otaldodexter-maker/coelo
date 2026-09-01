import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/import_job.dart';
import '../domain/import_repository.dart';

/// Production adapter: every read is scoped by the hub RPC and uploads are
/// binary requests to the authenticated Edge boundary.
final class SupabaseImportRepository implements ImportRepository, ImportExecutionCapabilities {
  SupabaseImportRepository(this._client);

  final SupabaseClient _client;
  final Map<String, String> _createKeys = <String, String>{};
  final Map<String, String> _confirmKeys = <String, String>{};

  @override
  Set<ImportEntity> get supportedImportEntities => const <ImportEntity>{ImportEntity.units};

  @override
  Future<List<ImportJob>> fetchJobs() async =>
      (await fetchPage(const ImportJobQuery(pageSize: 100))).items;

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async {
    try {
      final cursor = _decodeCursor(query.cursor);
      final data = _map(
        await _client.rpc<Object?>(
          'superadmin_list_import_export_jobs',
          params: <String, Object?>{
            'p_domains': query.entities.map((x) => x.name).toList(growable: false),
            'p_states': query.status == null ? const <String>[] : <String>[_state(query.status!)],
            'p_formats': query.file == null ? const <String>[] : <String>[query.file!.name],
            'p_search': query.search,
            'p_created_from': query.createdAfter?.toUtc().toIso8601String(),
            'p_created_to': query.createdBefore?.toUtc().toIso8601String(),
            'p_before_created_at': cursor?.createdAt,
            'p_before_job_id': cursor?.jobId,
            'p_page_size': query.pageSize,
          },
        ),
      );
      final rows = data['items'];
      if (rows is! List) throw const FormatException('Invalid import hub list.');
      return ImportJobPage(
        items: rows.map(_job).toList(growable: false),
        nextCursor: _encodeCursor(data['next_cursor']),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const ImportRepositoryUnavailableException();
    } on FormatException {
      throw const ImportRepositoryUnavailableException();
    }
  }

  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) async {
    if (entity != ImportEntity.units) return _unavailable();
    final intent = '${entity.name}|${strategy.name}|$context|${file.name}';
    final key = _createKeys.putIfAbsent(intent, _uuid);
    final result = await _invoke(<String, Object?>{
      'action': 'create_import',
      'domain': 'units',
      'file_name': file.fileName,
      'mime_type': _mime(file),
      'source_format': file.name,
      'idempotency_key': key,
    });
    if (_createKeys[intent] == key) _createKeys.remove(intent);
    return result;
  }

  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) async {
    if (job.entity != ImportEntity.units || sourceFile == null || sourceFile.bytes.isEmpty) {
      return _unavailable();
    }
    try {
      final response = await _client.functions.invoke(
        'import-export-jobs',
        body: sourceFile.bytes,
        headers: <String, String>{
          'Content-Type': sourceFile.mimeType,
          'x-coelo-import-action': 'upload',
          'x-coelo-import-job-id': job.id,
        },
      );
      if (response.status < 200 || response.status >= 300) return _unavailable();
      final requestId = _confirmKeys.putIfAbsent(job.id, _uuid);
      final result = await _invoke(<String, Object?>{
        'action': 'confirm_import',
        'job_id': job.id,
        'request_id': requestId,
      });
      if (_confirmKeys[job.id] == requestId) _confirmKeys.remove(job.id);
      return result;
    } on FunctionException {
      throw const ImportRepositoryUnavailableException();
    } on ClientException {
      throw const ImportRepositoryUnavailableException();
    }
  }

  @override
  Future<ImportJob> update(ImportJob job) async {
    try {
      return _job(
        _map(
          await _client.rpc<Object?>(
            'superadmin_get_import_export_job',
            params: <String, Object?>{'p_import_job_id': job.id},
          ),
        ),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const ImportRepositoryUnavailableException();
    } on FormatException {
      throw const ImportRepositoryUnavailableException();
    }
  }

  Future<ImportJob> _invoke(Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke('import-export-jobs', body: body);
      if (response.status < 200 || response.status >= 300) return _unavailable();
      return _job(response.data);
    } on FunctionException {
      throw const ImportRepositoryUnavailableException();
    } on ClientException {
      throw const ImportRepositoryUnavailableException();
    } on FormatException {
      throw const ImportRepositoryUnavailableException();
    }
  }

  Future<T> _unavailable<T>() => Future<T>.error(const ImportRepositoryUnavailableException());
}

ImportJob _job(Object? raw) {
  final row = _map(raw);
  final result = _mapOrEmpty(row['result']);
  final summary = _mapOrEmpty(row['summary']);
  final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
  final file = switch (row['format']?.toString().toLowerCase()) {
    'csv' => ImportFileFixture.csv,
    'xlsx' => ImportFileFixture.xlsx,
    _ => throw const FormatException('Invalid format.'),
  };
  if (created == null || row['domain']?.toString() != 'units') {
    throw const FormatException('Invalid job.');
  }
  return ImportJob(
    id: _required(row['job_id']),
    entity: ImportEntity.units,
    context: row['direction']?.toString() == 'export' ? 'Exportação de Unidades' : 'Unidades',
    file: file,
    strategy: ImportStrategy.createOnly,
    mapping: const <String, String>{},
    previewRows: const <ImportPreviewRow>[],
    conflicts: _list(row['errors'])
        .map((x) {
          final error = _map(x);
          return ImportConflict(
            row: _int(error['row_number']),
            field: error['field']?.toString() ?? '',
            reason: error['message']?.toString() ?? error['code']?.toString() ?? '',
          );
        })
        .toList(growable: false),
    result: ImportResult(
      created: _int(result['created_count']),
      updated: _int(result['updated_count']),
      ignored: _int(result['ignored_count']),
      rejected: _int(result['rejected_count'] ?? summary['rejected_count']),
    ),
    status: switch (row['state']?.toString()) {
      'PROCESSANDO' => ImportJobStatus.inProgress,
      'SUCESSO' => ImportJobStatus.completed,
      'REJEICAO' => ImportJobStatus.rejected,
      'ERRO' => ImportJobStatus.error,
      'PENDENTE' => ImportJobStatus.draft,
      _ => throw const FormatException('Invalid state.'),
    },
    progress: _int(row['progress']).clamp(0, 100),
    actor: '',
    createdAt: created,
    sourceFileName: row['file_name']?.toString(),
  );
}

String _state(ImportJobStatus value) => switch (value) {
  ImportJobStatus.draft => 'PENDENTE',
  ImportJobStatus.inProgress => 'PROCESSANDO',
  ImportJobStatus.completed => 'SUCESSO',
  ImportJobStatus.rejected => 'REJEICAO',
  ImportJobStatus.error => 'ERRO',
};

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Invalid payload.');
}

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];
int _int(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String value => int.tryParse(value) ?? 0,
  _ => 0,
};

String _required(Object? value) {
  final result = value?.toString().trim() ?? '';
  if (result.isEmpty) throw const FormatException('Missing job id.');
  return result;
}

_ImportCursor? _decodeCursor(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final raw = jsonDecode(value);
  if (raw is! Map) throw const FormatException('Invalid import cursor.');
  final createdAt = raw['created_at']?.toString() ?? '';
  final jobId = raw['job_id']?.toString() ?? '';
  if (DateTime.tryParse(createdAt) == null || jobId.isEmpty) {
    throw const FormatException('Invalid import cursor.');
  }
  return _ImportCursor(createdAt, jobId);
}

String? _encodeCursor(Object? value) {
  if (value == null) return null;
  final raw = _map(value);
  final createdAt = raw['created_at']?.toString() ?? '';
  final jobId = raw['job_id']?.toString() ?? '';
  if (DateTime.tryParse(createdAt) == null || jobId.isEmpty) {
    throw const FormatException('Invalid import cursor.');
  }
  return jsonEncode(<String, String>{'created_at': createdAt, 'job_id': jobId});
}

Exception _mapError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' || 'PGRST302' => const ImportRepositoryUnauthorizedException(),
  _ => const ImportRepositoryUnavailableException(),
};

String _mime(ImportFileFixture value) => switch (value) {
  ImportFileFixture.csv => 'text/csv',
  ImportFileFixture.xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

String _uuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final source = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${source.substring(0, 8)}-${source.substring(8, 12)}-${source.substring(12, 16)}-${source.substring(16, 20)}-${source.substring(20)}';
}

final class _ImportCursor {
  const _ImportCursor(this.createdAt, this.jobId);

  final String createdAt;
  final String jobId;
}
