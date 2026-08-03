import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/data/fake_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publish, cancel and accept emit one minimized activity and audit each', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final activities = SuperadminActivityController(now: () => now);
    final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
    final repository = FakeNoticeRepository(store: store, now: () => now);
    final notice = repository.create(
      const NoticeDraft(
        title: 'Janela local',
        message: 'Mensagem fictícia.',
        priority: NoticePriority.important,
        audience: NoticeAudience.coeloTeam,
        audienceLabel: 'Equipe Coelo',
        behavior: NoticeBehavior.confirmation,
        mandatory: true,
      ),
    );

    final published = repository.publish(notice.id);
    expect(published.status, NoticeStatus.active);
    expect(activities.activities, hasLength(1));
    expect(store.auditEvents, hasLength(1));
    final cancelled = repository.cancel(published.id);
    expect(cancelled.status, NoticeStatus.cancelled);
    expect(activities.activities, hasLength(2));
    expect(store.auditEvents, hasLength(2));

    final active = repository.publish(repository.duplicate(notice.id).id);
    repository.accept(active.id);
    expect(activities.activities, hasLength(4));
    expect(store.auditEvents, hasLength(4));
    expect(
      store.auditEvents.every(
        (event) => event.after.keys.every({'status', 'priority', 'audience', 'behavior'}.contains),
      ),
      isTrue,
    );
  });
}
