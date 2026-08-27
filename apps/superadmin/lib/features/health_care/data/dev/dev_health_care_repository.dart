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

  factory DevHealthCareRepository.content() {
    const childIds = ['child-demo-a', 'child-demo-b'];
    final actor = HealthCareActor(
      id: 'health-care-owner-dev',
      profile: HealthCareAccessProfile.owner,
      institutionId: 'institution-demo',
      authorizedChildIds: childIds.toSet(),
    );
    final children = [
      for (final (index, id) in childIds.indexed)
        HealthCareChild(
          id: id,
          personId: 'person-demo-${index + 1}',
          displayName: 'Criança Demo ${index == 0 ? 'A' : 'B'}',
          operationalStatus: HealthCareOperationalStatus.active,
          links: const [HealthCareContextLink(institutionId: 'institution-demo')],
          careProfile: index == 0 ? [HealthCareProfileItem(catalogItemId: 'autism')] : const [],
        ),
    ];
    return DevHealthCareRepository(
      actor: actor,
      children: children,
      careProfileDrafts: {
        childIds.first: HealthCareProfileDraft(
          childId: childIds.first,
          allergyType: HealthCareAllergyType.medication,
          allergyStatus: HealthCareAllergyStatus.monitoring,
          lastEpisode: '15/07/2026',
          severity: HealthCareEpisodeSeverity.severe,
          observedReaction: 'Edema no episódio registrado.',
          allergyGuidance: 'Seguir o plano familiar de cuidado.',
          allergyNotes: 'Registro demonstrativo local.',
          careItemIds: const {'autism'},
          importantSigns: 'Mudança súbita de comportamento.',
          adaptations: 'Antecipar mudanças de rotina.',
          justification: 'Revisão do perfil demonstrativo.',
        ),
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
        careProfile: [for (final id in draft.careItemIds) HealthCareProfileItem(catalogItemId: id)],
      ),
    );
  }

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    final visible = _children.where(actor.canReadDetail).where(query.matches).toList();
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
