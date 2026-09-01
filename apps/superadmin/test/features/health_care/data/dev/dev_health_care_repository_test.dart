import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content exposes the linked 180 children and 147 care profiles', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevHealthCareRepository.content(catalog: catalog);
    final page = await repository.fetchDirectory(
      const HealthCareDirectoryQuery(pageSize: 200),
      actor: repository.defaultActor,
    );

    expect(page.totalCount, 180);
    expect(
      page.items.map((item) => item.id).toSet(),
      catalog.children.map((item) => item.id).toSet(),
    );
    expect(
      await Future.wait([
        for (final child in catalog.children) repository.loadCareProfileDraft(child.id),
      ]).then((drafts) => drafts.whereType<HealthCareProfileDraft>().length),
      147,
    );
  });

  test('content preserves linked search, context filters and pagination', () async {
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevHealthCareRepository.content(catalog: catalog);
    final target = catalog.children[73];

    final search = await repository.fetchDirectory(
      HealthCareDirectoryQuery(search: target.name, pageSize: 25),
      actor: repository.defaultActor,
    );
    final context = await repository.fetchDirectory(
      HealthCareDirectoryQuery(
        institutionIds: {target.institutionId},
        unitIds: {target.unitId},
        groupOrActivityIds: {target.groupId},
        pageSize: 200,
      ),
      actor: repository.defaultActor,
    );
    final secondPage = await repository.fetchDirectory(
      const HealthCareDirectoryQuery(page: 1, pageSize: 25),
      actor: repository.defaultActor,
    );

    expect(search.items.map((item) => item.id), contains(target.id));
    expect(context.items, isNotEmpty);
    expect(
      context.items.map((item) => item.id),
      everyElement(isIn(catalog.children.map((item) => item.id))),
    );
    expect(secondPage.items, hasLength(25));
    expect(secondPage.items.first.id, catalog.children[25].id);
  });

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
    final catalog = DevelopmentAccessHealthFixtureCatalog.standard();
    final repository = DevHealthCareRepository.content(catalog: catalog);
    final draft = HealthCareProfileDraft(
      childId: catalog.children[1].id,
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
