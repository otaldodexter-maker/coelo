library;

enum AuditOutcome {
  success('success'),
  failure('failure'),
  denied('denied');

  const AuditOutcome(this.databaseValue);

  final String databaseValue;

  static AuditOutcome fromDatabase(String value) => switch (value) {
    'success' => success,
    'failure' => failure,
    'denied' => denied,
    _ => throw const FormatException('Unsupported audit outcome.'),
  };
}

final class AuditActor {
  const AuditActor({required this.id, required this.displayName, required this.roleCode});

  final String? id;
  final String displayName;
  final String roleCode;
}

final class AuditInstitution {
  const AuditInstitution({required this.id, required this.name});

  final String id;
  final String name;
}

final class AuditContext {
  const AuditContext({required this.kind, this.id});

  final String kind;
  final String? id;
}

final class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.actor,
    required this.actionCode,
    required this.resourceType,
    required this.resourceId,
    required this.outcome,
    required this.origin,
    required this.context,
    required this.occurredAt,
    this.institution,
    this.correlationId,
  });

  final String id;
  final AuditActor actor;
  final AuditInstitution? institution;
  final String actionCode;
  final String? resourceType;
  final String? resourceId;
  final AuditOutcome outcome;
  final String? correlationId;
  final String origin;
  final AuditContext context;
  final DateTime occurredAt;
}

final class AuditIntegrity {
  const AuditIntegrity({
    required this.position,
    required this.hash,
    required this.verified,
    this.previousHash,
  });

  final int position;
  final String? previousHash;
  final String hash;
  final bool verified;
}

final class AuditEventDetail {
  AuditEventDetail({
    required this.event,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required this.integrity,
    this.reason,
  }) : before = Map.unmodifiable(before),
       after = Map.unmodifiable(after);

  final AuditEvent event;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
  final String? reason;
  final AuditIntegrity integrity;
}

/// The cursor is an opaque backend continuation token to presentation code.
final class AuditCursor {
  const AuditCursor({required this.occurredAt, required this.eventId});

  final DateTime occurredAt;
  final String eventId;
}

final class AuditQuery {
  AuditQuery({
    this.search = '',
    Set<String> actorIds = const {},
    Set<String> contextKinds = const {},
    Set<String> actionCodes = const {},
    Set<String> resourceTypes = const {},
    Set<AuditOutcome> outcomes = const {},
    Set<String> origins = const {},
    this.institutionId,
    this.from,
    this.to,
    this.cursor,
    this.pageSize = 25,
  }) : assert(pageSize > 0 && pageSize <= 100),
       actorIds = Set.unmodifiable(actorIds),
       contextKinds = Set.unmodifiable(contextKinds),
       actionCodes = Set.unmodifiable(actionCodes),
       resourceTypes = Set.unmodifiable(resourceTypes),
       outcomes = Set.unmodifiable(outcomes),
       origins = Set.unmodifiable(origins);

  final String search;
  final Set<String> actorIds;
  final Set<String> contextKinds;
  final Set<String> actionCodes;
  final Set<String> resourceTypes;
  final Set<AuditOutcome> outcomes;
  final Set<String> origins;
  final String? institutionId;
  final DateTime? from;
  final DateTime? to;
  final AuditCursor? cursor;
  final int pageSize;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      actorIds.isNotEmpty ||
      contextKinds.isNotEmpty ||
      actionCodes.isNotEmpty ||
      resourceTypes.isNotEmpty ||
      outcomes.isNotEmpty ||
      origins.isNotEmpty ||
      institutionId != null ||
      from != null ||
      to != null;

  AuditQuery withCursor(AuditCursor? value) => AuditQuery(
    search: search,
    actorIds: actorIds,
    contextKinds: contextKinds,
    actionCodes: actionCodes,
    resourceTypes: resourceTypes,
    outcomes: outcomes,
    origins: origins,
    institutionId: institutionId,
    from: from,
    to: to,
    cursor: value,
    pageSize: pageSize,
  );

  AuditQuery withoutCursor() => withCursor(null);

  AuditQuery withSearch(String value) => AuditQuery(
    search: value,
    actorIds: actorIds,
    contextKinds: contextKinds,
    actionCodes: actionCodes,
    resourceTypes: resourceTypes,
    outcomes: outcomes,
    origins: origins,
    institutionId: institutionId,
    from: from,
    to: to,
    pageSize: pageSize,
  );
}

final class AuditPage {
  AuditPage({
    required List<AuditEvent> events,
    required this.hasMore,
    required this.totalCount,
    required this.canExport,
    this.nextCursor,
  }) : events = List.unmodifiable(events),
       assert(hasMore == (nextCursor != null));

  final List<AuditEvent> events;
  final bool hasMore;
  final AuditCursor? nextCursor;
  final int totalCount;
  final bool canExport;
}

enum AuditExportFormat { csv, xlsx }

enum AuditExportStatus {
  queued,
  processing,
  completed,
  failed;

  static AuditExportStatus fromDatabase(String value) => switch (value) {
    'PENDENTE' => queued,
    'PROCESSANDO' => processing,
    'SUCESSO' => completed,
    'ERRO' => failed,
    _ => throw const FormatException('Unsupported audit export status.'),
  };
}

final class AuditExportRequest {
  const AuditExportRequest({
    required this.idempotencyKey,
    required this.format,
    required this.query,
  });

  final String idempotencyKey;
  final AuditExportFormat format;
  final AuditQuery query;
}

final class AuditExportJob {
  const AuditExportJob({
    required this.id,
    required this.status,
    required this.format,
    this.createdAt,
    this.phase,
    this.rowCount,
    this.retentionExpiresAt,
    this.errorCode,
    this.downloadUrl,
    this.downloadExpiresInSeconds,
  });

  final String id;
  final AuditExportStatus status;
  final AuditExportFormat format;
  final DateTime? createdAt;
  final String? phase;
  final int? rowCount;
  final DateTime? retentionExpiresAt;
  final String? errorCode;
  final Uri? downloadUrl;
  final int? downloadExpiresInSeconds;
}

abstract interface class AuditRepository {
  Future<AuditPage> fetchPage(AuditQuery query);
  Future<AuditEventDetail> fetchDetail(String eventId);
  Future<AuditExportJob> startExport(AuditExportRequest request);
  Future<AuditExportJob> fetchExportStatus(String jobId);
}

final class AuditUnauthorizedException implements Exception {
  const AuditUnauthorizedException();
}

final class AuditNotFoundException implements Exception {
  const AuditNotFoundException();
}

final class AuditValidationException implements Exception {
  const AuditValidationException();
}

final class AuditUnavailableException implements Exception {
  const AuditUnavailableException();
}

final class UnavailableAuditRepository implements AuditRepository {
  const UnavailableAuditRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const AuditUnavailableException());

  @override
  Future<AuditEventDetail> fetchDetail(String eventId) => _unavailable();

  @override
  Future<AuditPage> fetchPage(AuditQuery query) => _unavailable();

  @override
  Future<AuditExportJob> startExport(AuditExportRequest request) => _unavailable();

  @override
  Future<AuditExportJob> fetchExportStatus(String jobId) => _unavailable();
}
