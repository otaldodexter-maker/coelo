import 'package:flutter/foundation.dart';

import '../domain/agenda_models.dart';

final class AgendaPrototypeStore extends ChangeNotifier {
  AgendaPrototypeStore.seeded({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _contexts = _seedContexts();
    _items = _seedItems();
    _requests = _seedRequests();
  }
  final DateTime Function() _clock;
  late List<AgendaItem> _items;
  late List<AgendaContext> _contexts;
  late List<GuardianBirthdayRequest> _requests;
  DateTime get referenceDate => DateTime(2026, 8, 3);
  List<AgendaItem> get items => List.unmodifiable(_items);
  List<AgendaContext> get contexts => List.unmodifiable(_contexts);
  List<GuardianBirthdayRequest> get requests => List.unmodifiable(_requests);
  AgendaItem? itemById(String id) => _firstOrNull(_items.where((e) => e.id == id));
  GuardianBirthdayRequest? requestById(String id) =>
      _firstOrNull(_requests.where((e) => e.id == id));

  void upsertItem(AgendaItem item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index < 0) {
      _items = [..._items, item];
    } else {
      _items = [..._items]..[index] = item;
    }
    notifyListeners();
  }

  void upsertRequest(GuardianBirthdayRequest request) {
    final index = _requests.indexWhere((e) => e.id == request.id);
    if (index < 0) {
      _requests = [..._requests, request];
    } else {
      _requests = [..._requests]..[index] = request;
    }
    notifyListeners();
  }

  List<AgendaItem> itemsForInstitution(String id) =>
      List.unmodifiable(_items.where((e) => e.audience.institutionId == id));
  List<AgendaItem> itemsForContext(String id) {
    final c = _context(id);
    if (c == null) return const [];
    final ancestors = _ancestorIds(c);
    return List.unmodifiable(
      _items.where(
        (e) =>
            e.audience.institutionId == c.institutionId &&
            e.audience.includesContext(contextId: id, ancestors: ancestors),
      ),
    );
  }

  List<AgendaOccurrence> occurrencesBetween(DateTime start, DateTime end) {
    final result = <AgendaOccurrence>[];
    for (final item in _items) {
      final recurrence = item.recurrence;
      if (recurrence == null) {
        if (item.startsAt.isBefore(end) && item.endsAt.isAfter(start)) {
          result.add(AgendaOccurrence(item: item, startsAt: item.startsAt, endsAt: item.endsAt));
        }
        continue;
      }
      var occurrence = item.startsAt;
      final duration = item.duration;
      while (!occurrence.isAfter(recurrence.until) && occurrence.isBefore(end)) {
        if (!occurrence.isBefore(start.subtract(duration)) && !recurrence.isException(occurrence)) {
          result.add(
            AgendaOccurrence(item: item, startsAt: occurrence, endsAt: occurrence.add(duration)),
          );
        }
        occurrence = occurrence.add(Duration(days: 7 * recurrence.interval));
      }
    }
    return List.unmodifiable(result..sort(AgendaOccurrence.compareChronologically));
  }

  PermissionResolution resolveCapability(String contextId, AgendaCapability capability) {
    final context = _context(contextId);
    if (context == null) {
      return const PermissionResolution(state: PermissionState.blockedByAncestor);
    }
    final chain = <AgendaContext>[];
    AgendaContext? cursor = context;
    while (cursor != null) {
      chain.insert(0, cursor);
      cursor = cursor.parentId == null ? null : _context(cursor.parentId!);
    }
    AgendaContext? grant;
    for (final node in chain) {
      if (node.restrictedCapabilities.contains(capability)) {
        return PermissionResolution(
          state: node.id == contextId
              ? PermissionState.restrictedHere
              : PermissionState.blockedByAncestor,
          grantedByContextName: grant?.name,
          blockedByContextName: node.name,
        );
      }
      if (node.grantedCapabilities.contains(capability)) {
        grant = node;
      }
    }
    if (grant == null) return const PermissionResolution(state: PermissionState.blockedByAncestor);
    return PermissionResolution(
      state: grant.id == contextId ? PermissionState.allowed : PermissionState.inherited,
      grantedByContextName: grant.name,
    );
  }

