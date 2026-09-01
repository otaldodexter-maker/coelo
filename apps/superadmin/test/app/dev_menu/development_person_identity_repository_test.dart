import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/app/dev_menu/development_person_identity_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves a shared guardian by name inside the authorized institution', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final guardian = catalog.guardians.first;
    final repository = DevelopmentPersonIdentityRepository(catalog: catalog);

    final candidates = await repository.resolve(
      kind: PersonIdentityLookupKind.name,
      query: guardian.name,
      institutionId: guardian.institutionIds.first,
    );

    expect(candidates.map((candidate) => candidate.personId), contains(guardian.id));
    expect(candidates.every((candidate) => candidate.maskedMatch != guardian.email), isTrue);
  });

  test('does not expose a shared person outside their structural scope', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final guardian = catalog.guardians.first;
    final linkedInstitutionIds = catalog.children
        .where((child) => child.guardianIds.contains(guardian.id))
        .map((child) => child.institutionId)
        .toSet();
    final otherInstitution = catalog.institutionIds.firstWhere((id) {
      return !guardian.institutionIds.contains(id) && !linkedInstitutionIds.contains(id);
    });
    final repository = DevelopmentPersonIdentityRepository(catalog: catalog);

    final candidates = await repository.resolve(
      kind: PersonIdentityLookupKind.email,
      query: guardian.email,
      institutionId: otherInstitution,
    );

    expect(candidates, isEmpty);
  });
}
