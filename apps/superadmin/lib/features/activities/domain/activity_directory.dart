enum ActivityStatus {
  draft('draft', 'Rascunho'),
  active('active', 'Ativa'),
  inactive('inactive', 'Inativa'),
  suspended('suspended', 'Suspensa'),
  archived('archived', 'Arquivada');

  const ActivityStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ActivityStatus fromDatabase(String value) =>
      values.firstWhere((status) => status.databaseValue == value);
}

enum ActivityOrigin {
  institution('institution', 'Instituição'),
  unit('unit', 'Unidade');

  const ActivityOrigin(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ActivityOrigin fromDatabase(String value) =>
      values.firstWhere((origin) => origin.databaseValue == value);
}

enum ActivityDistribution {
  institutionStandard('institution_standard', 'Padrão institucional'),
  unitLocal('unit_local', 'Local da unidade');

  const ActivityDistribution(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ActivityDistribution fromDatabase(String value) =>
      values.firstWhere((distribution) => distribution.databaseValue == value);
}

enum ActivityGovernance {
  optional('optional', 'Opcional'),
  mandatory('mandatory', 'Obrigatória'),
  fixed('fixed', 'Fixa');

  const ActivityGovernance(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ActivityGovernance fromDatabase(String value) =>
      values.firstWhere((governance) => governance.databaseValue == value);
}

enum ActivityParticipation {
  all('all', 'Todo o grupo'),
  selected('selected', 'Participantes selecionados');

  const ActivityParticipation(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ActivityParticipation fromDatabase(String value) =>
      values.firstWhere((participation) => participation.databaseValue == value);
}

final class ActivityDirectoryItem {
  const ActivityDirectoryItem({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.name,
    required this.description,
    required this.status,
    required this.origin,
    required this.distribution,
    required this.governance,
    required this.activeUnitCount,
    required this.activeGroupCount,
    required this.updatedAt,
  });

  factory ActivityDirectoryItem.fromJson(Map<String, dynamic> json) {
    final institution = _map(json['institutions']);
    return ActivityDirectoryItem(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      institutionName: institution?['name'] as String? ?? 'Instituição não identificada',
      name: json['name'] as String,
      description: json['description'] as String?,
      status: ActivityStatus.fromDatabase(json['status'] as String),
      origin: ActivityOrigin.fromDatabase(json['origin_scope_kind'] as String),
      distribution: ActivityDistribution.fromDatabase(json['distribution_scope'] as String),
      governance: ActivityGovernance.fromDatabase(json['governance_kind'] as String),
      activeUnitCount: _activeCount(json['activity_unit_links']),
      activeGroupCount: _activeCount(json['activity_group_links']),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String institutionId;
  final String institutionName;
  final String name;
  final String? description;
  final ActivityStatus status;
  final ActivityOrigin origin;
  final ActivityDistribution distribution;
  final ActivityGovernance governance;
  final int activeUnitCount;
  final int activeGroupCount;
  final DateTime updatedAt;
}

final class ActivityUnitLink {
  const ActivityUnitLink({
    required this.id,
    required this.name,
    required this.status,
    required this.startsAt,
    this.endsAt,
  });

  final String id;
  final String name;
  final ActivityStatus status;
  final DateTime startsAt;
  final DateTime? endsAt;
}

final class ActivityGroupLink {
  const ActivityGroupLink({
    required this.id,
    required this.name,
    required this.unitName,
    required this.status,
    required this.participation,
    required this.assigneeCount,
    required this.participantCount,
  });

  final String id;
  final String name;
  final String unitName;
  final ActivityStatus status;
  final ActivityParticipation participation;
  final int assigneeCount;
  final int participantCount;
}

final class ActivityDetail {
  const ActivityDetail({
    required this.item,
    required this.createdAt,
    required this.units,
    required this.groups,
    this.originUnitName,
    this.archivedAt,
  });

  final ActivityDirectoryItem item;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final String? originUnitName;
  final List<ActivityUnitLink> units;
  final List<ActivityGroupLink> groups;
}

enum ActivityDirectorySortColumn { name }

final class ActivityDirectoryQuery {
  static const defaultPageSize = 11;
  static const allowedPageSizes = <int>[8, 11, 20, 50, 100];

  ActivityDirectoryQuery({
    this.search = '',
    Set<String> institutionIds = const {},
    Set<ActivityStatus> statuses = const {},
    Set<ActivityOrigin> origins = const {},
    this.page = 0,
    this.pageSize = defaultPageSize,
    this.sortColumn = ActivityDirectorySortColumn.name,
    this.sortAscending = true,
  }) : assert(page >= 0),
       assert(allowedPageSizes.contains(pageSize)),
       institutionIds = Set.unmodifiable(institutionIds),
       statuses = Set.unmodifiable(statuses),
       origins = Set.unmodifiable(origins);

  final String search;
  final Set<String> institutionIds;
  final Set<ActivityStatus> statuses;
  final Set<ActivityOrigin> origins;
  final int page;
  final int pageSize;
  final ActivityDirectorySortColumn sortColumn;
  final bool sortAscending;

  int get offset => page * pageSize;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      institutionIds.isNotEmpty ||
      statuses.isNotEmpty ||
      origins.isNotEmpty;
}

final class ActivityDirectoryResult {
  const ActivityDirectoryResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<ActivityDirectoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;

  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
}

final class ActivityFilterOption {
  const ActivityFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

final class ActivityFilterOptions {
  const ActivityFilterOptions({this.institutions = const []});

  final List<ActivityFilterOption> institutions;
}

final class ActivityFormInstitutionOption {
  const ActivityFormInstitutionOption({required this.id, required this.name});

  final String id;
  final String name;
}

final class ActivityFormUnitOption {
  const ActivityFormUnitOption({
    required this.id,
    required this.institutionId,
    required this.name,
  });

  final String id;
  final String institutionId;
  final String name;
}

final class ActivityFormOptions {
  const ActivityFormOptions({
    this.institutions = const [],
    this.units = const [],
  });

  final List<ActivityFormInstitutionOption> institutions;
  final List<ActivityFormUnitOption> units;

  List<ActivityFormUnitOption> unitsFor(String institutionId) => units
      .where((unit) => unit.institutionId == institutionId)
      .toList(growable: false);
}

abstract interface class ActivityDirectoryRepository {
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query);
  Future<ActivityFilterOptions> fetchFilterOptions();
  Future<ActivityFormOptions> fetchFormOptions();
  Future<ActivityDetail?> fetchById(String activityId);
}

final class ActivityDirectoryUnauthorizedException implements Exception {
  const ActivityDirectoryUnauthorizedException();
}

final class ActivityDirectoryUnavailableException implements Exception {
  const ActivityDirectoryUnavailableException();
}

Map<String, dynamic>? _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

int _activeCount(Object? value) => value is List
    ? value.where((entry) => _map(entry)?['status'] == ActivityStatus.active.databaseValue).length
    : 0;
