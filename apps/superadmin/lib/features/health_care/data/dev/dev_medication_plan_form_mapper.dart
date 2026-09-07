import 'package:flutter/material.dart';

import '../../../../app/dev_menu/development_access_health_fixture_catalog.dart';
import '../../domain/medication_plan_edit_snapshot.dart';
import '../../domain/medication_plan_repository.dart';
import '../../presentation/health_medication_plan_form_page.dart';

HealthMedicationPlanFormDraft developmentMedicationFormDraft({
  required MedicationPlanDetail detail,
  required MedicationPlanSaveCommand? contextCommand,
}) {
  final schedule = detail.schedules.firstOrNull;
  final timeParts = schedule?.timeOfDay.split(':');
  final matchingContext =
      contextCommand != null &&
      contextCommand.childPersonId == detail.childPersonId &&
      (contextCommand.planId == null || contextCommand.planId == detail.id);
  final context = matchingContext ? contextCommand : null;
  return HealthMedicationPlanFormDraft(
    planId: detail.id,
    expectedVersion: detail.currentVersion,
    childId: detail.childPersonId,
    medicationName: detail.medicationName,
    doseAmount: detail.doseAmount,
    doseUnit: detail.doseUnit,
    administrationRoute: detail.administrationRoute,
    validFrom: detail.validFrom,
    validUntil: detail.validUntil,
    time: timeParts == null
        ? null
        : TimeOfDay(hour: int.parse(timeParts.first), minute: int.parse(timeParts.last)),
    weekdays: schedule?.weekdays ?? const {},
    responsibleIds: const {},
    editSnapshot: MedicationPlanEditSnapshot(
      planId: detail.id,
      childPersonId: detail.childPersonId,
      timezone: detail.timezone,
      schedules: detail.schedules,
      instructions: detail.instructions,
      routeDetails: detail.routeDetails,
      scopeKind: context?.scopeKind,
      institutionId: context?.institutionId,
      unitId: context?.unitId,
      groupId: context?.groupId,
      childContextId: context?.childContextId,
    ),
  );
}

MedicationPlanSaveCommand developmentMedicationSaveCommand({
  required HealthMedicationPlanFormDraft draft,
  required Map<String, DevelopmentChildFixture> childrenById,
}) {
  final requestId = draft.requestId;
  final validFrom = draft.validFrom;
  if (requestId == null || requestId.isEmpty || validFrom == null) {
    throw const MedicationPlanInvalidInputException();
  }
  final snapshot = draft.editSnapshot;
  final editing = draft.planId != null;
  final child = childrenById[draft.childId];
  if (editing) {
    if (snapshot == null ||
        snapshot.planId != draft.planId ||
        snapshot.childPersonId != draft.childId ||
        snapshot.scopeKind == null ||
        snapshot.schedules.isEmpty ||
        draft.time == null ||
        draft.weekdays.isEmpty) {
      throw const MedicationPlanInvalidInputException();
    }
  } else if (child == null) {
    throw const MedicationPlanInvalidInputException();
  }
  final original = editing ? snapshot!.schedules.first : null;
  final time = draft.time;
  final timezone = editing ? snapshot!.timezone : 'America/Sao_Paulo';
  return MedicationPlanSaveCommand(
    requestId: requestId,
    planId: draft.planId,
    childPersonId: draft.childId,
    expectedVersion: draft.expectedVersion,
    medicationName: draft.medicationName,
    doseAmount: draft.doseAmount,
    doseUnit: draft.doseUnit,
    administrationRoute: draft.administrationRoute,
    validFrom: validFrom,
    validUntil: draft.validUntil,
    reason: 'Prévia local de desenvolvimento',
    scopeKind: editing ? snapshot!.scopeKind! : 'institution',
    institutionId: editing ? snapshot!.institutionId : child!.institutionId,
    unitId: editing ? snapshot!.unitId : child!.unitId,
    groupId: editing ? snapshot!.groupId : child!.groupId,
    // Matches the existing synthetic fixture convention, not a production ID.
    childContextId: editing ? snapshot!.childContextId : child!.groupId,
    timezone: timezone,
    instructions: editing ? snapshot!.instructions : null,
    routeDetails: editing ? snapshot!.routeDetails : null,
    schedules: [
      MedicationScheduleDraft(
        timeOfDay: time == null
            ? '08:00'
            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        weekdays: draft.weekdays.isEmpty ? const {1, 2, 3, 4, 5} : draft.weekdays,
        timezone: original?.timezone ?? timezone,
        frequencyKind: original?.frequencyKind ?? 'weekly',
        startDate: original?.startDate,
        endDate: original?.endDate,
        maxOccurrencesPerDay: original?.maxOccurrencesPerDay,
      ),
      if (editing) ...snapshot!.schedules.skip(1),
    ],
  );
}
