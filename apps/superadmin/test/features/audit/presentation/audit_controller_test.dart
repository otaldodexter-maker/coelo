import 'dart:async';

import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads content and follows the opaque server cursor', () async {
    final repository = _Repository()
      ..pages.addAll([
        _page(items: [_event('event-1')], nextCursor: 'cursor-2'),
        _page(items: [_event('event-2')]),
        _page(items: [_event('event-1')], nextCursor: 'cursor-2'),
      ]);
    final controller = AuditDirectoryController(repository: repository);
    addTearDown(controller.dispose);

    final pending = controller.load();
    expect(controller.snapshot.state, AuditLoadState.loading);
    await pending;
    expect(controller.snapshot.state, AuditLoadState.content);
    expect(controller.canExport, isTrue);
    expect(controller.snapshot.events.map((item) => item.id), ['event-1']);

    await controller.next();

    expect(repository.queries.last.cursor?.eventId, 'cursor-2');
    expect(controller.snapshot.events.map((item) => item.id), ['event-2']);

    await controller.previous();
    expect(repository.queries.last.cursor, isNull);
    expect(controller.snapshot.events.map((item) => item.id), ['event-1']);
  });

  test('applies search on the server and distinguishes empty from no-results', () async {
    final repository = _Repository()..pages.addAll([_page(), _page()]);
    final controller = AuditDirectoryController(repository: repository);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.snapshot.state, AuditLoadState.empty);
    expect(controller.canExport, isFalse);
    expect(controller.canExport, isFalse);

    await controller.updateSearch('sem resultado');
    expect(repository.queries.last.search, 'sem resultado');
    expect(controller.snapshot.state, AuditLoadState.noResults);
    expect(controller.canExport, isFalse);
    expect(controller.canExport, isFalse);
  });

  test('exposes safe failure, unauthorized and not-found states', () async {
    final repository = _Repository();
    final controller = AuditDirectoryController(repository: repository);
    addTearDown(controller.dispose);

    repository.pageError = const AuditUnavailableException();
    await controller.load();
    expect(controller.snapshot.state, AuditLoadState.failure);

    repository.pageError = const AuditUnauthorizedException();
    await controller.load();
    expect(controller.snapshot.state, AuditLoadState.unauthorized);

    repository.pageError = null;
    repository.detailError = const AuditNotFoundException();
    await controller.loadDetail('hidden-id');
    expect(controller.detail.state, AuditDetailLoadState.notFound);
  });

  test('loads detail on demand and starts export through repository', () async {
    final repository = _Repository()..detailResult = _detail('event-1');
    final controller = AuditDirectoryController(
      repository: repository,
      createIdempotencyKey: () => '88888888-8888-4888-8888-888888888888',
    );
    addTearDown(controller.dispose);

    await controller.loadDetail('event-1');
    expect(controller.detail.state, AuditDetailLoadState.content);
    expect(controller.detail.value?.event.id, 'event-1');

    final job = await controller.startExport(format: AuditExportFormat.xlsx);
    expect(job.id, 'job-1');
    expect(repository.exportRequests.single.query.cursor, isNull);
    expect(repository.exportRequests.single.query.search, controller.query.search);
    expect(repository.exportRequests.single.idempotencyKey, '88888888-8888-4888-8888-888888888888');
  });

  test('debounces search and ignores stale page and detail responses', () async {
    final activePage = Completer<AuditPage>();
    final debouncedPage = Completer<AuditPage>();
    final stalePage = Completer<AuditPage>();
    final currentPage = Completer<AuditPage>();
    final firstDetail = Completer<AuditEventDetail>();
    final secondDetail = Completer<AuditEventDetail>();
    final repository = _Repository()
      ..pageFutures.addAll([
        activePage.future,
        debouncedPage.future,
        stalePage.future,
        currentPage.future,
      ])
      ..detailFutures.addAll([firstDetail.future, secondDetail.future]);
    final controller = AuditDirectoryController(repository: repository);
    addTearDown(controller.dispose);

    final activeLoad = controller.load();
    final ignoredSearch = controller.updateSearch('a');
    final appliedSearch = controller.updateSearch('ator');
    activePage.complete(_page(items: [_event('stale-during-debounce')]));
    await activeLoad;
    expect(controller.snapshot.events, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.search, 'ator');
    debouncedPage.complete(_page(items: [_event('search-page')]));
    await Future.wait([ignoredSearch, appliedSearch]);

    final staleLoad = controller.updateFilters(AuditQuery(search: 'antiga'));
    final currentLoad = controller.updateFilters(AuditQuery(search: 'nova'));
    currentPage.complete(_page(items: [_event('current-page')]));
    stalePage.complete(_page(items: [_event('stale-page')]));
    await currentLoad;
    await staleLoad;
    expect(controller.snapshot.events.single.id, 'current-page');

    final staleDetailLoad = controller.loadDetail('stale-detail');
    final currentDetailLoad = controller.loadDetail('current-detail');
    secondDetail.complete(_detail('current-detail'));
    firstDetail.complete(_detail('stale-detail'));
    await Future.wait([staleDetailLoad, currentDetailLoad]);
    expect(controller.detail.value?.event.id, 'current-detail');
  });

  test('retries export with the same generated idempotency key', () async {
    final repository = _Repository()..exportErrors.add(const AuditUnavailableException());
    final controller = AuditDirectoryController(
      repository: repository,
      createIdempotencyKey: () => '99999999-9999-4999-8999-999999999999',
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.startExport(format: AuditExportFormat.csv),
      throwsA(isA<AuditUnavailableException>()),
    );
    await controller.startExport(format: AuditExportFormat.csv);

    expect(repository.exportRequests, hasLength(2));
    expect(repository.exportRequests.map((request) => request.idempotencyKey).toSet(), {
      '99999999-9999-4999-8999-999999999999',
    });
  });

  test('starts a new export attempt after server-side filters change', () async {
    var generated = 0;
    final repository = _Repository()
      ..exportErrors.add(const AuditUnavailableException())
      ..pages.add(_page());
    final controller = AuditDirectoryController(
      repository: repository,
      createIdempotencyKey: () => '99999999-9999-4999-8999-99999999999${generated++}',
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.startExport(format: AuditExportFormat.csv),
      throwsA(isA<AuditUnavailableException>()),
    );
    await controller.updateFilters(AuditQuery(resourceTypes: const {'profile'}));
    await controller.startExport(format: AuditExportFormat.csv);

    expect(
      repository.exportRequests[0].idempotencyKey,
      isNot(repository.exportRequests[1].idempotencyKey),
    );
  });
}

