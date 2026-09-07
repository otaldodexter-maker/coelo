import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_form_mapper.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final child = DevelopmentAccessHealthFixtureCatalog.standard().children.first;
  final children = {child.id: child};
  MedicationPlanSaveCommand context({
    String? planId = 'plan-1',
    String? childId,
    String scope = 'institution',
  }) => MedicationPlanSaveCommand(
    requestId: 'historical-request',
    planId: planId,
    childPersonId: childId ?? child.id,
    expectedVersion: 0,
    medicationName: 'Synthetic',
    doseAmount: 1,
    doseUnit: 'unit',
    administrationRoute: 'oral',
    validFrom: DateTime(2026, 1, 1),
    reason: 'Synthetic',
    scopeKind: scope,
    timezone: 'UTC',
    schedules: _schedules(),
    institutionId: scope == 'institution' ? child.institutionId : null,
    unitId: scope == 'institution' ? child.unitId : null,
    groupId: scope == 'institution' ? child.groupId : null,
    childContextId: 'synthetic-context',
  );
  MedicationPlanDetail detail({List<MedicationScheduleDraft>? schedules}) => MedicationPlanDetail(
    id: 'plan-1',
    childPersonId: child.id,
    status: MedicationPlanStatus.suspended,
    currentVersion: 4,
    medicationName: 'Synthetic',
    doseAmount: 1,
    doseUnit: 'unit',
    administrationRoute: 'oral',
    validFrom: DateTime(2026, 1, 1),
    timezone: 'UTC',
    schedules: schedules ?? _schedules(),
    routeDetails: 'Stored route',
    instructions: 'Stored instructions',
  );
  HealthMedicationPlanFormDraft hydrate({MedicationPlanSaveCommand? command}) =>
      developmentMedicationFormDraft(detail: detail(), contextCommand: command ?? context());
  MedicationPlanSaveCommand map(HealthMedicationPlanFormDraft draft) =>
      developmentMedicationSaveCommand(draft: draft, childrenById: children);

  test('edit preserves stored metadata and additional schedules while changing first time', () {
    final source = hydrate();
    final saved = map(
      _submitted(source, time: const TimeOfDay(hour: 9, minute: 30), weekdays: {6}),
    );
    expect(saved.schedules, hasLength(2));
    final first = saved.schedules.first;
    expect(first.timeOfDay, '09:30');
    expect(first.weekdays, {6});
    expect(first.frequencyKind, 'synthetic-frequency');
    expect(first.timezone, 'UTC');
    expect(first.startDate, DateTime(2026, 1, 2));
    expect(first.endDate, DateTime(2026, 12, 20));
    expect(first.maxOccurrencesPerDay, 1);
    expect(saved.schedules.last, same(source.editSnapshot!.schedules.last));
    expect(saved.timezone, 'UTC');
    expect(saved.instructions, 'Stored instructions');
    expect(saved.routeDetails, 'Stored route');
    expect(saved.institutionId, child.institutionId);
    expect(saved.unitId, child.unitId);
    expect(saved.groupId, child.groupId);
    expect(saved.childContextId, 'synthetic-context');
    expect(saved.expectedVersion, 4);
    expect(saved.requestId, 'new-request');
  });

  test('home scope is preserved without fabricating institution fields', () {
    final saved = map(_submitted(hydrate(command: context(scope: 'home'))));
    expect(saved.scopeKind, 'home');
    expect(saved.institutionId, isNull);
    expect(saved.unitId, isNull);
    expect(saved.groupId, isNull);
  });

  test('create resolves the selected synthetic child context', () {
    final saved = map(_create(child.id));
    expect(saved.planId, isNull);
    expect(saved.institutionId, child.institutionId);
    expect(saved.unitId, child.unitId);
    expect(saved.groupId, child.groupId);
    expect(saved.childContextId, child.groupId);
  });

  test('unknown child is rejected before creation', () {
    expect(
      () => map(_create('missing-child')),
      throwsA(isA<MedicationPlanInvalidInputException>()),
    );
  });

  test('create receipt command with null plan ID can hydrate the saved plan', () async {
    final command = map(_create(child.id));
    final repository = DevMedicationPlanRepository();
    final created = await repository.save(command);
    final draft = developmentMedicationFormDraft(detail: created, contextCommand: command);
    final edit = map(_submitted(draft));
    expect(edit.planId, created.id);
    expect(edit.expectedVersion, 1);
    expect(edit.institutionId, child.institutionId);
  });

  for (final commandKind in ['missing', 'wrong-plan', 'wrong-child']) {
    test('edit cannot fabricate context from a $commandKind source command', () {
      final command = switch (commandKind) {
        'missing' => null,
        'wrong-plan' => context(planId: 'other-plan'),
        _ => context(childId: 'other-child'),
      };
      final draft = developmentMedicationFormDraft(detail: detail(), contextCommand: command);
      expect(() => map(_submitted(draft)), throwsA(isA<MedicationPlanInvalidInputException>()));
    });
  }

  for (final mismatch in ['plan', 'child']) {
    test('a snapshot for another $mismatch cannot be submitted', () {
      final source = hydrate();
      expect(
        () => map(
          _submitted(
            source,
            planId: mismatch == 'plan' ? 'other-plan' : null,
            childId: mismatch == 'child' ? 'other-child' : null,
          ),
        ),
        throwsA(isA<MedicationPlanInvalidInputException>()),
      );
    });
  }

  test('empty schedules hydrate without crashing and cannot be silently invented on edit', () {
    final source = developmentMedicationFormDraft(
      detail: detail(schedules: []),
      contextCommand: context(),
    );
    expect(source.time, isNull);
    expect(source.weekdays, isEmpty);
    expect(() => map(_submitted(source)), throwsA(isA<MedicationPlanInvalidInputException>()));
  });

  test('snapshot compares values deeply and does not depend on list identity', () {
    final first = hydrate().editSnapshot!;
    final second = hydrate().editSnapshot!;
    expect(first, isNot(same(second)));
    expect(first.hasSameValue(second), isTrue);
    expect(first.hasSameValue(hydrate(command: context(scope: 'home')).editSnapshot!), isFalse);
    expect(() => first.schedules.clear(), throwsUnsupportedError);
    expect(() => first.schedules.first.weekdays.clear(), throwsUnsupportedError);
  });

  test('mapping the same pending edit replays without a new revision', () async {
    final original = detail();
    final repository = DevMedicationPlanRepository(plans: [original]);
    final pending = _submitted(hydrate());
    final first = await repository.save(map(pending));
    expect(await repository.save(map(pending)), same(first));
    expect((await repository.fetchDetail(original.id)).currentVersion, 5);
    expect((await repository.fetchDetail(original.id)).status, MedicationPlanStatus.suspended);
  });
}

