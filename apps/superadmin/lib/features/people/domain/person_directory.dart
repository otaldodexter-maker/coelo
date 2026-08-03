enum PersonType {
  adult('adult', 'Adulto'),
  child('child', 'Criança'),
  service('service', 'Serviço');

  const PersonType(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static PersonType fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

enum PersonStatus {
  draft('draft', 'Rascunho'),
  active('active', 'Ativa'),
  inactive('inactive', 'Inativa'),
  archived('archived', 'Arquivada');

  const PersonStatus(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static PersonStatus fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

enum AuthLinkStatus {
  linked('linked', 'Vinculado'),
  unlinked('unlinked', 'Sem vínculo'),
  pending('pending', 'Pendente');

  const AuthLinkStatus(this.databaseValue, this.label);
  final String databaseValue;
  final String label;

  static AuthLinkStatus fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

enum PersonDirectoryLayout { cards, table }

enum PersonDirectorySegment {
  all('Todos'),
  institutionalTeam('Equipe institucional'),
  guardians('Responsáveis'),
  children('Crianças'),
  dualProfile('Perfil duplo');

  const PersonDirectorySegment(this.label);
  final String label;
}

enum PersonDirectoryTableView {
  grouped('Visão agrupada'),
  institutions('Instituições'),
  units('Unidades'),
  groups('Grupos'),
  activities('Atividades');

  const PersonDirectoryTableView(this.label);
  final String label;
}

enum PersonDirectorySortColumn {
  displayName('display_name'),
  type('type'),
  status('status'),
  institution('institution_name'),
  unit('unit_name'),
  group('group_name'),
  role('contextual_role'),
  authLink('auth_link');

  const PersonDirectorySortColumn(this.databaseValue);
  final String databaseValue;
}

final class PersonMembership {
  const PersonMembership({
    required this.id,
    this.membershipId,
    required this.institutionId,
    required this.institutionName,
    this.unitId,
    this.unitName,
    this.groupId,
    this.groupName,
    this.activityId,
    this.activityName,
    required this.role,
    this.isPlatform = false,
  });

  final String id;
  final String? membershipId;
  final String institutionId;
  final String institutionName;
  final String? unitId;
  final String? unitName;
  final String? groupId;
  final String? groupName;
  final String? activityId;
  final String? activityName;
  final String role;
  final bool isPlatform;

  PersonMembership copyWith({String? role}) => PersonMembership(
    id: id,
    membershipId: membershipId,
    institutionId: institutionId,
    institutionName: institutionName,
    unitId: unitId,
    unitName: unitName,
    groupId: groupId,
    groupName: groupName,
    activityId: activityId,
    activityName: activityName,
    role: role ?? this.role,
    isPlatform: isPlatform,
  );

  factory PersonMembership.fromJson(Map<String, dynamic> json) => PersonMembership(
    id: (json['assignment_id'] ?? json['id']) as String,
    membershipId: json['membership_id'] as String?,
    institutionId: json['institution_id'] as String,
    institutionName: json['institution_name'] as String? ?? '',
    unitId: json['unit_id'] as String?,
    unitName: json['unit_name'] as String?,
    groupId: json['group_id'] as String?,
    groupName: json['group_name'] as String?,
    activityId: json['activity_id'] as String?,
    activityName: json['activity_name'] as String?,
    role: json['role'] as String,
    isPlatform: json['is_platform'] as bool? ?? false,
  );
}

final class PersonChildContext {
  const PersonChildContext({
    required this.id,
    required this.institutionId,
    this.institutionName,
    this.unitId,
    this.unitName,
    this.groupId,
    this.groupName,
    this.childUnitLinkId,
    this.childGroupLinkId,
  });

  factory PersonChildContext.fromJson(Map<String, dynamic> json) {
    final unitLinks = json['unit_links'] as List<dynamic>? ?? const [];
    final unitLink = switch (unitLinks.firstOrNull) {
      final Map<dynamic, dynamic> value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };
    final groupLinks = unitLink['group_links'] as List<dynamic>? ?? const [];
    final groupLink = switch (groupLinks.firstOrNull) {
      final Map<dynamic, dynamic> value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };
    return PersonChildContext(
      id: (json['child_context_id'] ?? json['id']) as String,
      institutionId: json['institution_id'] as String,
      institutionName: json['institution_name'] as String?,
      unitId: (json['unit_id'] ?? unitLink['unit_id']) as String?,
      unitName: (json['unit_name'] ?? unitLink['unit_name']) as String?,
      groupId: (json['group_id'] ?? groupLink['group_id']) as String?,
      groupName: (json['group_name'] ?? groupLink['group_name']) as String?,
      childUnitLinkId: (json['child_unit_link_id'] ?? unitLink['id']) as String?,
      childGroupLinkId: (json['child_group_link_id'] ?? groupLink['id']) as String?,
    );
  }

  final String id;
  final String institutionId;
  final String? institutionName;
  final String? unitId;
  final String? unitName;
  final String? groupId;
  final String? groupName;
  final String? childUnitLinkId;
  final String? childGroupLinkId;

  PersonChildContext copyWith({
    String? unitId,
    String? unitName,
    String? groupId,
    String? groupName,
  }) => PersonChildContext(
    id: id,
    institutionId: institutionId,
    institutionName: institutionName,
    unitId: unitId ?? this.unitId,
    unitName: unitName ?? this.unitName,
    groupId: groupId ?? this.groupId,
    groupName: groupName ?? this.groupName,
    childUnitLinkId: childUnitLinkId,
    childGroupLinkId: childGroupLinkId,
  );
}

final class PersonDirectoryItem {
  const PersonDirectoryItem({
    required this.id,
    this.tenantId = 'tenant-coelo',
    this.firstName,
    this.lastName,
    required this.displayName,
    this.legalName,
    required this.type,
    required this.status,
    this.authLink = AuthLinkStatus.unlinked,
    this.memberships = const [],
    this.childContexts = const [],
    this.platformMembershipSummary,
    this.guardianLinksSummary,
    this.maskedContact,
    this.linkedChildrenCount = 0,
    this.accompaniedStudentsCount = 0,
    this.linkedGuardiansCount = 0,
    this.stateCode,
    this.municipalityId,
    this.neighborhoodId,
    required this.updatedAt,
  });

  factory PersonDirectoryItem.fromJson(Map<String, dynamic> json) {
    final rawMemberships = json['memberships'] as List<dynamic>? ?? const [];
    final rawChildContexts = json['child_contexts'] as List<dynamic>? ?? const [];
    final hasActiveLogin = json['has_active_login'] as bool? ?? false;
    return PersonDirectoryItem(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? 'tenant-coelo',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String,
      legalName: json['legal_name'] as String?,
      type: PersonType.fromDatabase((json['person_type'] ?? json['type']) as String),
      status: PersonStatus.fromDatabase(json['status'] as String),
      authLink: hasActiveLogin
          ? AuthLinkStatus.linked
          : AuthLinkStatus.fromDatabase(json['auth_link'] as String? ?? 'unlinked'),
      memberships: rawMemberships
          .map((value) => PersonMembership.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false),
      childContexts: rawChildContexts
          .map((value) => PersonChildContext.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false),
      platformMembershipSummary: json['platform_membership_summary'] as String?,
      guardianLinksSummary: json['guardian_links_summary'] as String?,
      maskedContact: null,
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

  final String id;
  final String tenantId;
  final String? firstName;
  final String? lastName;
  final String displayName;
  final String? legalName;
  final PersonType type;
  final PersonStatus status;
  final AuthLinkStatus authLink;
  final List<PersonMembership> memberships;
  final List<PersonChildContext> childContexts;
  final String? platformMembershipSummary;
  final String? guardianLinksSummary;
  final String? maskedContact;
  final int linkedChildrenCount;
  final int accompaniedStudentsCount;
  final int linkedGuardiansCount;
  final String? stateCode;
  final String? municipalityId;
  final String? neighborhoodId;
  final DateTime updatedAt;

  bool get isEditable => type != PersonType.service;
  String get initials {
    final words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String get institutionSummary => memberships
      .map((item) => item.institutionName)
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(', ');
  String get roleSummary => memberships.map((item) => item.role).toSet().join(', ');
  String get unitSummary => memberships
      .map((item) => item.unitName)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(', ');
  String get groupSummary => memberships
      .map((item) => item.groupName)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(', ');
  String get activitySummary => memberships
      .map((item) => item.activityName)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .join(', ');

  int get institutionCount => memberships.map((item) => item.institutionId).toSet().length;
  int get unitCount => memberships.map((item) => item.unitId).whereType<String>().toSet().length;
  int get groupCount => memberships.map((item) => item.groupId).whereType<String>().toSet().length;
  int get activityCount =>
      memberships.map((item) => item.activityId).whereType<String>().toSet().length;

  bool get isGuardian => memberships.any((item) => item.role == 'guardian');
  bool get isInstitutionalTeam =>
      memberships.any((item) => !const {'guardian', 'student'}.contains(item.role));
  bool matchesSegment(PersonDirectorySegment segment) => switch (segment) {
    PersonDirectorySegment.all => true,
    PersonDirectorySegment.institutionalTeam => isInstitutionalTeam,
    PersonDirectorySegment.guardians => isGuardian,
    PersonDirectorySegment.children => type == PersonType.child,
    PersonDirectorySegment.dualProfile => isGuardian && isInstitutionalTeam,
  };

  PersonDirectoryItem copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    String? legalName,
    List<PersonMembership>? memberships,
    List<PersonChildContext>? childContexts,
    int? linkedChildrenCount,
    int? accompaniedStudentsCount,
    int? linkedGuardiansCount,
    DateTime? updatedAt,
  }) => PersonDirectoryItem(
    id: id,
    tenantId: tenantId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    displayName: displayName ?? this.displayName,
    legalName: legalName ?? this.legalName,
    type: type,
    status: status,
    authLink: authLink,
    memberships: memberships ?? this.memberships,
    childContexts: childContexts ?? this.childContexts,
    platformMembershipSummary: platformMembershipSummary,
    guardianLinksSummary: guardianLinksSummary,
    maskedContact: maskedContact,
    linkedChildrenCount: linkedChildrenCount ?? this.linkedChildrenCount,
    accompaniedStudentsCount: accompaniedStudentsCount ?? this.accompaniedStudentsCount,
    linkedGuardiansCount: linkedGuardiansCount ?? this.linkedGuardiansCount,
    stateCode: stateCode,
    municipalityId: municipalityId,
    neighborhoodId: neighborhoodId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

final class PersonDirectoryQuery {
  static const cardsPageSize = 11;
  static const tablePageSize = 8;
  static const selectablePageSizes = <int>[20, 50, 100];
  static const allowedPageSizes = <int>[cardsPageSize, tablePageSize, ...selectablePageSizes];

  PersonDirectoryQuery({
    this.search = '',
    Set<PersonType> types = const {},
    Set<PersonStatus> statuses = const {},
    Set<String> institutionIds = const {},
    Set<String> unitIds = const {},
    Set<String> groupIds = const {},
    Set<String> activityIds = const {},
    Set<String> stateCodes = const {},
    Set<String> municipalityIds = const {},
    Set<String> neighborhoodIds = const {},
    Set<String> contextualRoles = const {},
    Set<AuthLinkStatus> authLinks = const {},
    this.page = 0,
    this.pageSize = cardsPageSize,
    this.sortColumn = PersonDirectorySortColumn.displayName,
    this.sortAscending = true,
    this.segment = PersonDirectorySegment.all,
  }) : assert(page >= 0),
       assert(allowedPageSizes.contains(pageSize)),
       types = Set.unmodifiable(types),
       statuses = Set.unmodifiable(statuses),
       institutionIds = Set.unmodifiable(institutionIds),
       unitIds = Set.unmodifiable(unitIds),
       groupIds = Set.unmodifiable(groupIds),
       activityIds = Set.unmodifiable(activityIds),
       stateCodes = Set.unmodifiable(stateCodes),
       municipalityIds = Set.unmodifiable(municipalityIds),
       neighborhoodIds = Set.unmodifiable(neighborhoodIds),
       contextualRoles = Set.unmodifiable(contextualRoles),
       authLinks = Set.unmodifiable(authLinks);

  factory PersonDirectoryQuery.cards() => PersonDirectoryQuery();
  factory PersonDirectoryQuery.table() => PersonDirectoryQuery(pageSize: tablePageSize);

  final String search;
  final Set<PersonType> types;
  final Set<PersonStatus> statuses;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final Set<String> groupIds;
  final Set<String> activityIds;
  final Set<String> stateCodes;
  final Set<String> municipalityIds;
  final Set<String> neighborhoodIds;
  final Set<String> contextualRoles;
  final Set<AuthLinkStatus> authLinks;
  final int page;
  final int pageSize;
  final PersonDirectorySortColumn sortColumn;
  final bool sortAscending;
  final PersonDirectorySegment segment;

  int get offset => page * pageSize;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      types.isNotEmpty ||
      statuses.isNotEmpty ||
      institutionIds.isNotEmpty ||
      unitIds.isNotEmpty ||
      groupIds.isNotEmpty ||
      activityIds.isNotEmpty ||
      stateCodes.isNotEmpty ||
      municipalityIds.isNotEmpty ||
      neighborhoodIds.isNotEmpty ||
      contextualRoles.isNotEmpty ||
      authLinks.isNotEmpty ||
      segment != PersonDirectorySegment.all;
}

final class PersonDirectoryPage {
  const PersonDirectoryPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
  final List<PersonDirectoryItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
  bool get hasPrevious => page > 0;
  bool get hasNext => offset + items.length < totalCount;
  int get offset => page * pageSize;
}

final class PersonFilterOption {
  const PersonFilterOption(
    this.id,
    this.label, {
    this.institutionId,
    this.unitId,
    this.groupId,
    this.stateCode,
    this.municipalityId,
  });
  final String id;
  final String label;
  final String? institutionId;
  final String? unitId;
  final String? groupId;
  final String? stateCode;
  final String? municipalityId;
}

final class PersonDirectoryFilterOptions {
  const PersonDirectoryFilterOptions({
    this.institutions = const [],
    this.units = const [],
    this.groups = const [],
    this.roles = const [],
    this.activities = const [],
    this.states = const [],
    this.municipalities = const [],
    this.neighborhoods = const [],
  });
  final List<PersonFilterOption> institutions;
  final List<PersonFilterOption> units;
  final List<PersonFilterOption> groups;
  final List<PersonFilterOption> roles;
  final List<PersonFilterOption> activities;
  final List<PersonFilterOption> states;
  final List<PersonFilterOption> municipalities;
  final List<PersonFilterOption> neighborhoods;
}

final class PersonMembershipDraft {
  const PersonMembershipDraft({
    required this.institutionId,
    this.unitId,
    this.groupId,
    required this.role,
  });
  final String institutionId;
  final String? unitId;
  final String? groupId;
  final String role;
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'unit_id': unitId,
    'group_id': groupId,
    'role': role,
  };
}

final class PersonChildContextDraft {
  const PersonChildContextDraft({required this.institutionId, this.unitId, this.groupId});

  final String institutionId;
  final String? unitId;
  final String? groupId;

  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'unit_id': unitId,
    'group_id': groupId,
  };
}

final class PersonDraft {
  const PersonDraft({
    required this.type,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.legalName,
    this.memberships = const [],
    this.childContexts = const [],
  });
  final PersonType type;
  final String firstName;
  final String lastName;
  final String displayName;
  final String legalName;
  final List<PersonMembershipDraft> memberships;
  final List<PersonChildContextDraft> childContexts;
  Map<String, dynamic> toJson() => {
    'type': type.databaseValue,
    'first_name': firstName,
    'last_name': lastName,
    'display_name': displayName,
    'legal_name': legalName,
    'memberships': memberships.map((item) => item.toJson()).toList(growable: false),
    'child_contexts': childContexts.map((item) => item.toJson()).toList(growable: false),
  };
}

enum PersonMembershipChangeKind { add, update, remove }

final class PersonMembershipChange {
  const PersonMembershipChange._(this.kind, this.membership);
  factory PersonMembershipChange.add(PersonMembership value) =>
      PersonMembershipChange._(PersonMembershipChangeKind.add, value);
  factory PersonMembershipChange.update(PersonMembership value) =>
      PersonMembershipChange._(PersonMembershipChangeKind.update, value);
  factory PersonMembershipChange.remove(PersonMembership value) =>
      PersonMembershipChange._(PersonMembershipChangeKind.remove, value);
  final PersonMembershipChangeKind kind;
  final PersonMembership membership;
  Map<String, dynamic> toJson() => {
    'operation': kind.name,
    'assignment_id': kind == PersonMembershipChangeKind.add ? null : membership.id,
    'membership_id': membership.membershipId,
    'institution_id': membership.institutionId,
    'unit_id': membership.unitId,
    'group_id': membership.groupId,
    'role': membership.role,
  };
}

enum PersonChildContextChangeKind { add, update, remove }

final class PersonChildContextChange {
  const PersonChildContextChange._(this.kind, this.context);
  factory PersonChildContextChange.add(PersonChildContext value) =>
      PersonChildContextChange._(PersonChildContextChangeKind.add, value);
  factory PersonChildContextChange.update(PersonChildContext value) =>
      PersonChildContextChange._(PersonChildContextChangeKind.update, value);
  factory PersonChildContextChange.remove(PersonChildContext value) =>
      PersonChildContextChange._(PersonChildContextChangeKind.remove, value);
  final PersonChildContextChangeKind kind;
  final PersonChildContext context;
  Map<String, dynamic> toJson() => {
    'operation': kind.name,
    'child_context_id': kind == PersonChildContextChangeKind.add ? null : context.id,
    'institution_id': context.institutionId,
    'unit_id': context.unitId,
    'group_id': context.groupId,
    'child_unit_link_id': ?context.childUnitLinkId,
    'child_group_link_id': ?context.childGroupLinkId,
  };
}

final class PersonUpdate {
  const PersonUpdate({
    required this.personId,
    required this.expectedUpdatedAt,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.legalName,
    this.membershipChanges = const [],
    this.childContextChanges = const [],
  });
  final String personId;
  final DateTime expectedUpdatedAt;
  final String firstName;
  final String lastName;
  final String displayName;
  final String legalName;
  final List<PersonMembershipChange> membershipChanges;
  final List<PersonChildContextChange> childContextChanges;
  Map<String, dynamic> toJson() => {
    'person_id': personId,
    'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
    'first_name': firstName,
    'last_name': lastName,
    'display_name': displayName,
    'legal_name': legalName,
    'membership_changes': membershipChanges.map((item) => item.toJson()).toList(growable: false),
    'child_context_changes': childContextChanges
        .map((item) => item.toJson())
        .toList(growable: false),
  };
}

abstract interface class PersonDirectoryRepository {
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query);
  Future<PersonDirectoryFilterOptions> fetchFilterOptions();
  Future<PersonDirectoryItem> fetchDetail(String personId);
  Future<PersonDirectoryItem> createDraft(PersonDraft draft);
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update);
}

final class PersonDirectoryUnauthorizedException implements Exception {
  const PersonDirectoryUnauthorizedException();
}

final class PersonDirectoryConflictException implements Exception {
  const PersonDirectoryConflictException();
}

final class PersonDirectoryReadOnlyException implements Exception {
  const PersonDirectoryReadOnlyException();
}

final class PersonDirectoryUnavailableException implements Exception {
  const PersonDirectoryUnavailableException();
}
