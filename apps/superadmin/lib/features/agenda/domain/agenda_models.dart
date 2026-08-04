enum AgendaItemType {
  event,
  recurringRoutine,
  birthday,
  holidayOrBreak,
  appointment,
  deadline,
  operationalChange,
  resourceReservation,
  other,
}

extension AgendaItemTypeLabel on AgendaItemType {
  String get label => const [
    'Evento',
    'Rotina recorrente',
    'Aniversário',
    'Feriado ou recesso',
    'Compromisso/agendamento',
    'Prazo/pendência',
    'Alteração operacional',
    'Reserva de espaço/recurso',
    'Outros',
  ][index];
}

enum AgendaPriority { normal, important, urgent }

enum AgendaItemStatus { draft, scheduled, published, canceled }

enum AgendaItemOrigin { institution, guardianRequest, fixture }

enum AgendaVisualProminence { institutional, unit, group, activity, personal }

enum AgendaContextLevel { institution, unit, group, activity }

enum AgendaCapability { publishAgendaItems, approveGuardianBirthdayRequest }

enum PermissionState { allowed, inherited, restrictedHere, blockedByAncestor }

enum GuardianRequestStatus { sent, underReview, approved, rejected, convertedToDraft }

enum RequestDecisionResult {
  approvedAndConvertedToDraft,
  rejected,
  alreadyDecided,
  notAuthorized,
  reasonRequired,
  notFound,
}

final class AgendaAudience {
  const AgendaAudience({
    required this.institutionId,
    this.unitIds = const {},
    this.groupIds = const {},
    this.activityIds = const {},
    this.personIds = const {},
  });
  final String institutionId;
  final Set<String> unitIds, groupIds, activityIds, personIds;
  bool includesContext({required String contextId, Set<String> ancestors = const {}}) {
    final all = {institutionId, ...unitIds, ...groupIds, ...activityIds, ...personIds};
    return all.contains(contextId) || ancestors.any(all.contains);
  }
}

AgendaVisualProminence deriveAgendaProminence({
  required AgendaAudience audience,
  required AgendaItemType type,
}) {
  if (type == AgendaItemType.birthday || audience.personIds.isNotEmpty) {
    return AgendaVisualProminence.personal;
  }
  if (audience.activityIds.isNotEmpty) return AgendaVisualProminence.activity;
  if (audience.groupIds.length == 1) return AgendaVisualProminence.group;
  if (audience.groupIds.length > 1 || audience.unitIds.length == 1) {
    return AgendaVisualProminence.unit;
  }
  return AgendaVisualProminence.institutional;
}

final class AgendaRecurrence {
  const AgendaRecurrence.weekly({
    this.interval = 1,
    required this.until,
    this.exceptions = const {},
  });
  final int interval;
  final DateTime until;
  final Set<DateTime> exceptions;
  bool isException(DateTime value) =>
      exceptions.any((d) => d.year == value.year && d.month == value.month && d.day == value.day);
}

final class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.audience,
    required this.priority,
    required this.status,
    required this.origin,
    required this.startsAt,
    required this.endsAt,
    this.location = '',
    this.description = '',
    this.recurrence,
    this.allDay = false,
    this.requiresRsvp = false,
    this.authorizationReference,
  });
  factory AgendaItem.fixture({
    required String id,
    required String title,
    required AgendaAudience audience,
    required DateTime startsAt,
    required DateTime endsAt,
    AgendaItemType type = AgendaItemType.event,
    AgendaPriority priority = AgendaPriority.normal,
    AgendaItemStatus status = AgendaItemStatus.published,
    AgendaItemOrigin origin = AgendaItemOrigin.fixture,
    String location = '',
    String description = '',
    AgendaRecurrence? recurrence,
    bool allDay = false,
    bool requiresRsvp = false,
    String? authorizationReference,
  }) => AgendaItem(
    id: id,
    title: title,
    type: type,
    audience: audience,
    priority: priority,
    status: status,
    origin: origin,
    startsAt: startsAt,
    endsAt: endsAt,
    location: location,
    description: description,
    recurrence: recurrence,
    allDay: allDay,
    requiresRsvp: requiresRsvp,
    authorizationReference: authorizationReference,
  );
  final String id, title, location, description;
  final AgendaItemType type;
  final AgendaAudience audience;
  final AgendaPriority priority;
  final AgendaItemStatus status;
  final AgendaItemOrigin origin;
  final DateTime startsAt, endsAt;
  final AgendaRecurrence? recurrence;
  final bool allDay, requiresRsvp;
  final String? authorizationReference;
  Duration get duration => endsAt.difference(startsAt);
  AgendaVisualProminence get prominence => deriveAgendaProminence(audience: audience, type: type);
  AgendaItem copyWith({
    String? id,
    String? title,
    AgendaItemType? type,
    AgendaAudience? audience,
    AgendaPriority? priority,
    AgendaItemStatus? status,
    AgendaItemOrigin? origin,
    DateTime? startsAt,
    DateTime? endsAt,
    String? location,
    String? description,
    AgendaRecurrence? recurrence,
    bool? allDay,
    bool? requiresRsvp,
    String? authorizationReference,
  }) => AgendaItem(
    id: id ?? this.id,
    title: title ?? this.title,
    type: type ?? this.type,
    audience: audience ?? this.audience,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    origin: origin ?? this.origin,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    location: location ?? this.location,
    description: description ?? this.description,
    recurrence: recurrence ?? this.recurrence,
    allDay: allDay ?? this.allDay,
    requiresRsvp: requiresRsvp ?? this.requiresRsvp,
    authorizationReference: authorizationReference ?? this.authorizationReference,
  );
}