  bool setCapabilityRestricted(String contextId, AgendaCapability capability, bool restricted) {
    final index = _contexts.indexWhere((e) => e.id == contextId);
    if (index < 0) return false;
    final context = _contexts[index];
    if (!restricted) {
      final parent = context.parentId;
      if (parent != null && !resolveCapability(parent, capability).isAllowed) return false;
    }
    final restrictions = {...context.restrictedCapabilities};
    restricted ? restrictions.add(capability) : restrictions.remove(capability);
    _contexts = [..._contexts]
      ..[index] = context.copyWith(restrictedCapabilities: Set.unmodifiable(restrictions));
    notifyListeners();
    return true;
  }

  RequestDecisionResult decideRequest({
    required String requestId,
    required String actorContextId,
    required String actorName,
    required bool approve,
    String? reason,
  }) {
    final index = _requests.indexWhere((e) => e.id == requestId);
    if (index < 0) return RequestDecisionResult.notFound;
    final request = _requests[index];
    if (request.decision != null) return RequestDecisionResult.alreadyDecided;
    if (!resolveCapability(
          actorContextId,
          AgendaCapability.approveGuardianBirthdayRequest,
        ).isAllowed ||
        !_isAncestorOrSelf(actorContextId, request.contextId)) {
      return RequestDecisionResult.notAuthorized;
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      return RequestDecisionResult.reasonRequired;
    }
    final decision = GuardianRequestDecision(
      approved: approve,
      actorName: actorName,
      actorContextId: actorContextId,
      decidedAt: _clock(),
      reason: reason?.trim(),
    );
    String? linked;
    if (approve) {
      linked = 'request-draft-${request.id}';
      upsertItem(
        AgendaItem.fixture(
          id: linked,
          title: request.title,
          type: AgendaItemType.birthday,
          audience: AgendaAudience(
            institutionId: request.institutionId,
            personIds: {request.childId},
          ),
          startsAt: request.startsAt,
          endsAt: request.endsAt,
          status: AgendaItemStatus.draft,
          origin: AgendaItemOrigin.guardianRequest,
          description: request.details,
        ),
      );
    }
    _requests = [..._requests]
      ..[index] = request.copyWith(
        status: approve ? GuardianRequestStatus.convertedToDraft : GuardianRequestStatus.rejected,
        decision: decision,
        linkedAgendaItemId: linked,
      );
    notifyListeners();
    return approve
        ? RequestDecisionResult.approvedAndConvertedToDraft
        : RequestDecisionResult.rejected;
  }

  AgendaContext? _context(String id) => _firstOrNull(_contexts.where((e) => e.id == id));
  Set<String> _ancestorIds(AgendaContext context) {
    final result = <String>{};
    var parent = context.parentId;
    while (parent != null) {
      result.add(parent);
      parent = _context(parent)?.parentId;
    }
    return result;
  }

  bool _isAncestorOrSelf(String ancestor, String child) {
    if (ancestor == child) return true;
    var cursor = _context(child)?.parentId;
    while (cursor != null) {
      if (cursor == ancestor) return true;
      cursor = _context(cursor)?.parentId;
    }
    return false;
  }