AuditEvent _event(String id) => AuditEvent(
  id: id,
  actor: const AuditActor(id: 'actor-1', displayName: 'Operador', roleCode: 'owner'),
  actionCode: 'updated',
  resourceType: 'institution',
  resourceId: 'institution-1',
  outcome: AuditOutcome.success,
  origin: 'admin_ui',
  context: const AuditContext(kind: 'global'),
  occurredAt: DateTime.utc(2026, 8, 11),
);

AuditEventDetail _detail(String id) => AuditEventDetail(
  event: _event(id),
  before: const {},
  after: const {},
  integrity: const AuditIntegrity(position: 1, hash: 'hash', verified: true),
);

AuditPage _page({List<AuditEvent> items = const [], String? nextCursor, bool canExport = true}) =>
    AuditPage(
      events: items,
      hasMore: nextCursor != null,
      nextCursor: nextCursor == null
          ? null
          : AuditCursor(occurredAt: DateTime.utc(2026, 8, 11), eventId: nextCursor),
      totalCount: items.length,
      canExport: canExport,
    );

final class _Repository implements AuditRepository {
  final pages = <AuditPage>[];
  final queries = <AuditQuery>[];
  final exportRequests = <AuditExportRequest>[];
  Object? pageError;
  Object? detailError;
  AuditEventDetail? detailResult;
  final pageFutures = <Future<AuditPage>>[];
  final detailFutures = <Future<AuditEventDetail>>[];
  final exportErrors = <Object>[];

  @override
  Future<AuditPage> fetchPage(AuditQuery query) async {
    queries.add(query);
    if (pageError case final error?) throw error;
    if (pageFutures.isNotEmpty) return pageFutures.removeAt(0);
    return pages.removeAt(0);
  }

  @override
  Future<AuditEventDetail> fetchDetail(String eventId) async {
    if (detailError case final error?) throw error;
    if (detailFutures.isNotEmpty) return detailFutures.removeAt(0);
    return detailResult!;
  }

  @override
  Future<AuditExportJob> startExport(AuditExportRequest request) async {
    exportRequests.add(request);
    if (exportErrors.isNotEmpty) throw exportErrors.removeAt(0);
    return AuditExportJob(
      id: 'job-1',
      status: AuditExportStatus.queued,
      format: request.format,
      createdAt: DateTime.utc(2026, 8, 11),
    );
  }

  @override
  Future<AuditExportJob> fetchExportStatus(String jobId) async => AuditExportJob(
    id: jobId,
    status: AuditExportStatus.completed,
    format: AuditExportFormat.csv,
    createdAt: DateTime.utc(2026, 8, 11),
  );
}
