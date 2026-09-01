import '../../features/people/domain/person_directory.dart';
import '../../features/institutions/data/fake_institution_directory_repository.dart';
import 'development_access_health_fixture_catalog.dart';

List<PersonDirectoryItem> _buildSamplePeople(DevelopmentAccessHealthFixtureCatalog catalog) {
  final institutionsById = {for (final item in demoInstitutionRecords) item.id: item};
  final guardianIds = catalog.guardians.map((item) => item.id).toSet();
  final teamById = {for (final item in catalog.teamMembers) item.id: item};

  PersonMembership membership({
    required String personId,
    required String institutionId,
    required String role,
    DevelopmentChildFixture? child,
  }) {
    final institution = institutionsById[institutionId]!;
    final unit = child == null
        ? institution.units.first
        : institution.units.firstWhere(
            (item) => item.id == child.unitId,
            orElse: () => institution.units.first,
          );
    final group = child == null
        ? unit.groups.first
        : unit.groups.firstWhere(
            (item) => item.id == child.groupId,
            orElse: () => unit.groups.first,
          );
    return PersonMembership(
      id: 'membership-$personId-$role-$institutionId',
      institutionId: institution.id,
      institutionName: institution.publicName,
      unitId: unit.id,
      unitName: unit.name,
      groupId: group.id,
      groupName: group.name,
      role: role,
    );
  }

  final children = <PersonDirectoryItem>[
    for (var index = 0; index < catalog.children.length; index++)
      () {
        final child = catalog.children[index];
        final names = _personNameParts(child.name);
        final institution = institutionsById[child.institutionId]!;
        return PersonDirectoryItem(
          id: child.id,
          firstName: names.$1,
          lastName: names.$2,
          displayName: child.name,
          legalName: child.name,
          type: PersonType.child,
          status: PersonStatus.active,
          memberships: [
            membership(
              personId: child.id,
              institutionId: child.institutionId,
              role: 'student',
              child: child,
            ),
          ],
          guardianLinksSummary: '${child.guardianIds.length} responsáveis vinculados',
          linkedGuardiansCount: child.guardianIds.length,
          stateCode: institution.state,
          municipalityId: _municipalityId(institution.city),
          neighborhoodId: _neighborhoodId(institution.district),
          updatedAt: DateTime.utc(2026, 7, 29, 12).add(Duration(seconds: index)),
        );
      }(),
  ];

  final adults = <PersonDirectoryItem>[
    for (var index = 0; index < catalog.guardians.length; index++)
      () {
        final adult = catalog.guardians[index];
        final names = _personNameParts(adult.name);
        final linkedChildren = catalog.children
            .where((child) => child.guardianIds.contains(adult.id))
            .toList(growable: false);
        final isDualProfile = adult.profileCodes.contains('institution_collaborator');
        final contextualInstitutionIds = {
          ...adult.institutionIds,
          ...linkedChildren.map((child) => child.institutionId),
        };
        final memberships = <PersonMembership>[
          for (final institutionId in contextualInstitutionIds)
            membership(
              personId: adult.id,
              institutionId: institutionId,
              role: 'guardian',
              child: linkedChildren
                  .where((child) => child.institutionId == institutionId)
                  .firstOrNull,
            ),
          if (isDualProfile)
            membership(
              personId: adult.id,
              institutionId: teamById[adult.id]?.institutionIds.first ?? adult.institutionIds.first,
              role: 'educator',
              child: linkedChildren.firstOrNull,
            ),
        ];
        final institution = institutionsById[adult.institutionIds.first]!;
        return PersonDirectoryItem(
          id: adult.id,
          firstName: names.$1,
          lastName: names.$2,
          displayName: adult.name,
          legalName: adult.name,
          type: PersonType.adult,
          status: index % 17 == 0 ? PersonStatus.draft : PersonStatus.active,
          authLink: index % 6 == 0 ? AuthLinkStatus.pending : AuthLinkStatus.linked,
          maskedContact: _maskedEmail(adult.email),
          memberships: memberships,
          childContexts: [
            for (final child in linkedChildren)
              PersonChildContext(
                id: child.id,
                institutionId: child.institutionId,
                institutionName: child.institutionName,
                unitId: child.unitId,
                unitName: child.unitName,
                groupId: child.groupId,
                groupName: child.groupName,
              ),
          ],
          linkedChildrenCount: linkedChildren.length,
          accompaniedStudentsCount: isDualProfile ? 8 + index % 9 : 0,
          linkedGuardiansCount: isDualProfile ? 6 + index % 5 : 0,
          stateCode: institution.state,
          municipalityId: _municipalityId(institution.city),
          neighborhoodId: _neighborhoodId(institution.district),
          updatedAt: DateTime.utc(2026, 7, 29, 13).add(Duration(seconds: index)),
        );
      }(),
    for (var index = 0; index < catalog.teamMembers.length; index++)
      if (!guardianIds.contains(catalog.teamMembers[index].id))
        () {
          final adult = catalog.teamMembers[index];
          final names = _personNameParts(adult.name);
          final institution = institutionsById[adult.institutionIds.first]!;
          return PersonDirectoryItem(
            id: adult.id,
            firstName: names.$1,
            lastName: names.$2,
            displayName: adult.name,
            legalName: adult.name,
            type: PersonType.adult,
            status: PersonStatus.active,
            authLink: AuthLinkStatus.linked,
            maskedContact: _maskedEmail(adult.email),
            memberships: [
              membership(
                personId: adult.id,
                institutionId: adult.institutionIds.first,
                role: 'educator',
              ),
            ],
            accompaniedStudentsCount: 10 + index % 8,
            linkedGuardiansCount: 6 + index % 5,
            stateCode: institution.state,
            municipalityId: _municipalityId(institution.city),
            neighborhoodId: _neighborhoodId(institution.district),
            updatedAt: DateTime.utc(2026, 7, 29, 14).add(Duration(seconds: index)),
          );
        }(),
  ];

  return List.unmodifiable([...children, ...adults]);
}

