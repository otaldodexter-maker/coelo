import 'dart:async';

import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_read_repository.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_read_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in ['page logout', 'detail logout', 'page scope change']) {
    test('reentrant $action prevents dispatch after loading notification', () async {
      final repo = _Repository();
      final controller = AgendaReadController(repo, boundaryKey: 'a');
      var invalidated = false;
      controller.addListener(() {
        if (invalidated) return;
        invalidated = true;
        controller.setBoundary(action.endsWith('scope change') ? 'scope-B' : null);
      });
      if (action.startsWith('detail')) {
        await controller.openDetail('a');
      } else {
        await _load(controller);
      }
      expect(repo.calls, isEmpty);
      controller.dispose();
    });
  }

  test('synchronous denial prevents starting the sibling RPC', () async {
    final repo = _Repository()
      ..failure = const AgendaReadException(AgendaReadFailure.unauthorized)
      ..synchronousFailure = true;
    final controller = _controller(repo);
    await _load(controller);
    expect(repo.calls, ['list']);
    expect(controller.pageStatus, AgendaProjectionStatus.unauthorized);
  });

  test('missing boundary prevents all reads', () async {
    final repo = _Repository();
    final controller = AgendaReadController(repo, boundaryKey: null);
    addTearDown(controller.dispose);
    await _load(controller);
    await controller.openDetail('a');
    expect(repo.calls, isEmpty);
    expect(controller.pageStatus, AgendaProjectionStatus.unauthorized);
  });

  test('publishes list and contexts atomically with requested pagination', () async {
    final repo = _Repository();
    final contexts = Completer<AgendaReadContexts>();
    repo.contexts = () => contexts.future;
    final controller = _controller(repo);
    final future = _load(controller, offset: 20);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pageStatus, AgendaProjectionStatus.loading);
    expect(controller.page, isNull);
    contexts.complete(_contexts());
    await future;
    expect(controller.pageStatus, AgendaProjectionStatus.ready);
    expect(controller.page!.offset, 20);
    expect(controller.contexts, isNotNull);
    expect(repo.lastOffset, 20);
  });

  test('empty result remains distinct from failure and retains total', () async {
    final repo = _Repository()..empty = true;
    final controller = _controller(repo);
    await _load(controller);
    expect(controller.pageStatus, AgendaProjectionStatus.empty);
    expect(controller.page!.total, 0);
  });

  test('transient error exposes no old page and explicit retry repeats query', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    await _load(controller, offset: 20);
    repo.failure = const AgendaReadException(AgendaReadFailure.unavailable);
    await _load(controller, offset: 40);
    expect(controller.pageStatus, AgendaProjectionStatus.failure);
    expect(controller.page, isNull);
    repo.failure = null;
    await controller.retryPage();
    expect(controller.page!.offset, 40);
  });

  test('denial is immediate despite pending sibling and clears all projections', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    await _load(controller);
    await controller.openDetail('a');
    final pending = Completer<AgendaReadContexts>();
    repo.contexts = () => pending.future;
    repo.failure = const AgendaReadException(
      AgendaReadFailure.unauthorized,
      code: 'SAI_MEMBERSHIP_REVOKED',
    );
    final future = _load(controller);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pageStatus, AgendaProjectionStatus.unauthorized);
    expect(controller.detailStatus, AgendaProjectionStatus.unauthorized);
    expect(controller.page, isNull);
    expect(controller.detail, isNull);
    expect(controller.contexts, isNull);
    pending.complete(_contexts());
    await future;
    expect(controller.contexts, isNull);
  });

  for (final deniedPart in ['contexts', 'list']) {
    test('late $deniedPart denial overrides prior sibling transport failure', () async {
      final repo = _Repository();
      final controller = _controller(repo);
      final pendingPage = Completer<AgendaReadPage>();
      final pendingContexts = Completer<AgendaReadContexts>();
      if (deniedPart == 'contexts') {
        repo.failure = const AgendaReadException(AgendaReadFailure.unavailable);
        repo.contexts = () => pendingContexts.future;
      } else {
        repo.list = () => pendingPage.future;
        repo.contexts = () =>
            Future.error(const AgendaReadException(AgendaReadFailure.unavailable));
      }
      final load = _load(controller);
      await Future<void>.delayed(Duration.zero);
      await controller.openDetail('a');
      final error = const AgendaReadException(AgendaReadFailure.unauthorized);
      if (deniedPart == 'contexts') {
        pendingContexts.completeError(error);
      } else {
        pendingPage.completeError(error);
      }
      await load;
      await Future<void>.delayed(Duration.zero);
      expect(controller.pageStatus, AgendaProjectionStatus.unauthorized);
      expect(controller.detailStatus, AgendaProjectionStatus.unauthorized);
      expect(controller.page, isNull);
      expect(controller.contexts, isNull);
      expect(controller.detail, isNull);
    });
  }

  test('denied context cannot retry until boundary revision changes', () async {
    final repo = _Repository()..failure = const AgendaReadException(AgendaReadFailure.unauthorized);
    final controller = _controller(repo);
    await _load(controller);
    final calls = repo.calls.length;
    repo.failure = null;
    await controller.retryPage();
    await controller.openDetail('a');
    expect(repo.calls.length, calls);
    controller.setBoundary('session-A:scope-A:revision-2');
    await _load(controller);
    expect(controller.pageStatus, AgendaProjectionStatus.ready);
  });

  test('boundary replacement discards delayed page and clears retry query', () async {
    final repo = _Repository();
    final pending = Completer<AgendaReadPage>();
    repo.list = () => pending.future;
    final controller = _controller(repo);
    final old = _load(controller);
    controller.setBoundary('session-B:scope-B:revision-1');
    expect(controller.pageStatus, AgendaProjectionStatus.idle);
    pending.complete(_page(0));
    await old;
    expect(controller.page, isNull);
    final calls = repo.calls.length;
    await controller.retryPage();
    expect(repo.calls.length, calls);
  });

  test('newer page wins when requests finish out of order', () async {
    final repo = _Repository();
    final pending = Completer<AgendaReadPage>();
    repo.list = () => pending.future;
    final controller = _controller(repo);
    final old = _load(controller);
    repo.list = null;
    await _load(controller, offset: 20);
    pending.complete(_page(0));
    await old;
    expect(controller.page!.offset, 20);
  });

  test('detail request replaces prior detail and stale completion is ignored', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    await controller.openDetail('a');
    final pending = Completer<AgendaReadDetail>();
    repo.get = (_) => pending.future;
    final old = controller.openDetail('b');
    expect(controller.detail, isNull);
    repo.get = null;
    await controller.openDetail('c');
    pending.complete(_detail('b'));
    await old;
    expect(controller.detail!.item.id, 'c');
  });

  test('detail not found does not erase authorized directory', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    await _load(controller);
    repo.get = (_) => Future.error(const AgendaReadException(AgendaReadFailure.notFound));
    await controller.openDetail('missing');
    expect(controller.detailStatus, AgendaProjectionStatus.notFound);
    expect(controller.pageStatus, AgendaProjectionStatus.ready);
    expect(controller.detail, isNull);
  });

  test('detail denial invalidates concurrent page result', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    final pending = Completer<AgendaReadPage>();
    repo.list = () => pending.future;
    final load = _load(controller);
    repo.get = (_) => Future.error(const AgendaReadException(AgendaReadFailure.unauthorized));
    await controller.openDetail('a');
    pending.complete(_page(0));
    await load;
    expect(controller.page, isNull);
    expect(controller.pageStatus, AgendaProjectionStatus.unauthorized);
  });

  test('closing detail invalidates late callback without removing page', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    await _load(controller);
    final pending = Completer<AgendaReadDetail>();
    repo.get = (_) => pending.future;
    final load = controller.openDetail('a');
    controller.closeDetail();
    pending.complete(_detail('a'));
    await load;
    expect(controller.detail, isNull);
    expect(controller.detailStatus, AgendaProjectionStatus.idle);
    expect(controller.page, isNotNull);
  });

  test('logout clears data synchronously and late callbacks remain discarded', () async {
    final repo = _Repository();
    final controller = _controller(repo);
    await _load(controller);
    await controller.openDetail('a');
    controller.setBoundary(null);
    expect(controller.page, isNull);
    expect(controller.detail, isNull);
    expect(controller.contexts, isNull);
    expect(controller.pageStatus, AgendaProjectionStatus.unauthorized);
  });

  test('dispose clears data and ignores a pending result without notifying', () async {
    final repo = _Repository();
    final controller = AgendaReadController(repo, boundaryKey: 'a');
    final pending = Completer<AgendaReadPage>();
    repo.list = () => pending.future;
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = _load(controller);
    final before = notifications;
    controller.dispose();
    pending.complete(_page(0));
    await load;
    expect(notifications, before);
    expect(controller.page, isNull);
  });
}