  static T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  static List<AgendaContext> _seedContexts() => const [
    AgendaContext(
      id: 'inst-horizonte',
      name: 'Centro Horizonte',
      level: AgendaContextLevel.institution,
      institutionId: 'inst-horizonte',
      grantedCapabilities: {
        AgendaCapability.publishAgendaItems,
        AgendaCapability.approveGuardianBirthdayRequest,
      },
    ),
    AgendaContext(
      id: 'unit-cambui',
      name: 'Unidade Cambuí',
      level: AgendaContextLevel.unit,
      institutionId: 'inst-horizonte',
      parentId: 'inst-horizonte',
    ),
    AgendaContext(
      id: 'group-girassol',
      name: 'Turma Girassol',
      level: AgendaContextLevel.group,
      institutionId: 'inst-horizonte',
      parentId: 'unit-cambui',
    ),
    AgendaContext(
      id: 'activity-ballet',
      name: 'Ballet',
      level: AgendaContextLevel.activity,
      institutionId: 'inst-horizonte',
      parentId: 'group-girassol',
    ),
    AgendaContext(
      id: 'inst-aurora',
      name: 'Escola Aurora',
      level: AgendaContextLevel.institution,
      institutionId: 'inst-aurora',
      grantedCapabilities: {AgendaCapability.publishAgendaItems},
    ),
    AgendaContext(
      id: 'unit-lagoa',
      name: 'Unidade Lagoa',
      level: AgendaContextLevel.unit,
      institutionId: 'inst-aurora',
      parentId: 'inst-aurora',
    ),
    AgendaContext(
      id: 'group-estrelas',
      name: 'Turma Estrelas',
      level: AgendaContextLevel.group,
      institutionId: 'inst-aurora',
      parentId: 'unit-lagoa',
    ),
  ];

  static List<AgendaItem> _seedItems() {
    const h = AgendaAudience(institutionId: 'inst-horizonte');
    const u = AgendaAudience(institutionId: 'inst-horizonte', unitIds: {'unit-cambui'});
    const g = AgendaAudience(institutionId: 'inst-horizonte', groupIds: {'group-girassol'});
    const a = AgendaAudience(institutionId: 'inst-horizonte', activityIds: {'activity-ballet'});
    const aurora = AgendaAudience(institutionId: 'inst-aurora');
    AgendaItem item(
      String id,
      String title,
      AgendaItemType type,
      AgendaAudience audience,
      int day,
      int hour,
      int duration, {
      String location = '',
      String description = '',
      AgendaPriority priority = AgendaPriority.normal,
      bool allDay = false,
    }) => AgendaItem.fixture(
      id: id,
      title: title,
      type: type,
      audience: audience,
      startsAt: DateTime(2026, 8, day, hour),
      endsAt: DateTime(2026, 8, day, hour).add(Duration(hours: duration)),
      location: location,
      description: description,
      priority: priority,
      allDay: allDay,
    );
    return [
      item(
        'event-parents',
        'Dia dos Pais',
        AgendaItemType.event,
        h,
        9,
        9,
        4,
        description: 'Celebração da comunidade escolar com atividades para toda a família.',
        priority: AgendaPriority.important,
      ),
      item(
        'event-pajama',
        'Festa do Pijama',
        AgendaItemType.event,
        u,
        7,
        18,
        3,
        description: 'Uma noite especial de convivência, histórias e brincadeiras.',
      ),
      item(
        'event-paint',
        'Pintando o 7',
        AgendaItemType.event,
        g,
        5,
        10,
        2,
        description: 'Vivência artística com cores, texturas e criação coletiva.',
      ),
      item(
        'activity-yellow',
        'Aprendendo a Cor Amarela',
        AgendaItemType.event,
        a,
        5,
        10,
        1,
        description: 'Atividade lúdica para explorar cores no cotidiano da turma.',
      ),
      AgendaItem.fixture(
        id: 'routine-ballet',
        title: 'Ballet',
        type: AgendaItemType.recurringRoutine,
        audience: a,
        startsAt: DateTime(2026, 8, 4, 17),
        endsAt: DateTime(2026, 8, 4, 18),
        description: 'Movimento, musicalidade e expressão corporal em grupo.',
        location: 'Studio Movimento',
        recurrence: AgendaRecurrence.weekly(
          until: DateTime(2026, 8, 25),
          exceptions: {DateTime(2026, 8, 11)},
        ),
      ),
      item(
        'routine-school',
        'Permanência na escola',
        AgendaItemType.recurringRoutine,
        g,
        3,
        8,
        9,
        location: 'Centro Horizonte',
        description: 'Atividades e acompanhamento durante todo o período escolar.',
      ),
      item(
        'routine-swim',
        'Natação',
        AgendaItemType.recurringRoutine,
        g,
        6,
        16,
        1,
        location: 'Clube da Lagoa',
        description: 'Prática orientada com segurança e acompanhamento da turma.',
      ),
      AgendaItem.fixture(
        id: 'birthday-lia',
        title: 'Aniversário da Lia',
        type: AgendaItemType.birthday,
        audience: const AgendaAudience(institutionId: 'inst-horizonte', personIds: {'child-lia'}),
        startsAt: DateTime(2026, 8, 5),
        endsAt: DateTime(2026, 8, 6),
        description: 'Um registro carinhoso para celebrar a data com a comunidade.',
        allDay: true,
      ),
      item(
        'holiday-national',
        'Feriado nacional',
        AgendaItemType.holidayOrBreak,
        h,
        15,
        0,
        24,
        allDay: true,
      ),
      item(
        'holiday-state',
        'Feriado estadual',
        AgendaItemType.holidayOrBreak,
        aurora,
        20,
        0,
        24,
        allDay: true,
      ),
      item(
        'holiday-city',
        'Feriado municipal',
        AgendaItemType.holidayOrBreak,
        u,
        25,
        0,
        24,
        allDay: true,
      ),
      item(
        'deadline-auth',
        'Prazo de autorização',
        AgendaItemType.deadline,
        g,
        5,
        17,
        1,
        priority: AgendaPriority.urgent,
      ),
      item('change-time', 'Alteração de horário', AgendaItemType.operationalChange, u, 5, 9, 1),
      item(
        'reserve-auditorium',
        'Reserva do auditório',
        AgendaItemType.resourceReservation,
        h,
        5,
        10,
        3,
        location: 'Auditório',
      ),
      item('other-menu', 'Cardápio especial', AgendaItemType.other, aurora, 12, 11, 1),
    ];
  }

