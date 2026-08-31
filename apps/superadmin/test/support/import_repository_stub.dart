import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';

final class InMemoryImportRepository implements ImportRepository {
  InMemoryImportRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final List<ImportJob> _jobs = <ImportJob>[];
  int _nextId = 1;

  @override
  Future<List<ImportJob>> fetchJobs() async => List.unmodifiable(_jobs);
  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async =>
      ImportJobPage(items: List.unmodifiable(_jobs));

  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) async => ImportJob(
    id: 'import-${_nextId++}',
    entity: entity,
    context: context,
    file: file,
    strategy: strategy,
    mapping: const <String, String>{
      'codigo_unidade': 'Código da unidade',
      'nome': 'Nome da unidade',
      'codigo_instituicao': 'Instituição',
      'cidade': 'Cidade',
    },
    previewRows: List.generate(
      8,
      (index) => ImportPreviewRow(
        row: index + 1,
        values: <String, String>{
          'nome': 'Unidade ${index + 1}',
          'codigo': 'UNI-${(index + 1).toString().padLeft(3, '0')}',
        },
      ),
    ),
    conflicts: const <ImportConflict>[
      ImportConflict(row: 6, field: 'codigo_unidade', reason: 'Código já cadastrado.'),
    ],
    result: const ImportResult(created: 7, ignored: 1),
    status: ImportJobStatus.draft,
    progress: 0,
    actor: 'test',
    createdAt: _now(),
  );
  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) async {
    _jobs.insert(0, job);
    return job;
  }

  @override
  Future<ImportJob> update(ImportJob job) async {
    final completed = job.copyWith(status: ImportJobStatus.completed, progress: 100);
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index >= 0) _jobs[index] = completed;
    return completed;
  }
}
