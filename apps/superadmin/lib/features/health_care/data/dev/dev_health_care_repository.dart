import '../../../../app/dev_menu/development_access_health_fixture_catalog.dart';
import '../../domain/health_care.dart';
import '../../domain/health_care_repository.dart';

final class DevHealthCareRepository implements HealthCareRepository {
  DevHealthCareRepository({
    required HealthCareActor actor,
    List<HealthCareChild> children = const [],
    Map<String, HealthCareProfileDraft> careProfileDrafts = const {},
  }) : _actor = actor,
       _seed = List.unmodifiable(children),
       _children = List.of(children),
       _seedCareProfileDrafts = Map.unmodifiable(careProfileDrafts),
       _careProfileDrafts = Map.of(careProfileDrafts);

  factory DevHealthCareRepository.content({DevelopmentAccessHealthFixtureCatalog? catalog}) {
    final fixtures = catalog ?? DevelopmentAccessHealthFixtureCatalog.standard();
    final careProfilesByChild = {
      for (final profile in fixtures.careProfiles) profile.childId: profile,
    };
    final actor = HealthCareActor(
      id: 'health-care-owner-dev',
      profile: HealthCareAccessProfile.owner,
      authorizedChildIds: fixtures.children.map((child) => child.id).toSet(),
    );
    final children = [
      for (final (index, child) in fixtures.children.indexed)
        HealthCareChild(
          id: child.id,
          personId: child.id,
          displayName: child.name,
          operationalStatus: index % 29 == 0
              ? HealthCareOperationalStatus.inactive
              : careProfilesByChild.containsKey(child.id)
              ? HealthCareOperationalStatus.active
              : HealthCareOperationalStatus.implementation,
          links: [
            HealthCareContextLink(
              institutionId: child.institutionId,
              unitId: child.unitId,
              groupOrActivityId: child.groupId,
            ),
          ],
          allergies: _fixtureAllergies(child.id, careProfilesByChild[child.id]),
        ),
    ];
    return DevHealthCareRepository(
      actor: actor,
      children: children,
      careProfileDrafts: {
        for (final profile in fixtures.careProfiles)
          profile.childId: _fixtureDraft(profile, profile.childId),
      },
    );
  }

  final HealthCareActor _actor;
  final List<HealthCareChild> _seed;
  final Map<String, HealthCareProfileDraft> _seedCareProfileDrafts;
  List<HealthCareChild> _children;
  Map<String, HealthCareProfileDraft> _careProfileDrafts;

  @override
  HealthCareActor get defaultActor => _actor;
  void resetSession() {
    _children = List.of(_seed);
    _careProfileDrafts = Map.of(_seedCareProfileDrafts);
  }

  /// Catálogo local do ambiente de prévia (`/dev/*`); produção lê o lote 93.
  Future<HealthCareCatalog> loadCatalog(
    HealthCareCatalogCollection collection,
    String? search,
  ) async {
    final term = (search ?? '').trim().toLowerCase();
    final groups = switch (collection) {
      HealthCareCatalogCollection.guidance => healthCareProfileCatalog,
      HealthCareCatalogCollection.food => developmentFoodCatalog,
      HealthCareCatalogCollection.restriction => developmentRestrictionCatalog,
    };
    return HealthCareCatalog(
      collection: collection,
      groups: [
        for (final group in groups)
          if (group.id != 'other')
            HealthCareProfileCatalogGroup(
              id: group.id,
              label: group.label,
              items: [
                for (final item in group.items)
                  if (item.id != 'other' &&
                      (term.length < 2 || item.label.toLowerCase().contains(term)))
                    item,
              ],
            ),
      ].where((group) => group.items.isNotEmpty).toList(growable: false),
    );
  }

  Future<HealthCareProfileDraft?> loadCareProfileDraft(String childId) async {
    _requireEdit(_actor, childId);
    return _careProfileDrafts[childId];
  }

  Future<void> saveCareProfileDraft(HealthCareProfileDraft draft) async {
    _requireEdit(_actor, draft.childId);
    _careProfileDrafts[draft.childId] = draft;
    final child = (await findChild(draft.childId, actor: _actor))!;
    _replace(
      child.copyWith(
        careProfile: [
          for (final item in draft.careItems)
            HealthCareProfileItem(
              catalogItemId: item.catalogItemId,
              otherText: item.otherText,
              label: item.label,
            ),
        ],
      ),
    );
  }

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    final visible = _children
        .where((child) => _careProfileDrafts.containsKey(child.id))
        .where(actor.canReadDetail)
        .where(query.matches)
        .toList();
    final start = query.offset;
    final page = start >= visible.length
        ? const <HealthCareChild>[]
        : visible.skip(start).take(query.pageSize).toList();
    return HealthCareDirectoryPage(
      items: page
          .map((child) => HealthCareChildSummary.fromChild(child, profile: actor.profile))
          .toList(),
      totalCount: visible.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) async {
    final child = _children.where((item) => item.id == childId).firstOrNull;
    return child != null && actor.canReadDetail(child) ? child : null;
  }

