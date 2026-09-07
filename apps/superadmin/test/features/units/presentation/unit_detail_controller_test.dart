import 'dart:async';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reload removes previous detail before waiting and maps denial', () async {
    final repository = _Repository();
    final controller = UnitDetailController(repository: repository, id: 'first');
    addTearDown(controller.dispose);
    final initial = controller.load();
    repository.calls[0].complete(_detail('first'));
    await initial;
    expect(controller.detail!.id, 'first');
    final reload = controller.load();
    expect(controller.detail, isNull);
    expect(controller.state, UnitDetailState.loading);
    repository.calls[1].completeError(const UnitDetailException(UnitDetailFailure.denied));
    await reload;
    expect(controller.detail, isNull);
    expect(controller.state, UnitDetailState.denied);
  });

  test('stale success cannot replace a newer denied target', () async {
    final repository = _Repository();
    final controller = UnitDetailController(repository: repository, id: 'first');
    addTearDown(controller.dispose);
    final first = controller.load();
    final second = controller.load(id: 'second');
    repository.calls[1].completeError(const UnitDetailException(UnitDetailFailure.denied));
    await second;
    repository.calls[0].complete(_detail('first'));
    await first;
    expect(controller.state, UnitDetailState.denied);
    expect(controller.detail, isNull);
    expect(repository.ids, ['first', 'second']);
  });

  test('stale error cannot replace newer authorized detail', () async {
    final repository = _Repository();
    final controller = UnitDetailController(repository: repository, id: 'first');
    addTearDown(controller.dispose);
    final first = controller.load();
    final second = controller.load(id: 'second');
    repository.calls[1].complete(_detail('second'));
    await second;
    repository.calls[0].completeError(StateError('stale'));
    await first;
    expect(controller.state, UnitDetailState.ready);
    expect(controller.detail!.id, 'second');
  });

  test('repository replacement invalidates the in-flight result', () async {
    final oldRepository = _Repository();
    final newRepository = _Repository();
    final controller = UnitDetailController(repository: oldRepository, id: 'first');
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
    final controller = UnitDetailController(repository: repository, id: 'first');
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

  for (final failure in UnitDetailFailure.values) {
    test('maps typed failure $failure with no payload', () async {
      final repository = _Repository();
      final controller = UnitDetailController(repository: repository, id: 'first');
      addTearDown(controller.dispose);
      final load = controller.load();
      repository.calls.single.completeError(UnitDetailException(failure));
      await load;
      expect(
        controller.state,
        failure == UnitDetailFailure.unavailable
            ? UnitDetailState.unavailable
            : UnitDetailState.denied,
      );
      expect(controller.detail, isNull);
    });
  }
}

class _Repository implements UnitDetailRepository {
  final calls = <Completer<UnitDetail>>[];
  final ids = <String>[];
  @override
  Future<UnitDetail> fetchById(String id) {
    ids.add(id);
    final completer = Completer<UnitDetail>();
    calls.add(completer);
    return completer.future;
  }
}

UnitDetail _detail(String id) => UnitDetail(
  id: id,
  name: 'Unidade',
  slug: 'unidade',
  status: 'active',
  institutionId: 'institution',
  institutionName: 'Instituição',
  institutionType: null,
  unitType: const UnitDetailType(id: 'type', name: 'Escola'),
  address: null,
  contact: null,
  effectivePlan: null,
);
