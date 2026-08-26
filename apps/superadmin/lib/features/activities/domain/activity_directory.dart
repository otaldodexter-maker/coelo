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
  all('all', 'Toda a turma'),
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
    this.handleStem,
    this.canonicalHandle,
    required this.activeUnitCount,
    required this.activeGroupCount,
    this.locationNames = const [],
    this.activeProfessionalCount,
    this.activeParticipantCount,
    this.linkedUnits = const [],
    this.linkedGroups = const [],
    this.managementVersion = 0,
    required this.updatedAt,
  });

  factory ActivityDirectoryItem.fromJson(Map<String, dynamic> json) {
    final institution = _map(json['institutions']);
    return ActivityDirectoryItem(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      institutionName:
          json['institution_name'] as String? ??
          institution?['name'] as String? ??
          'Instituição não identificada',
      name: json['name'] as String,
      description: json['description'] as String?,
      status: ActivityStatus.fromDatabase(json['status'] as String),
      origin: ActivityOrigin.fromDatabase(json['origin_scope_kind'] as String),
      distribution: ActivityDistribution.fromDatabase(json['distribution_scope'] as String),
      governance: ActivityGovernance.fromDatabase(json['governance_kind'] as String),
      handleStem: json['handle_stem'] as String?,
      canonicalHandle: json['canonical_handle'] as String?,
      activeUnitCount: _activeCount(json['activity_unit_links'], json['active_unit_count']),
      activeGroupCount: _activeCount(json['activity_group_links'], json['active_group_count']),
      locationNames: _strings(json['location_names']),
      activeProfessionalCount: (json['active_professional_count'] as num?)?.toInt(),
      activeParticipantCount: (json['active_participant_count'] as num?)?.toInt(),
      linkedUnits: _rows(json['linked_units'])
          .map(
            (row) => ActivityDirectoryUnitSummary(
              id: row['id'] as String,
              name: row['name'] as String,
              institutionId: row['institution_id'] as String,
            ),
          )
          .toList(growable: false),
      linkedGroups: _rows(json['linked_groups'])
          .map(
            (row) => ActivityDirectoryGroupSummary(
              id: row['id'] as String,
              name: row['name'] as String,
              unitId: row['unit_id'] as String,
              unitName: row['unit_name'] as String,
            ),
          )
          .toList(growable: false),
      managementVersion: (json['management_version'] as num?)?.toInt() ?? 0,
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
  final String? handleStem;
  final String? canonicalHandle;
  final int activeUnitCount;
  final int activeGroupCount;
  final List<String> locationNames;
  final int? activeProfessionalCount;
  final int? activeParticipantCount;
  final List<ActivityDirectoryUnitSummary> linkedUnits;
  final List<ActivityDirectoryGroupSummary> linkedGroups;
  final int managementVersion;
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

enum ActivityDetailIdentityKind { photo, initials, icon }

final class ActivityIdentityStorageRef {
  const ActivityIdentityStorageRef({required this.bucket, required this.path});

  final String bucket;
  final String path;
}

final class ActivityDetailIdentity {
  const ActivityDetailIdentity({
    required this.kind,
    this.initials,
    this.color,
    this.icon,
    this.storageRef,
  });

  const ActivityDetailIdentity.initials()
    : kind = ActivityDetailIdentityKind.initials,
      initials = null,
      color = null,
      icon = null,
      storageRef = null;

  final ActivityDetailIdentityKind kind;
  final String? initials;
  final String? color;
  final String? icon;
  final ActivityIdentityStorageRef? storageRef;
}

final class ActivityDetailParticipant {
  const ActivityDetailParticipant({
    required this.groupId,
    required this.childGroupLinkId,
    required this.belongs,
  });

  final String groupId;
  final String childGroupLinkId;
  final bool belongs;
}

enum ActivityDetailProfessionalRole { instructor, activityAdmin }

final class ActivityDetailProfessionalAssignment {
  const ActivityDetailProfessionalAssignment({
    required this.groupId,
    required this.membershipId,
    required this.role,
    this.capabilities = const {},
  });

  final String? groupId;
  final String membershipId;
  final ActivityDetailProfessionalRole role;
  final Map<String, String> capabilities;
}

final class ActivityDetail {
  const ActivityDetail({
    required this.item,
    required this.createdAt,
    required this.units,
    required this.groups,
    this.taxonomyId,
    this.subtypeId,
    this.templateId,
    this.taxonomyOtherDescription = '',
    this.identity = const ActivityDetailIdentity.initials(),
    this.participants = const [],
    this.professionalAssignments = const [],
    this.pedagogicalConfiguration,
    this.originUnitName,
    this.archivedAt,
  });

  final ActivityDirectoryItem item;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final String? originUnitName;
  final List<ActivityUnitLink> units;
  final List<ActivityGroupLink> groups;
  final String? taxonomyId;
  final String? subtypeId;
  final String? templateId;
  final String taxonomyOtherDescription;
  final ActivityDetailIdentity identity;
  final List<ActivityDetailParticipant> participants;
  final List<ActivityDetailProfessionalAssignment> professionalAssignments;
  final Map<String, dynamic>? pedagogicalConfiguration;
}

enum ActivityDirectorySortColumn { name }

final class ActivityDirectoryQuery {
  static const defaultPageSize = 11;
  static const allowedPageSizes = <int>[8, 11, 20, 50, 100];

  ActivityDirectoryQuery({
    this.search = '',
    Set<String> institutionIds = const {},
    Set<String> unitIds = const {},
    Set<String> groupIds = const {},
    Set<ActivityStatus> statuses = const {},
    Set<ActivityOrigin> origins = const {},
    this.page = 0,
    this.pageSize = defaultPageSize,
    this.sortColumn = ActivityDirectorySortColumn.name,
    this.sortAscending = true,
  }) : assert(page >= 0),
       assert(allowedPageSizes.contains(pageSize)),
       institutionIds = Set.unmodifiable(institutionIds),
       unitIds = Set.unmodifiable(unitIds),
       groupIds = Set.unmodifiable(groupIds),
       statuses = Set.unmodifiable(statuses),
       origins = Set.unmodifiable(origins);

  final String search;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final Set<String> groupIds;
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
      unitIds.isNotEmpty ||
      groupIds.isNotEmpty ||
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
  const ActivityFilterOption({required this.id, required this.label, this.parentId});

  final String id;
  final String label;
  final String? parentId;
}

final class ActivityDirectoryUnitSummary {
  const ActivityDirectoryUnitSummary({
    required this.id,
    required this.name,
    required this.institutionId,
  });

  final String id;
  final String name;
  final String institutionId;
}

final class ActivityDirectoryGroupSummary {
  const ActivityDirectoryGroupSummary({
    required this.id,
    required this.name,
    required this.unitId,
    required this.unitName,
  });

  final String id;
  final String name;
  final String unitId;
  final String unitName;
}

final class ActivityFilterOptions {
  const ActivityFilterOptions({
    this.institutions = const [],
    this.units = const [],
    this.groups = const [],
  });

  final List<ActivityFilterOption> institutions;
  final List<ActivityFilterOption> units;
  final List<ActivityFilterOption> groups;
}

final class ActivityFormInstitutionOption {
  const ActivityFormInstitutionOption({required this.id, required this.name});

  final String id;
  final String name;
}

final class ActivityFormUnitOption {
  const ActivityFormUnitOption({required this.id, required this.institutionId, required this.name});

  final String id;
  final String institutionId;
  final String name;
}

final class ActivityTaxonomySubtypeOption {
  const ActivityTaxonomySubtypeOption({required this.id, required this.label});

  final String id;
  final String label;
}

final class ActivityTaxonomyOption {
  const ActivityTaxonomyOption({
    required this.id,
    required this.label,
    this.isOther = false,
    this.subtypes = const [],
  });

  final String id;
  final String label;
  final bool isOther;
  final List<ActivityTaxonomySubtypeOption> subtypes;
}

enum ActivityTemplateScopeKind {
  platform('platform'),
  institution('institution');

  const ActivityTemplateScopeKind(this.databaseValue);
  final String databaseValue;

  static ActivityTemplateScopeKind fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

final class ActivityTemplateOption {
  const ActivityTemplateOption({
    required this.id,
    required this.name,
    required this.taxonomyId,
    this.subtypeId,
    this.description = '',
    this.scopeKind = ActivityTemplateScopeKind.platform,
    this.institutionId,
    this.governance = ActivityGovernance.optional,
  });

  final String id;
  final String name;
  final String taxonomyId;
  final String? subtypeId;
  final String description;
  final ActivityTemplateScopeKind scopeKind;
  final String? institutionId;
  final ActivityGovernance governance;
}

final class ActivityFormLocationOption {
  const ActivityFormLocationOption({required this.id, required this.unitId, required this.name});

  final String id;
  final String unitId;
  final String name;
}

final class ActivityLocationDraft {
  const ActivityLocationDraft({
    required this.institutionId,
    required this.unitIds,
    required this.name,
  });

  final String institutionId;
  final Set<String> unitIds;
  final String name;
}

final class ActivityFormGroupOption {
  const ActivityFormGroupOption({
    required this.id,
    required this.unitId,
    required this.name,
    required this.participantCount,
  });

  final String id;
  final String unitId;
  final String name;
  final int participantCount;
}

final class ActivityFormProfessionalOption {
  const ActivityFormProfessionalOption({
    required this.id,
    required this.name,
    required this.role,
    this.personId,
  });

  /// Contextual membership id used by commands. It is never a global person id.
  final String id;
  final String name;
  final String role;
  final String? personId;
}

final class ActivityFormStudentOption {
  const ActivityFormStudentOption({
    required this.childGroupLinkId,
    required this.id,
    required this.groupId,
    required this.name,
    this.age,
    this.gender,
  });

  final String childGroupLinkId;
  final String id;
  final String groupId;
  final String name;
  final int? age;
  final String? gender;
}

final class ActivityFormOptions {
  const ActivityFormOptions({
    this.institutions = const [],
    this.units = const [],
    this.locations = const [],
    this.groups = const [],
    this.professionals = const [],
    this.students = const [],
    this.taxonomy = const [],
    this.templates = const [],
  });

  final List<ActivityFormInstitutionOption> institutions;
  final List<ActivityFormUnitOption> units;
  final List<ActivityFormLocationOption> locations;
  final List<ActivityFormGroupOption> groups;
  final List<ActivityFormProfessionalOption> professionals;
  final List<ActivityFormStudentOption> students;
  final List<ActivityTaxonomyOption> taxonomy;
  final List<ActivityTemplateOption> templates;

  List<ActivityFormUnitOption> unitsFor(String institutionId) =>
      units.where((unit) => unit.institutionId == institutionId).toList(growable: false);
}

final class ActivityTemplateOptions {
  const ActivityTemplateOptions({
    this.institutions = const [],
    this.taxonomy = const [],
    this.templates = const [],
  });

  final List<ActivityFormInstitutionOption> institutions;
  final List<ActivityTaxonomyOption> taxonomy;
  final List<ActivityTemplateOption> templates;
}

abstract interface class ActivityDirectoryRepository {
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query);
  Future<ActivityFilterOptions> fetchFilterOptions();
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId});
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId});
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  });
  Future<ActivityDetail?> fetchById(String activityId);
}

final class UnavailableActivityDirectoryRepository implements ActivityDirectoryRepository {
  const UnavailableActivityDirectoryRepository();

  Future<T> _unavailable<T>() => Future.error(const ActivityDirectoryUnavailableException());

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _unavailable();

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _unavailable();

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) => _unavailable();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) => _unavailable();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _unavailable();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _unavailable();
}

final class ActivityDirectoryUnauthorizedException implements Exception {
  const ActivityDirectoryUnauthorizedException();
}

final class ActivityDirectoryUnavailableException implements Exception {
  const ActivityDirectoryUnavailableException();
}

Map<String, dynamic>? _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

int _activeCount(Object? value, [Object? projected]) => projected is num
    ? projected.toInt()
    : value is List
    ? value.where((entry) => _map(entry)?['status'] == ActivityStatus.active.databaseValue).length
    : 0;

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().where((item) => item.trim().isNotEmpty).toList(growable: false)
    : const [];

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false)
    : const [];
