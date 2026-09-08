import 'dart:async';

import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/health_care_fixture_repository.dart';

void main() {
  for (final detailStartsLast in [true, false]) {
    test(
      'the last read wins across directory and detail when detailStartsLast=$detailStartsLast',
      () async {
        final repository = _PendingDetails();
        final controller = HealthCareController(repository);
        addTearDown(controller.dispose);
        final child = await repository.fixture.findChild('child-demo-b', actor: controller.actor);
        final page = await repository.fixture.fetchDirectory(
          const HealthCareDirectoryQuery(),
          actor: controller.actor,
        );
        late Future<void> directoryLoad;
        late Future<void> detailLoad;
        if (detailStartsLast) {
          directoryLoad = controller.load();
          detailLoad = controller.loadDetail('child-demo-b');
          repository.pending['child-demo-b']!.complete(child);
          await detailLoad;
          repository.directory.complete(page);
          await directoryLoad;
          expect(controller.detail?.id, 'child-demo-b');
          expect(controller.page, isNull);
        } else {
          detailLoad = controller.loadDetail('child-demo-b');
          directoryLoad = controller.load();
          repository.directory.complete(page);
          await directoryLoad;
          repository.pending['child-demo-b']!.complete(child);
          await detailLoad;
          expect(controller.page, same(page));
          expect(controller.detail, isNull);
        }
        expect(controller.state, HealthCareLoadState.ready);
        expect(controller.error, isNull);
      },
    );
  }

  for (final outcome in ['success', 'absent', 'unauthorized', 'error']) {
    test('late detail $outcome cannot replace the newer child context', () async {
      final repository = _PendingDetails();
      final controller = HealthCareController(repository);
      addTearDown(controller.dispose);
      final a = controller.loadDetail('child-demo-a');
      final b = controller.loadDetail('child-demo-b');
      final childB = await repository.fixture.findChild('child-demo-b', actor: controller.actor);
      repository.pending['child-demo-b']!.complete(childB);
      await b;
      expect(controller.detail?.id, 'child-demo-b');
      switch (outcome) {
        case 'success':
          repository.pending['child-demo-a']!.complete(
            await repository.fixture.findChild('child-demo-a', actor: controller.actor),
          );
        case 'absent':
          repository.pending['child-demo-a']!.complete(null);
        case 'unauthorized':
          repository.pending['child-demo-a']!.completeError(StateError('old child denied'));
        case 'error':
          repository.pending['child-demo-a']!.completeError(Exception('old child failure'));
      }
      await a;
      expect(controller.detail?.id, 'child-demo-b');
      expect(controller.state, HealthCareLoadState.ready);
      expect(controller.error, isNull);
    });
  }

  test('a new detail load clears an earlier error immediately', () async {
    final repository = _PendingDetails();
    final controller = HealthCareController(repository);
    addTearDown(controller.dispose);
    final failed = controller.loadDetail('child-demo-a');
    repository.pending['child-demo-a']!.completeError(StateError('denied'));
    await failed;
    expect(controller.error, isNotNull);
    final next = controller.loadDetail('child-demo-b');
    expect(controller.error, isNull);
    repository.pending['child-demo-b']!.complete(null);
    await next;
  });

  test('disposed controller ignores detail completion and starts no later read', () async {
    final repository = _PendingDetails();
    final controller = HealthCareController(repository);
    final pending = controller.loadDetail('child-demo-a');
    controller.dispose();
    repository.pending['child-demo-a']!.complete(null);
    await pending;
    await controller.loadDetail('child-demo-b');
    expect(repository.pending.keys, ['child-demo-a']);
  });
}

final class _PendingDetails implements HealthCareRepository {
  final fixture = FixtureHealthCareRepository();
  final pending = <String, Completer<HealthCareChild?>>{};
  final directory = Completer<HealthCareDirectoryPage>();

  @override
  HealthCareActor get defaultActor => fixture.defaultActor;

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) => directory.future;

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) =>
      (pending[childId] = Completer<HealthCareChild?>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
