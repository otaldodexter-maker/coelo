import '../../../app/activity/superadmin_activity.dart';
import '../../../app/prototype/superadmin_prototype_store.dart';
import '../domain/platform_notice.dart';

/// Session-only fixtures. Nothing here sends, persists, or identifies a recipient.
final class FakeNoticeRepository {
  FakeNoticeRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _items = List.of(_fixtures(now ?? DateTime.now));

  final SuperadminPrototypeStore store;
  final DateTime Function() _now;
  final List<PlatformNotice> _items;
  var _nextId = 3;

  List<PlatformNotice> list({
    String search = '',
    NoticeStatus? status,
    NoticeTargetDevice? target,
  }) {
    _closeExpiredNotices();
    final query = search.trim().toLowerCase();
    return _items
        .where((notice) {
          final matchesText =
              query.isEmpty ||
              '${notice.title} ${notice.audienceLabel} ${notice.message}'.toLowerCase().contains(
                query,
              );
          final matchesStatus = status == null || notice.status == status;
          final matchesTarget =
              target == null ||
              notice.targetDevice == NoticeTargetDevice.all ||
              notice.targetDevice == target;
          return matchesText && matchesStatus && matchesTarget;
        })
        .toList(growable: false);
  }

  PlatformNotice? find(String id) {
    for (final notice in _items) {
      if (notice.id == id) return notice;
    }
    return null;
  }

  PlatformNotice create(NoticeDraft draft) {
    final now = _now();
    final notice = _fromDraft(
      'notice-${_nextId++}',
      draft,
      status: NoticeStatus.draft,
      startsAt: draft.startsAt ?? now,
    );
    _items.insert(0, notice);
    _record(notice, 'criou');
    return notice;
  }

  PlatformNotice update(String id, NoticeDraft draft) {
    final old = _required(id);
    if (!old.canEdit) {
      throw StateError('Apenas rascunhos, agendados ou pausados podem ser editados.');
    }
    final startedAt = draft.startsAt ?? old.startsAt;
    final notice = _fromDraft(id, draft, status: old.status, startsAt: startedAt, reach: old.reach);
    _replace(notice);
    _record(notice, 'atualizou');
    return notice;
  }

  PlatformNotice duplicate(String id) {
    final now = _now();
    final original = _required(id);
    final duplicate = original.copyWith(
      id: 'notice-${_nextId++}',
      status: NoticeStatus.draft,
      title: '${original.title} (cópia)',
      startsAt: now,
      clearEndsAt: true,
      clearRecurrenceUntil: true,
      deliveredCount: 0,
      viewedCount: 0,
      acceptedCount: 0,
    );
    _items.insert(0, duplicate);
    _record(duplicate, 'duplicou');
    return duplicate;
  }

  PlatformNotice publish(String id) {
    final old = _required(id);
    if (!old.canEdit && old.status != NoticeStatus.paused) {
      throw StateError('Este aviso não pode ser publicado novamente.');
    }
    final now = _now();
    final start = old.startsAt;
    final status = start.isAfter(now) ? NoticeStatus.scheduled : NoticeStatus.active;
    final published = old.copyWith(status: status, deliveredCount: old.reach);
    _replace(published);
    _record(published, 'publicou');
    return published;
  }

  PlatformNotice pause(String id) {
    final old = _required(id);
    if (old.status != NoticeStatus.active) {
      throw StateError('Apenas avisos ativos podem ser pausados.');
    }
    final paused = old.copyWith(status: NoticeStatus.paused);
    _replace(paused);
    _record(paused, 'pausou');
    return paused;
  }

  PlatformNotice resume(String id) {
    final old = _required(id);
    if (old.status != NoticeStatus.paused) {
      throw StateError('Apenas avisos pausados podem ser reativados.');
    }
    final now = _now();
    final status = old.startsAt.isAfter(now) ? NoticeStatus.scheduled : NoticeStatus.active;
    final resumed = old.copyWith(status: status);
    _replace(resumed);
    _record(resumed, 'reativou');
    return resumed;
  }

  PlatformNotice cancel(String id) {
    final old = _required(id);
    if (!const {
      NoticeStatus.draft,
      NoticeStatus.scheduled,
      NoticeStatus.active,
      NoticeStatus.paused,
    }.contains(old.status)) {
      throw StateError('Este aviso não pode ser inativado.');
    }
    final notice = old.copyWith(status: NoticeStatus.cancelled);
    _replace(notice);
    _record(notice, 'inativou');
    return notice;
  }

  PlatformNotice accept(String id, {bool checkboxChecked = false}) {
    final old = _required(id);
    if (old.status != NoticeStatus.active || !old.requiresAcceptance) {
      throw StateError('Este aviso não requer aceite.');
    }
    if (old.behavior == NoticeBehavior.checkboxConfirmation && !checkboxChecked) {
      throw StateError('Confirme a ciência antes de aceitar.');
    }
    final notice = old.copyWith(acceptedCount: old.acceptedCount + 1);
    _replace(notice);
    _record(notice, 'aceitou');
    return notice;
  }

