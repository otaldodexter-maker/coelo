import 'dart:async';

import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_superadmin/features/daily_routine/presentation/routine_directory_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_routine_repository.dart';

void main() {
  const item = RoutineDirectoryItem(
    id: 'model-a',
    kind: RoutineEntryKind.model,
    name: 'Modelo A',
    status: 'draft',
    version: 1,
  );

  RoutineDirectoryPage page([List<RoutineDirectoryItem> items = const [item]]) =>
      RoutineDirectoryPage(
        items: items,
        page: 1,
        pageSize: 20,
        totalCount: items.length,
        canManage: true,
      );

  test('starts loading with no entries exposed', () {
    final controller = RoutineDirectoryController(
      FakeRoutineRepository(pageLoader: (_) async => page()),
    );

    expect(controller.state.status, RoutineDirectoryStatus.loading);
    expect(controller.state.page, isNull);
  });

  test('loading a new request clears previously loaded entries fail closed', () async {
    final second = Completer<RoutineDirectoryPage>();
    var request = 0;
    final controller = RoutineDirectoryController(
      FakeRoutineRepository(
        pageLoader: (_) {
          request++;
          return request == 1 ? Future.value(page()) : second.future;
        },
      ),
    );
    await controller.load();
    expect(controller.state.status, RoutineDirectoryStatus.data);

    final pending = controller.load();
    expect(controller.state.status, RoutineDirectoryStatus.loading);
    expect(controller.state.page, isNull);
    second.complete(page());
    await pending;
  });

  test('failure and unauthorized never retain entries', () async {
    final failures = <Exception>[
      Exception('offline'),
      const PostgrestException(message: 'forbidden', code: '42501'),
    ];
    final expected = [RoutineDirectoryStatus.failure, RoutineDirectoryStatus.unauthorized];

    for (var index = 0; index < failures.length; index++) {
      final controller = RoutineDirectoryController(
        FakeRoutineRepository(pageLoader: (_) async => throw failures[index]),
      );
      await controller.load();
      expect(controller.state.status, expected[index]);
      expect(controller.state.page, isNull);
      expect(controller.state.message, isNot(contains('forbidden')));
    }
  });

  test('empty and no-results are distinct server-result states', () async {
    final controller = RoutineDirectoryController(
      FakeRoutineRepository(pageLoader: (_) async => page(const [])),
    );

    await controller.load();
    expect(controller.state.status, RoutineDirectoryStatus.empty);
    await controller.load(
      query: const RoutineDirectoryQuery(kind: RoutineEntryKind.model, search: 'sem resultado'),
    );
    expect(controller.state.status, RoutineDirectoryStatus.noResults);
  });

  test('stale response cannot replace a newer authorized result', () async {
    final first = Completer<RoutineDirectoryPage>();
    final second = Completer<RoutineDirectoryPage>();
    var request = 0;
    final controller = RoutineDirectoryController(
      FakeRoutineRepository(pageLoader: (_) => request++ == 0 ? first.future : second.future),
    );

    final oldLoad = controller.load();
    final newLoad = controller.load();
    second.complete(page());
    await newLoad;
    first.complete(page(const []));
    await oldLoad;

    expect(controller.state.status, RoutineDirectoryStatus.data);
    expect(controller.state.page?.items.single.id, 'model-a');
  });
}
