enum GroupStatus {
  unknown('unknown', 'Desconhecido'),
  draft('draft', 'Rascunho'),
  active('active', 'Ativo'),
  inactive('inactive', 'Inativo'),
  suspended('suspended', 'Suspenso'),
  archived('archived', 'Arquivado');

  const GroupStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static GroupStatus fromDatabaseValue(String? value) => value == null
      ? GroupStatus.unknown
      : values.firstWhere(
          (status) => status.databaseValue == value,
          orElse: () => GroupStatus.unknown,
        );
}

final class GroupRecord {
  const GroupRecord({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.name,
    required this.groupType,
    required this.status,
    this.statusValue,
    required this.createdAt,
    required this.updatedAt,
    this.groupTypeOtherText,
    this.inheritAppearance = true,
    this.inheritAccess = true,
    this.inheritActivities = true,
    this.managementVersion = 0,
    this.appearanceOrigin = 'unit',
    this.effectiveAppearance = const {},
    this.effectiveAccess = const [],
    this.activityIds = const [],
    this.invites = const [],
  });

  final String id;
  final String institutionId;
  final String institutionName;
  final String unitId;
  final String unitName;
  final String name;
  final String groupType;
  final GroupStatus status;
  final String? statusValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupTypeOtherText;
  final bool inheritAppearance;
  final bool inheritAccess;
  final bool inheritActivities;
  final int managementVersion;
  final String appearanceOrigin;
  final Map<String, String?> effectiveAppearance;
  final List<GroupEffectiveAccess> effectiveAccess;
  final List<String> activityIds;
  final List<GroupDirectoryInviteBinding> invites;

  String get groupTypeLabel => groupTypeLabelFor(groupType);
  String get statusLabel =>
      status == GroupStatus.unknown && statusValue != null && statusValue!.isNotEmpty
      ? 'Desconhecido (${statusValue!})'
      : status.label;
  String get statusDatabaseValue => statusValue ?? status.databaseValue;

  static String groupTypeLabelFor(String value) => value == 'class' ? 'Turma' : value;

  GroupRecord copyWith({
    String? id,
    String? institutionId,
    String? institutionName,
    String? unitId,
    String? unitName,
    String? name,
    String? groupType,
    GroupStatus? status,
    String? statusValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? groupTypeOtherText,
    bool? inheritAppearance,
    bool? inheritAccess,
    bool? inheritActivities,
    int? managementVersion,
    String? appearanceOrigin,
    Map<String, String?>? effectiveAppearance,
    List<GroupEffectiveAccess>? effectiveAccess,
    List<String>? activityIds,
    List<GroupDirectoryInviteBinding>? invites,
  }) {
    if (institutionId != null && institutionId != this.institutionId) {
      throw ArgumentError('Changing an existing group institution is not supported.');
    }
    if (unitId != null && unitId != this.unitId) {
      throw ArgumentError('Changing an existing group unit is not supported.');
    }
    return GroupRecord(
      id: id ?? this.id,
      institutionId: this.institutionId,
      institutionName: institutionName ?? this.institutionName,
      unitId: this.unitId,
      unitName: unitName ?? this.unitName,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      status: status ?? this.status,
      statusValue: statusValue ?? this.statusValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      groupTypeOtherText: groupTypeOtherText ?? this.groupTypeOtherText,
      inheritAppearance: inheritAppearance ?? this.inheritAppearance,
      inheritAccess: inheritAccess ?? this.inheritAccess,
      inheritActivities: inheritActivities ?? this.inheritActivities,
      managementVersion: managementVersion ?? this.managementVersion,
      appearanceOrigin: appearanceOrigin ?? this.appearanceOrigin,
      effectiveAppearance: effectiveAppearance ?? this.effectiveAppearance,
      effectiveAccess: effectiveAccess ?? this.effectiveAccess,
      activityIds: activityIds ?? this.activityIds,
      invites: invites ?? this.invites,
    );
  }
}

final class GroupEffectiveAccess {
  const GroupEffectiveAccess({
    required this.personId,
    required this.displayName,
    required this.origin,
    required this.inherited,
    required this.profileId,
    required this.profileCode,
    required this.profileName,
    this.capabilities = const [],
    this.restrictions = const [],
  });

  final String personId;
  final String displayName;
  final String origin;
  final bool inherited;
  final String profileId;
  final String profileCode;
  final String profileName;
  final List<String> capabilities;
  final List<String> restrictions;
}

final class GroupDirectoryItem {
  const GroupDirectoryItem(this.record);

  final GroupRecord record;

