import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final instant = DateTime.utc(2026, 8, 3, 12);

  test('records activities exactly once in the shared activity center', () {
    final activities = SuperadminActivityController(now: () => instant);
    final store = SuperadminPrototypeStore(activityController: activities, now: () => instant);

    store.recordActivity(
      kind: SuperadminActivityKind.announcement,
      subject: 'Plano atualizado',
      summary: 'Coelo Essencial foi atualizado',
    );

    expect(activities.activities, hasLength(1));
    expect(activities.activities.single.subject, 'Plano atualizado');
    expect(activities.activities.single.createdAt, instant);
  });

  test('keeps audit events newest first and externally immutable', () {
    var now = instant;
    final store = SuperadminPrototypeStore(
      activityController: SuperadminActivityController(now: () => now),
      now: () => now,
    );

    store.recordAuditEvent(
      module: 'Planos',
      action: 'Atualizou',
      objectType: 'plano',
      objectId: 'basic',
    );
    now = instant.add(const Duration(minutes: 1));
    store.recordAuditEvent(
      module: 'Convites',
      action: 'Reenviou',
      objectType: 'convite',
      objectId: 'invite-1',
    );

    expect(store.auditEvents.map((event) => event.module), ['Convites', 'Planos']);
    expect(() => store.auditEvents.add(store.auditEvents.first), throwsUnsupportedError);
  });

  test('copies minimized changes and strips sensitive audit values', () {
    final before = <String, String>{'status': 'pending', 'recipient': 'pessoa@exemplo.com'};
    final store = SuperadminPrototypeStore(
      activityController: SuperadminActivityController(now: () => instant),
      now: () => instant,
    );

    store.recordAuditEvent(
      module: 'Convites',
      action: 'Reenviou',
      objectType: 'convite',
      objectId: 'invite-1',
      before: before,
      after: const {
        'status': 'pending',
        'link': 'https://app.coelo.me/invite/token-secreto',
        'message': 'Mensagem integral proibida',
      },
    );
    before['status'] = 'accepted';

    final event = store.auditEvents.single;
    expect(event.before, {'status': 'pending'});
    expect(event.after, {'status': 'pending'});
    expect(event.searchableText, isNot(contains('pessoa@exemplo.com')));
    expect(event.searchableText, isNot(contains('token-secreto')));
    expect(event.searchableText, isNot(contains('Mensagem integral')));
  });
}
