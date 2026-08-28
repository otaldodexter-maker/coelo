import '../../domain/medication_plan_repository.dart';

final class DevMedicationPlanRepository implements MedicationPlanRepository {
  DevMedicationPlanRepository({List<MedicationPlanDetail> plans = const []})
    : _seed = List.unmodifiable(plans),
      _plans = List.of(plans);

  final List<MedicationPlanDetail> _seed;
  List<MedicationPlanDetail> _plans;
  final Map<String, _MedicationPlanReplay> _replays = {};
  final Map<String, MedicationPlanSaveCommand> _commandsByPlanId = {};

  void resetSession() {
    _plans = List.of(_seed);
    _replays.clear();
    _commandsByPlanId.clear();
  }

  MedicationPlanSaveCommand? latestCommandFor(String planId) => _commandsByPlanId[planId];

  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async {
    final items = _plans
        .where((plan) => query.statuses.isEmpty || query.statuses.contains(plan.status))
        .map(
          (plan) => MedicationPlanSummary(
            id: plan.id,
            childPersonId: plan.childPersonId,
            status: plan.status,
            version: plan.currentVersion,
            medicationName: plan.medicationName,
            doseAmount: plan.doseAmount,
            doseUnit: plan.doseUnit,
            route: plan.administrationRoute,
            validFrom: plan.validFrom,
            validUntil: plan.validUntil,
          ),
        )
        .toList();
    final pageItems = items.skip(query.offset).take(query.pageSize).toList();
    return MedicationPlanPage(
      items: pageItems,
      total: items.length,
      limit: query.pageSize,
      offset: query.offset,
    );
  }

  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async =>
      _plans.where((plan) => plan.id == planId).firstOrNull ??
      (throw const MedicationPlanNotFoundException());

  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async {
    final replay = _replays[command.requestId];
    if (replay != null) {
      if (!_sameCommand(replay.command, command)) {
        throw const MedicationPlanConflictException();
      }
      return replay.result;
    }
    final existing = command.planId == null
        ? null
        : _plans.where((plan) => plan.id == command.planId).firstOrNull ??
              (throw const MedicationPlanNotFoundException());
    if (existing != null && existing.currentVersion != command.expectedVersion) {
      throw const MedicationPlanConflictException();
    }
    final detail = MedicationPlanDetail(
      id: existing?.id ?? command.planId ?? 'medication-plan-${_plans.length + 1}',
      childPersonId: command.childPersonId,
      status: MedicationPlanStatus.active,
      currentVersion: (existing?.currentVersion ?? 0) + 1,
      medicationName: command.medicationName,
      doseAmount: command.doseAmount,
      doseUnit: command.doseUnit,
      administrationRoute: command.administrationRoute,
      validFrom: command.validFrom,
      validUntil: command.validUntil,
      timezone: command.timezone,
      schedules: command.schedules,
      routeDetails: command.routeDetails,
      instructions: command.instructions,
    );
    _plans = [
      for (final plan in _plans)
        if (plan.id != detail.id) plan,
      detail,
    ];
    _commandsByPlanId[detail.id] = command;
    _replays[command.requestId] = _MedicationPlanReplay(command, detail);
    return detail;
  }
}

final class _MedicationPlanReplay {
  const _MedicationPlanReplay(this.command, this.result);

  final MedicationPlanSaveCommand command;
  final MedicationPlanDetail result;
}

bool _sameCommand(MedicationPlanSaveCommand left, MedicationPlanSaveCommand right) =>
    left.requestId == right.requestId &&
    left.planId == right.planId &&
    left.childPersonId == right.childPersonId &&
    left.expectedVersion == right.expectedVersion &&
    left.medicationName == right.medicationName &&
    left.doseAmount == right.doseAmount &&
    left.doseUnit == right.doseUnit &&
    left.administrationRoute == right.administrationRoute &&
    left.validFrom == right.validFrom &&
    left.validUntil == right.validUntil &&
    left.reason == right.reason &&
    left.scopeKind == right.scopeKind &&
    left.timezone == right.timezone &&
    left.routeDetails == right.routeDetails &&
    left.instructions == right.instructions &&
    left.institutionId == right.institutionId &&
    left.unitId == right.unitId &&
    left.groupId == right.groupId &&
    left.childContextId == right.childContextId &&
    _sameSchedules(left.schedules, right.schedules);

bool _sameSchedules(List<MedicationScheduleDraft> left, List<MedicationScheduleDraft> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final first = left[index];
    final second = right[index];
    if (first.timeOfDay != second.timeOfDay ||
        first.timezone != second.timezone ||
        first.frequencyKind != second.frequencyKind ||
        first.startDate != second.startDate ||
        first.endDate != second.endDate ||
        first.maxOccurrencesPerDay != second.maxOccurrencesPerDay ||
        first.weekdays.length != second.weekdays.length ||
        !first.weekdays.containsAll(second.weekdays)) {
      return false;
    }
  }
  return true;
}

extension on Iterable<MedicationPlanDetail> {
  MedicationPlanDetail? get firstOrNull => isEmpty ? null : first;
}
