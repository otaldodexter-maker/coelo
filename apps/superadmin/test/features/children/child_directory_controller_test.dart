import 'dart:async';
import 'package:coelo_api/children.dart';
import 'package:coelo_superadmin/features/children/presentation/child_directory_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const institutionA = '10000000-0000-0000-0000-000000000001';
const institutionB = '10000000-0000-0000-0000-000000000002';
const contextId = '20000000-0000-0000-0000-000000000001';
const personId = '30000000-0000-0000-0000-000000000001';
ChildDirectoryPage page({String institution = institutionA, ChildDirectoryCursor? cursor}) =>
    ChildDirectoryPage(
      items: [
        if (cursor != null)
          for (var index = 2; index <= 20; index++)
            ChildDirectoryItem(
              contextId: '20000000-0000-0000-0000-${index.toRadixString(16).padLeft(12, '0')}',
              personId: '30000000-0000-0000-0000-${index.toRadixString(16).padLeft(12, '0')}',
              personName: 'Sintética $index',
              institutionId: institution,
              institutionName: 'Sintética',
            ),
        ChildDirectoryItem(
          contextId: contextId,
          personId: personId,
          personName: 'Sintética',
          institutionId: institution,
          institutionName: 'Sintética',
        ),
      ],
      nextCursor: cursor,
    );

