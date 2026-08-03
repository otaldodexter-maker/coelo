import '../domain/import_job.dart';

final class FakeImportRepository {
  FakeImportRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final List<ImportJob> _jobs = [];
  int _nextId = 1;

  List<ImportJob> get jobs => List.unmodifiable(_jobs);

  ImportJob createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) {
    final label = entity.label.substring(
      0,
      entity.label.length - (entity == ImportEntity.people ? 1 : 0),
    );
    final rows = List.generate(
      8,
      (index) => ImportPreviewRow(
        row: index + 2,
        values: {'nome': '$label ${index + 1}', 'codigo': '${entity.name}-${index + 1}'},
      ),
    );
    return ImportJob(
      id: 'import-${_nextId++}',
      entity: entity,
      context: context,
      file: file,
      strategy: strategy,
      mapping: const {'nome': 'Nome', 'codigo': 'Código'},
      previewRows: rows,
      conflicts: const [ImportConflict(row: 4, field: 'Código', reason: 'Registro já existe')],
      result: ImportResult(
        created: 6,
        updated: strategy == ImportStrategy.createAndUpdate ? 1 : 0,
        ignored: 1,
        rejected: 1,
      ),
      status: ImportJobStatus.draft,
      progress: 0,
      actor: 'Operadora Coelo',
      createdAt: _now(),
    );
  }

  ImportJob save(ImportJob job) {
    _jobs.insert(0, job);
    return job;
  }

  ImportJob update(ImportJob job) {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index >= 0) _jobs[index] = job;
    return job;
  }
}
