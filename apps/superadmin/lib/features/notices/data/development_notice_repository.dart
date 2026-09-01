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
  _fixture(
    id: 'notice-spring-break',
    title: 'Recesso escolar de primavera',
    message: 'As instituições funcionarão em horário especial durante o recesso de primavera.',
    type: CommunicationType.notice,
    priority: NoticePriority.important,
    status: NoticeStatus.scheduled,
    startsAt: now.add(const Duration(days: 5)),
    audience: NoticeAudience.everyone,
    audienceLabel: 'Famílias e profissionais',
    reach: 2380,
  ),
  _fixture(
    id: 'content-report-card',
    title: 'Boletim do segundo bimestre disponível',
    message:
        'Os boletins estão disponíveis para consulta das famílias no perfil de cada estudante.',
    type: CommunicationType.content,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(hours: 4)),
    audience: NoticeAudience.institution,
    audienceLabel: 'Colégio Viver',
    reach: 1184,
  ),
  _fixture(
    id: 'highlight-environment-week',
    title: 'Semana do Meio Ambiente',
    message:
        'Conheça os projetos de sustentabilidade realizados pelas turmas ao longo desta semana.',
    type: CommunicationType.highlight,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(hours: 12)),
    audience: NoticeAudience.unit,
    audienceLabel: 'Unidade Centro',
    reach: 764,
  ),
  _fixture(
    id: 'for-you-study-routine',
    title: 'Dicas para uma rotina de estudos',
    message:
        'Organize pausas, materiais e horários para construir uma rotina de estudos sustentável.',
    type: CommunicationType.forYou,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 2)),
    audience: NoticeAudience.group,
    audienceLabel: 'Turmas do Ensino Fundamental II',
    reach: 486,
  ),
  _fixture(
    id: 'notice-family-meeting',
    title: 'Reunião de responsáveis',
    message: 'A reunião do trimestre acontecerá na próxima quinta-feira, com horários por turma.',
    type: CommunicationType.notice,
    priority: NoticePriority.important,
    status: NoticeStatus.scheduled,
    startsAt: now.add(const Duration(days: 8)),
    audience: NoticeAudience.group,
    audienceLabel: 'Educação Infantil',
    reach: 312,
  ),
  _fixture(
    id: 'content-lunch-menu',
    title: 'Cardápio de setembro',
    message: 'Confira as refeições planejadas pela equipe de nutrição para o próximo mês letivo.',
    type: CommunicationType.content,
    priority: NoticePriority.routine,
    status: NoticeStatus.scheduled,
    startsAt: now.add(const Duration(days: 3)),
    audience: NoticeAudience.institution,
    audienceLabel: 'Escola Horizonte',
    reach: 893,
  ),
  _fixture(
    id: 'highlight-science-fair',
    title: 'Projetos da Feira de Ciências',
    message:
        'Veja uma seleção dos experimentos apresentados pelos estudantes à comunidade escolar.',
    type: CommunicationType.highlight,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 4)),
    audience: NoticeAudience.unit,
    audienceLabel: 'Unidade Jardins',
    reach: 651,
  ),
  _fixture(
    id: 'for-you-adaptation',
    title: 'Acolhimento no período de adaptação',
    message:
        'Orientações práticas ajudam a família e a escola a atravessarem a adaptação com segurança.',
    type: CommunicationType.forYou,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 5)),
    audience: NoticeAudience.role,
    audienceLabel: 'Responsáveis por crianças novas',
    reach: 274,
  ),
  _fixture(
    id: 'notice-sports-festival',
    title: 'Festival esportivo entre turmas',
    message:
        'As equipes participarão de atividades cooperativas no ginásio durante a manhã de sábado.',
    type: CommunicationType.notice,
    priority: NoticePriority.routine,
    status: NoticeStatus.draft,
    startsAt: now.add(const Duration(days: 12)),
    audience: NoticeAudience.group,
    audienceLabel: 'Ensino Médio',
    reach: 428,
  ),
  _fixture(
    id: 'content-digital-safety',
    title: 'Segurança digital em família',
    message: 'Um material curto reúne acordos de uso e cuidados importantes para a vida conectada.',
    type: CommunicationType.content,
    priority: NoticePriority.important,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 6)),
    audience: NoticeAudience.everyone,
    audienceLabel: 'Todas as instituições',
    reach: 1956,
  ),
  _fixture(
    id: 'highlight-music-recital',
    title: 'Recital das oficinas de música',
    message:
        'Confira os melhores momentos das apresentações preparadas pelos estudantes neste semestre.',
    type: CommunicationType.highlight,
    priority: NoticePriority.routine,
    status: NoticeStatus.ended,
    startsAt: now.subtract(const Duration(days: 8)),
    audience: NoticeAudience.institution,
    audienceLabel: 'Colégio Viver',
    reach: 821,
    validity: const Duration(days: 7),
  ),
  _fixture(
    id: 'for-you-reading-habit',
    title: 'Como fortalecer o hábito de leitura',
    message:
        'Pequenas escolhas no cotidiano ajudam crianças e adolescentes a se aproximarem dos livros.',
    type: CommunicationType.forYou,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 9)),
    audience: NoticeAudience.role,
    audienceLabel: 'Responsáveis do Ensino Fundamental',
    reach: 703,
  ),
  _fixture(
    id: 'notice-water-interruption',
    title: 'Manutenção no abastecimento de água',
    message: 'A Unidade Jardins terá atividades encerradas mais cedo durante o serviço programado.',
    type: CommunicationType.notice,
    priority: NoticePriority.urgent,
    status: NoticeStatus.ended,
    startsAt: now.subtract(const Duration(days: 11)),
    audience: NoticeAudience.unit,
    audienceLabel: 'Unidade Jardins',
    reach: 406,
    validity: const Duration(days: 10),
  ),
  _fixture(
    id: 'content-vaccination-guidance',
    title: 'Orientações para atualização vacinal',
    message:
        'A equipe de saúde reuniu informações sobre documentos, prazos e acompanhamento das famílias.',
    type: CommunicationType.content,
    priority: NoticePriority.important,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 13)),
    audience: NoticeAudience.role,
    audienceLabel: 'Responsáveis da Educação Infantil',
    reach: 537,
  ),
  _fixture(
    id: 'highlight-art-exhibition',
    title: 'Exposição de artes aberta às famílias',
    message: 'Produções das turmas ocupam os corredores da Unidade Centro até o fim do mês.',
    type: CommunicationType.highlight,
    priority: NoticePriority.routine,
    status: NoticeStatus.active,
    startsAt: now.subtract(const Duration(days: 15)),
    audience: NoticeAudience.unit,
    audienceLabel: 'Unidade Centro',
    reach: 612,
  ),
  _fixture(
    id: 'for-you-emotional-listening',
    title: 'Escuta emocional depois da escola',
    message:
        'Perguntas abertas e atenção sem pressa favorecem conversas significativas ao fim do dia.',
    type: CommunicationType.forYou,
    priority: NoticePriority.routine,
    status: NoticeStatus.paused,
    startsAt: now.subtract(const Duration(days: 18)),
    audience: NoticeAudience.everyone,
    audienceLabel: 'Famílias da comunidade Coelo',
    reach: 1468,
  ),
];

PlatformNotice _fixture({
  required String id,
  required String title,
  required String message,
  required CommunicationType type,
  required NoticePriority priority,
  required NoticeStatus status,
  required DateTime startsAt,
  required NoticeAudience audience,
  required String audienceLabel,
  required int reach,
  Duration validity = const Duration(days: 30),
}) => PlatformNotice(
  type: type,
  id: id,
  title: title,
  message: message,
  priority: priority,
  status: status,
  startsAt: startsAt,
  endsAt: startsAt.add(validity),
  audience: audience,
  audienceLabel: audienceLabel,
  behavior: NoticeBehavior.dismissible,
  targetDevice: NoticeTargetDevice.all,
  reach: reach,
  deliveredCount: status == NoticeStatus.scheduled || status == NoticeStatus.draft ? 0 : reach,
  viewedCount: status == NoticeStatus.scheduled || status == NoticeStatus.draft
      ? 0
      : (reach * 0.72).round(),
  acceptedCount: 0,
);

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
