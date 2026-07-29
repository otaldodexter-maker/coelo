import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies status and scope filters as real multiselect sets', () async {
    final repository = FakeAccessProfileRepository(
      profiles: const [_activePlatform, _inactiveInstitution, _archivedInstitution],
    );

    final result = await repository.fetchProfiles(
      const AccessProfileQuery(
        statuses: {AccessProfileStatus.active, AccessProfileStatus.inactive},
        scopes: {AccessProfileScope.platform, AccessProfileScope.institution},
      ),
    );

    expect(result.items.map((item) => item.id), ['active-platform', 'inactive-institution']);
  });
}

const _activePlatform = AccessProfile(
  id: 'active-platform',
  domain: AccessProfileDomain.platform,
  code: 'active.platform',
  name: 'Ativo plataforma',
  description: '',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
);

const _inactiveInstitution = AccessProfile(
  id: 'inactive-institution',
  domain: AccessProfileDomain.platform,
  code: 'inactive.institution',
  name: 'Inativo instituição',
  description: '',
  status: AccessProfileStatus.inactive,
  maxScope: AccessProfileScope.institution,
  version: 1,
  membershipCount: 0,
);

const _archivedInstitution = AccessProfile(
  id: 'archived-institution',
  domain: AccessProfileDomain.platform,
  code: 'archived.institution',
  name: 'Arquivado instituição',
  description: '',
  status: AccessProfileStatus.archived,
  maxScope: AccessProfileScope.institution,
  version: 1,
  membershipCount: 0,
);
