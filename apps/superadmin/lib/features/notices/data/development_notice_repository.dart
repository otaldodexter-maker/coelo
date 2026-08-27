import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';

/// In-memory data used only by the explicit `/dev` composition.
final class DevelopmentNoticeRepository implements NoticeRepository {
  DevelopmentNoticeRepository({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _items.addAll(_seed(_now()));
  }

  final DateTime Function() _now;
  final List<PlatformNotice> _items = [];
  var _nextId = 100;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) async {
    final search = query.search?.trim().toLowerCase();
    final filtered =
        _items.where((notice) {
          if (search != null &&
              search.isNotEmpty &&
              !notice.title.toLowerCase().contains(search) &&
              !notice.message.toLowerCase().contains(search) &&
              !notice.audienceLabel.toLowerCase().contains(search)) {
            return false;
          }
          if (query.types.isNotEmpty && !query.types.contains(notice.type)) return false;
          if (query.statuses.isNotEmpty && !query.statuses.contains(notice.status)) return false;
          if (query.priorities.isNotEmpty && !query.priorities.contains(notice.priority)) {
            return false;
          }
          if (query.cursorOccurredAt case final cursor?) {
            final byDate = notice.startsAt.compareTo(cursor);
            if (byDate > 0 || (byDate == 0 && notice.id.compareTo(query.cursorId ?? '') >= 0)) {
              return false;
            }
          }
          return true;
        }).toList()..sort((a, b) {
          final byDate = b.startsAt.compareTo(a.startsAt);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
    final page = filtered.take(query.pageSize).toList(growable: false);
    final hasMore = filtered.length > page.length;
    return NoticePage(
      items: page,
      nextCursorOccurredAt: hasMore ? page.last.startsAt : null,
      nextCursorId: hasMore ? page.last.id : null,
    );
  }

  @override
  Future<NoticeAudienceOptionsPage> fetchAudienceOptions({
    required NoticeAudienceDimension dimension,
    String? search,
    List<String> parentIds = const [],
    String? cursorLabel,
    String? cursorId,
    int pageSize = 30,
  }) async {
    final options = switch (dimension) {
      NoticeAudienceDimension.institution => const [
        NoticeAudienceOption(id: 'inst-viver', label: 'Colégio Viver'),
        NoticeAudienceOption(id: 'inst-horizonte', label: 'Escola Horizonte'),
      ],
      NoticeAudienceDimension.unit => const [
        NoticeAudienceOption(id: 'unit-centro', label: 'Unidade Centro'),
        NoticeAudienceOption(id: 'unit-jardins', label: 'Unidade Jardins'),
      ],
      NoticeAudienceDimension.group => const [
        NoticeAudienceOption(id: 'group-infantil-4', label: 'Infantil 4'),
        NoticeAudienceOption(id: 'group-infantil-5', label: 'Infantil 5'),
      ],
      _ => const <NoticeAudienceOption>[],
    };
    final normalized = search?.trim().toLowerCase();
    final filtered = options
        .where(
          (option) =>
              normalized == null ||
              normalized.isEmpty ||
              option.label.toLowerCase().contains(normalized),
        )
        .take(pageSize)
        .toList(growable: false);
    return NoticeAudienceOptionsPage(items: filtered, nextCursorLabel: null, nextCursorId: null);
  }

  @override
  Future<PlatformNotice> getById(String noticeId) async => _find(noticeId);

  @override
  Future<PlatformNotice> saveDraft(
    NoticeDraft draft, {
    required String requestId,
    String? noticeId,
    int? expectedVersion,
  }) async {
    if (draft.title.trim().isEmpty || draft.message.trim().isEmpty) {
      throw const NoticeValidationException();
    }
    final current = noticeId == null ? null : _find(noticeId);
    if (current != null &&
        expectedVersion != null &&
        current.managementVersion != expectedVersion) {
      throw const NoticeConflictException();
    }
    final notice = _fromDraft(
      draft,
      id: noticeId ?? 'notice-dev-${_nextId++}',
      status: current?.status ?? NoticeStatus.draft,
      version: (current?.managementVersion ?? -1) + 1,
    );
    if (current == null) {
      _items.add(notice);
    } else {
      _replace(notice);
    }
    return notice;
  }

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) async {
    final current = _find(notice.id);
    _checkVersion(current, expectedVersion);
    final updated = current.copyWith(
      status: current.startsAt.isAfter(_now()) ? NoticeStatus.scheduled : NoticeStatus.active,
      managementVersion: current.managementVersion + 1,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) async {
    final current = _find(noticeId);
    _checkVersion(current, expectedVersion);
    final updated = current.copyWith(
      status: status,
      managementVersion: current.managementVersion + 1,
    );
    _replace(updated);
    return updated;
  }

  PlatformNotice _fromDraft(
    NoticeDraft draft, {
    required String id,
    required NoticeStatus status,
    required int version,
  }) => PlatformNotice(
    type: draft.type,
    id: id,
    title: draft.title,
    message: draft.message,
    priority: draft.priority,
    status: status,
    startsAt: draft.startsAt ?? _now(),
    endsAt: draft.endsAt,
    audience: draft.audience,
    audienceLabel: draft.audienceLabel,
    behavior: draft.behavior,
    targetDevice: draft.targetDevice,
    reach: 0,
    contentFormat: draft.contentFormat,
    backgroundColorValue: draft.backgroundColorValue,
    textColorValue: draft.textColorValue,
    buttonColorValue: draft.buttonColorValue,
    popupSize: draft.popupSize,
    hasOuterInset: draft.hasOuterInset,
    audienceSelection: draft.audienceSelection,
    recurrence: draft.recurrence,
    intervalDays: draft.intervalDays,
    weeklyDays: draft.weeklyDays,
    dayOfMonth: draft.dayOfMonth,
    recurrenceUntil: draft.recurrenceUntil,
    imageOrientation: draft.imageOrientation,
    backgroundTone: draft.backgroundTone,
    textTone: draft.textTone,
    buttonLabel: draft.buttonLabel,
    linkLabel: draft.linkLabel,
    managementVersion: version,
  );

  PlatformNotice _find(String id) {
    for (final notice in _items) {
      if (notice.id == id) return notice;
    }
    throw const NoticeNotFoundException();
  }

  void _replace(PlatformNotice notice) {
    final index = _items.indexWhere((item) => item.id == notice.id);
    if (index < 0) throw const NoticeNotFoundException();
    _items[index] = notice;
  }

  void _checkVersion(PlatformNotice notice, int expectedVersion) {
    if (notice.managementVersion != expectedVersion) throw const NoticeConflictException();
  }
}

List<PlatformNotice> _seed(DateTime now) => [
  _content(
    id: 'content-welcome',
    title: 'Volta às aulas com acolhimento',
    message:
        'Veja como preparar uma retomada tranquila, com escuta ativa, rotina previsível e parceria entre escola e família.',
    startsAt: now.subtract(const Duration(hours: 2)),
    audienceLabel: 'Todas as instituições',
    delivered: 1842,
    viewed: 1287,
  ),
  _content(
    id: 'content-reading',
    title: 'Leitura compartilhada em família',
    message:
        'Cinco ideias simples para transformar quinze minutos do dia em um encontro afetivo com histórias e imaginação.',
    startsAt: now.subtract(const Duration(days: 1)),
    audienceLabel: 'Famílias da Educação Infantil',
    delivered: 926,
    viewed: 711,
  ),
  _content(
    id: 'content-sleep',
    title: 'Sono infantil e rotina saudável',
    message:
        'Um guia prático sobre sinais de cansaço, preparação do ambiente e horários consistentes para cada faixa etária.',
    startsAt: now.subtract(const Duration(days: 3)),
    audienceLabel: 'Responsáveis por crianças de 2 a 6 anos',
    delivered: 744,
    viewed: 583,
  ),
  PlatformNotice(
    id: 'notice-maintenance',
    title: 'Manutenção programada',
    message: 'O Coelo ficará indisponível no sábado, das 2h às 3h, para manutenção preventiva.',
    priority: NoticePriority.important,
    status: NoticeStatus.scheduled,
    startsAt: now.add(const Duration(days: 2)),
    endsAt: now.add(const Duration(days: 3)),
    audience: NoticeAudience.everyone,
    audienceLabel: 'Toda a plataforma',
    behavior: NoticeBehavior.confirmation,
    targetDevice: NoticeTargetDevice.all,
    reach: 2400,
    deliveredCount: 0,
    viewedCount: 0,
    acceptedCount: 0,
  ),
];

PlatformNotice _content({
  required String id,
  required String title,
  required String message,
  required DateTime startsAt,
  required String audienceLabel,
  required int delivered,
  required int viewed,
}) => PlatformNotice(
  type: CommunicationType.content,
  id: id,
  title: title,
  message: message,
  priority: NoticePriority.routine,
  status: NoticeStatus.active,
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(days: 30)),
  audience: NoticeAudience.role,
  audienceLabel: audienceLabel,
  behavior: NoticeBehavior.dismissible,
  targetDevice: NoticeTargetDevice.all,
  reach: delivered,
  backgroundTone: NoticeVisualTone.light,
  textTone: NoticeVisualTone.light,
  linkLabel: 'Ler conteúdo',
  deliveredCount: delivered,
  viewedCount: viewed,
  acceptedCount: 0,
);