AgendaReadController _controller(_Repository repo) {
  final controller = AgendaReadController(repo, boundaryKey: 'session-A:scope-A:revision-1');
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _load(AgendaReadController controller, {int offset = 0}) => controller.loadPage(
  from: DateTime.utc(2026, 9, 1),
  to: DateTime.utc(2026, 10, 1),
  offset: offset,
);
AgendaReadContexts _contexts() => AgendaReadContexts(contexts: [], correlationId: 'correlation');
AgendaReadPage _page(int offset, {bool empty = false}) => AgendaReadPage(
  items: empty ? [] : [_item('a')],
  total: empty ? 0 : 100,
  limit: 20,
  offset: offset,
  correlationId: 'correlation',
);
AgendaReadDetail _detail(String id) =>
    AgendaReadDetail(item: _item(id), correlationId: 'correlation');
AgendaReadItem _item(String id) => AgendaReadItem(
  id: id,
  institutionId: 'institution',
  contextId: 'institution',
  contextKind: AgendaContextLevel.institution,
  title: 'Evento $id',
  type: AgendaItemType.event,
  priority: AgendaPriority.normal,
  status: AgendaItemStatus.published,
  origin: AgendaItemOrigin.institution,
  startsAt: DateTime.utc(2026, 9, 8, 12),
  endsAt: DateTime.utc(2026, 9, 8, 13),
  allDay: false,
  timeZoneId: 'UTC',
  location: '',
  description: '',
  responseMode: AgendaResponseMode.none,
  guardianResponsePolicy: GuardianResponsePolicy.oneIsEnough,
  audience: AgendaReadAudience(
    institutionId: 'institution',
    unitIds: {},
    groupIds: {},
    activityIds: {},
  ),
  reminders: {},
  questions: [],
  revision: 1,
  history: [],
);

final class _Repository implements AgendaReadRepository {
  final calls = <String>[];
  int? lastOffset;
  bool empty = false;
  bool synchronousFailure = false;
  AgendaReadException? failure;
  Future<AgendaReadPage> Function()? list;
  Future<AgendaReadContexts> Function()? contexts;
  Future<AgendaReadDetail> Function(String)? get;
  @override
  Future<AgendaReadPage> fetchEvents({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
    int limit = 100,
    int offset = 0,
  }) {
    calls.add('list');
    lastOffset = offset;
    if (failure != null) {
      if (synchronousFailure) throw failure!;
      return Future.error(failure!);
    }
    return list == null ? Future.value(_page(offset, empty: empty)) : list!();
  }

  @override
  Future<AgendaReadContexts> fetchContexts() async {
    calls.add('contexts');
    return contexts == null ? _contexts() : contexts!();
  }

  @override
  Future<AgendaReadDetail> fetchEvent(String id) async {
    calls.add('get:$id');
    return get == null ? _detail(id) : get!(id);
  }
}
