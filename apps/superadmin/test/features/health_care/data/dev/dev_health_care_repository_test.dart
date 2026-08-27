import 'package:coelo_superadmin/features/health_care/data/dev/dev_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows owner care-profile update and blocks minimized actor', () async {
    final child = HealthCareChild(
      id: 'child-1',
      personId: 'person-1',
      displayName: 'Ana',
      operationalStatus: HealthCareOperationalStatus.active,
      links: [const HealthCareContextLink(institutionId: 'institution-1')],
    );
    final owner = HealthCareActor(
      id: 'owner',
      profile: HealthCareAccessProfile.owner,
      institutionId: 'institution-1',
      authorizedChildIds: {'child-1'},
    );
    final repository = DevHealthCareRepository(actor: owner, children: [child]);
    await repository.updateCareProfile(
      childId: 'child-1',
      items: [HealthCareProfileItem(catalogItemId: 'asthma')],
      justification: 'Atualização',
      actor: owner,
    );
    expect((await repository.findChild('child-1', actor: owner))!.careProfile, hasLength(1));
    final minimized = HealthCareActor(
      id: 'minimized',
      profile: HealthCareAccessProfile.minimized,
      institutionId: 'institution-1',
      authorizedChildIds: {'child-1'},
    );
    expect(
      () => repository.updateCareProfile(
        childId: 'child-1',
        items: const [],
        justification: 'x',
        actor: minimized,
      ),
      throwsStateError,
    );
    repository.resetSession();
    expect((await repository.findChild('child-1', actor: owner))!.careProfile, isEmpty);
  });

  test('local profile draft round-trips every field and updates directory data', () async {
    final repository = DevHealthCareRepository.content();
    final draft = HealthCareProfileDraft(
      childId: 'child-demo-b',
      allergyType: HealthCareAllergyType.restriction,
      allergyStatus: HealthCareAllergyStatus.monitoring,
      lastEpisode: '20/08/2026',
      severity: HealthCareEpisodeSeverity.mild,
      observedReaction: 'Coceira',
      allergyGuidance: 'Observar',
      allergyNotes: 'Somente local',
      careItemIds: const {'asthma'},
      importantSigns: 'Tosse',
      adaptations: 'Evitar poeira',
      justification: 'Cadastro demonstrativo',
    );

    await repository.saveCareProfileDraft(draft);
    final loaded = await repository.loadCareProfileDraft(draft.childId);

    expect(loaded?.allergyType, draft.allergyType);
    expect(loaded?.allergyStatus, draft.allergyStatus);
    expect(loaded?.lastEpisode, draft.lastEpisode);
    expect(loaded?.severity, draft.severity);
    expect(loaded?.observedReaction, draft.observedReaction);
    expect(loaded?.allergyGuidance, draft.allergyGuidance);
    expect(loaded?.allergyNotes, draft.allergyNotes);
    expect(loaded?.careItemIds, draft.careItemIds);
    expect(loaded?.importantSigns, draft.importantSigns);
    expect(loaded?.adaptations, draft.adaptations);
    expect(loaded?.justification, draft.justification);
    final child = await repository.findChild(draft.childId, actor: repository.defaultActor);
    expect(child?.careProfile.single.catalogItemId, 'asthma');
  });
}
