import 'agenda_models.dart';

/// Dedicated read-only contract. It deliberately does not implement the legacy
/// AgendaRepository, whose audience model implies individual completeness.
abstract interface class AgendaReadRepository {
  Future<AgendaReadPage> fetchEvents({
    required DateTime from,
    required DateTime to,
    String? institutionId,
    String search = '',
    int limit = 100,
    int offset = 0,
  });
  Future<AgendaReadDetail> fetchEvent(String id);
  Future<AgendaReadContexts> fetchContexts();
}

enum AgendaReadFailure { unauthorized, notFound, invalidArgument, unavailable }

final class AgendaReadException implements Exception {
  const AgendaReadException(this.failure, {this.code, this.correlationId});
  final AgendaReadFailure failure;
  final String? code, correlationId;
}

/// Individuals were not projected by this read contract. No personIds getter
/// exists: callers cannot mistake omitted details for a known empty audience.
final class AgendaReadAudience {
  AgendaReadAudience({
    required this.institutionId,
    required Set<String> unitIds,
    required Set<String> groupIds,
    required Set<String> activityIds,
  }) : unitIds = Set.unmodifiable(unitIds),
       groupIds = Set.unmodifiable(groupIds),
       activityIds = Set.unmodifiable(activityIds);
  final String institutionId;
  final Set<String> unitIds, groupIds, activityIds;
  bool get individualDetailsAvailable => false;
}

final class AgendaReadHistory {
  const AgendaReadHistory({
    required this.action,
    required this.occurredAt,
    this.reason,
    this.previousRevision,
    this.nextRevision,
  });
  final String action;
  final DateTime occurredAt;
  final String? reason;
  final int? previousRevision, nextRevision;
}

final class AgendaReadItem {
  AgendaReadItem({
    required this.id,
    required this.institutionId,
    required this.contextId,
    required this.contextKind,
    required this.title,
    required this.type,
    required this.priority,
    required this.status,
    required this.origin,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.timeZoneId,
    required this.location,
    required this.description,
    required this.responseMode,
    required this.guardianResponsePolicy,
    required this.audience,
    required Set<String> reminders,
    required List<AgendaQuestion> questions,
    required this.revision,
    this.recurrence,
    List<AgendaReadHistory>? history,
  }) : reminders = Set.unmodifiable(reminders),
       questions = List.unmodifiable(questions),
       history = history == null ? null : List.unmodifiable(history);
  final String id, institutionId, contextId, title, timeZoneId, location, description;
  final AgendaContextLevel contextKind;
  final AgendaItemType type;
  final AgendaPriority priority;
  final AgendaItemStatus status;
  final AgendaItemOrigin origin;
  final DateTime startsAt, endsAt;
  final bool allDay;
  final AgendaResponseMode responseMode;
  final GuardianResponsePolicy guardianResponsePolicy;
  final AgendaReadAudience audience;
  final AgendaRecurrence? recurrence;
  final Set<String> reminders;
  final List<AgendaQuestion> questions;
  final int revision;

  /// Null for list projections; an empty detail history is a different state.
  final List<AgendaReadHistory>? history;
}

final class AgendaReadContext {
  AgendaReadContext({
    required this.id,
    required this.name,
    required this.institutionId,
    required this.parentId,
    required this.level,
    required Set<AgendaCapability> granted,
    required Set<AgendaCapability> restricted,
  }) : granted = Set.unmodifiable(granted),
       restricted = Set.unmodifiable(restricted);
  final String id, name, institutionId;
  final String? parentId;
  final AgendaContextLevel level;
  final Set<AgendaCapability> granted, restricted;
}

final class AgendaReadPage {
  AgendaReadPage({
    required List<AgendaReadItem> items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.correlationId,
  }) : items = List.unmodifiable(items);
  final List<AgendaReadItem> items;
  final int total, limit, offset;
  final String correlationId;
}

final class AgendaReadDetail {
  const AgendaReadDetail({required this.item, required this.correlationId});
  final AgendaReadItem item;
  final String correlationId;
}

final class AgendaReadContexts {
  AgendaReadContexts({required List<AgendaReadContext> contexts, required this.correlationId})
    : contexts = List.unmodifiable(contexts);
  final List<AgendaReadContext> contexts;
  final String correlationId;
  bool get mutationActionsAvailable => false;
}
