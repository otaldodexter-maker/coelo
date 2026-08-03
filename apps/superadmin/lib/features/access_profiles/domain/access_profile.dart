enum AccessProfileDomain {
  platform('platform', 'Superadmin', 'Perfis Superadmin'),
  institution('institution', 'Admin', 'Perfis Admin'),
  principal('principal', 'Principal', 'Capacidades do Principal');

  const AccessProfileDomain(this.databaseValue, this.label, this.title);

  final String databaseValue;
  final String label;
  final String title;
}

enum AccessProfileStatus {
  active('active', 'Ativo'),
  inactive('inactive', 'Inativo'),
  archived('archived', 'Arquivado');

  const AccessProfileStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static AccessProfileStatus fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

enum AccessProfileScope {
  platform('platform', 'Plataforma'),
  institution('institution', 'Instituição'),
  unit('unit', 'Unidade'),
  group('group', 'Grupo');

  const AccessProfileScope(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static AccessProfileScope fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

enum AccessProfileLayout { cards, table }

enum AccessProfileTableView { grouped, assignments }

extension AccessProfileTableViewLabel on AccessProfileTableView {
  String get label => switch (this) {
    AccessProfileTableView.grouped => 'Agrupado',
    AccessProfileTableView.assignments => 'Detalhado por atribuições',
  };
}

enum AccessAssignmentContext { institution, unit, group, activity }

final class AccessProfileAssignment {
  const AccessProfileAssignment({required this.context, required this.label});

  final AccessAssignmentContext context;
  final String label;
}

final class AccessPermission {
  const AccessPermission({
    required this.code,
    required this.module,
    required this.name,
    this.description,
    this.risk = 'normal',
    this.requiresMfa = false,
    this.selected = false,
    this.grantable = true,
    this.inherited = false,
    this.unavailableReason,
  });

  factory AccessPermission.fromJson(Map<String, dynamic> json, {bool selected = false}) =>
      AccessPermission(
        code: json['code'] as String,
        module: json['module'] as String? ?? 'geral',
        name: json['name'] as String? ?? json['description'] as String? ?? json['code'] as String,
        description: json['description'] as String?,
        risk: json['risk'] as String? ?? 'normal',
        requiresMfa: json['requires_mfa'] as bool? ?? false,
        selected: json['selected'] as bool? ?? selected,
        grantable: json['grantable'] as bool? ?? true,
        inherited: json['inherited'] as bool? ?? false,
        unavailableReason: json['unavailable_reason'] as String?,
      );

  final String code;
  final String module;
  final String name;
  final String? description;
  final String risk;
  final bool requiresMfa;
  final bool selected;
  final bool grantable;
  final bool inherited;
  final String? unavailableReason;

  bool get isSensitive => risk == 'high' || risk == 'critical' || requiresMfa;

  AccessPermission withSelection(bool value) => AccessPermission(
    code: code,
    module: module,
    name: name,
    description: description,
    risk: risk,
    requiresMfa: requiresMfa,
    selected: grantable && !inherited ? value : selected,
    grantable: grantable,
    inherited: inherited,
    unavailableReason: unavailableReason,
  );
}

final class AccessProfile {
  const AccessProfile({
    required this.id,
    required this.domain,
    required this.code,
    required this.name,
    required this.description,
    required this.status,
    required this.maxScope,
    required this.version,
    required this.membershipCount,
    this.institutionId,
    this.isSystem = false,
    this.permissions = const [],
    this.links = const [],
    this.auditEvents = const [],
    this.auditAvailable = false,
    this.localAssignments = const [],
  });

  factory AccessProfile.fromJson(AccessProfileDomain domain, Map<String, dynamic> json) {
    final permissionRows = json['permissions'] as List<dynamic>? ?? const [];
    final auditRows = json['audit'] as List<dynamic>? ?? const [];
    final linkRows = json['memberships'] as List<dynamic>? ?? const [];
    return AccessProfile(
      id: json['id'] as String,
      domain: domain,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      status: AccessProfileStatus.fromDatabase(json['status'] as String),
      maxScope: AccessProfileScope.fromDatabase(json['max_scope_kind'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      membershipCount:
          (json['membership_count'] as num?)?.toInt() ??
          ((json['memberships'] as List<dynamic>?)?.length ?? 0),
      institutionId: json['institution_id'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      permissions: permissionRows
          .map((row) => AccessPermission.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      links: linkRows
          .map((row) => AccessProfileLink.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      auditEvents: auditRows
          .map((row) => AccessAuditEvent.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      auditAvailable: json.containsKey('audit') && json['audit'] != null,
    );
  }

  final String id;
  final AccessProfileDomain domain;
  final String code;
  final String name;
  final String description;
  final AccessProfileStatus status;
  final AccessProfileScope maxScope;
  final int version;
  final int membershipCount;
  final String? institutionId;
  final bool isSystem;
  final List<AccessPermission> permissions;
  final List<AccessProfileLink> links;
  final List<AccessAuditEvent> auditEvents;
  final bool auditAvailable;
  final List<AccessProfileAssignment> localAssignments;

  AccessProfile copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    AccessProfileStatus? status,
    AccessProfileScope? maxScope,
    int? version,
    int? membershipCount,
    String? institutionId,
    bool? isSystem,
    List<AccessPermission>? permissions,
    List<AccessProfileLink>? links,
    List<AccessAuditEvent>? auditEvents,
    bool? auditAvailable,
    List<AccessProfileAssignment>? localAssignments,
  }) => AccessProfile(
    id: id ?? this.id,
    domain: domain,
    code: code ?? this.code,
    name: name ?? this.name,
    description: description ?? this.description,
    status: status ?? this.status,
    maxScope: maxScope ?? this.maxScope,
    version: version ?? this.version,
    membershipCount: membershipCount ?? this.membershipCount,
    institutionId: institutionId ?? this.institutionId,
    isSystem: isSystem ?? this.isSystem,
    permissions: permissions ?? this.permissions,
    links: links ?? this.links,
    auditEvents: auditEvents ?? this.auditEvents,
    auditAvailable: auditAvailable ?? this.auditAvailable,
    localAssignments: localAssignments ?? this.localAssignments,
  );

  Map<String, dynamic> toDraftJson() => {
    if (id.isNotEmpty) 'id': id,
    'domain': domain.databaseValue,
    if (institutionId != null) 'institution_id': institutionId,
    'code': code,
    'name': name,
    'description': description,
    'status': status.databaseValue,
    'max_scope_kind': maxScope.databaseValue,
    'permission_codes': permissions
        .where((permission) => permission.selected && !permission.inherited)
        .map((permission) => permission.code)
        .toList(growable: false),
  };
}

final class AccessProfileLink {
  const AccessProfileLink({required this.id, required this.personName, required this.scope});

  factory AccessProfileLink.fromJson(Map<String, dynamic> json) => AccessProfileLink(
    id: json['id'] as String,
    personName: json['person_name'] as String? ?? 'Pessoa',
    scope: json['scope'] as String? ?? '—',
  );

  final String id;
  final String personName;
  final String scope;
}

final class AccessAuditEvent {
  const AccessAuditEvent({required this.action, required this.occurredAt, this.reason});

  factory AccessAuditEvent.fromJson(Map<String, dynamic> json) => AccessAuditEvent(
    action: json['action'] as String,
    occurredAt: DateTime.parse(json['occurred_at'] as String).toUtc(),
    reason: json['reason'] as String?,
  );

  final String action;
  final DateTime occurredAt;
  final String? reason;
}

final class PrincipalCapability {
  const PrincipalCapability({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.contextCount,
  });

  factory PrincipalCapability.fromJson(Map<String, dynamic> json) => PrincipalCapability(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    contextCount: (json['context_count'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String code;
  final String name;
  final String description;
  final int contextCount;
}

final class AccessProfileQuery {
  const AccessProfileQuery({
    this.domain = AccessProfileDomain.platform,
    this.search = '',
    this.statuses = const {},
    this.scopes = const {},
    this.page = 0,
    this.pageSize = 11,
    this.layout = AccessProfileLayout.cards,
  });

  final AccessProfileDomain domain;
  final String search;
  final Set<AccessProfileStatus> statuses;
  final Set<AccessProfileScope> scopes;
  final int page;
  final int pageSize;
  final AccessProfileLayout layout;

  bool get hasFilters => search.trim().isNotEmpty || statuses.isNotEmpty || scopes.isNotEmpty;

  AccessProfileQuery copyWith({
    AccessProfileDomain? domain,
    String? search,
    Set<AccessProfileStatus>? statuses,
    bool clearStatuses = false,
    Set<AccessProfileScope>? scopes,
    bool clearScopes = false,
    int? page,
    int? pageSize,
    AccessProfileLayout? layout,
    bool resetPage = false,
  }) => AccessProfileQuery(
    domain: domain ?? this.domain,
    search: search ?? this.search,
    statuses: clearStatuses ? const {} : statuses ?? this.statuses,
    scopes: clearScopes ? const {} : scopes ?? this.scopes,
    page: resetPage ? 0 : page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    layout: layout ?? this.layout,
  );
}

abstract final class AccessProfileQueryTableSizes {
  static const int table = 8;
}

final class AccessProfilePage {
  const AccessProfilePage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    this.isDemo = false,
  });

  const AccessProfilePage.empty()
    : items = const [],
      totalCount = 0,
      page = 0,
      pageSize = 11,
      isDemo = false;

  final List<AccessProfile> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool isDemo;

  bool get hasPrevious => page > 0;
  bool get hasNext => (page + 1) * pageSize < totalCount;
}

final class AccessProfileReview {
  const AccessProfileReview({
    required this.addedCodes,
    required this.removedCodes,
    required this.scopeChanged,
    required this.isSensitive,
  });

  factory AccessProfileReview.compare(AccessProfile original, AccessProfile draft) {
    final before = original.permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    final after = draft.permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    final added = (after.difference(before).toList()..sort());
    final removed = (before.difference(after).toList()..sort());
    final sensitiveCodes = draft.permissions
        .where((permission) => permission.isSensitive)
        .map((permission) => permission.code)
        .toSet();
    return AccessProfileReview(
      addedCodes: added,
      removedCodes: removed,
      scopeChanged: original.maxScope != draft.maxScope,
      isSensitive:
          removed.isNotEmpty ||
          original.maxScope != draft.maxScope ||
          added.any(sensitiveCodes.contains),
    );
  }

  final List<String> addedCodes;
  final List<String> removedCodes;
  final bool scopeChanged;
  final bool isSensitive;
}

abstract interface class AccessProfileRepository {
  bool get isDemo;

  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query);

  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId);

  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain);

  Future<List<PrincipalCapability>> fetchPrincipalCapabilities();

  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  });

  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  });
}

class AccessProfileException implements Exception {
  const AccessProfileException(this.message);
  final String message;
}

final class AccessProfileUnauthorizedException extends AccessProfileException {
  const AccessProfileUnauthorizedException()
    : super('Você não tem permissão para gerenciar perfis.');
}

final class AccessProfileConflictException extends AccessProfileException {
  const AccessProfileConflictException() : super('Este perfil foi alterado por outra pessoa.');
}

final class AccessProfileUnavailableException extends AccessProfileException {
  const AccessProfileUnavailableException()
    : super('A integração de Perfis e Permissões não está disponível.');
}
