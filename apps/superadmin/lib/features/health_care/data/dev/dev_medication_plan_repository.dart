import '../../../../app/dev_menu/development_access_health_fixture_catalog.dart';
import '../../domain/medication_plan_repository.dart';

final class DevMedicationPlanRepository implements MedicationPlanRepository {
  DevMedicationPlanRepository({
    List<MedicationPlanDetail> plans = const [],
    Map<String, MedicationPlanSaveCommand> commandsByPlanId = const {},
  }) : _seed = List.unmodifiable(plans),
       _plans = List.of(plans),
       _seedCommandsByPlanId = Map.unmodifiable(commandsByPlanId),
       _commandsByPlanId = Map.of(commandsByPlanId);

  factory DevMedicationPlanRepository.content({DevelopmentAccessHealthFixtureCatalog? catalog}) {
    final fixtures = catalog ?? DevelopmentAccessHealthFixtureCatalog.standard();
    final childrenById = {for (final child in fixtures.children) child.id: child};
    final commands = <String, MedicationPlanSaveCommand>{};
    final plans = <MedicationPlanDetail>[];
    for (final (index, fixture) in fixtures.medicationPlans.indexed) {
      final child = childrenById[fixture.childId]!;
      final medication = _medicationData(fixture.medicationName);
      final validFrom = DateTime(2026, 1 + index % 10, 1 + index % 20);
      final schedule = MedicationScheduleDraft(
        timeOfDay: '${(7 + index % 4).toString().padLeft(2, '0')}:${index.isEven ? '30' : '00'}',
        weekdays: const {1, 2, 3, 4, 5},
        timezone: 'America/Sao_Paulo',
      );
      final command = MedicationPlanSaveCommand(
        requestId: 'seed-${fixture.id}',
        planId: fixture.id,
        childPersonId: fixture.childId,
        expectedVersion: 1,
        medicationName: fixture.medicationName,
        doseAmount: medication.$1,
        doseUnit: medication.$2,
        administrationRoute: medication.$3,
        validFrom: validFrom,
        validUntil: DateTime(2027, 12, 31),
        reason: 'Plano demonstrativo vinculado à criança.',
        scopeKind: 'institution',
        timezone: 'America/Sao_Paulo',
        schedules: [schedule],
        institutionId: child.institutionId,
        unitId: child.unitId,
        groupId: child.groupId,
        childContextId: child.groupId,
      );
      commands[fixture.id] = command;
      plans.add(
        MedicationPlanDetail(
          id: fixture.id,
          childPersonId: fixture.childId,
          status: switch (fixture.status) {
            'awaiting_approval' => MedicationPlanStatus.draft,
            'suspended' => MedicationPlanStatus.suspended,
            _ => MedicationPlanStatus.active,
          },
          currentVersion: 1,
          medicationName: fixture.medicationName,
          doseAmount: medication.$1,
          doseUnit: medication.$2,
          administrationRoute: medication.$3,
          validFrom: validFrom,
          validUntil: DateTime(2027, 12, 31),
          timezone: 'America/Sao_Paulo',
          schedules: [schedule],
          instructions: 'Administrar conforme orientação registrada no plano.',
        ),
      );
    }
    return DevMedicationPlanRepository(plans: plans, commandsByPlanId: commands);
  }

  final List<MedicationPlanDetail> _seed;
  final Map<String, MedicationPlanSaveCommand> _seedCommandsByPlanId;
  List<MedicationPlanDetail> _plans;
  final Map<String, _MedicationPlanReplay> _replays = {};
  Map<String, MedicationPlanSaveCommand> _commandsByPlanId;

  void resetSession() {
    _plans = List.of(_seed);
    _replays.clear();
    _commandsByPlanId = Map.of(_seedCommandsByPlanId);
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

(num, String, String) _medicationData(String name) => switch (name) {
  'Budesonida' => (1, 'jato', 'Inalatória'),
  'Loratadina' => (5, 'ml', 'Oral'),
  'Insulina' => (4, 'UI', 'Subcutânea'),
  'Levetiracetam' => (5, 'ml', 'Oral'),
  'Salbutamol' => (2, 'jatos', 'Inalatória'),
  _ => (1, 'dose', 'Conforme prescrição'),
};