  String get id => record.id;
  String get institutionId => record.institutionId;
  String get institutionName => record.institutionName;
  String get unitId => record.unitId;
  String get unitName => record.unitName;
  String get name => record.name;
  String get groupType => record.groupType;
  String get groupTypeLabel => record.groupTypeLabel;
  GroupStatus get status => record.status;
  String get statusLabel => record.statusLabel;
}

enum GroupDirectorySortColumn { name, institutionName, unitName, groupType, status }

enum GroupDirectoryStatusCategory { all, active, onboarding, inactive }

final class GroupDirectoryQuery {
  static const defaultPageSize = 11;
  static const allowedPageSizes = <int>[8, 11, 20, 50, 100];

  GroupDirectoryQuery({
    this.search = '',
    Set<String> institutionIds = const {},
    Set<String> unitIds = const {},
    Set<String> typeIds = const {},
    Set<GroupStatus> statuses = const {},
    this.page = 0,
    this.pageSize = defaultPageSize,
    this.sortColumn = GroupDirectorySortColumn.name,
    this.sortAscending = true,
  }) : assert(page >= 0),
       assert(allowedPageSizes.contains(pageSize)),
       institutionIds = Set.unmodifiable(institutionIds),
       unitIds = Set.unmodifiable(unitIds),
       typeIds = Set.unmodifiable(typeIds),
       statuses = Set.unmodifiable(statuses);

  final String search;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final Set<String> typeIds;
  final Set<GroupStatus> statuses;
  final int page;
  final int pageSize;
  final GroupDirectorySortColumn sortColumn;
  final bool sortAscending;

  int get offset => page * pageSize;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      institutionIds.isNotEmpty ||
      unitIds.isNotEmpty ||
      typeIds.isNotEmpty ||
      statuses.isNotEmpty;
}

extension GroupDirectoryStatusCategoryExtension on GroupDirectoryStatusCategory {
  Set<GroupStatus> get statuses => switch (this) {
    GroupDirectoryStatusCategory.all => const {},
    GroupDirectoryStatusCategory.active => const {GroupStatus.active},
    GroupDirectoryStatusCategory.onboarding => const {GroupStatus.draft},
    GroupDirectoryStatusCategory.inactive => const {
      GroupStatus.inactive,
      GroupStatus.suspended,
      GroupStatus.archived,
    },
  };
}

extension GroupDirectoryStatusCategoryLabel on GroupDirectoryStatusCategory {
  String get label => switch (this) {
    GroupDirectoryStatusCategory.all => 'Todos',
    GroupDirectoryStatusCategory.active => 'Ativos',
    GroupDirectoryStatusCategory.onboarding => 'Em Implantação',
    GroupDirectoryStatusCategory.inactive => 'Inativos',
  };
}

GroupDirectoryStatusCategory groupDirectoryStatusCategoryFrom(Set<GroupStatus> statuses) {
  if (statuses.isEmpty) return GroupDirectoryStatusCategory.all;
  if (statuses.length == 1) {
    if (statuses.contains(GroupStatus.active)) {
      return GroupDirectoryStatusCategory.active;
    }
    if (statuses.contains(GroupStatus.draft)) {
      return GroupDirectoryStatusCategory.onboarding;
    }
    if (statuses.contains(GroupStatus.inactive) ||
        statuses.contains(GroupStatus.suspended) ||
        statuses.contains(GroupStatus.archived)) {
      return GroupDirectoryStatusCategory.inactive;
    }
  }
  return GroupDirectoryStatusCategory.all;
}

final class GroupDirectoryPage {
  const GroupDirectoryPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<GroupDirectoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
}

final class GroupDirectoryFilterOption {
  const GroupDirectoryFilterOption({required this.id, required this.label, this.institutionId});

  final String id;
  final String label;
  final String? institutionId;
}

final class GroupDirectoryFilterOptions {
  const GroupDirectoryFilterOptions({
    this.institutions = const [],
    this.units = const [],
    this.types = const [],
  });

  final List<GroupDirectoryFilterOption> institutions;
  final List<GroupDirectoryFilterOption> units;
  final List<GroupDirectoryFilterOption> types;
}

final class GroupDirectoryFormContext {
  const GroupDirectoryFormContext({
    required this.institutions,
    required this.units,
    this.types = const [],
  });

  final List<GroupDirectoryFilterOption> institutions;
  final List<GroupDirectoryFilterOption> units;
  final List<GroupDirectoryFilterOption> types;
}

enum GroupDirectorySaveStage { group, people, professionals, activityLinks, invites }

enum GroupDirectorySaveStepStatus { success, skipped, failure }

