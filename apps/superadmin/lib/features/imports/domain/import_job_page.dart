import 'package:flutter/foundation.dart';

import 'import_job.dart';

@immutable
final class ImportJobQuery {
  const ImportJobQuery({
    this.search,
    this.entities = const <ImportEntity>{},
    this.file,
    this.status,
    this.createdAfter,
    this.createdBefore,
    this.cursor,
    this.pageSize = 25,
  }) : assert(pageSize > 0 && pageSize <= 100);
  final String? search;
  final Set<ImportEntity> entities;
  final ImportFileFixture? file;
  final ImportJobStatus? status;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  final String? cursor;
  final int pageSize;
}

@immutable
final class ImportJobPage {
  const ImportJobPage({required this.items, this.nextCursor, this.previousCursor});
  final List<ImportJob> items;
  final String? nextCursor;
  final String? previousCursor;
}

abstract interface class ImportJobPageRepository {
  Future<ImportJobPage> fetchPage(ImportJobQuery query);
}
