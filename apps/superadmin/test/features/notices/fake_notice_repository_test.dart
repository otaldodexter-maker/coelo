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
    expect(activities.activities, hasLength(2));
    expect(store.auditEvents, hasLength(2));
    final cancelled = repository.cancel(published.id);
    expect(cancelled.status, NoticeStatus.cancelled);
    expect(activities.activities, hasLength(3));
    expect(store.auditEvents, hasLength(3));

    final active = repository.publish(repository.duplicate(notice.id).id);
    repository.accept(active.id);
    expect(activities.activities, hasLength(6));
    expect(store.auditEvents, hasLength(6));
    expect(
      store.auditEvents.every(
        (event) => event.after.keys.every({'status', 'priority', 'audience', 'behavior'}.contains),
      ),
      isTrue,
    );
  });

  test('duplicate resets a terminal notice to a clean draft', () {
    final repository = _repository();
    const draft = NoticeDraft(
      title: 'Janela local',
      message: 'Mensagem fictícia.',
      priority: NoticePriority.important,
      audience: NoticeAudience.everyone,
      audienceLabel: 'Todos',
      behavior: NoticeBehavior.confirmation,
    );

    final inactive = repository.cancel(repository.publish(repository.create(draft).id).id);
    final copy = repository.duplicate(inactive.id);

    expect(copy.status, NoticeStatus.draft);
    expect(copy.deliveredCount, 0);
    expect(copy.viewedCount, 0);
    expect(copy.acceptedCount, 0);
  });

  test('mandatory checkbox acceptance requires acknowledgement', () {
    final repository = _repository();
    const checkboxDraft = NoticeDraft(
      title: 'Janela local',
      message: 'Mensagem fictícia.',
      priority: NoticePriority.important,
      audience: NoticeAudience.everyone,
      audienceLabel: 'Todos',
      behavior: NoticeBehavior.checkboxConfirmation,
    );

    final active = repository.publish(repository.create(checkboxDraft).id);

    expect(() => repository.accept(active.id), throwsStateError);
    expect(repository.accept(active.id, checkboxChecked: true).acceptedCount, 1);
  });

  test('cancel transitions a draft notice to inactive', () {
    final repository = _repository();
    const draft = NoticeDraft(
      title: 'Janela local',
      message: 'Mensagem fictícia.',
      priority: NoticePriority.important,
      audience: NoticeAudience.everyone,
      audienceLabel: 'Todos',
      behavior: NoticeBehavior.dismissible,
    );

    final cancelled = repository.cancel(repository.create(draft).id);

    expect(cancelled.status, NoticeStatus.cancelled);
  });

  test('create derives the legacy mandatory flag from behavior', () {
    final repository = _repository();
    const draft = NoticeDraft(
      title: 'Janela local',
      message: 'Mensagem fictícia.',
      priority: NoticePriority.important,
      audience: NoticeAudience.everyone,
      audienceLabel: 'Todos',
      behavior: NoticeBehavior.dismissible,
      mandatory: true,
    );

    final notice = repository.create(draft);

    expect(notice.mandatory, isFalse);
  });

  test('create preserves local content metadata', () {
    final repository = _repository();
    const draft = NoticeDraft(
      title: 'Janela local',
      message: 'Mensagem fictícia.',
      priority: NoticePriority.important,
      audience: NoticeAudience.group,
      audienceLabel: 'Turma Azul',
      audienceRoleLabel: 'Responsáveis',
      behavior: NoticeBehavior.confirmation,
      contentFormat: NoticeContentFormat.textBackground,
      backgroundColorValue: 0xFFD63C00,
      textColorValue: 0xFFFFFFFF,
    );

    final notice = repository.create(draft);

    expect(notice.contentFormat, NoticeContentFormat.textBackground);
    expect(notice.audienceRoleLabel, 'Responsáveis');
    expect(notice.backgroundColorValue, 0xFFD63C00);
    expect(notice.textColorValue, 0xFFFFFFFF);
    expect(notice.mandatory, isTrue);
  });
}

FakeNoticeRepository _repository() {
  final now = DateTime.utc(2026, 8, 3, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  return FakeNoticeRepository(store: store, now: () => now);
}
