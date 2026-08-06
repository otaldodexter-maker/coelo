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
  test('duplicate expired notice resets expiration limits and publish delivers reach', () {
    var now = DateTime.utc(2026, 8, 3, 12);
    final repository = _repositoryWithClock(() => now);
    final active = repository.publish(
      repository
          .create(
            _draft(
              endsAt: now.add(const Duration(hours: 1)),
              recurrence: NoticeRecurrence.daily,
              recurrenceUntil: now.add(const Duration(hours: 1)),
            ),
          )
          .id,
    );
    expect(active.deliveredCount, active.reach);
    now = now.add(const Duration(hours: 2));

    final duplicate = repository.duplicate(active.id);

    expect(repository.find(active.id)!.status, NoticeStatus.ended);
    expect(duplicate.endsAt, isNull);
    expect(duplicate.recurrenceUntil, isNull);
  });

  test('actions materialize expiration before accept pause resume and cancel', () {
    var now = DateTime.utc(2026, 8, 3, 12);
    final acceptRepository = _repositoryWithClock(() => now);
    final activeForAccept = _publishWithEnd(acceptRepository, now.add(const Duration(hours: 1)));
    now = now.add(const Duration(hours: 2));
    expect(() => acceptRepository.accept(activeForAccept.id), throwsStateError);
    expect(acceptRepository.find(activeForAccept.id)!.status, NoticeStatus.ended);

    now = DateTime.utc(2026, 8, 3, 12);
    final pauseRepository = _repositoryWithClock(() => now);
    final activeForPause = _publishWithEnd(pauseRepository, now.add(const Duration(hours: 1)));
    now = now.add(const Duration(hours: 2));
    expect(() => pauseRepository.pause(activeForPause.id), throwsStateError);
    expect(pauseRepository.find(activeForPause.id)!.status, NoticeStatus.ended);

    now = DateTime.utc(2026, 8, 3, 12);
    final resumeRepository = _repositoryWithClock(() => now);
    final activeForResume = _publishWithEnd(resumeRepository, now.add(const Duration(hours: 1)));
    resumeRepository.pause(activeForResume.id);
    now = now.add(const Duration(hours: 2));
    expect(() => resumeRepository.resume(activeForResume.id), throwsStateError);
    expect(resumeRepository.find(activeForResume.id)!.status, NoticeStatus.ended);

    now = DateTime.utc(2026, 8, 3, 12);
    final cancelRepository = _repositoryWithClock(() => now);
    final activeForCancel = _publishWithEnd(cancelRepository, now.add(const Duration(hours: 1)));
    now = now.add(const Duration(hours: 2));
    expect(() => cancelRepository.cancel(activeForCancel.id), throwsStateError);
    expect(cancelRepository.find(activeForCancel.id)!.status, NoticeStatus.ended);
  });

  test('mandatory is derived from behavior by constructor and copyWith', () {
    final dismissible = _platformNotice(behavior: NoticeBehavior.dismissible, mandatory: true);
    final confirmation = dismissible.copyWith(
      behavior: NoticeBehavior.confirmation,
      mandatory: false,
    );

    expect(dismissible.mandatory, isFalse);
    expect(confirmation.mandatory, isTrue);
  });

  test('recurrence rejects invalid and irrelevant configuration fields', () {
    final repository = _repository();
    expect(
      () => repository.create(_draft(recurrence: NoticeRecurrence.interval, intervalDays: 0)),
      throwsArgumentError,
    );
    expect(
      () => repository.create(_draft(recurrence: NoticeRecurrence.weekly)),
      throwsArgumentError,
    );
    expect(
      () => repository.create(_draft(recurrence: NoticeRecurrence.weekly, weeklyDays: [8])),
      throwsArgumentError,
    );
    expect(
      () => repository.create(_draft(recurrence: NoticeRecurrence.monthly, dayOfMonth: 0)),
      throwsArgumentError,
    );
    expect(
      () => repository.create(_draft(recurrence: NoticeRecurrence.daily, intervalDays: 2)),
      throwsArgumentError,
    );
  });
  test('notice labels preserve Portuguese accents', () {
    expect(NoticeAudience.institution.label, 'Instituição');
    expect(NoticeBehavior.confirmation.label, 'Confirmação obrigatória');
    expect(NoticeRecurrence.oneTime.label, 'Única');
    expect(NoticeRecurrence.daily.label, 'Diária');
    expect(
      recurrenceSummaryLabel(recurrence: NoticeRecurrence.daily, until: DateTime.utc(2026, 8, 4)),
      'diária até 04/08/2026',
    );
  });
}

FakeNoticeRepository _repository() {
  final now = DateTime.utc(2026, 8, 3, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  return FakeNoticeRepository(store: store, now: () => now);
}

FakeNoticeRepository _repositoryWithClock(DateTime Function() now) {
  final activities = SuperadminActivityController(now: now);
  final store = SuperadminPrototypeStore(activityController: activities, now: now);
  return FakeNoticeRepository(store: store, now: now);
}

PlatformNotice _publishWithEnd(FakeNoticeRepository repository, DateTime endsAt) =>
    repository.publish(repository.create(_draft(endsAt: endsAt)).id);

NoticeDraft _draft({
  NoticeRecurrence recurrence = NoticeRecurrence.oneTime,
  int? intervalDays,
  List<int> weeklyDays = const [],
  int? dayOfMonth,
  DateTime? endsAt,
  DateTime? recurrenceUntil,
}) => NoticeDraft(
  title: 'Janela local',
  message: 'Mensagem fict?cia.',
  priority: NoticePriority.important,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.confirmation,
  recurrence: recurrence,
  intervalDays: intervalDays,
  weeklyDays: weeklyDays,
  dayOfMonth: dayOfMonth,
  endsAt: endsAt,
  recurrenceUntil: recurrenceUntil,
);

PlatformNotice _platformNotice({required NoticeBehavior behavior, required bool mandatory}) =>
    PlatformNotice(
      id: 'notice-direct',
      title: 'Janela local',
      message: 'Mensagem fict?cia.',
      priority: NoticePriority.important,
      status: NoticeStatus.draft,
      startsAt: DateTime.utc(2026, 8, 3, 12),
      endsAt: null,
      audience: NoticeAudience.everyone,
      audienceLabel: 'Todos',
      behavior: behavior,
      mandatory: mandatory,
      targetDevice: NoticeTargetDevice.all,
      reach: 1,
    );
