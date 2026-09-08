import 'dart:async';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/presentation/person_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = '10000000-0000-4000-8000-000000000001';
const _b = '10000000-0000-4000-8000-000000000002';

void main() {
  test('ready then reload clears data before denial', () async {
    final reader = _Reader();
    final controller = PersonDetailController(reader: reader, id: _a);
    addTearDown(controller.dispose);
    final first = controller.load();
    reader.calls.single.complete(_person(_a));
    await first;
    expect(controller.state, PersonDetailState.ready);
    final reload = controller.load();
    expect(controller.detail, isNull);
    expect(controller.state, PersonDetailState.loading);
    reader.calls.last.completeError(const PersonDirectoryUnauthorizedException());
    await reload;
    expect(controller.state, PersonDetailState.denied);
    expect(controller.detail, isNull);
  });

  for (final error in [
    const PersonDirectoryUnavailableException(),
    StateError('private transport text'),
  ]) {
    test('failure is unavailable with no retained data: ${error.runtimeType}', () async {
      final reader = _Reader();
      final controller = PersonDetailController(reader: reader, id: _a);
      addTearDown(controller.dispose);
      final load = controller.load();
      reader.calls.single.completeError(error);
      await load;
      expect(controller.state, PersonDetailState.unavailable);
      expect(controller.detail, isNull);
    });
  }

  test('invalid id is denied without requesting data', () async {
    final reader = _Reader();
    final controller = PersonDetailController(reader: reader, id: 'invalid');
    addTearDown(controller.dispose);
    await controller.load();
    expect(reader.calls, isEmpty);
    expect(controller.state, PersonDetailState.denied);
  });

  for (final staleError in [false, true]) {
    test('new reader and target discard late ${staleError ? 'error' : 'success'}', () async {
      final reader = _Reader();
      final next = _Reader();
      final controller = PersonDetailController(reader: reader, id: _a);
      addTearDown(controller.dispose);
      final first = controller.load();
      final second = controller.load(id: _b, reader: next);
      next.calls.single.complete(_person(_b));
      await second;
      if (staleError) {
        reader.calls.single.completeError(const PersonDirectoryUnauthorizedException());
      } else {
        reader.calls.single.complete(_person(_a));
      }
      await first;
      expect(controller.detail!.id, _b);
      expect(controller.state, PersonDetailState.ready);
    });
  }

  for (final error in [false, true]) {
    test('dispose ignores pending ${error ? 'error' : 'success'} and future loads', () async {
      final reader = _Reader();
      final controller = PersonDetailController(reader: reader, id: _a);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final load = controller.load();
      controller.dispose();
      if (error) {
        reader.calls.single.completeError(StateError('late'));
      } else {
        reader.calls.single.complete(_person(_a));
      }
      await load;
      await controller.load();
      expect(notifications, 1);
      expect(reader.calls, hasLength(1));
      expect(controller.detail, isNull);
    });
  }

  test('mismatched injected response is never rendered', () async {
    final reader = _Reader();
    final controller = PersonDetailController(reader: reader, id: _a);
    addTearDown(controller.dispose);
    final load = controller.load();
    reader.calls.single.complete(_person(_b));
    await load;
    expect(controller.state, PersonDetailState.unavailable);
    expect(controller.detail, isNull);
  });

  test('listener replacement cancels superseded request before dispatch', () async {
    final old = _Reader();
    final next = _Reader();
    final controller = PersonDetailController(reader: old, id: _a);
    addTearDown(controller.dispose);
    Future<void>? replacement;
    var replaced = false;
    controller.addListener(() {
      if (!replaced) {
        replaced = true;
        replacement = controller.load(reader: next, id: _b);
      }
    });
    await controller.load();
    expect(old.calls, isEmpty);
    expect(next.ids, [_b]);
    next.calls.single.complete(_person(_b));
    await replacement;
    expect(controller.detail!.id, _b);
  });

  test('unavailable default never returns a fabricated record', () async {
    await expectLater(
      const UnavailablePersonDetailReader().fetchDetail(_a),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });
}

class _Reader implements PersonDetailReader {
  final calls = <Completer<PersonDirectoryItem>>[];
  final ids = <String>[];
  @override
  Future<PersonDirectoryItem> fetchDetail(String id) {
    ids.add(id);
    final call = Completer<PersonDirectoryItem>();
    calls.add(call);
    return call.future;
  }
}

PersonDirectoryItem _person(String id) => PersonDirectoryItem(
  id: id,
  displayName: 'Synthetic person',
  type: PersonType.adult,
  status: PersonStatus.active,
  updatedAt: DateTime.utc(2026, 9, 7),
);
