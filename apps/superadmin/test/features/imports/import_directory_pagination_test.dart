import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requests import directory pages from the server adapter', (tester) async {
    final repository = _PagedRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ImportDirectoryPage(repository: repository, onNewImport: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(repository.queries, hasLength(1));
    expect(repository.queries.single.cursor, isNull);
    await tester.tap(find.byTooltip('Próxima página'));
    await tester.pump();
    await tester.pump();
    expect(repository.queries.last.cursor, 'next-page');
  });
}

final class _PagedRepository implements ImportRepository {
  final queries = <ImportJobQuery>[];
  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async {
    queries.add(query);
    return query.cursor == 'next-page'
        ? ImportJobPage(items: <ImportJob>[_job('second')])
        : ImportJobPage(items: <ImportJob>[_job('first')], nextCursor: 'next-page');
  }

  @override
  Future<List<ImportJob>> fetchJobs() async => <ImportJob>[];
  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) => throw UnimplementedError();
  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) =>
      throw UnimplementedError();
  @override
  Future<ImportJob> update(ImportJob job) => throw UnimplementedError();
}

ImportJob _job(String id) => ImportJob(
  id: id,
  entity: ImportEntity.units,
  context: 'Unidades',
  file: ImportFileFixture.csv,
  strategy: ImportStrategy.createOnly,
  mapping: const {},
  previewRows: const [],
  conflicts: const [],
  result: const ImportResult(),
  status: ImportJobStatus.completed,
  progress: 100,
  actor: '—',
  createdAt: DateTime.utc(2026),
);