  static List<GuardianBirthdayRequest> _seedRequests() => [
    GuardianBirthdayRequest(
      id: 'request-pending',
      childId: 'child-lia',
      childName: 'Lia',
      guardianName: 'Ana Martins',
      contextId: 'group-girassol',
      institutionId: 'inst-horizonte',
      title: 'Festa de aniversário da Lia',
      startsAt: DateTime(2026, 8, 21, 15),
      endsAt: DateTime(2026, 8, 21, 16),
      status: GuardianRequestStatus.sent,
      details: 'Bolo simples na sala.',
    ),
    GuardianBirthdayRequest(
      id: 'request-approved',
      childId: 'child-noah',
      childName: 'Noah',
      guardianName: 'Rafael Lima',
      contextId: 'group-estrelas',
      institutionId: 'inst-aurora',
      title: 'Aniversário do Noah',
      startsAt: DateTime(2026, 8, 18, 14),
      endsAt: DateTime(2026, 8, 18, 15),
      status: GuardianRequestStatus.approved,
      details: 'Solicitação aprovada para revisão.',
    ),
    GuardianBirthdayRequest(
      id: 'request-rejected',
      childId: 'child-bia',
      childName: 'Bia',
      guardianName: 'Marina Alves',
      contextId: 'group-girassol',
      institutionId: 'inst-horizonte',
      title: 'Aniversário da Bia',
      startsAt: DateTime(2026, 8, 28, 16),
      endsAt: DateTime(2026, 8, 28, 17),
      status: GuardianRequestStatus.rejected,
      details: 'Data solicitada.',
      decision: GuardianRequestDecision(
        approved: false,
        actorName: 'Coordenação',
        actorContextId: 'unit-cambui',
        decidedAt: DateTime(2026, 8, 1, 10),
        reason: 'A unidade estará em recesso.',
      ),
    ),
  ];
}
