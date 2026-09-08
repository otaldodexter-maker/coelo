import 'dart:async';

import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads server page and exposes server segment counts', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);

    await controller.load();

    expect(controller.state, ChildSafetyLoadState.ready);
    expect(controller.records.single.childName, 'Ana');
    expect(controller.totalCount, 12);
    expect(controller.segmentCounts.awaitingApproval, 3);
    expect(controller.canCreate, isTrue);
  });

  test('filters and pagination always trigger scoped server queries', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    await controller.load();

    await controller.setStatusSegment(ChildSafetyDirectorySegment.awaitingApproval);
    await controller.setInstitutions({'institution-1'});
    await controller.goToPage(1);

    expect(repository.queries.last.segment, ChildSafetyDirectorySegment.awaitingApproval);
    expect(repository.queries.last.institutionIds, {'institution-1'});
    expect(repository.queries.last.pageIndex, 1);
  });

  test('fails closed and does not retain records on authorization failure', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    await controller.load();
    repository.unauthorized = true;

    await controller.retry();

    expect(controller.state, ChildSafetyLoadState.unauthorized);
    expect(controller.records, isEmpty);
    expect(controller.totalCount, 0);
    expect(controller.canCreate, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('commands refresh only after backend success', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository);
    await controller.load();
    final loadsBefore = repository.queries.length;

    await controller.transitionAuthorization(
      const TransitionPickupAuthorizationCommand(
        requestId: '11111111-1111-4111-8111-111111111111',
        childId: 'child-1',
        authorizationId: 'authorization-1',
        status: PickupAuthorizationStatus.approved,
        reason: 'Documento conferido',
      ),
    );

    expect(repository.transitions, 1);
    expect(repository.queries, hasLength(loadsBefore + 1));
    expect(controller.isSaving, isFalse);
  });

  test('new search clears cursors from the previous result set', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    await controller.load();
    await controller.goToPage(1);
    final queryCount = repository.queries.length;

    controller.setSearch('Bia');
    await Future<void>.delayed(Duration.zero);
    await controller.goToPage(1);

    expect(repository.queries, hasLength(queryCount + 2));
    expect(repository.queries.last.search, 'Bia');
    expect(repository.queries.last.pageIndex, 1);
    expect(repository.queries.last.cursor, 'cursor-Bia');
  });

  test('a concurrent command reports failure instead of false success', () async {
    final repository = _Repository()..holdTransitions = true;
    final controller = ChildSafetyController(repository);
    await controller.load();
    const command = TransitionPickupAuthorizationCommand(
      requestId: '11111111-1111-4111-8111-111111111111',
      childId: 'child-1',
      authorizationId: 'authorization-1',
      status: PickupAuthorizationStatus.approved,
      reason: 'Documento conferido',
    );

    final first = controller.transitionAuthorization(command);
    final second = await controller.transitionAuthorization(command);
    expect(second, isFalse);
    repository.completeTransition();
    expect(await first, isTrue);
  });

  test('disposed controller starts no directory read or search timer', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    controller.dispose();

    await controller.load();
    await controller.retry();
    await controller.setInstitutions({'institution-2'});
    controller.setSearch('Bia');
    await Future<void>.delayed(Duration.zero);

    expect(repository.queries, isEmpty);
  });

  test('disposed controller rejects child reads without contacting repository', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository)..dispose();

    await expectLater(
      controller.fetchChild('child-1'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );
    await expectLater(
      controller.searchChildren('Ana'),
      throwsA(isA<ChildSafetyUnavailableException>()),
    );

    expect(repository.childReads, 0);
    expect(repository.childSearches, 0);
  });

  test('debounced search invalidates the previous response before its timer fires', () async {
    final repository = _Repository();
    final oldPage = await repository.fetchDirectory(ChildSafetyDirectoryQuery());
    final pending = Completer<ChildSafetyDirectoryPage>();
    repository.nextDirectory = pending.future;
    final controller = ChildSafetyController(repository, searchDebounce: const Duration(days: 1));
    addTearDown(controller.dispose);

    final oldLoad = controller.load();
    controller.setSearch('Bia');
    pending.complete(oldPage);
    await oldLoad;

    expect(controller.query.search, 'Bia');
    expect(controller.state, ChildSafetyLoadState.loading);
    expect(controller.records, isEmpty);
    expect(controller.canCreate, isFalse);
  });

  test('debounced search hides prior records and capabilities immediately', () async {
    final repository = _Repository();
    final controller = ChildSafetyController(repository, searchDebounce: const Duration(days: 1));
    addTearDown(controller.dispose);
    await controller.load();

    controller.setSearch('Bia');

    expect(controller.state, ChildSafetyLoadState.loading);
    expect(controller.records, isEmpty);
    expect(controller.totalCount, 0);
    expect(controller.canCreate, isFalse);
  });

  test('child data completing after dispose is not delivered to retained callbacks', () async {
    final repository = _Repository();
    final pending = Completer<ChildSafetyRecord?>();
    repository.nextChild = pending.future;
    final controller = ChildSafetyController(repository);
    final result = controller.fetchChild('child-1');
    final expectation = expectLater(result, throwsA(isA<ChildSafetyUnavailableException>()));
    controller.dispose();
    pending.complete((await repository.fetchDirectory(ChildSafetyDirectoryQuery())).records.single);

    await expectation;
    expect(repository.childReads, 1);
  });

  test('old authorization error cannot replace a debounced search', () async {
    final repository = _Repository();
    final pending = Completer<ChildSafetyDirectoryPage>();
    repository.nextDirectory = pending.future;
    final controller = ChildSafetyController(repository, searchDebounce: const Duration(days: 1));
    addTearDown(controller.dispose);
    final oldLoad = controller.load();

    controller.setSearch('Bia');
    pending.completeError(const ChildSafetyUnauthorizedException());
    await oldLoad;

    expect(controller.state, ChildSafetyLoadState.loading);
    expect(controller.errorMessage, isNull);
    expect(controller.records, isEmpty);
  });

  test('child search completing after dispose is rejected', () async {
    final repository = _Repository();
    final pending = Completer<List<ChildSafetyChildOption>>();
    repository.nextChildSearch = pending.future;
    final controller = ChildSafetyController(repository);
    final result = controller.searchChildren('Ana');
    final expectation = expectLater(result, throwsA(isA<ChildSafetyUnavailableException>()));

    controller.dispose();
    pending.complete([]);

    await expectation;
    expect(repository.childSearches, 1);
  });
}