  @override
  Future<HealthMedication> createMedication({
    required String childId,
    required String name,
    required String dose,
    required String doseUnit,
    required String route,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<HealthMedicationSchedule> schedules,
    String? documentName,
    String? documentType,
    required HealthCareActor actor,
  }) async {
    _requireEdit(actor, childId);
    final medicationId = 'medication-${DateTime.now().microsecondsSinceEpoch}';
    final medication = HealthMedication(
      id: medicationId,
      childId: childId,
      versions: [
        HealthMedicationVersion(
          id: 'version-1',
          medicationId: medicationId,
          version: 1,
          name: name,
          dose: dose,
          doseUnit: doseUnit,
          route: route,
          startsAt: startsAt,
          endsAt: endsAt,
          status: HealthMedicationReviewStatus.active,
          schedules: schedules,
          documentName: documentName,
          documentType: documentType,
        ),
      ],
    );
    final child = (await findChild(childId, actor: actor))!;
    _replace(child.copyWith(medications: [...child.medications, medication]));
    return medication;
  }

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) async => throw UnsupportedError('Use the medication plan dev repository.');
  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) async => throw UnsupportedError('Allergy preview is not part of this fixture.');
  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) async => throw UnsupportedError('Allergy preview is not part of this fixture.');

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) async {
    _requireEdit(actor, childId);
    final child = (await findChild(childId, actor: actor))!;
    _replace(child.copyWith(careProfile: items));
    return HealthCareAcknowledgement(
      id: 'ack-${DateTime.now().microsecondsSinceEpoch}',
      childId: childId,
      subject: HealthCareAcknowledgementSubject.careProfile,
      createdAt: DateTime.now(),
    );
  }

  void _requireEdit(HealthCareActor actor, String childId) {
    final child = _children.where((item) => item.id == childId).firstOrNull;
    if (child == null) throw StateError('Criança não encontrada.');
    if (!actor.can(HealthCareCapability.recordCreateEdit) || !actor.canReadDetail(child)) {
      throw StateError('Acesso não autorizado.');
    }
  }

  void _replace(HealthCareChild value) {
    _children = [for (final child in _children) child.id == value.id ? value : child];
  }
}

extension on Iterable<HealthCareChild> {
  HealthCareChild? get firstOrNull => isEmpty ? null : first;
}

List<HealthCareAllergy> _fixtureAllergies(String childId, DevelopmentCareProfileFixture? profile) =>
    [
      if (profile?.hasAllergies ?? false)
        HealthCareAllergy(
          id: '${profile!.id}-allergy',
          childId: childId,
          label: 'Alergia registrada pela família',
          type: HealthCareAllergyType.food,
          active: true,
          status: HealthCareAllergyStatus.monitoring,
          guidance: 'Consultar as orientações cadastradas antes do atendimento.',
        ),
      if (profile?.hasRestrictions ?? false)
        HealthCareAllergy(
          id: '${profile!.id}-restriction',
          childId: childId,
          label: 'Restrição de cuidado registrada',
          type: HealthCareAllergyType.restriction,
          active: true,
          guidance: 'Respeitar a restrição informada pelos responsáveis.',
        ),
    ];

HealthCareProfileDraft _fixtureDraft(DevelopmentCareProfileFixture profile, String childId) =>
    HealthCareProfileDraft(
      childId: childId,
      allergyType: profile.hasRestrictions
          ? HealthCareAllergyType.restriction
          : HealthCareAllergyType.food,
      allergyStatus: profile.hasAllergies || profile.hasRestrictions
          ? HealthCareAllergyStatus.monitoring
          : HealthCareAllergyStatus.active,
      observedReaction: profile.hasAllergies ? 'Reação registrada no perfil de cuidado.' : '',
      allergyGuidance: profile.hasAllergies || profile.hasRestrictions
          ? 'Consultar as orientações cadastradas antes do atendimento.'
          : '',
      adaptations: profile.hasRestrictions ? 'Aplicar a restrição informada pela família.' : '',
      justification: 'Carga demonstrativa vinculada à estrutura institucional.',
    );

const developmentFoodCatalog = <HealthCareProfileCatalogGroup>[
  HealthCareProfileCatalogGroup(
    id: 'dairy',
    label: 'Leite e derivados',
    items: [
      HealthCareProfileCatalogItem(id: 'food_milk', label: 'Leite de vaca'),
      HealthCareProfileCatalogItem(id: 'food_cheese', label: 'Queijo'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'legume',
    label: 'Leguminosas',
    items: [
      HealthCareProfileCatalogItem(id: 'food_peanut', label: 'Amendoim'),
      HealthCareProfileCatalogItem(id: 'food_soy', label: 'Soja'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'fruit',
    label: 'Frutas',
    items: [
      HealthCareProfileCatalogItem(id: 'food_banana', label: 'Banana'),
      HealthCareProfileCatalogItem(id: 'food_apple', label: 'Maçã'),
      HealthCareProfileCatalogItem(id: 'food_strawberry', label: 'Morango'),
    ],
  ),
];

const developmentRestrictionCatalog = <HealthCareProfileCatalogGroup>[
  HealthCareProfileCatalogGroup(
    id: 'contact',
    label: 'Contato e ambiente',
    items: [
      HealthCareProfileCatalogItem(id: 'restriction_latex', label: 'Látex'),
      HealthCareProfileCatalogItem(id: 'restriction_insect', label: 'Picada de inseto'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'medication',
    label: 'Medicamentos',
    items: [
      HealthCareProfileCatalogItem(id: 'restriction_dipyrone', label: 'Dipirona'),
      HealthCareProfileCatalogItem(id: 'restriction_penicillin', label: 'Penicilina e amoxicilina'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'diet',
    label: 'Dieta por regra',
    items: [
      HealthCareProfileCatalogItem(id: 'restriction_no_sugar', label: 'Sem açúcar'),
      HealthCareProfileCatalogItem(id: 'restriction_vegetarian', label: 'Vegetariana'),
    ],
  ),
];
