import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_person_directory_repository.dart';

void main() {
  test('test repository filters and paginates inside its tenant', () async {
    final repository = FakePersonDirectoryRepository(
      seed: [
        ...FakePersonDirectoryRepository.samplePeople,
        PersonDirectoryItem(
          id: 'other-tenant-person',
          tenantId: 'tenant-other',
          displayName: 'Pessoa externa',
          type: PersonType.child,
          status: PersonStatus.active,
          updatedAt: DateTime.utc(2026, 8, 11),
        ),
      ],
    );

    final page = await repository.fetchPage(
      PersonDirectoryQuery(types: const {PersonType.child}, pageSize: 8),
    );

    expect(page.items, hasLength(8));
    expect(page.items, everyElement(isA<PersonDirectoryItem>()));
    expect(
      page.items,
      everyElement(predicate<PersonDirectoryItem>((item) => item.tenantId == 'tenant-coelo')),
    );
    expect(
      page.items,
      everyElement(predicate<PersonDirectoryItem>((item) => item.type == PersonType.child)),
    );
  });

  test('test repository creates an adult draft without auth activation', () async {
    final repository = FakePersonDirectoryRepository(seed: const []);

    final created = await repository.createDraft(
      const PersonDraft(
        type: PersonType.adult,
        firstName: 'Ana',
        lastName: 'Lima',
        displayName: 'Ana Lima',
        legalName: 'Ana Lima',
      ),
    );

    expect(created.status, PersonStatus.draft);
    expect(created.authLink, AuthLinkStatus.unlinked);
    expect(created.tenantId, 'tenant-coelo');
  });
}
