import 'dart:async';

import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  for (final denied in [false, true]) {
    test('new search discards old ${denied ? 'denial' : 'result'} during debounce', () async {
      final repository = _PendingRepository();
      final model = PersonDirectoryViewModel(repository, searchDebounce: const Duration(days: 1));
      addTearDown(model.dispose);
      final load = model.load();
      model.setSearch('new query');
      if (denied) {
        repository.pending.completeError(const PersonDirectoryUnauthorizedException());
      } else {
        repository.pending.complete(_page);
      }
      await load;
      expect(model.query.search, 'new query');
      expect(model.page.items, isEmpty);
      expect(model.state, PersonDirectoryLoadState.loading);
    });
  }

  test('search clears previous rows before debounce finishes', () async {
    final model = PersonDirectoryViewModel(
      FakePersonDirectoryRepository(),
      searchDebounce: const Duration(days: 1),
    );
    addTearDown(model.dispose);
    await model.load();
    expect(model.page.items, isNotEmpty);
    model.setSearch('new query');
    expect(model.page.items, isEmpty);
    expect(model.state, PersonDirectoryLoadState.loading);
  });

  test('pending response cannot mutate a disposed directory', () async {
    final repository = _PendingRepository();
    final model = PersonDirectoryViewModel(repository);
    final load = model.load();
    model.dispose();
    repository.pending.complete(_page);
    await expectLater(load, completes);
    expect(model.page.items, isEmpty);
  });
}

final _page = PersonDirectoryPage(
  items: FakePersonDirectoryRepository.samplePeople.take(1).toList(),
  totalCount: 1,
  page: 0,
  pageSize: 11,
);

final class _PendingRepository implements PersonDirectoryRepository {
  final pending = Completer<PersonDirectoryPage>();

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => pending.future;

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() async =>
      const PersonDirectoryFilterOptions();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
