import 'dart:async';

import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final editing in [false, true]) {
    test('single flight shares ${editing ? 'edit' : 'create'} result', () async {
      final repository = _PendingRepository();
      final model = _model(repository, editing: editing);
      addTearDown(model.dispose);
      final first = model.save();
      final second = model.save();
      expect(repository.calls, 1);
      repository.pending.complete(_person);
      expect(await first, same(_person));
      expect(await second, same(_person));
      expect(model.saving, isFalse);
    });
  }

  test('reentrant busy listener shares operation and cannot change snapshot', () async {
    final repository = _PendingRepository();
    final model = _model(repository);
    addTearDown(model.dispose);
    Future<PersonDirectoryItem>? nested;
    var entered = false;
    model.addListener(() {
      if (!model.saving || entered) return;
      entered = true;
      model.displayName = 'Later';
      nested = model.save();
    });
    final first = model.save();
    expect(repository.calls, 1);
    expect(repository.drafts.single.displayName, 'Original');
    repository.pending.complete(_person);
    expect(await first, same(_person));
    expect(await nested!, same(_person));
    expect(model.displayName, 'Later');
  });

  for (final fails in [false, true]) {
    test('pending ${fails ? 'failure' : 'success'} does not notify after dispose', () async {
      final repository = _PendingRepository();
      final model = _model(repository);
      var notifications = 0;
      model.addListener(() => notifications++);
      final result = model.save();
      final error = StateError('write failed');
      final assertion = expectLater(
        result,
        fails ? throwsA(same(error)) : completion(same(_person)),
      );
      model.dispose();
      final count = notifications;
      if (fails) {
        repository.pending.completeError(error);
      } else {
        repository.pending.complete(_person);
      }
      await assertion;
      expect(notifications, count);
      expect(model.saveError, isNull);
    });
  }

  test('save after dispose does not call repository', () async {
    final repository = _PendingRepository();
    final model = _model(repository)..dispose();
    await expectLater(model.save(), throwsStateError);
    expect(repository.calls, 0);
  });

  test('edit snapshot is immutable and receipt preserves newer intent', () async {
    final repository = _PendingRepository();
    final model = _model(repository, editing: true)
      ..addMembership(_membership)
      ..addChildContext(_context);
    addTearDown(model.dispose);
    final result = model.save();
    final command = repository.updates.single;
    final snapshot = command.toJson();
    model
      ..displayName = 'Later'
      ..updateMembership(_membership.copyWith(role: 'teacher'))
      ..updateChildContext(_context.copyWith(unitId: 'unit-later'));
    expect(command.toJson(), snapshot);
    expect(() => command.membershipChanges.clear(), throwsUnsupportedError);
    expect(() => command.childContextChanges.clear(), throwsUnsupportedError);
    repository.pending.complete(_person);
    await result;
    expect(model.displayName, 'Later');
    expect(model.membershipChanges.single.membership.role, 'teacher');
    expect(model.childContextChanges.single.context.unitId, 'unit-later');
    expect(model.original, same(_person));
  });

  test('create snapshot freezes links before later edits', () async {
    final repository = _PendingRepository();
    final model = _model(repository)
      ..addMembership(_membership)
      ..addChildContext(_context);
    addTearDown(model.dispose);
    final result = model.save();
    final command = repository.drafts.single;
    final snapshot = command.toJson();
    model
      ..removeMembership(_membership)
      ..removeChildContext(_context);
    expect(command.toJson(), snapshot);
    expect(() => command.memberships.clear(), throwsUnsupportedError);
    expect(() => command.childContexts.clear(), throwsUnsupportedError);
    expect(() => command.memberships[0] = command.memberships[0], throwsUnsupportedError);
    expect(() => command.childContexts[0] = command.childContexts[0], throwsUnsupportedError);
    repository.pending.complete(_person);
    await result;
    expect(model.memberships, isEmpty);
    expect(model.childContexts, isEmpty);
  });

  test('shared failure preserves patch and releases retry with current intent', () async {
    final repository = _PendingRepository();
    final model = _model(repository, editing: true)..addMembership(_membership);
    addTearDown(model.dispose);
    final error = StateError('retryable');
    final first = expectLater(model.save(), throwsA(same(error)));
    final second = expectLater(model.save(), throwsA(same(error)));
    repository.pending.completeError(error);
    await Future.wait([first, second]);
    expect(repository.calls, 1);
    expect(model.saving, isFalse);
    expect(model.saveError, same(error));
    expect(model.membershipChanges, hasLength(1));
    model.displayName = 'Retry';
    repository.pending = Completer<PersonDirectoryItem>();
    final retry = model.save();
    expect(model.saveError, isNull);
    expect(repository.calls, 2);
    expect(repository.updates.last.displayName, 'Retry');
    expect(repository.updates.last.expectedUpdatedAt, _person.updatedAt);
    expect(repository.updates.last.membershipChanges, hasLength(1));
    repository.pending.complete(_person);
    await retry;
    expect(model.saving, isFalse);
  });
}

final _person = PersonDirectoryItem(
  id: 'person',
  firstName: 'First',
  lastName: 'Last',
  displayName: 'Original',
  legalName: 'First Last',
  type: PersonType.adult,
  status: PersonStatus.draft,
  updatedAt: DateTime.utc(2026, 9, 7),
);
const _membership = PersonMembership(
  id: 'membership',
  institutionId: 'institution',
  institutionName: 'Institution',
  role: 'guardian',
);
const _context = PersonChildContext(id: 'context', institutionId: 'institution');

PersonFormViewModel _model(_PendingRepository repository, {bool editing = false}) =>
    PersonFormViewModel(repository, original: editing ? _person : null)
      ..firstName = 'First'
      ..lastName = 'Last'
      ..legalName = 'First Last'
      ..displayName = 'Original';

class _PendingRepository implements PersonDirectoryRepository {
  var pending = Completer<PersonDirectoryItem>();
  final drafts = <PersonDraft>[];
  final updates = <PersonUpdate>[];
  int get calls => drafts.length + updates.length;

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) {
    drafts.add(draft);
    return pending.future;
  }

  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) {
    updates.add(update);
    return pending.future;
  }

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) => throw UnimplementedError();
  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() => throw UnimplementedError();
  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => throw UnimplementedError();
}
