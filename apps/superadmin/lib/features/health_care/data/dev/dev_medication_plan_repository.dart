import '../../domain/medication_plan_repository.dart';

final class DevMedicationPlanRepository implements MedicationPlanRepository {
  DevMedicationPlanRepository({List<MedicationPlanDetail> plans = const []})
      : _seed = List.unmodifiable(plans),
        _plans = List.of(plans);

  final List<MedicationPlanDetail> _seed;
  List<MedicationPlanDetail> _plans;

  void resetSession() => _plans = List.of(_seed);

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async {
    final items = _plans.where((plan) => query.statuses.isEmpty || query.statuses.contains(plan.status)).map((plan) => MedicationPlanSummary(
      id: plan.id, childPersonId: plan.childPersonId, status: plan.status, version: plan.currentVersion,
      medicationName: plan.medicationName, doseAmount: plan.doseAmount, doseUnit: plan.doseUnit,
      route: plan.administrationRoute, validFrom: plan.validFrom, validUntil: plan.validUntil,
    )).toList();
    final pageItems = items.skip(query.offset).take(query.pageSize).toList();
    return MedicationPlanPage(items: pageItems, total: items.length, limit: query.pageSize, offset: query.offset);
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async => _plans.where((plan) => plan.id == planId).firstOrNull ?? (throw const MedicationPlanNotFoundException());

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async {
    final existing = command.planId == null ? null : await fetchDetail(command.planId!);
    if (existing != null && existing.currentVersion != command.expectedVersion) throw const MedicationPlanConflictException();
    final detail = MedicationPlanDetail(
      id: existing?.id ?? command.planId ?? 'medication-plan-${_plans.length + 1}', childPersonId: command.childPersonId,
      status: MedicationPlanStatus.active, currentVersion: (existing?.currentVersion ?? 0) + 1,
      medicationName: command.medicationName, doseAmount: command.doseAmount, doseUnit: command.doseUnit,
      administrationRoute: command.administrationRoute, validFrom: command.validFrom, validUntil: command.validUntil,
      timezone: command.timezone, schedules: command.schedules, routeDetails: command.routeDetails, instructions: command.instructions,
    );
    _plans = [for (final plan in _plans) if (plan.id != detail.id) plan, detail];
    return detail;
  }
}

extension on Iterable<MedicationPlanDetail> {
  MedicationPlanDetail? get firstOrNull => isEmpty ? null : first;
}
