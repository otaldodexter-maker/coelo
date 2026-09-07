import 'dart:async';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reload removes previous detail before waiting and maps denial', () async {
    final repository = _Repository();
    final controller = GroupDetailController(repository: repository, id: 'first');
    addTearDown(controller.dispose);
    final initial = controller.load();
    repository.calls[0].complete(_detail('first'));
    await initial;
    expect(controller.detail!.id, 'first');
    final reload = controller.load();
    expect(controller.detail, isNull);
    expect(controller.state, GroupDetailState.loading);
    repository.calls[1].completeError(const GroupDetailException(GroupDetailFailure.denied));
    await reload;
    expect(controller.detail, isNull);
    expect(controller.state, GroupDetailState.denied);
  });

  test('stale success cannot replace a newer denied target', () async {
    final repository = _Repository();
    final controller = GroupDetailController(repository: repository, id: 'first');
    addTearDown(controller.dispose);
    final first = controller.load();
    final second = controller.load(id: 'second');
    repository.calls[1].completeError(const GroupDetailException(GroupDetailFailure.denied));
    await second;
    repository.calls[0].complete(_detail('first'));
    await first;
    expect(controller.state, GroupDetailState.denied);
    expect(controller.detail, isNull);
    expect(repository.ids, ['first', 'second']);
  });

  test('stale error cannot replace newer authorized detail', () async {
    final repository = _Repository();
    final controller = GroupDetailController(repository: repository, id: 'first');
    addTearDown(controller.dispose);
    final first = controller.load();
    final second = controller.load(id: 'second');
    repository.calls[1].complete(_detail('second'));
    await second;
    repository.calls[0].completeError(StateError('stale'));
    await first;
    expect(controller.state, GroupDetailState.ready);
    expect(controller.detail!.id, 'second');
  });

  test('repository replacement invalidates the in-flight result', () async {
    final oldRepository = _Repository();
    final newRepository = _Repository();
    final controller = GroupDetailController(repository: oldRepository, id: 'first');
    addTearDown(controller.dispose);
    final oldLoad = controller.load();
    final newLoad = controller.load(repository: newRepository);
    newRepository.calls.single.complete(_detail('new'));
    await newLoad;
    oldRepository.calls.single.complete(_detail('old'));
    await oldLoad;
    expect(controller.detail!.id, 'new');
  });

  test('dispose ignores completion and prevents new requests', () async {
    final repository = _Repository();
    final controller = GroupDetailController(repository: repository, id: 'first');
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = controller.load();
    controller.dispose();
    repository.calls.single.complete(_detail('first'));
    await load;
    await controller.load();
    expect(notifications, 1);
    expect(repository.calls, hasLength(1));
    expect(controller.detail, isNull);
  });

  for (final failure in GroupDetailFailure.values) {
    test('maps typed failure $failure with no payload', () async {
      final repository = _Repository();
      final controller = GroupDetailController(repository: repository, id: 'first');
      addTearDown(controller.dispose);
      final load = controller.load();
      repository.calls.single.completeError(GroupDetailException(failure));
      await load;
      expect(
        controller.state,
        failure == GroupDetailFailure.unavailable
            ? GroupDetailState.unavailable
            : GroupDetailState.denied,
      );
      expect(controller.detail, isNull);
    });
  }
}

class _Repository implements GroupDetailRepository {
  final calls = <Completer<GroupDetail>>[];
  final ids = <String>[];
  @override
  Future<GroupDetail> fetchById(String id) {
    ids.add(id);
    final completer = Completer<GroupDetail>();
    calls.add(completer);
    return completer.future;
  }
}

GroupDetail _detail(String id) => GroupDetail(
  id: id,
  institutionId: 'institution',
  institutionName: 'Instituição',
  unitId: 'unit',
  unitName: 'Unidade',
  name: 'Turma',
  groupType: 'class',
  groupTypeOtherText: null,
  status: 'active',
  inheritAppearance: true,
  inheritAccess: true,
  inheritActivities: true,
  managementVersion: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
