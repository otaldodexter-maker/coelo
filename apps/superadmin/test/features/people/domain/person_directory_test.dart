import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  test('segments classify institutional team, guardians, children and dual profiles', () {
    final people = FakePersonDirectoryRepository.samplePeople;

    expect(
      people.where((person) => person.matchesSegment(PersonDirectorySegment.institutionalTeam)),
      isNotEmpty,
    );
    expect(
      people.where((person) => person.matchesSegment(PersonDirectorySegment.guardians)),
      isNotEmpty,
    );
    expect(
      people.where((person) => person.matchesSegment(PersonDirectorySegment.children)),
      isNotEmpty,
    );
    expect(
      people.where((person) => person.matchesSegment(PersonDirectorySegment.dualProfile)),
      isNotEmpty,
    );
    expect(people.every((person) => person.matchesSegment(PersonDirectorySegment.all)), isTrue);
  });

  test('query reports progressive context and location filters as active', () {
    final query = PersonDirectoryQuery(
      activityIds: {'activity-0'},
      stateCodes: {'SP'},
      municipalityIds: {'municipality-sp'},
      neighborhoodIds: {'neighborhood-centro'},
    );

    expect(query.hasActiveFilters, isTrue);
  });

  test('cards and table use the approved default page sizes', () {
    expect(PersonDirectoryQuery.cards().pageSize, 11);
    expect(PersonDirectoryQuery.table().pageSize, 8);
    expect(PersonDirectoryQuery.selectablePageSizes, [20, 50, 100]);
  });

  test('query reports every authorized filter as active', () {
    final queries = [
      PersonDirectoryQuery(search: 'ana'),
      PersonDirectoryQuery(types: {PersonType.adult}),
      PersonDirectoryQuery(statuses: {PersonStatus.draft}),
      PersonDirectoryQuery(institutionIds: {'i1'}),
      PersonDirectoryQuery(unitIds: {'u1'}),
      PersonDirectoryQuery(groupIds: {'g1'}),
      PersonDirectoryQuery(contextualRoles: {'guardian'}),
      PersonDirectoryQuery(authLinks: {AuthLinkStatus.linked}),
    ];

    expect(queries.every((query) => query.hasActiveFilters), isTrue);
  });

  test('service records are read-only and expose safe initials', () {
    final person = PersonDirectoryItem.fromJson({
      'id': 'service-1',
      'display_name': 'Serviço Integração',
      'person_type': 'service',
      'status': 'active',
      'has_active_login': false,
      'updated_at': '2026-07-29T12:00:00Z',
    });

    expect(person.initials, 'SI');
    expect(person.isEditable, isFalse);
    expect(person.authLink, AuthLinkStatus.unlinked);
    expect(person.updatedAt, DateTime.utc(2026, 7, 29, 12));
  });

  test('draft command excludes unapproved and sensitive fields', () {
    const draft = PersonDraft(
      type: PersonType.adult,
      firstName: 'Ana',
      lastName: 'Lima',
      displayName: 'Ana Lima',
      legalName: 'Ana Maria Lima',
      memberships: [
        PersonMembershipDraft(institutionId: 'i1', unitId: 'u1', groupId: 'g1', role: 'guardian'),
      ],
    );

    expect(draft.toJson(), {
      'type': 'adult',
      'first_name': 'Ana',
      'last_name': 'Lima',
      'display_name': 'Ana Lima',
      'legal_name': 'Ana Maria Lima',
      'memberships': [
        {'institution_id': 'i1', 'unit_id': 'u1', 'group_id': 'g1', 'role': 'guardian'},
      ],
      'child_contexts': <Object>[],
    });
  });

  test('child contexts remain separate from contextual memberships', () {
    final person = PersonDirectoryItem.fromJson({
      'id': 'child-1',
      'display_name': 'Bia',
      'person_type': 'child',
      'status': 'draft',
      'updated_at': '2026-07-29T12:00:00Z',
      'memberships': <Object>[],
      'child_contexts': [
        {'id': 'context-1', 'institution_id': 'i1', 'unit_id': 'u1', 'group_id': 'g1'},
      ],
    });

    expect(person.memberships, isEmpty);
    expect(person.childContexts.single.groupId, 'g1');
  });

  test('child draft serializes child contexts outside memberships', () {
    const draft = PersonDraft(
      type: PersonType.child,
      firstName: 'Bia',
      lastName: 'Lima',
      displayName: 'Bia Lima',
      legalName: 'Beatriz Lima',
      childContexts: [PersonChildContextDraft(institutionId: 'i1', unitId: 'u1', groupId: 'g1')],
    );

    expect(draft.toJson()['memberships'], isEmpty);
    expect(draft.toJson()['child_contexts'], [
      {'institution_id': 'i1', 'unit_id': 'u1', 'group_id': 'g1'},
    ]);
  });

  test('membership updates preserve membership and target one assignment', () {
    final membership = PersonMembership.fromJson({
      'assignment_id': 'assignment-1',
      'membership_id': 'membership-1',
      'institution_id': 'institution-1',
      'role': 'guardian',
    });

    expect(PersonMembershipChange.update(membership).toJson(), {
      'operation': 'update',
      'assignment_id': 'assignment-1',
      'membership_id': 'membership-1',
      'institution_id': 'institution-1',
      'unit_id': null,
      'group_id': null,
      'role': 'guardian',
    });
  });

  test('child context removal targets only the selected context', () {
    final context = PersonChildContext.fromJson({
      'child_context_id': 'context-1',
      'institution_id': 'institution-1',
    });

    expect(PersonChildContextChange.remove(context).toJson(), {
      'operation': 'remove',
      'child_context_id': 'context-1',
      'institution_id': 'institution-1',
      'unit_id': null,
      'group_id': null,
    });
  });

  test('child context parses names and link identifiers from detail payload', () {
    final context = PersonChildContext.fromJson({
      'id': 'context-1',
      'institution_id': 'institution-1',
      'institution_name': 'Instituição 1',
      'unit_id': 'unit-1',
      'group_id': 'group-1',
      'unit_links': [
        {
          'id': 'child-unit-1',
          'unit_id': 'unit-1',
          'unit_name': 'Unidade 1',
          'group_links': [
            {'id': 'child-group-1', 'group_id': 'group-1', 'group_name': 'Grupo 1'},
          ],
        },
      ],
    });

    expect(context.institutionName, 'Instituição 1');
    expect(context.unitName, 'Unidade 1');
    expect(context.groupName, 'Grupo 1');
    expect(context.childUnitLinkId, 'child-unit-1');
    expect(context.childGroupLinkId, 'child-group-1');
    expect(
      PersonChildContextChange.update(context).toJson(),
      containsPair('child_unit_link_id', 'child-unit-1'),
    );
  });
}