  PlatformNotice _fromDraft(
    String id,
    NoticeDraft draft, {
    required NoticeStatus status,
    DateTime? startsAt,
    int reach = 42,
  }) {
    _validateRecurrence(draft);
    return PlatformNotice(
      id: id,
      title: draft.title.trim(),
      message: draft.message.trim(),
      priority: draft.priority,
      status: status,
      startsAt: startsAt ?? _now(),
      endsAt: draft.endsAt,
      audience: draft.audience,
      audienceLabel: draft.audienceLabel.trim(),
      behavior: draft.behavior,
      mandatory: draft.behavior != NoticeBehavior.dismissible,
      reach: reach,
      targetDevice: draft.targetDevice,
      contentFormat: draft.contentFormat,
      audienceRoleLabel: draft.audienceRoleLabel?.trim(),
      backgroundColorValue: draft.backgroundColorValue,
      textColorValue: draft.textColorValue,
      recurrence: draft.recurrence,
      intervalDays: draft.intervalDays,
      weeklyDays: List.of(draft.weeklyDays),
      dayOfMonth: draft.dayOfMonth,
      recurrenceUntil: draft.recurrenceUntil,
      imageOrientation: draft.imageOrientation,
      showImagePlaceholder: draft.showImagePlaceholder,
      backgroundTone: draft.backgroundTone,
      textTone: draft.textTone,
      buttonLabel: draft.buttonLabel.trim().isEmpty ? 'Confirmar' : draft.buttonLabel.trim(),
      linkLabel: draft.linkLabel?.trim(),
    );
  }

  void _validateRecurrence(NoticeDraft draft) {
    final valid = switch (draft.recurrence) {
      NoticeRecurrence.oneTime || NoticeRecurrence.daily =>
        draft.intervalDays == null && draft.weeklyDays.isEmpty && draft.dayOfMonth == null,
      NoticeRecurrence.weekly =>
        draft.intervalDays == null &&
            draft.weeklyDays.isNotEmpty &&
            draft.weeklyDays.every((day) => day >= 1 && day <= 7) &&
            draft.dayOfMonth == null,
      NoticeRecurrence.monthly =>
        draft.intervalDays == null &&
            draft.weeklyDays.isEmpty &&
            draft.dayOfMonth != null &&
            draft.dayOfMonth! >= 1 &&
            draft.dayOfMonth! <= 31,
      NoticeRecurrence.interval =>
        draft.intervalDays != null &&
            draft.intervalDays! > 0 &&
            draft.weeklyDays.isEmpty &&
            draft.dayOfMonth == null,
    };
    if (!valid) throw ArgumentError('Configuração de recorrência inválida.');
  }

  void _closeExpiredNotices() {
    final now = _now();
    for (var index = 0; index < _items.length; index++) {
      final notice = _items[index];
      final endedByDate = notice.endsAt != null && !notice.endsAt!.isAfter(now);
      if ((notice.status == NoticeStatus.active ||
              notice.status == NoticeStatus.scheduled ||
              notice.status == NoticeStatus.paused) &&
          endedByDate &&
          notice.status != NoticeStatus.ended) {
        final updated = notice.copyWith(status: NoticeStatus.ended);
        _items[index] = updated;
        _record(updated, 'encerrou');
      }
    }
  }

  PlatformNotice _required(String id) {
    _closeExpiredNotices();
    return find(id) ?? (throw StateError('Aviso não encontrado.'));
  }

  void _replace(PlatformNotice notice) =>
      _items[_items.indexWhere((item) => item.id == notice.id)] = notice;

  void _record(PlatformNotice notice, String action) {
    store.recordActivity(
      kind: SuperadminActivityKind.announcement,
      subject: 'Avisos',
      summary: 'Aviso ${notice.status.label.toLowerCase()}: $action.',
    );
    store.recordAuditEvent(
      module: 'Avisos',
      action: action,
      objectType: 'aviso',
      objectId: notice.id,
      after: {
        'status': notice.status.name,
        'priority': notice.priority.name,
        'audience': notice.audience.name,
        'behavior': notice.behavior.name,
      },
    );
  }
}

List<PlatformNotice> _fixtures(DateTime Function() now) {
  final instant = now();
  return [
    PlatformNotice(
      id: 'notice-1',
      title: 'Atualização do preview',
      message: 'Conheça as superfícies operacionais locais.',
      priority: NoticePriority.important,
      status: NoticeStatus.active,
      startsAt: instant,
      endsAt: instant.add(const Duration(days: 4)),
      audience: NoticeAudience.coeloTeam,
      audienceLabel: 'Equipe Coelo',
      targetDevice: NoticeTargetDevice.all,
      behavior: NoticeBehavior.confirmation,
      mandatory: true,
      reach: 24,
      deliveredCount: 24,
      viewedCount: 18,
      acceptedCount: 12,
      recurrence: NoticeRecurrence.daily,
      recurrenceUntil: instant.add(const Duration(days: 4)),
      imageOrientation: NoticeImageOrientation.horizontal,
      showImagePlaceholder: true,
      backgroundTone: NoticeVisualTone.brand,
      textTone: NoticeVisualTone.light,
      linkLabel: 'Ver detalhes',
    ),
    PlatformNotice(
      id: 'notice-2',
      title: 'Manutenção programada',
      message: 'Uma manutenção fictícia será exibida no preview.',
      priority: NoticePriority.routine,
      status: NoticeStatus.draft,
      startsAt: instant,
      endsAt: null,
      audience: NoticeAudience.institution,
      audienceLabel: 'Instituição Aurora',
      targetDevice: NoticeTargetDevice.web,
      behavior: NoticeBehavior.dismissible,
      mandatory: false,
      reach: 42,
      recurrence: NoticeRecurrence.oneTime,
      imageOrientation: NoticeImageOrientation.vertical,
      showImagePlaceholder: false,
      backgroundTone: NoticeVisualTone.dark,
      textTone: NoticeVisualTone.light,
      linkLabel: null,
    ),
  ];
}
