import 'dart:math' as math;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/import_job.dart';
import '../domain/import_repository.dart';

/// The browser talks to the import hub only through guarded RPCs and its
/// authenticated binary-processing Edge endpoint. It never writes job tables.
final class SupabaseImportRepository implements ImportRepository {
  const SupabaseImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ImportJob>> fetchJobs() async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'superadmin_list_import_export_jobs',
          params: const {'p_page_size': 100},
        ),
      );
      final items = payload['items'];
      if (items is! List) throw const FormatException('Invalid import hub list.');
      return items.map(_jobFromPayload).toList(growable: false);
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
  }) {
    if (entity != ImportEntity.units) return _unavailable();
    return _invokeJson({
      'action': 'create_import',
      'domain': 'units',
      'file_name': file.fileName,
      'mime_type': _mimeType(file),
      'source_format': file.name,
      'idempotency_key': _uuidV4(),
    });
  }

  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) async {
    if (job.entity != ImportEntity.units || sourceFile == null || sourceFile.bytes.isEmpty) {
      return _unavailable();
    }
    try {
      final upload = await _client.functions.invoke(
        'import-export-jobs',
        body: sourceFile.bytes,
        headers: {
          'Content-Type': sourceFile.mimeType,
          'x-coelo-import-action': 'upload',
          'x-coelo-import-job-id': job.id,
        },
      );
      if (upload.status < 200 || upload.status >= 300) {
        throw const ImportRepositoryUnavailableException();
      }
      return _invokeJson({'action': 'confirm_import', 'job_id': job.id, 'request_id': _uuidV4()});
    } on FunctionException {
      throw const ImportRepositoryUnavailableException();
    } on ClientException {
      throw const ImportRepositoryUnavailableException();
    }
  }

  @override
  Future<ImportJob> update(ImportJob job) async {
    try {
      return _jobFromPayload(
        _map(
          await _client.rpc<Object?>(
            'superadmin_get_import_export_job',
            params: {'p_import_job_id': job.id},
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

  Future<ImportJob> _invokeJson(Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke('import-export-jobs', body: body);
      if (response.status < 200 || response.status >= 300) {
        throw const ImportRepositoryUnavailableException();
      }
      return _jobFromPayload(response.data);
    } on FunctionException {
      throw const ImportRepositoryUnavailableException();
    } on ClientException {
      throw const ImportRepositoryUnavailableException();
    } on FormatException {
      throw const ImportRepositoryUnavailableException();
    }
  }

  Future<T> _unavailable<T>() => Future<T>.error(const ImportRepositoryUnavailableException());

  ImportJob _jobFromPayload(Object? raw) {
    final row = _map(raw);
    final status = switch (row['state']?.toString()) {
      'PROCESSANDO' => ImportJobStatus.inProgress,
      'SUCESSO' => ImportJobStatus.completed,
      'REJEICAO' => ImportJobStatus.rejected,
      'ERRO' => ImportJobStatus.error,
      'PENDENTE' => ImportJobStatus.draft,
      _ => throw const FormatException('Invalid import hub state.'),
    };
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (createdAt == null) throw const FormatException('Invalid import job date.');
    final format = switch (row['format']?.toString().toLowerCase()) {
      'csv' => ImportFileFixture.csv,
      'xlsx' => ImportFileFixture.xlsx,
      _ => throw const FormatException('Invalid import file format.'),
    };
    final result = _mapOrEmpty(row['result']);
    final summary = _mapOrEmpty(row['summary']);
    final errors = _list(row['errors'])
        .map((item) {
          final error = _map(item);
          return ImportConflict(
            row: _int(error['row_number']),
            field: error['field']?.toString() ?? '',
            reason: error['message']?.toString() ?? error['code']?.toString() ?? '',
          );
        })
        .toList(growable: false);
    if (row['domain']?.toString() != 'units') {
      throw const FormatException('Unsupported import hub domain.');
    }
    return ImportJob(
      id: _requiredText(row['job_id']),
      entity: ImportEntity.units,
      context: row['direction']?.toString() == 'export' ? 'Exportação de Unidades' : 'Unidades',
      file: format,
      strategy: ImportStrategy.createOnly,
      mapping: const {},
      previewRows: const [],
      conflicts: errors,
      result: ImportResult(
        created: _int(result['created_count']),
        updated: _int(result['updated_count']),
        ignored: _int(result['ignored_count']),
        rejected: _int(result['rejected_count'] ?? summary['rejected_count']),
      ),
      status: status,
      progress: status.isTerminal ? 100 : 0,
      actor: '—',
      createdAt: createdAt,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Invalid import hub payload.');
}

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

String _requiredText(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) throw const FormatException('Missing import job id.');
  return text;
}

int _int(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

Exception _mapError(PostgrestException error) => const ImportRepositoryUnavailableException();

String _mimeType(ImportFileFixture file) => switch (file) {
  ImportFileFixture.csv => 'text/csv',
  ImportFileFixture.xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

String _uuidV4() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final text = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}
