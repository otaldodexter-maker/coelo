import '../../features/people/domain/person_directory.dart';
import '../../features/institutions/data/fake_institution_directory_repository.dart';

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

  static final samplePeople = List<PersonDirectoryItem>.generate(400, (index) {
    final institution = demoInstitutionRecords[index % demoInstitutionRecords.length];
    final unit = institution.units[index % institution.units.length];
    final group = unit.groups[index % unit.groups.length];
    final secondaryInstitution =
        demoInstitutionRecords[(index + 3) % demoInstitutionRecords.length];
    final secondaryUnit =
        secondaryInstitution.units[(index + 1) % secondaryInstitution.units.length];
    final secondaryGroup = secondaryUnit.groups[(index + 2) % secondaryUnit.groups.length];
    final type = index % 37 == 0
        ? PersonType.service
        : index % 5 < 2
        ? PersonType.child
        : PersonType.adult;
    final dualProfile = type == PersonType.adult && index % 7 == 0;
    final primaryRole = type == PersonType.child
        ? 'student'
        : type == PersonType.service
        ? 'integration'
        : dualProfile
        ? 'guardian'
        : index.isEven
        ? 'educator'
        : 'guardian';
    return PersonDirectoryItem(
      id: 'person-$index',
      firstName: type == PersonType.service ? null : 'Pessoa',
      lastName: type == PersonType.service ? null : '${index + 1}',
      displayName: switch (type) {
        PersonType.adult =>
          index.isEven ? 'Educador Coelo ${index + 1}' : 'Responsável Coelo ${index + 1}',
        PersonType.child => 'Criança Coelo ${index + 1}',
        PersonType.service => 'Serviço Coelo ${index + 1}',
      },
      legalName: type == PersonType.service ? null : 'Pessoa Coelo ${index + 1}',
      type: type,
      status: index % 4 == 0 ? PersonStatus.draft : PersonStatus.active,
      authLink: type == PersonType.adult && index.isEven
          ? AuthLinkStatus.linked
          : AuthLinkStatus.unlinked,
      maskedContact: type == PersonType.child
          ? null
          : index.isEven
          ? 'p***${index + 1}@exemplo.test'
          : '(11) 9****-${(1000 + index).toString().padLeft(4, '0')}',
      stateCode: index.isEven ? 'SP' : 'RJ',
      municipalityId: index.isEven ? 'municipality-sp' : 'municipality-rj',
      neighborhoodId: index.isEven ? 'neighborhood-centro' : 'neighborhood-jardim',
      memberships: [
        PersonMembership(
          id: 'membership-$index-a',
          institutionId: institution.id,
          institutionName: institution.publicName,
          unitId: unit.id,
          unitName: unit.name,
          groupId: group.id,
          groupName: group.name,
          activityId: 'activity-${index % 30 + 1}',
          activityName: index.isEven ? 'Música' : 'Robótica',
          role: primaryRole,
        ),
        PersonMembership(
          id: 'membership-$index-b',
          institutionId: secondaryInstitution.id,
          institutionName: secondaryInstitution.publicName,
          unitId: secondaryUnit.id,
          unitName: secondaryUnit.name,
          groupId: secondaryGroup.id,
          groupName: secondaryGroup.name,
          activityId: 'activity-${(index + 11) % 30 + 1}',
          activityName: index.isEven ? 'Teatro' : 'Leitura',
          role: type == PersonType.service
              ? 'integration'
              : dualProfile
              ? 'educator'
              : 'member',
        ),
      ],
      childContexts: type == PersonType.adult && (primaryRole == 'guardian' || dualProfile)
          ? [
              for (var childIndex = 0; childIndex < index % 3 + 1; childIndex++)
                PersonChildContext(
                  id: 'child-context-$index-$childIndex',
                  institutionId: institution.id,
                  institutionName: institution.publicName,
                  unitId: unit.id,
                  unitName: unit.name,
                  groupId: unit.groups[(index + childIndex) % unit.groups.length].id,
                  groupName: unit.groups[(index + childIndex) % unit.groups.length].name,
                ),
            ]
          : const [],
      platformMembershipSummary: type == PersonType.service ? 'Serviço interno' : null,
      guardianLinksSummary: type == PersonType.child
          ? '${2 + index % 2} responsáveis vinculados'
          : null,
      linkedChildrenCount: type == PersonType.adult && primaryRole == 'guardian'
          ? index % 3 + 1
          : 0,
      accompaniedStudentsCount:
          type == PersonType.adult && (primaryRole == 'educator' || dualProfile)
          ? 8 + index % 9
          : 0,
      linkedGuardiansCount: type == PersonType.child
          ? 2
          : type == PersonType.adult && (primaryRole == 'educator' || dualProfile)
          ? 6 + index % 5
          : 0,
      updatedAt: DateTime.utc(2026, 7, 29, 12, 0, index),
    );
  });

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
