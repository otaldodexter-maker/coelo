import 'package:flutter/foundation.dart';

import '../domain/agenda_models.dart';

final class AgendaPrototypeStore extends ChangeNotifier {
  AgendaPrototypeStore.empty({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _contexts = const [];
    _items = const [];
    _requests = const [];
    _birthdays = const [];
    _publicationRequests = const [];
  }

  AgendaPrototypeStore.seeded({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _contexts = _seedContexts();
    _items = _seedItems();
    _requests = _seedRequests();
    _birthdays = _seedBirthdays();
    _publicationRequests = const [];
  }
  final DateTime Function() _clock;
  late List<AgendaItem> _items;
  late List<AgendaContext> _contexts;
  late List<GuardianBirthdayRequest> _requests;
  late List<AgendaBirthday> _birthdays;
  late List<AgendaPublicationRequest> _publicationRequests;
  DateTime get referenceDate => DateTime(2026, 8, 3);
  List<AgendaItem> get items => List.unmodifiable(_items);
  List<AgendaContext> get contexts => List.unmodifiable(_contexts);
  List<GuardianBirthdayRequest> get requests => List.unmodifiable(_requests);
  List<AgendaPublicationRequest> get publicationRequests => List.unmodifiable(_publicationRequests);
  AgendaItem? itemById(String id) => _firstOrNull(_items.where((e) => e.id == id));
  GuardianBirthdayRequest? requestById(String id) =>
      _firstOrNull(_requests.where((e) => e.id == id));

  AgendaMutationResult requestPublication(String itemId, {required String requestedBy}) {
    final item = itemById(itemId);
    if (item == null) return AgendaMutationResult.notFound;
    if (item.status != AgendaItemStatus.draft) return AgendaMutationResult.invalidLifecycle;
    final attempts = _publicationRequests.where((request) => request.itemId == itemId).length;
    final id = 'publication-$itemId-${attempts + 1}';
    if (_publicationRequests.any(
      (request) =>
          request.itemId == itemId && request.status == AgendaPublicationRequestStatus.pending,
    )) {
      return AgendaMutationResult.success;
    }
    _publicationRequests = [
      ..._publicationRequests,
      AgendaPublicationRequest(
        id: id,
        itemId: item.id,
        title: item.title,
        contextLabel: _context(item.audience.institutionId)?.name ?? item.audience.institutionId,
        requestedBy: requestedBy,
        requestedAt: _clock(),
      ),
    ];
    notifyListeners();
    return AgendaMutationResult.success;
  }

  AgendaMutationResult decidePublicationRequest({
    required String requestId,
    required bool approve,
    required String decidedBy,
    required String reason,
  }) {
    final index = _publicationRequests.indexWhere((request) => request.id == requestId);
    if (index < 0) return AgendaMutationResult.notFound;
    final request = _publicationRequests[index];
    if (request.status != AgendaPublicationRequestStatus.pending) {
      return AgendaMutationResult.invalidLifecycle;
    }
    if (reason.trim().isEmpty) return AgendaMutationResult.reasonRequired;
    _publicationRequests = [..._publicationRequests]
      ..[index] = request.decided(
        status: approve
            ? AgendaPublicationRequestStatus.approved
            : AgendaPublicationRequestStatus.rejected,
        decidedBy: decidedBy,
        decidedAt: _clock(),
        reason: reason.trim(),
      );
    if (approve) {
      final itemIndex = _items.indexWhere((item) => item.id == request.itemId);
      if (itemIndex >= 0) {
        _items = [..._items]
          ..[itemIndex] = _items[itemIndex].copyWith(status: AgendaItemStatus.published);
      }
    }
    notifyListeners();
    return AgendaMutationResult.success;
  }

  AgendaMutationResult cancelItem(String id, {required String actorName}) {
    final item = itemById(id);
    if (item == null) return AgendaMutationResult.notFound;
    if (item.status == AgendaItemStatus.canceled || item.status == AgendaItemStatus.draft) {
      return AgendaMutationResult.invalidLifecycle;
    }
    upsertItem(
      item.copyWith(
        status: AgendaItemStatus.canceled,
        history: [
          ...item.history,
          AgendaHistoryEntry(
            action: AgendaHistoryAction.canceled,
            actorName: actorName,
            occurredAt: _clock(),
            previousStatus: item.status,
          ),
        ],
      ),
    );
    return AgendaMutationResult.success;
  }

  AgendaMutationResult restoreItem(
    String id, {
    required String actorName,
    String? actorContextId,
    bool overrideConflict = false,
    String? reason,
  }) {
    final item = itemById(id);
    if (item == null) return AgendaMutationResult.notFound;
    if (item.status != AgendaItemStatus.canceled) return AgendaMutationResult.invalidLifecycle;
    final previous = item.history.reversed
        .where((entry) => entry.action == AgendaHistoryAction.canceled)
        .firstOrNull
        ?.previousStatus;
    final restored = item.copyWith(
      status: previous == AgendaItemStatus.scheduled
          ? AgendaItemStatus.scheduled
          : AgendaItemStatus.published,
      history: [
        ...item.history,
        AgendaHistoryEntry(
          action: AgendaHistoryAction.restored,
          actorName: actorName,
          occurredAt: _clock(),
        ),
      ],
    );
    if (_hasReservationConflict(restored)) {
      if (!overrideConflict) return AgendaMutationResult.reservationConflict;
      if (actorContextId == null ||
          !resolveCapability(
            actorContextId,
            AgendaCapability.overrideReservationConflict,
          ).isAllowed) {
        return AgendaMutationResult.notAuthorized;
      }
      if (reason == null || reason.trim().isEmpty) {
        return AgendaMutationResult.reasonRequired;
      }
      upsertItem(
        restored.copyWith(
          history: [
            ...restored.history,
            AgendaHistoryEntry(
              action: AgendaHistoryAction.reservationConflictOverridden,
              actorName: actorName,
              occurredAt: _clock(),
              reason: reason.trim(),
            ),
          ],
        ),
      );
      return AgendaMutationResult.success;
    }
    upsertItem(restored);
    return AgendaMutationResult.success;
  }

  AgendaMutationResult deleteDraft(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return AgendaMutationResult.notFound;
    if (_items[index].status != AgendaItemStatus.draft) {
      return AgendaMutationResult.invalidLifecycle;
    }
    _items = [..._items]..removeAt(index);
    _publicationRequests = _publicationRequests
        .where(
          (request) =>
              request.itemId != id || request.status != AgendaPublicationRequestStatus.pending,
        )
        .toList(growable: false);
    notifyListeners();
    return AgendaMutationResult.success;
  }

  AgendaMutationResult recordOccurrenceEdit({
    required String itemId,
    required DateTime occurrenceStartsAt,
    required AgendaOccurrenceEditScope scope,
    required String actorName,
  }) {
    final item = itemById(itemId);
    if (item == null) return AgendaMutationResult.notFound;
    upsertItem(
      item.copyWith(
        history: [
          ...item.history,
          AgendaHistoryEntry(
            action: AgendaHistoryAction.occurrenceEdited,
            actorName: actorName,
            occurredAt: _clock(),
            occurrenceStartsAt: occurrenceStartsAt,
            occurrenceEditScope: scope,
          ),
        ],
      ),
    );
    return AgendaMutationResult.success;
  }

  AgendaMutationResult saveItem(
    AgendaItem item, {
    required String actorContextId,
    String actorName = '',
    bool overrideConflict = false,
    String? reason,
  }) {
    final hasReservationConflict = _hasReservationConflict(item);
    if (!hasReservationConflict) {
      upsertItem(item);
      return AgendaMutationResult.success;
    }
    if (!overrideConflict) return AgendaMutationResult.reservationConflict;
    if (!resolveCapability(
      actorContextId,
      AgendaCapability.overrideReservationConflict,
    ).isAllowed) {
      return AgendaMutationResult.notAuthorized;
    }
    if (reason == null || reason.trim().isEmpty) return AgendaMutationResult.reasonRequired;
    upsertItem(
      item.copyWith(
        history: [
          ...item.history,
          AgendaHistoryEntry(
            action: AgendaHistoryAction.reservationConflictOverridden,
            actorName: actorName,
            occurredAt: _clock(),
            reason: reason.trim(),
          ),
        ],
      ),
    );
    return AgendaMutationResult.success;
  }

  bool _hasReservationConflict(AgendaItem item) =>
      item.type == AgendaItemType.resourceReservation &&
      item.status != AgendaItemStatus.canceled &&
      item.location.trim().isNotEmpty &&
      _items.any(
        (other) =>
            other.id != item.id &&
            other.type == AgendaItemType.resourceReservation &&
            other.status != AgendaItemStatus.canceled &&
            other.audience.institutionId == item.audience.institutionId &&
            other.location.trim().toLowerCase() == item.location.trim().toLowerCase() &&
            item.startsAt.isBefore(other.endsAt) &&
            item.endsAt.isAfter(other.startsAt),
      );

  List<AgendaBirthday> birthdaysForContext(String contextId) {
    final context = _context(contextId);
    if (context == null) return const [];
    return List.unmodifiable(
      _birthdays.where(
        (birthday) =>
            birthday.institutionId == context.institutionId &&
            _isAncestorOrSelf(contextId, birthday.contextId),
      ),
    );
  }

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
      var occurrenceIndex = 0;
      final duration = item.duration;
      while ((recurrence.until == null || !occurrence.isAfter(recurrence.until!)) &&
          (recurrence.occurrenceCount == null || occurrenceIndex < recurrence.occurrenceCount!) &&
          occurrence.isBefore(end)) {
        if (!occurrence.isBefore(start.subtract(duration)) && !recurrence.isException(occurrence)) {
          result.add(
            AgendaOccurrence(item: item, startsAt: occurrence, endsAt: occurrence.add(duration)),
          );
        }
        occurrenceIndex++;
        occurrence = _occurrenceAt(item.startsAt, recurrence, occurrenceIndex);
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

  static DateTime _occurrenceAt(DateTime value, AgendaRecurrence recurrence, int occurrenceIndex) {
    switch (recurrence.frequency) {
      case AgendaRecurrenceFrequency.daily:
        return value.add(Duration(days: recurrence.interval * occurrenceIndex));
      case AgendaRecurrenceFrequency.weekly:
        return value.add(Duration(days: 7 * recurrence.interval * occurrenceIndex));
      case AgendaRecurrenceFrequency.monthly:
        final targetMonth = value.month + (recurrence.interval * occurrenceIndex);
        final lastDay = DateTime(value.year, targetMonth + 1, 0).day;
        return DateTime(
          value.year,
          targetMonth,
          value.day > lastDay ? lastDay : value.day,
          value.hour,
          value.minute,
          value.second,
          value.millisecond,
          value.microsecond,
        );
    }
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
        AgendaCapability.overrideReservationConflict,
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
        'Feira cultural 2026',
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
        'Reunião de responsáveis',
        AgendaItemType.event,
        u,
        7,
        18,
        3,
        description: 'Uma noite especial de convivência, histórias e brincadeiras.',
      ),
      item(
        'event-paint',
        'Passeio pedagógico',
        AgendaItemType.event,
        g,
        5,
        10,
        2,
        description: 'Vivência artística com cores, texturas e criação coletiva.',
      ),
      item(
        'activity-yellow',
        'Festival de esportes',
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
        'Mostra de projetos',
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

  static List<AgendaBirthday> _seedBirthdays() => const [
    AgendaBirthday(
      personId: 'child-lia',
      firstName: 'Lia',
      institutionId: 'inst-horizonte',
      contextId: 'group-girassol',
      month: 8,
      day: 5,
    ),
  ];
}
