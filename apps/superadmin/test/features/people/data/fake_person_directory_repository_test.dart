import 'package:coelo_superadmin/features/people/data/fake_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters, sorts and paginates without crossing tenant scope', () async {
    final repository = FakePersonDirectoryRepository(
      seed: [
        ...FakePersonDirectoryRepository.samplePeople,
        PersonDirectoryItem(
          id: 'other',
          tenantId: 'tenant-other',
          displayName: 'Pessoa Externa',
          type: PersonType.adult,
          status: PersonStatus.active,
          updatedAt: DateTime.utc(2026, 7, 29),
        ),
      ],
      tenantId: 'tenant-coelo',
    );

    final page = await repository.fetchPage(
      PersonDirectoryQuery(types: {PersonType.child}, pageSize: 20),
    );

    expect(page.items, isNotEmpty);
    expect(page.items.every((item) => item.type == PersonType.child), isTrue);
    expect(page.items.any((item) => item.id == 'other'), isFalse);
  });

  test('creates adults as draft without auth access', () async {
    final repository = FakePersonDirectoryRepository();

    final created = await repository.createDraft(
      const PersonDraft(
        type: PersonType.adult,
        firstName: 'Nova',
        lastName: 'Pessoa',
        displayName: 'Nova Pessoa',
        legalName: 'Nova Pessoa',
      ),
    );

    expect(created.status, PersonStatus.draft);
    expect(created.authLink, AuthLinkStatus.unlinked);
  });

  test('concurrent update preserves untouched memberships', () async {
    final repository = FakePersonDirectoryRepository();
    final original = repository.people.firstWhere((person) => person.isEditable);
    final untouched = original.memberships.last;

    final updated = await repository.updatePerson(
      PersonUpdate(
        personId: original.id,
        expectedUpdatedAt: original.updatedAt,
        displayName: 'Nome atualizado',
        firstName: 'Nome',
        lastName: 'Atualizado',
        legalName: 'Nome atualizado',
        membershipChanges: [
          PersonMembershipChange.update(original.memberships.first.copyWith(role: 'educator')),
        ],
      ),
    );

    expect(updated.displayName, 'Nome atualizado');
    expect(updated.memberships, contains(untouched));
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
  });

  test('rejects stale concurrent update', () async {
    final repository = FakePersonDirectoryRepository();
    final original = repository.people.firstWhere((person) => person.isEditable);

    expect(
      () => repository.updatePerson(
        PersonUpdate(
          personId: original.id,
          expectedUpdatedAt: original.updatedAt.subtract(const Duration(seconds: 1)),
          displayName: 'Conflito',
          firstName: original.firstName ?? '',
          lastName: original.lastName ?? '',
          legalName: original.legalName ?? original.displayName,
        ),
      ),
      throwsA(isA<PersonDirectoryConflictException>()),
    );
  });

  test('does not update service records', () async {
    final repository = FakePersonDirectoryRepository();
    final service = repository.people.firstWhere((person) => person.type == PersonType.service);

    expect(
      () => repository.updatePerson(
        PersonUpdate(
          personId: service.id,
          expectedUpdatedAt: service.updatedAt,
          displayName: 'Não permitido',
          firstName: service.firstName ?? '',
          lastName: service.lastName ?? '',
          legalName: service.legalName ?? service.displayName,
        ),
      ),
      throwsA(isA<PersonDirectoryReadOnlyException>()),
    );
  });
}