final class AgendaOccurrence {
  const AgendaOccurrence({required this.item, required this.startsAt, required this.endsAt});
  final AgendaItem item;
  final DateTime startsAt, endsAt;
  Duration get duration => endsAt.difference(startsAt);
  static int compareChronologically(AgendaOccurrence a, AgendaOccurrence b) {
    final s = a.startsAt.compareTo(b.startsAt);
    if (s != 0) return s;
    final d = b.duration.compareTo(a.duration);
    return d != 0 ? d : a.item.title.compareTo(b.item.title);
  }
}

final class AgendaContext {
  const AgendaContext({
    required this.id,
    required this.name,
    required this.level,
    required this.institutionId,
    this.parentId,
    this.grantedCapabilities = const {},
    this.restrictedCapabilities = const {},
  });
  final String id, name, institutionId;
  final AgendaContextLevel level;
  final String? parentId;
  final Set<AgendaCapability> grantedCapabilities, restrictedCapabilities;
  AgendaContext copyWith({Set<AgendaCapability>? restrictedCapabilities}) => AgendaContext(
    id: id,
    name: name,
    level: level,
    institutionId: institutionId,
    parentId: parentId,
    grantedCapabilities: grantedCapabilities,
    restrictedCapabilities: restrictedCapabilities ?? this.restrictedCapabilities,
  );
}

final class PermissionResolution {
  const PermissionResolution({
    required this.state,
    this.grantedByContextName,
    this.blockedByContextName,
  });
  final PermissionState state;
  final String? grantedByContextName, blockedByContextName;
  bool get isAllowed => state == PermissionState.allowed || state == PermissionState.inherited;
}

final class GuardianRequestDecision {
  const GuardianRequestDecision({
    required this.approved,
    required this.actorName,
    required this.actorContextId,
    required this.decidedAt,
    this.reason,
  });
  final bool approved;
  final String actorName, actorContextId;
  final DateTime decidedAt;
  final String? reason;
}

final class GuardianBirthdayRequest {
  const GuardianBirthdayRequest({
    required this.id,
    required this.childId,
    required this.childName,
    required this.guardianName,
    required this.contextId,
    required this.institutionId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.details,
    this.decision,
    this.linkedAgendaItemId,
  });
  final String id, childId, childName, guardianName, contextId, institutionId, title, details;
  final DateTime startsAt, endsAt;
  final GuardianRequestStatus status;
  final GuardianRequestDecision? decision;
  final String? linkedAgendaItemId;
  GuardianBirthdayRequest copyWith({
    GuardianRequestStatus? status,
    GuardianRequestDecision? decision,
    String? linkedAgendaItemId,
  }) => GuardianBirthdayRequest(
    id: id,
    childId: childId,
    childName: childName,
    guardianName: guardianName,
    contextId: contextId,
    institutionId: institutionId,
    title: title,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status ?? this.status,
    details: details,
    decision: decision ?? this.decision,
    linkedAgendaItemId: linkedAgendaItemId ?? this.linkedAgendaItemId,
  );
}