final class GroupDirectorySaveStepResult {
  const GroupDirectorySaveStepResult({required this.stage, required this.status, this.message});

  final GroupDirectorySaveStage stage;
  final GroupDirectorySaveStepStatus status;
  final String? message;

  bool get isFailure => status == GroupDirectorySaveStepStatus.failure;
  bool get isSuccessfulOrSkipped => status != GroupDirectorySaveStepStatus.failure;

  static GroupDirectorySaveStepResult skipped({
    required GroupDirectorySaveStage stage,
    String? message,
  }) => GroupDirectorySaveStepResult(
    stage: stage,
    status: GroupDirectorySaveStepStatus.skipped,
    message: message,
  );

  static GroupDirectorySaveStepResult success({
    required GroupDirectorySaveStage stage,
    String? message,
  }) => GroupDirectorySaveStepResult(
    stage: stage,
    status: GroupDirectorySaveStepStatus.success,
    message: message,
  );

  static GroupDirectorySaveStepResult failure({
    required GroupDirectorySaveStage stage,
    required String message,
  }) => GroupDirectorySaveStepResult(
    stage: stage,
    status: GroupDirectorySaveStepStatus.failure,
    message: message,
  );
}

extension GroupDirectorySaveStageLabel on GroupDirectorySaveStage {
  String get label => switch (this) {
    GroupDirectorySaveStage.group => 'Turma',
    GroupDirectorySaveStage.people => 'Pessoas',
    GroupDirectorySaveStage.professionals => 'Profissionais',
    GroupDirectorySaveStage.activityLinks => 'Atividades',
    GroupDirectorySaveStage.invites => 'Convites',
  };
}

final class GroupDirectoryPersonBinding {
  const GroupDirectoryPersonBinding({
    required this.id,
    required this.name,
    required this.identifier,
    required this.role,
    this.profile,
  });

  final String id;
  final String name;
  final String identifier;
  final String role;
  final String? profile;
}

final class GroupDirectoryInviteBinding {
  const GroupDirectoryInviteBinding({
    required this.id,
    required this.identifier,
    required this.role,
    required this.profile,
    required this.status,
  });

  final String id;
  final String identifier;
  final String role;
  final String profile;
  final String status;
}

final class GroupDirectorySaveRequest {
  const GroupDirectorySaveRequest({
    required this.record,
    required this.requestId,
    this.people = const [],
    this.professionals = const [],
    this.activityIds = const [],
    this.invites = const [],
    this.branding = const {},
    this.typeRequestLabel,
    this.typeRequestJustification,
  });

  final GroupRecord record;
  final String requestId;
  final List<GroupDirectoryPersonBinding> people;
  final List<GroupDirectoryPersonBinding> professionals;
  final List<String> activityIds;
  final List<GroupDirectoryInviteBinding> invites;
  final Map<String, String?> branding;
  final String? typeRequestLabel;
  final String? typeRequestJustification;
}

final class GroupDirectorySaveResult {
  const GroupDirectorySaveResult({required this.requestId, required this.steps});

  final String requestId;
  final List<GroupDirectorySaveStepResult> steps;

  bool get hasFailure => steps.any((step) => step.isFailure);
  bool get isSuccess => !hasFailure;
}

final class GroupDirectoryExportResult {
  const GroupDirectoryExportResult({required this.jobId, required this.downloadUrl});

  final String jobId;
  final String downloadUrl;
}

abstract interface class GroupDirectoryRepository {
  Future<GroupRecord?> findById(String id);
  String createId(String institutionId, String unitId, String name);
  Future<void> upsert(GroupRecord record);
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request);
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query);
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}});
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId});
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query);
}

final class GroupDirectoryUnauthorizedException implements Exception {
  const GroupDirectoryUnauthorizedException();
}

final class GroupDirectoryUnavailableException implements Exception {
  const GroupDirectoryUnavailableException();
}

final class UnavailableGroupDirectoryRepository implements GroupDirectoryRepository {
  const UnavailableGroupDirectoryRepository();

  Never _unavailable() => throw const GroupDirectoryUnavailableException();

  Future<T> _unavailableFuture<T>() => Future<T>.error(const GroupDirectoryUnavailableException());

  @override
  Future<GroupRecord?> findById(String id) => _unavailableFuture();

  @override
  String createId(String institutionId, String unitId, String name) => _unavailable();

  @override
  Future<void> upsert(GroupRecord record) => _unavailableFuture();

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) =>
      _unavailableFuture();

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) => _unavailableFuture();

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}}) =>
      _unavailableFuture();

  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) =>
      _unavailableFuture();

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) =>
      _unavailableFuture();
}