List<MedicationScheduleDraft> _schedules() => [
  MedicationScheduleDraft(
    timeOfDay: '08:15',
    weekdays: {2, 4},
    timezone: 'UTC',
    frequencyKind: 'synthetic-frequency',
    startDate: DateTime(2026, 1, 2),
    endDate: DateTime(2026, 12, 20),
    maxOccurrencesPerDay: 1,
  ),
  MedicationScheduleDraft(timeOfDay: '16:45', weekdays: {1, 3}, timezone: 'America/Sao_Paulo'),
];

HealthMedicationPlanFormDraft _submitted(
  HealthMedicationPlanFormDraft source, {
  TimeOfDay? time,
  Set<int>? weekdays,
  String? planId,
  String? childId,
}) => HealthMedicationPlanFormDraft(
  requestId: 'new-request',
  planId: planId ?? source.planId,
  childId: childId ?? source.childId,
  expectedVersion: source.expectedVersion,
  medicationName: source.medicationName,
  doseAmount: source.doseAmount,
  doseUnit: source.doseUnit,
  administrationRoute: source.administrationRoute,
  validFrom: source.validFrom,
  validUntil: source.validUntil,
  time: time ?? source.time,
  weekdays: weekdays ?? source.weekdays,
  responsibleIds: source.responsibleIds,
  editSnapshot: source.editSnapshot,
);

HealthMedicationPlanFormDraft _create(String childId) => HealthMedicationPlanFormDraft(
  requestId: 'create-request',
  childId: childId,
  medicationName: 'Synthetic',
  doseAmount: 1,
  doseUnit: 'unit',
  administrationRoute: 'oral',
  validFrom: DateTime(2026, 1, 1),
  weekdays: const {},
  responsibleIds: const {},
);
