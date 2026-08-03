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

  List<PlatformNotice> list({String search = ''}) {
    final query = search.trim().toLowerCase();
    return _items
        .where(
          (notice) =>
              query.isEmpty ||
              '${notice.title} ${notice.audienceLabel}'.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  PlatformNotice? find(String id) {
    for (final notice in _items) {
      if (notice.id == id) return notice;
    }
    return null;
  }

  PlatformNotice create(NoticeDraft draft) {
    final notice = _fromDraft('notice-${_nextId++}', draft, status: NoticeStatus.draft);
    _items.insert(0, notice);
    return notice;
  }

  PlatformNotice update(String id, NoticeDraft draft) {
    final old = _required(id);
    if (!old.canEdit) throw StateError('Apenas rascunhos ou avisos agendados podem ser editados.');
    final notice = _fromDraft(
      id,
      draft,
      status: old.status,
      startsAt: old.startsAt,
      reach: old.reach,
    );
    _replace(notice);
    return notice;
  }

  PlatformNotice duplicate(String id) {
    final original = _required(id);
    final copy = original.copyWith(
      status: NoticeStatus.draft,
      title: '${original.title} (cópia)',
      acceptedCount: 0,
      viewedCount: 0,
      deliveredCount: 0,
    );
    final duplicate = PlatformNotice(
      id: 'notice-${_nextId++}',
      title: copy.title,
      message: copy.message,
      priority: copy.priority,
      status: copy.status,
      startsAt: _now(),
      endsAt: copy.endsAt,
      audience: copy.audience,
      audienceLabel: copy.audienceLabel,
      behavior: copy.behavior,
      mandatory: copy.mandatory,
      reach: copy.reach,
      buttonLabel: copy.buttonLabel,
      linkLabel: copy.linkLabel,
    );
    _items.insert(0, duplicate);
    return duplicate;
  }

  PlatformNotice publish(String id) {
    final old = _required(id);
    if (!old.canEdit) throw StateError('Este aviso não pode ser publicado novamente.');
    final status = old.startsAt.isAfter(_now()) ? NoticeStatus.scheduled : NoticeStatus.active;
    final notice = old.copyWith(status: status, deliveredCount: old.reach);
    _replace(notice);
    _record(notice, 'publicou');
    return notice;
  }

  PlatformNotice cancel(String id) {
    final old = _required(id);
    if (old.status != NoticeStatus.active && old.status != NoticeStatus.scheduled) {
      throw StateError('Apenas avisos ativos ou agendados podem ser cancelados.');
    }
    final notice = old.copyWith(status: NoticeStatus.cancelled);
    _replace(notice);
    _record(notice, 'cancelou');
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
  }) => PlatformNotice(
    id: id,
    title: draft.title.trim(),
    message: draft.message.trim(),
    priority: draft.priority,
    status: status,
    startsAt: startsAt ?? _now(),
    endsAt: null,
    audience: draft.audience,
    audienceLabel: draft.audienceLabel.trim(),
    behavior: draft.behavior,
    mandatory: draft.mandatory,
    reach: reach,
    buttonLabel: draft.buttonLabel.trim().isEmpty ? 'Confirmar' : draft.buttonLabel.trim(),
    linkLabel: draft.linkLabel?.trim(),
  );

  PlatformNotice _required(String id) => find(id) ?? (throw StateError('Aviso não encontrado.'));
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
      endsAt: null,
      audience: NoticeAudience.coeloTeam,
      audienceLabel: 'Equipe Coelo',
      behavior: NoticeBehavior.confirmation,
      mandatory: true,
      reach: 24,
      deliveredCount: 24,
      viewedCount: 18,
      acceptedCount: 12,
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
      behavior: NoticeBehavior.dismissible,
      mandatory: false,
      reach: 42,
    ),
  ];
}
