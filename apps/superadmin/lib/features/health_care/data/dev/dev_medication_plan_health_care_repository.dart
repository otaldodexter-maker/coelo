import '../../../../app/dev_menu/development_access_health_fixture_catalog.dart';
import '../../domain/health_care.dart';
import '../../domain/health_care_repository.dart';
import '../../domain/medication_plan_repository.dart';
import 'dev_medication_plan_repository.dart';

final class DevMedicationPlanHealthCareRepository implements HealthCareRepository {
  DevMedicationPlanHealthCareRepository({
    required this.medicationPlans,
    required Map<String, String> childLabels,
    Map<String, HealthCareContextLink> childLinks = const {},
  }) : _childLabels = Map.unmodifiable(childLabels),
       _childLinks = Map.unmodifiable(childLinks),
       _actor = HealthCareActor(
         id: 'dev-medication-plan-directory',
         profile: HealthCareAccessProfile.owner,
         authorizedChildIds: childLabels.keys.toSet(),
       );

  factory DevMedicationPlanHealthCareRepository.content({
    required DevMedicationPlanRepository medicationPlans,
    DevelopmentAccessHealthFixtureCatalog? catalog,
  }) {
    final fixtures = catalog ?? DevelopmentAccessHealthFixtureCatalog.standard();
    return DevMedicationPlanHealthCareRepository(
      medicationPlans: medicationPlans,
      childLabels: {for (final child in fixtures.children) child.id: child.name},
      childLinks: {
        for (final child in fixtures.children)
          child.id: HealthCareContextLink(
            institutionId: child.institutionId,
            unitId: child.unitId,
            groupOrActivityId: child.groupId,
          ),
      },
    );
  }

  static const _institutionId = 'dev-medication-plan-institution';

  final DevMedicationPlanRepository medicationPlans;
  final Map<String, String> _childLabels;
  final Map<String, HealthCareContextLink> _childLinks;
  final HealthCareActor _actor;

  @override
  HealthCareActor get defaultActor => _actor;

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    final visible = (await _loadChildren())
        .where(actor.canReadDetail)
        .where(query.matches)
        .toList();
    final page = visible.skip(query.offset).take(query.pageSize).toList();
    return HealthCareDirectoryPage(
      items: [
        for (final child in page) HealthCareChildSummary.fromChild(child, profile: actor.profile),
      ],
      totalCount: visible.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) async {
    final child = (await _loadChildren()).where((item) => item.id == childId).firstOrNull;
    return child != null && actor.canReadDetail(child) ? child : null;
  }

  Future<List<HealthCareChild>> _loadChildren() async {
    final summaries = (await medicationPlans.fetchPage(
      const MedicationPlanQuery(pageSize: 100),
    )).items;
    final details = await Future.wait([
      for (final summary in summaries) medicationPlans.fetchDetail(summary.id),
    ]);
    return [
      for (final entry in _childLabels.entries)
        if (details.any((detail) => detail.childPersonId == entry.key))
          HealthCareChild(
            id: entry.key,
            personId: entry.key,
            displayName: entry.value,
            operationalStatus: HealthCareOperationalStatus.active,
            links: [
              _childLinks[entry.key] ?? const HealthCareContextLink(institutionId: _institutionId),
            ],
            medications: [
              for (final detail in details)
                if (detail.childPersonId == entry.key) _medication(detail),
            ],
          ),
    ];
  }

  HealthMedication _medication(MedicationPlanDetail detail) {
    final command = medicationPlans.latestCommandFor(detail.id);
    final institutionId = command?.scopeKind == 'institution' ? command?.institutionId : null;
    return HealthMedication(
      id: detail.id,
      childId: detail.childPersonId,
      versions: [
        HealthMedicationVersion(
          id: '${detail.id}-version-${detail.currentVersion}',
          medicationId: detail.id,
          version: detail.currentVersion,
          name: detail.medicationName,
          dose: detail.doseAmount.toString(),
          doseUnit: detail.doseUnit,
          route: detail.administrationRoute,
          startsAt: detail.validFrom,
          endsAt: detail.validUntil ?? DateTime.utc(9999, 12, 31),
          status: switch (detail.status) {
            MedicationPlanStatus.draft => HealthMedicationReviewStatus.requested,
            MedicationPlanStatus.active => HealthMedicationReviewStatus.active,
            MedicationPlanStatus.suspended => HealthMedicationReviewStatus.invalidated,
            MedicationPlanStatus.ended => HealthMedicationReviewStatus.ended,
          },
          schedules: [
            for (final (index, schedule) in detail.schedules.indexed)
              HealthMedicationSchedule(
                id: '${detail.id}-schedule-$index',
                time: _time(schedule.timeOfDay),
                atHome: institutionId == null,
                institutionId: institutionId,
              ),
          ],
        ),
      ],
    );
  }

  HealthCareTimeOfDay _time(String value) {
    final parts = value.split(':');
    return HealthCareTimeOfDay(int.parse(parts.first), int.parse(parts.last));
  }

  Never _unsupported() => throw UnsupportedError('This development adapter is read-only.');

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
  }) async => _unsupported();

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) async => _unsupported();

  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) async => _unsupported();

  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) async => _unsupported();

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) async => _unsupported();
}

extension on Iterable<HealthCareChild> {
  HealthCareChild? get firstOrNull => isEmpty ? null : first;
}