final class _Repository implements ChildSafetyRepository {
  final queries = <ChildSafetyDirectoryQuery>[];
  bool unauthorized = false;
  int transitions = 0;
  bool holdTransitions = false;
  Completer<void>? _transitionCompleter;
  Future<ChildSafetyDirectoryPage>? nextDirectory;
  Future<ChildSafetyRecord?>? nextChild;
  Future<List<ChildSafetyChildOption>>? nextChildSearch;
  int childReads = 0;
  int childSearches = 0;

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    queries.add(query);
    if (nextDirectory case final pending?) return pending;
    if (unauthorized) throw const ChildSafetyUnauthorizedException();
    return ChildSafetyDirectoryPage(
      records: const [
        ChildSafetyRecord(
          childId: 'child-1',
          childName: 'Ana',
          internalId: 'RA 1',
          institutionName: 'Aurora',
          unitName: 'Centro',
          authorizations: [],
        ),
      ],
      totalCount: 12,
      segmentCounts: const ChildSafetySegmentCounts(
        all: 12,
        awaitingApproval: 3,
        attention: 1,
        authorized: 7,
        withoutAuthorization: 1,
      ),
      canCreate: true,
      nextCursor: query.pageIndex == 0
          ? 'cursor-${query.search.isEmpty ? 'initial' : query.search}'
          : null,
    );
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async {
    childReads++;
    return nextChild == null ? null : await nextChild;
  }

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    childSearches++;
    return nextChildSearch == null ? [] : await nextChildSearch!;
  }

  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {}
  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {
    transitions++;
    if (holdTransitions) {
      _transitionCompleter = Completer<void>();
      await _transitionCompleter!.future;
    }
  }

  void completeTransition() => _transitionCompleter?.complete();

  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) async {}
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}
}
