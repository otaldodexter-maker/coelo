import 'medication_plan_repository.dart';

/// Immutable, non-editable values carried through a medication form revision.
final class MedicationPlanEditSnapshot {
  MedicationPlanEditSnapshot({
    required this.planId,
    required this.childPersonId,
    required this.timezone,
    required List<MedicationScheduleDraft> schedules,
    this.routeDetails,
    this.instructions,
    this.scopeKind,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.childContextId,
  }) : schedules = List.unmodifiable(schedules);

  final String planId, childPersonId, timezone;
  final String? routeDetails, instructions, scopeKind;
  final String? institutionId, unitId, groupId, childContextId;
  final List<MedicationScheduleDraft> schedules;

  bool hasSameValue(MedicationPlanEditSnapshot other) {
    if (planId != other.planId ||
        childPersonId != other.childPersonId ||
        timezone != other.timezone ||
        routeDetails != other.routeDetails ||
        instructions != other.instructions ||
        scopeKind != other.scopeKind ||
        institutionId != other.institutionId ||
        unitId != other.unitId ||
        groupId != other.groupId ||
        childContextId != other.childContextId ||
        schedules.length != other.schedules.length) {
      return false;
    }
    for (var index = 0; index < schedules.length; index++) {
      final first = schedules[index];
      final second = other.schedules[index];
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
}