final class PendingRead {
  final requests = <ChildDirectoryRequest>[];
  final responses = <Completer<ChildDirectoryPage>>[];
  Future<ChildDirectoryPage> call(ChildDirectoryRequest request) {
    requests.add(request);
    final response = Completer<ChildDirectoryPage>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  test('invalid institution prevents transport', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(
      read: reads.call,
      sessionAvailable: true,
      institutionId: 'bad',
    );
    await controller.reload();
    expect(reads.requests, isEmpty);
    expect(controller.state, ChildDirectoryState.unavailable);
    controller.dispose();
  });
  test('wrong owner response never becomes visible', () async {
    final controller = ChildDirectoryController(
      sessionAvailable: true,
      institutionId: institutionA,
      read: (_) async => page(institution: institutionB),
    );
    await controller.reload();
    expect(controller.state, ChildDirectoryState.unavailable);
    expect(controller.page, isNull);
    controller.dispose();
  });
  test('clearing institution filter resets page and cursor', () async {
    final requests = <ChildDirectoryRequest>[];
    final controller = ChildDirectoryController(
      sessionAvailable: true,
      institutionId: institutionA,
      read: (request) async {
        requests.add(request);
        return page();
      },
    );
    await controller.reload();
    await controller.setContext(sessionAvailable: true, institutionId: null, revision: 1);
    expect(requests.last.institutionId, isNull);
    expect(requests.last.after, isNull);
    controller.dispose();
  });
  test('listener context replacement uses new reader and never starts old request', () async {
    final reads = PendingRead();
    final replacement = PendingRead();
    final controller = ChildDirectoryController(read: reads.call, sessionAvailable: true);
    var changed = false;
    Future<void>? update;
    controller.addListener(() {
      if (!changed && controller.state == ChildDirectoryState.loading) {
        changed = true;
        update = controller.setContext(
          sessionAvailable: true,
          institutionId: institutionB,
          revision: 1,
          read: replacement.call,
        );
      }
    });
    await controller.reload();
    expect(reads.requests, isEmpty);
    expect(replacement.requests.single.institutionId, institutionB);
    replacement.responses.single.complete(page(institution: institutionB));
    await update;
    expect(controller.page!.items.single.institutionId, institutionB);
    controller.dispose();
  });
  test('absent session never reads', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(read: reads.call);
    await controller.reload();
    expect(reads.requests, isEmpty);
    expect(controller.state, ChildDirectoryState.denied);
    controller.dispose();
  });
  test('default unavailable never becomes fixture data', () async {
    final controller = ChildDirectoryController(sessionAvailable: true);
    await controller.reload();
    expect(controller.state, ChildDirectoryState.unavailable);
    expect(controller.page, isNull);
    controller.dispose();
  });
  test('first page request has defaults and explicit institution', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(
      read: reads.call,
      sessionAvailable: true,
      institutionId: institutionA,
    );
    final pending = controller.reload();
    expect(controller.state, ChildDirectoryState.loading);
    expect(controller.page, isNull);
    expect(reads.requests.single.institutionId, institutionA);
    expect(reads.requests.single.limit, 20);
    expect(reads.requests.single.after, isNull);
    reads.responses.single.complete(page());
    await pending;
    expect(controller.state, ChildDirectoryState.ready);
    controller.dispose();
  });
  test('next page uses opaque cursor once and clears previous page while loading', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(read: reads.call, sessionAvailable: true);
    var pending = controller.reload();
    const cursor = ChildDirectoryCursor(name: 'opaque', contextId: contextId);
    reads.responses.last.complete(page(cursor: cursor));
    await pending;
    pending = controller.nextPage();
    expect(reads.requests.last.after, same(cursor));
    expect(controller.page, isNull);
    await controller.nextPage();
    expect(reads.requests, hasLength(2));
    reads.responses.last.complete(ChildDirectoryPage(items: []));
    await pending;
    expect(controller.state, ChildDirectoryState.empty);
    await controller.nextPage();
    expect(reads.requests, hasLength(2));
    controller.dispose();
  });
  test('scope replacement clears cursor and ignores old success', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(
      read: reads.call,
      sessionAvailable: true,
      institutionId: institutionA,
    );
    final old = controller.reload();
    final newer = controller.setContext(
      sessionAvailable: true,
      institutionId: institutionB,
      revision: 1,
    );
    expect(reads.requests.last.after, isNull);
    expect(controller.page, isNull);
    reads.responses.last.complete(page(institution: institutionB));
    await newer;
    reads.responses.first.complete(page());
    await old;
    expect(controller.page!.items.single.institutionId, institutionB);
    controller.dispose();
  });
  test('same institution revision ignores late denial', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(
      read: reads.call,
      sessionAvailable: true,
      institutionId: institutionA,
    );
    final old = controller.reload();
    final newer = controller.setContext(
      sessionAvailable: true,
      institutionId: institutionA,
      revision: 1,
    );
    reads.responses.last.complete(page());
    await newer;
    reads.responses.first.completeError(const ChildDirectoryDeniedException());
    await old;
    expect(controller.state, ChildDirectoryState.ready);
    controller.dispose();
  });
  test('logout clears data and no late request resurrects it', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(read: reads.call, sessionAvailable: true);
    final old = controller.reload();
    await controller.setContext(sessionAvailable: false, institutionId: null, revision: 1);
    reads.responses.single.complete(page());
    await old;
    expect(controller.state, ChildDirectoryState.denied);
    expect(controller.page, isNull);
    expect(reads.requests, hasLength(1));
    controller.dispose();
  });
  test('reader replacement invalidates previous transport and data', () async {
    final reads = PendingRead();
    final replacement = PendingRead();
    final controller = ChildDirectoryController(read: reads.call, sessionAvailable: true);
    final old = controller.reload();
    final newer = controller.setContext(
      sessionAvailable: true,
      institutionId: null,
      revision: 1,
      read: replacement.call,
    );
    replacement.responses.single.complete(page(institution: institutionB));
    await newer;
    reads.responses.single.complete(page());
    await old;
    expect(controller.page!.items.single.institutionId, institutionB);
    controller.dispose();
  });
  test('reload drops previous pagination cursor', () async {
    final requests = <ChildDirectoryRequest>[];
    final controller = ChildDirectoryController(
      sessionAvailable: true,
      read: (request) async {
        requests.add(request);
        return page(
          cursor: const ChildDirectoryCursor(name: 'opaque', contextId: contextId),
        );
      },
    );
    await controller.reload();
    await controller.nextPage();
    await controller.reload();
    expect(requests[1].after, isNotNull);
    expect(requests.last.after, isNull);
    controller.dispose();
  });
  test('current failure and denied remove all previous data', () async {
    for (final error in [StateError('PRIVATE'), const ChildDirectoryDeniedException()]) {
      var calls = 0;
      final controller = ChildDirectoryController(
        sessionAvailable: true,
        read: (_) async {
          if (calls++ == 0) return page();
          throw error;
        },
      );
      await controller.reload();
      expect(controller.page, isNotNull);
      await controller.reload();
      expect(controller.page, isNull);
      expect(
        controller.state,
        error is ChildDirectoryDeniedException
            ? ChildDirectoryState.denied
            : ChildDirectoryState.unavailable,
      );
      controller.dispose();
    }
  });
  test('dispose ignores pending completion and future requests', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(read: reads.call, sessionAvailable: true);
    final pending = controller.reload();
    controller.dispose();
    reads.responses.single.complete(page());
    await pending;
    await controller.reload();
    await controller.nextPage();
    expect(controller.page, isNull);
    expect(reads.requests, hasLength(1));
  });
  test('listener logout before transport prevents call', () async {
    final reads = PendingRead();
    final controller = ChildDirectoryController(read: reads.call, sessionAvailable: true);
    controller.addListener(() {
      if (controller.state == ChildDirectoryState.loading) {
        unawaited(controller.setContext(sessionAvailable: false, institutionId: null, revision: 1));
      }
    });
    await controller.reload();
    expect(reads.requests, isEmpty);
    expect(controller.state, ChildDirectoryState.denied);
    controller.dispose();
  });
}
