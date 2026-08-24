import 'package:coelo_superadmin/features/health_care/data/dev/dev_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows owner care-profile update and blocks minimized actor', () async {
    final child = HealthCareChild(id: 'child-1', personId: 'person-1', displayName: 'Ana', operationalStatus: HealthCareOperationalStatus.active, links: [const HealthCareContextLink(institutionId: 'institution-1')]);
    final owner = HealthCareActor(id: 'owner', profile: HealthCareAccessProfile.owner, institutionId: 'institution-1', authorizedChildIds: {'child-1'});
    final repository = DevHealthCareRepository(actor: owner, children: [child]);
    await repository.updateCareProfile(childId: 'child-1', items: [HealthCareProfileItem(catalogItemId: 'asthma')], justification: 'Atualização', actor: owner);
    expect((await repository.findChild('child-1', actor: owner))!.careProfile, hasLength(1));
    final minimized = HealthCareActor(id: 'minimized', profile: HealthCareAccessProfile.minimized, institutionId: 'institution-1', authorizedChildIds: {'child-1'});
    expect(() => repository.updateCareProfile(childId: 'child-1', items: const [], justification: 'x', actor: minimized), throwsStateError);
    repository.resetSession();
    expect((await repository.findChild('child-1', actor: owner))!.careProfile, isEmpty);
  });
}