(String, String) _personNameParts(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return (parts.first, parts.skip(1).join(' '));
}

String _municipalityId(String city) => 'municipality-${city.toLowerCase().replaceAll(' ', '-')}';
String _neighborhoodId(String district) =>
    'neighborhood-${district.toLowerCase().replaceAll(' ', '-')}';

String _maskedEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return '***';
  return '${email[0]}***${email.substring(at)}';
}

/// Deterministic repository used only by the authenticated development preview.
final class DevelopmentPersonDirectoryRepository implements PersonDirectoryRepository {
  DevelopmentPersonDirectoryRepository({
    List<PersonDirectoryItem>? seed,
    this.tenantId = 'tenant-coelo',
    this.fail = false,
    this.unauthorized = false,
  }) : people = [...(seed ?? samplePeople)];

  final String tenantId;
  final bool fail;
  final bool unauthorized;
  final List<PersonDirectoryItem> people;

  static final samplePeople = _buildSamplePeople(DevelopmentAccessHealthFixtureCatalog.standard());

  void _guard() {
    if (unauthorized) throw const PersonDirectoryUnauthorizedException();
    if (fail) throw const PersonDirectoryUnavailableException();
  }

  Iterable<PersonDirectoryItem> get _scoped => people.where((item) => item.tenantId == tenantId);

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) async {
    _guard();
    var values = _scoped;
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      values = values.where((item) => item.displayName.toLowerCase().contains(search));
    }
    if (query.types.isNotEmpty) values = values.where((item) => query.types.contains(item.type));
    if (query.statuses.isNotEmpty) {
      values = values.where((item) => query.statuses.contains(item.status));
    }
    if (query.authLinks.isNotEmpty) {
      values = values.where((item) => query.authLinks.contains(item.authLink));
    }
    if (query.segment != PersonDirectorySegment.all) {
      values = values.where((item) => item.matchesSegment(query.segment));
    }
    bool membershipMatches(PersonMembership membership) =>
        (query.institutionIds.isEmpty || query.institutionIds.contains(membership.institutionId)) &&
        (query.unitIds.isEmpty || query.unitIds.contains(membership.unitId)) &&
        (query.groupIds.isEmpty || query.groupIds.contains(membership.groupId)) &&
        (query.activityIds.isEmpty || query.activityIds.contains(membership.activityId)) &&
        (query.contextualRoles.isEmpty || query.contextualRoles.contains(membership.role));
    if (query.institutionIds.isNotEmpty ||
        query.unitIds.isNotEmpty ||
        query.groupIds.isNotEmpty ||
        query.activityIds.isNotEmpty ||
        query.contextualRoles.isNotEmpty) {
      values = values.where((item) => item.memberships.any(membershipMatches));
    }
    if (query.stateCodes.isNotEmpty) {
      values = values.where((item) => query.stateCodes.contains(item.stateCode));
    }
    if (query.municipalityIds.isNotEmpty) {
      values = values.where((item) => query.municipalityIds.contains(item.municipalityId));
    }
    if (query.neighborhoodIds.isNotEmpty) {
      values = values.where((item) => query.neighborhoodIds.contains(item.neighborhoodId));
    }
    final sorted = values.toList()
      ..sort((a, b) {
        final first = switch (query.sortColumn) {
          PersonDirectorySortColumn.displayName => a.displayName,
          PersonDirectorySortColumn.type => a.type.label,
          PersonDirectorySortColumn.status => a.status.label,
          PersonDirectorySortColumn.institution => a.institutionSummary,
          PersonDirectorySortColumn.unit => a.memberships.firstOrNull?.unitName ?? '',
          PersonDirectorySortColumn.group => a.memberships.firstOrNull?.groupName ?? '',
          PersonDirectorySortColumn.role => a.roleSummary,
          PersonDirectorySortColumn.authLink => a.authLink.label,
        };
        final second = switch (query.sortColumn) {
          PersonDirectorySortColumn.displayName => b.displayName,
          PersonDirectorySortColumn.type => b.type.label,
          PersonDirectorySortColumn.status => b.status.label,
          PersonDirectorySortColumn.institution => b.institutionSummary,
          PersonDirectorySortColumn.unit => b.memberships.firstOrNull?.unitName ?? '',
          PersonDirectorySortColumn.group => b.memberships.firstOrNull?.groupName ?? '',
          PersonDirectorySortColumn.role => b.roleSummary,
          PersonDirectorySortColumn.authLink => b.authLink.label,
        };
        final result = first.compareTo(second);
        return query.sortAscending ? result : -result;
      });
    final start = query.offset.clamp(0, sorted.length);
    final end = (start + query.pageSize).clamp(start, sorted.length);
    return PersonDirectoryPage(
      items: sorted.sublist(start, end),
      totalCount: sorted.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() async {
    _guard();
    final states = <String, String>{};
    final municipalities = <String, ({String name, String state})>{};
    final neighborhoods = <String, ({String name, String state, String municipality})>{};
    for (final institution in demoInstitutionRecords) {
      states[institution.state] = institution.state;
      final municipalityId = 'municipality-${institution.city.toLowerCase().replaceAll(' ', '-')}';
      municipalities[municipalityId] = (name: institution.city, state: institution.state);
      final neighborhoodId =
          'neighborhood-${institution.district.toLowerCase().replaceAll(' ', '-')}';
      neighborhoods[neighborhoodId] = (
        name: institution.district,
        state: institution.state,
        municipality: municipalityId,
      );
    }
    const activityNames = [
      'Música',
      'Dança',
      'Capoeira',
      'Biologia',
      'Robótica',
      'Teatro',
      'Xadrez',
      'Matemática',
      'Inglês',
      'Artes',
    ];
    return PersonDirectoryFilterOptions(
      institutions: [
        for (final institution in demoInstitutionRecords)
          PersonFilterOption(institution.id, institution.publicName),
      ],
      units: [
        for (final institution in demoInstitutionRecords)
          for (final unit in institution.units)
            PersonFilterOption(unit.id, unit.name, institutionId: institution.id),
      ],
      groups: [
        for (final institution in demoInstitutionRecords)
          for (final unit in institution.units)
            for (final group in unit.groups)
              PersonFilterOption(
                group.id,
                group.name,
                institutionId: institution.id,
                unitId: unit.id,
              ),
      ],
      roles: const [
        PersonFilterOption('guardian', 'Responsável'),
        PersonFilterOption('student', 'Aluno'),
        PersonFilterOption('educator', 'Educador'),
        PersonFilterOption('integration', 'Integração'),
      ],
      activities: [
        for (var index = 0; index < 30; index++)
          PersonFilterOption(
            'activity-${index + 1}',
            '${activityNames[index % activityNames.length]} ${index ~/ activityNames.length + 1}',
            institutionId: demoInstitutionRecords[index % demoInstitutionRecords.length].id,
          ),
      ],
      states: [for (final entry in states.entries) PersonFilterOption(entry.key, entry.value)],
      municipalities: [
        for (final entry in municipalities.entries)
          PersonFilterOption(entry.key, entry.value.name, stateCode: entry.value.state),
      ],
      neighborhoods: [
        for (final entry in neighborhoods.entries)
          PersonFilterOption(
            entry.key,
            entry.value.name,
            stateCode: entry.value.state,
            municipalityId: entry.value.municipality,
          ),
      ],
    );
  }

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) async {
    _guard();
    return _scoped.firstWhere(
      (item) => item.id == personId,
      orElse: () => throw StateError('Person detail not found in development repository.'),
    );
  }

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) async {
    _guard();
    if (draft.type == PersonType.service) throw const PersonDirectoryReadOnlyException();
    final created = PersonDirectoryItem(
      id: 'person-${people.length + 1}',
      tenantId: tenantId,
      displayName: draft.displayName,
      firstName: draft.firstName,
      lastName: draft.lastName,
      legalName: draft.legalName,
      type: draft.type,
      status: PersonStatus.draft,
      memberships: [
        for (var index = 0; index < draft.memberships.length; index++)
          PersonMembership(
            id: 'membership-new-$index',
            institutionId: draft.memberships[index].institutionId,
            institutionName: draft.memberships[index].institutionId,
            unitId: draft.memberships[index].unitId,
            groupId: draft.memberships[index].groupId,
            role: draft.memberships[index].role,
          ),
      ],
      childContexts: [
        for (var index = 0; index < draft.childContexts.length; index++)
          PersonChildContext(
            id: 'child-context-new-$index',
            institutionId: draft.childContexts[index].institutionId,
            unitId: draft.childContexts[index].unitId,
            groupId: draft.childContexts[index].groupId,
          ),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
    people.add(created);
    return created;
  }

  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) async {
    _guard();
    final index = people.indexWhere(
      (item) => item.id == update.personId && item.tenantId == tenantId,
    );
    if (index < 0) throw StateError('Person not found');
    final current = people[index];
    if (!current.isEditable) throw const PersonDirectoryReadOnlyException();
    if (current.updatedAt != update.expectedUpdatedAt) {
      throw const PersonDirectoryConflictException();
    }
    final memberships = [...current.memberships];
    for (final change in update.membershipChanges) {
      final membershipIndex = memberships.indexWhere((item) => item.id == change.membership.id);
      switch (change.kind) {
        case PersonMembershipChangeKind.add:
          memberships.add(change.membership);
        case PersonMembershipChangeKind.update:
          if (membershipIndex >= 0) memberships[membershipIndex] = change.membership;
        case PersonMembershipChangeKind.remove:
          if (membershipIndex >= 0) memberships.removeAt(membershipIndex);
      }
    }
    final childContexts = [...current.childContexts];
    for (final change in update.childContextChanges) {
      final contextIndex = childContexts.indexWhere((item) => item.id == change.context.id);
      switch (change.kind) {
        case PersonChildContextChangeKind.add:
          childContexts.add(change.context);
        case PersonChildContextChangeKind.update:
          if (contextIndex >= 0) childContexts[contextIndex] = change.context;
        case PersonChildContextChangeKind.remove:
          if (contextIndex >= 0) childContexts.removeAt(contextIndex);
      }
    }
    final updated = current.copyWith(
      firstName: update.firstName,
      lastName: update.lastName,
      displayName: update.displayName,
      legalName: update.legalName,
      memberships: memberships,
      childContexts: childContexts,
      updatedAt: current.updatedAt.add(const Duration(microseconds: 1)),
    );
    people[index] = updated;
    return updated;
  }
}
