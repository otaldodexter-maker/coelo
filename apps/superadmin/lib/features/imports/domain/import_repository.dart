import 'import_job.dart';
import 'import_job_page.dart';

export 'import_job_page.dart';

abstract interface class ImportRepository {
  Future<List<ImportJob>> fetchJobs();
  Future<ImportJobPage> fetchPage(ImportJobQuery query);
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  });
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile});
  Future<ImportJob> update(ImportJob job);
}

final class ImportRepositoryUnavailableException implements Exception {
  const ImportRepositoryUnavailableException();
}

final class UnavailableImportRepository implements ImportRepository {
  const UnavailableImportRepository();
  Future<T> _unavailable<T>() => Future<T>.error(const ImportRepositoryUnavailableException());
  @override
  Future<List<ImportJob>> fetchJobs() => _unavailable();
  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) => _unavailable();
  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) => _unavailable();
  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) => _unavailable();
  @override
  Future<ImportJob> update(ImportJob job) => _unavailable();
}
