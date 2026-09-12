import 'package:coelo_superadmin/app/activity/context_notification_feed.dart';
import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sino remoto carrega preservando lido/nao lido e grava read_at ao abrir', () async {
    final repository = _FakeRepository([
      ContextNotification(
        eventId: 'e1',
        eventCode: 'child_safety.authorization',
        objectType: 'child_safety_authorization',
        createdAt: DateTime(2026, 9, 11, 10),
        payload: const {'title': 'Autorizacao registrada'},
        readAt: null,
      ),
      ContextNotification(
        eventId: 'e2',
        eventCode: 'custom.code',
        objectType: 'thing',
        createdAt: DateTime(2026, 9, 11, 9),
        payload: const {},
        readAt: DateTime(2026, 9, 11, 9, 30),
      ),
    ]);
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    final feed = ContextNotificationFeed(repository: repository, controller: controller);

    await feed.load();
    expect(controller.activities.map((a) => a.id), ['ctx-e1', 'ctx-e2']);
    expect(controller.unreadCount, 1);
    expect(controller.activities.first.subject, 'Segurança infantil · autorização');
    expect(controller.activities.first.summary, 'Autorizacao registrada');
    expect(controller.activities.last.subject, 'custom · code');

    // Recarga nao duplica.
    await feed.load();
    expect(controller.activities.length, 2);

    controller.setCenterOpen(true);
    await Future<void>.delayed(Duration.zero);
    expect(controller.unreadCount, 0);
    expect(repository.marked, ['e1']);

    // Abrir de novo sem novos itens nao grava de novo.
    controller.setCenterOpen(false);
    controller.setCenterOpen(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.marked, ['e1']);
  });

  test('carga concluida com o centro aberto marca localmente e no servidor', () async {
    final repository = _FakeRepository([_unreadNotification]);
    final controller = SuperadminActivityController()..setCenterOpen(true);
    addTearDown(controller.dispose);
    final feed = ContextNotificationFeed(repository: repository, controller: controller);

    await feed.load();

    expect(controller.unreadCount, 0);
    expect(controller.activities.single.isRead, isTrue);
    expect(repository.marked, ['e1']);
  });

  test('falha ao gravar read_at e repetida na proxima abertura', () async {
    final repository = _FakeRepository([_unreadNotification])..markFailuresRemaining = 1;
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    final feed = ContextNotificationFeed(repository: repository, controller: controller);

    await feed.load();
    controller.setCenterOpen(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.markAttempts, 1);
    expect(repository.marked, isEmpty);

    controller.setCenterOpen(false);
    controller.setCenterOpen(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.markAttempts, 2);
    expect(repository.marked, ['e1']);
  });
}

final _unreadNotification = ContextNotification(
  eventId: 'e1',
  eventCode: 'child_safety.authorization',
  objectType: 'child_safety_authorization',
  createdAt: DateTime(2026, 9, 11, 10),
  payload: const {'title': 'Autorizacao registrada'},
  readAt: null,
);

final class _FakeRepository implements ContextNotificationRepository {
  _FakeRepository(this.items);
  final List<ContextNotification> items;
  final marked = <String>[];
  var markAttempts = 0;
  var markFailuresRemaining = 0;

  @override
  Future<List<ContextNotification>> listMine({int limit = 30}) async => items;

  @override
  Future<void> markRead(Iterable<String> eventIds) async {
    markAttempts += 1;
    if (markFailuresRemaining > 0) {
      markFailuresRemaining -= 1;
      throw StateError('falha sintetica');
    }
    marked.addAll(eventIds);
  }
}
