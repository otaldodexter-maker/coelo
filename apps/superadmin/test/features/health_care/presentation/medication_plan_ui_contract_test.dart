import 'dart:async';

import 'package:coelo_superadmin/app/dev_menu/development_access_health_fixture_catalog.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_form_mapper.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_edit_snapshot.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_form_sections.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final replay in [false, true]) {
    testWidgets(
      'DEV mapper preserves edits made while ${replay ? 'replay' : 'first save'} awaits its receipt',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final child = DevelopmentAccessHealthFixtureCatalog.standard().children.first;
        final repository = DevMedicationPlanRepository();
        final receiptGate = Completer<void>();
        var calls = 0;
        var navigations = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            home: HealthMedicationPlanFormPage(
              logout: unavailableSuperadminLogout,
              onCancel: () {},
              onSaved: () async => navigations++,
              childOptions: [HealthCareFormChoice(id: child.id, label: 'Synthetic child')],
              initialDraft: HealthMedicationPlanFormDraft(
                childId: child.id,
                medicationName: 'Synthetic original',
                doseAmount: 1,
                doseUnit: 'unit',
                administrationRoute: 'oral',
                weekdays: const {},
                responsibleIds: const {},
                validFrom: DateTime(2026, 1, 1),
              ),
              onDraftSaved: (draft) async {
                calls++;
                final command = developmentMedicationSaveCommand(
                  draft: draft,
                  childrenById: {child.id: child},
                );
                final saved = await repository.save(command);
                if (replay && calls == 1) throw StateError('Synthetic lost response');
                if (calls == (replay ? 2 : 1)) await receiptGate.future;
                return HealthMedicationPlanSaveReceipt(
                  planId: saved.id,
                  version: saved.currentVersion,
                  editSnapshot: developmentMedicationFormDraft(
                    detail: saved,
                    contextCommand: command,
                  ).editSnapshot,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openReviewAndSave(tester, 'Criar plano');
        await tester.pumpAndSettle();
        if (replay) {
          await tester.tap(find.byKey(const Key('health-medication-primary-action')));
          await tester.pumpAndSettle();
        }
        tester
            .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
            .onStepSelected(0);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('health-medication-name')),
          'Synthetic changed during wait',
        );
        receiptGate.complete();
        await tester.pumpAndSettle();
        if (!replay) {
          expect(navigations, 0);
          await _openReviewAndSave(tester, 'Criar plano');
          await tester.pumpAndSettle();
        }
        final page = await repository.fetchPage(const MedicationPlanQuery());
        final saved = await repository.fetchDetail(page.items.single.id);
        expect(saved.currentVersion, 2);
        expect(saved.medicationName, 'Synthetic changed during wait');
        expect(navigations, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final lostAt in ['receipt', 'navigation', 'navigation-no-edit', 'receipt-schedule']) {
    testWidgets('DEV mapper preserves confirmed create defaults after lost $lostAt and edits', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final child = DevelopmentAccessHealthFixtureCatalog.standard().children.first;
      final repository = DevMedicationPlanRepository();
      final submissions = <HealthMedicationPlanFormDraft>[];
      var navigationCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: HealthMedicationPlanFormPage(
            logout: unavailableSuperadminLogout,
            onCancel: () {},
            childOptions: [HealthCareFormChoice(id: child.id, label: 'Synthetic child')],
            initialDraft: HealthMedicationPlanFormDraft(
              childId: child.id,
              medicationName: 'Synthetic medicine',
              doseAmount: 1,
              doseUnit: 'unit',
              administrationRoute: 'oral',
              weekdays: const {},
              responsibleIds: const {},
              validFrom: DateTime(2026, 1, 1),
            ),
            onDraftSaved: (draft) async {
              submissions.add(draft);
              final command = developmentMedicationSaveCommand(
                draft: draft,
                childrenById: {child.id: child},
              );
              final saved = await repository.save(command);
              if (lostAt.startsWith('receipt') && submissions.length == 1) {
                throw StateError('Synthetic lost receipt');
              }
              return HealthMedicationPlanSaveReceipt(
                planId: saved.id,
                version: saved.currentVersion,
                editSnapshot: developmentMedicationFormDraft(
                  detail: saved,
                  contextCommand: command,
                ).editSnapshot,
              );
            },
            onSaved: () async {
              navigationCalls++;
              if (lostAt.startsWith('navigation') && navigationCalls == 1) {
                throw StateError('Synthetic navigation failure');
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openReviewAndSave(tester, 'Criar plano');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('health-medication-save-error')), findsOneWidget);
      if (lostAt != 'navigation-no-edit') {
        tester
            .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
            .onStepSelected(0);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('health-medication-name')),
          'Synthetic changed',
        );
        if (lostAt == 'receipt-schedule') {
          tester
              .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
              .onStepSelected(2);
          await tester.pumpAndSettle();
          tester
              .widget<CoeloMedicationTimeField>(find.byType(CoeloMedicationTimeField))
              .onChanged(const TimeOfDay(hour: 9, minute: 30));
          tester
              .widget<CoeloMedicationWeekdaySelector>(find.byType(CoeloMedicationWeekdaySelector))
              .onChanged({6});
          await tester.pumpAndSettle();
        }
      }
      await _openReviewAndSave(
        tester,
        lostAt == 'navigation-no-edit' ? 'Tentar novamente' : 'Criar plano',
      );
      await tester.pumpAndSettle();
      final page = await repository.fetchPage(const MedicationPlanQuery());
      final saved = await repository.fetchDetail(page.items.single.id);
      expect(saved.currentVersion, lostAt == 'navigation-no-edit' ? 1 : 2);
      expect(
        saved.medicationName,
        lostAt == 'navigation-no-edit' ? 'Synthetic medicine' : 'Synthetic changed',
      );
      expect(saved.schedules.single.timeOfDay, lostAt == 'receipt-schedule' ? '09:30' : '08:00');
      expect(saved.schedules.single.weekdays, lostAt == 'receipt-schedule' ? {6} : {1, 2, 3, 4, 5});
      expect(repository.latestCommandFor(saved.id)!.institutionId, child.institutionId);
      expect(page.total, 1);
      expect(
        submissions,
        hasLength(
          lostAt.startsWith('receipt')
              ? 3
              : lostAt == 'navigation-no-edit'
              ? 1
              : 2,
        ),
      );
      if (lostAt.startsWith('receipt')) expect(submissions[1], same(submissions[0]));
      expect(find.byKey(const Key('health-medication-save-error')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  Widget subject({
    String? medicationId,
    String? childId,
    HealthMedicationPlanFormDraft? initialDraft,
    HealthMedicationPlanDraftSave? onDraftSaved,
    Future<void> Function()? onSaved,
    VoidCallback? onChangeChild,
  }) => MaterialApp(
    theme: CoeloTheme.light,
    home: HealthMedicationPlanFormPage(
      logout: unavailableSuperadminLogout,
      medicationId: medicationId,
      childId: childId,
      initialDraft: initialDraft,
      childOptions: const [
        HealthCareFormChoice(id: 'child-a', label: 'Ana'),
        HealthCareFormChoice(id: 'child-b', label: 'Bia'),
      ],
      onChangeChild: onChangeChild,
      onCancel: () {},
      onDraftSaved: onDraftSaved,
      onSaved: onSaved ?? () async {},
    ),
  );

  for (final editing in [false, true]) {
    testWidgets('${editing ? 'edit' : 'create'} without a save handler cannot report success', (
      tester,
    ) async {
      var navigations = 0;
      await tester.pumpWidget(
        subject(
          medicationId: editing ? 'plan-a' : null,
          initialDraft: _draft(),
          onSaved: () async => navigations++,
        ),
      );
      await tester.pumpAndSettle();
      await _openReviewAndSave(tester, editing ? 'Salvar alterações' : 'Criar plano');
      await tester.pumpAndSettle();

      expect(navigations, 0);
      expect(find.bySemanticsLabel('Salvar plano de medicação está indisponível.'), findsOneWidget);
      expect(find.text('Dipirona'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  MedicationPlanEditSnapshot snapshot({
    String planId = 'plan-a',
    String childId = 'child-a',
    String? differentContext,
  }) => MedicationPlanEditSnapshot(
    planId: planId,
    childPersonId: childId,
    timezone: 'America/Sao_Paulo',
    schedules: const [],
    scopeKind: differentContext == 'scope' ? 'home' : 'institution',
    institutionId: differentContext == 'institution' ? 'institution-b' : 'institution-a',
    unitId: differentContext == 'unit' ? 'unit-b' : 'unit-a',
    groupId: differentContext == 'group' ? 'group-b' : 'group-a',
    childContextId: differentContext == 'childContext' ? 'context-b' : 'context-a',
  );

  for (final mismatch in [
    'plan',
    'snapshotPlan',
    'child',
    'scope',
    'institution',
    'unit',
    'group',
    'childContext',
  ]) {
    testWidgets(
      'an edit receipt with another $mismatch preserves the pending intention for retry',
      (tester) async {
        var navigations = 0;
        final submitted = <HealthMedicationPlanFormDraft>[];
        final originalSnapshot = snapshot();
        await tester.pumpWidget(
          subject(
            medicationId: 'plan-a',
            initialDraft: _draft(editSnapshot: originalSnapshot),
            onSaved: () async => navigations++,
            onDraftSaved: (draft) async {
              submitted.add(draft);
              final invalid = submitted.length == 1;
              return HealthMedicationPlanSaveReceipt(
                planId: invalid && mismatch == 'plan' ? 'plan-b' : 'plan-a',
                version: 1,
                editSnapshot: invalid
                    ? snapshot(
                        planId: mismatch == 'snapshotPlan' ? 'plan-b' : 'plan-a',
                        childId: mismatch == 'child' ? 'child-b' : 'child-a',
                        differentContext: mismatch,
                      )
                    : originalSnapshot,
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        await _openReviewAndSave(tester, 'Salvar alterações');
        await tester.pumpAndSettle();

        expect(navigations, 0);
        expect(find.byKey(const Key('health-medication-save-error')), findsOneWidget);
        expect(find.text('Dipirona'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
        await tester.pumpAndSettle();

        expect(submitted, hasLength(2));
        expect(submitted.last, same(submitted.first));
        expect(submitted.last.planId, 'plan-a');
        expect(submitted.last.editSnapshot, same(originalSnapshot));
        expect(navigations, 1);
        expect(find.byKey(const Key('health-medication-save-error')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final withContext in [false, true]) {
    testWidgets(
      'creation accepts a server plan ID with a matching ${withContext ? 'context' : 'child'} snapshot',
      (tester) async {
        var navigations = 0;
        final submitted = <HealthMedicationPlanFormDraft>[];
        await tester.pumpWidget(
          subject(
            initialDraft: _draft(
              editSnapshot: withContext ? snapshot(planId: 'draft-context') : null,
            ),
            onSaved: () async => navigations++,
            onDraftSaved: (draft) async {
              submitted.add(draft);
              return HealthMedicationPlanSaveReceipt(
                planId: 'server-created-plan',
                version: 1,
                editSnapshot: snapshot(
                  planId: 'server-created-plan',
                  childId: !withContext && submitted.length == 1 ? 'child-b' : 'child-a',
                  differentContext: withContext && submitted.length == 1 ? 'childContext' : null,
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        await _openReviewAndSave(tester, 'Criar plano');
        await tester.pumpAndSettle();
        expect(navigations, 0);
        expect(find.byKey(const Key('health-medication-save-error')), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
        await tester.pumpAndSettle();
        expect(submitted.last, same(submitted.first));
        expect(submitted.last.planId, isNull);
        expect(navigations, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a late receipt from the previous snapshot context cannot navigate or change the new draft',
    (tester) async {
      final pending = Completer<HealthMedicationPlanSaveReceipt>();
      var navigations = 0;
      final submitted = <HealthMedicationPlanFormDraft>[];
      Future<void> onSaved() async {
        navigations++;
      }

      Future<HealthMedicationPlanSaveReceipt> save(HealthMedicationPlanFormDraft draft) {
        submitted.add(draft);
        if (submitted.length == 1) return pending.future;
        return Future.value(
          HealthMedicationPlanSaveReceipt(
            planId: 'plan-a',
            version: 1,
            editSnapshot: draft.editSnapshot,
          ),
        );
      }

      await tester.pumpWidget(
        subject(
          medicationId: 'plan-a',
          initialDraft: _draft(editSnapshot: snapshot()),
          onSaved: onSaved,
          onDraftSaved: save,
        ),
      );
      await tester.pumpAndSettle();
      await _openReviewAndSave(tester, 'Salvar alterações');
      await tester.pumpWidget(
        subject(
          medicationId: 'plan-a',
          initialDraft: _draft(editSnapshot: snapshot(differentContext: 'childContext')),
          onSaved: onSaved,
          onDraftSaved: save,
        ),
      );
      pending.complete(
        HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 9, editSnapshot: snapshot()),
      );
      await tester.pumpAndSettle();
      expect(navigations, 0);
      expect(find.byKey(const Key('health-medication-save-error')), findsNothing);
      await _openReviewAndSave(tester, 'Salvar alterações');
      await tester.pumpAndSettle();
      expect(submitted.last.editSnapshot!.childContextId, 'context-b');
      expect(submitted.last.expectedVersion, 0);
      expect(submitted.last.requestId, isNot(submitted.first.requestId));
      expect(navigations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final changed in [false, true]) {
    testWidgets(
      'snapshot source ${changed ? 'changes reset' : 'equivalent values preserve'} unsaved medication edits',
      (tester) async {
        MedicationPlanEditSnapshot snapshot(String instructions) => MedicationPlanEditSnapshot(
          planId: 'plan-a',
          childPersonId: 'child-a',
          timezone: 'UTC',
          instructions: instructions,
          schedules: [
            MedicationScheduleDraft(timeOfDay: '08:00', weekdays: {1}, timezone: 'UTC'),
          ],
          scopeKind: 'home',
        );
        await tester.pumpWidget(subject(initialDraft: _draft(editSnapshot: snapshot('original'))));
        await tester.pumpAndSettle();
        final name = _textField(tester, 'Nome do medicamento');
        name.controller!.text = 'Unsaved edit';
        await tester.pumpWidget(
          subject(initialDraft: _draft(editSnapshot: snapshot(changed ? 'updated' : 'original'))),
        );
        await tester.pumpAndSettle();
        expect(
          _textField(tester, 'Nome do medicamento').controller!.text,
          changed ? 'Dipirona' : 'Unsaved edit',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dispose in [false, true]) {
    testWidgets(
      'late medication receipt is ignored after ${dispose ? 'dispose' : 'callback replacement'}',
      (tester) async {
        final pending = Completer<HealthMedicationPlanSaveReceipt>();
        final initial = _draft(validFrom: DateTime(2026, 9, 10));
        var savedA = 0;
        var savedB = 0;
        await tester.pumpWidget(
          subject(
            initialDraft: initial,
            onDraftSaved: (_) => pending.future,
            onSaved: () async => savedA++,
          ),
        );
        await tester.pumpAndSettle();
        await _openReviewAndSave(tester, 'Criar plano');
        await tester.pumpWidget(
          dispose
              ? const SizedBox.shrink()
              : subject(initialDraft: initial, onSaved: () async => savedB++),
        );
        await tester.pump();
        pending.complete(const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1));
        await tester.pumpAndSettle();
        expect(savedA, 0);
        expect(savedB, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('replacing medication source clears the pending command and hydrates the new plan', (
    tester,
  ) async {
    final pending = Completer<HealthMedicationPlanSaveReceipt>();
    final draftsB = <HealthMedicationPlanFormDraft>[];
    final initialA = _draft(validFrom: DateTime(2026, 9, 10));
    final initialB = HealthMedicationPlanFormDraft(
      childId: 'child-b',
      medicationName: 'Medicamento sintético B',
      doseAmount: 2,
      doseUnit: 'unidade',
      administrationRoute: 'oral',
      weekdays: const {2},
      responsibleIds: const {},
      planId: 'plan-b',
      expectedVersion: 7,
      validFrom: DateTime(2026, 9, 10),
    );
    await tester.pumpWidget(
      subject(
        initialDraft: initialA,
        childId: 'child-a',
        medicationId: 'plan-a',
        onDraftSaved: (_) => pending.future,
      ),
    );
    await tester.pumpAndSettle();
    await _openReviewAndSave(tester, 'Salvar alterações');
    await tester.pumpWidget(
      subject(
        initialDraft: initialB,
        childId: 'child-b',
        medicationId: 'plan-b',
        onDraftSaved: (draft) async {
          draftsB.add(draft);
          return const HealthMedicationPlanSaveReceipt(planId: 'plan-b', version: 8);
        },
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(0);
    await tester.pumpAndSettle();
    expect(_textField(tester, 'Nome do medicamento').controller!.text, 'Medicamento sintético B');
    pending.complete(const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1));
    await tester.pumpAndSettle();
    await _openReviewAndSave(tester, 'Salvar alterações');
    await tester.pumpAndSettle();
    expect(draftsB, hasLength(1));
    expect(draftsB.single.childId, 'child-b');
    expect(draftsB.single.planId, 'plan-b');
    expect(draftsB.single.expectedVersion, 7);
    expect(draftsB.single.medicationName, 'Medicamento sintético B');
    expect(tester.takeException(), isNull);
  });

  for (final edit in [false, true]) {
    testWidgets(
      'obsolete medication replay ${edit ? 'with edits' : 'without edits'} cannot continue saving',
      (tester) async {
        final pending = Completer<HealthMedicationPlanSaveReceipt>();
        final initial = _draft(validFrom: DateTime(2026, 9, 10));
        final draftsA = <HealthMedicationPlanFormDraft>[];
        var savedA = 0;
        var savedB = 0;
        await tester.pumpWidget(
          subject(
            initialDraft: initial,
            onDraftSaved: (draft) async {
              draftsA.add(draft);
              if (draftsA.length == 1) throw StateError('synthetic response lost');
              return pending.future;
            },
            onSaved: () async => savedA++,
          ),
        );
        await tester.pumpAndSettle();
        await _openReviewAndSave(tester, 'Criar plano');
        await tester.pumpAndSettle();
        if (edit) {
          tester
              .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
              .onStepSelected(0);
          await tester.pumpAndSettle();
          final field = find.byKey(const Key('health-medication-name')).hitTestable();
          final control = tester.widget<CoeloFormTextField>(
            find.ancestor(of: field, matching: find.byType(CoeloFormTextField)),
          );
          control.controller.text = 'Nome sintético atualizado';
          control.onChanged?.call(control.controller.text);
          await tester.pumpAndSettle();
          tester
              .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
              .onStepSelected(4);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('health-medication-primary-action')).hitTestable());
        await tester.pump();
        expect(draftsA, hasLength(2));
        await tester.pumpWidget(subject(initialDraft: initial, onSaved: () async => savedB++));
        await tester.pump();
        pending.complete(const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1));
        await tester.pumpAndSettle();
        expect(draftsA, hasLength(2));
        expect(savedA, 0);
        expect(savedB, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('obsolete medication failure cannot clear a newer busy state or show an error', (
    tester,
  ) async {
    final pendingA = Completer<HealthMedicationPlanSaveReceipt>();
    final pendingB = Completer<HealthMedicationPlanSaveReceipt>();
    var savedA = 0;
    var savedB = 0;
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(),
        onDraftSaved: (_) => pendingA.future,
        onSaved: () async => savedA++,
      ),
    );
    await tester.pumpAndSettle();
    await _openReviewAndSave(tester, 'Criar plano');
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(),
        onDraftSaved: (_) => pendingB.future,
        onSaved: () async => savedB++,
      ),
    );
    await tester.pumpAndSettle();
    await _openReviewAndSave(tester, 'Criar plano');
    final primary = find.byKey(const Key('health-medication-primary-action')).hitTestable();
    expect(tester.widget<FilledButton>(primary).onPressed, isNull);
    pendingA.completeError(StateError('synthetic old failure'));
    await tester.pump();
    expect(find.byKey(const Key('health-medication-save-error')), findsNothing);
    expect(tester.widget<FilledButton>(primary).onPressed, isNull);
    pendingB.complete(const HealthMedicationPlanSaveReceipt(planId: 'plan-b', version: 1));
    await tester.pumpAndSettle();
    expect(savedA, 0);
    expect(savedB, 1);
    expect(tester.widget<FilledButton>(primary).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equivalent source draft rebuild preserves unsaved medication edits', (tester) async {
    await tester.pumpWidget(subject(initialDraft: _draft(validFrom: DateTime(2026, 9, 10))));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('health-medication-name')).hitTestable(),
      'Edição sintética local',
    );
    await tester.pumpWidget(subject(initialDraft: _draft(validFrom: DateTime(2026, 9, 10))));
    await tester.pumpAndSettle();
    expect(_textField(tester, 'Nome do medicamento').controller!.text, 'Edição sintética local');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'callback replacement retries the unchanged medication intention without an extra revision',
    (tester) async {
      final pending = Completer<HealthMedicationPlanSaveReceipt>();
      final initial = _draft(validFrom: DateTime(2026, 9, 10));
      final draftsA = <HealthMedicationPlanFormDraft>[];
      final draftsB = <HealthMedicationPlanFormDraft>[];
      var savedB = 0;
      await tester.pumpWidget(
        subject(
          initialDraft: initial,
          onDraftSaved: (draft) {
            draftsA.add(draft);
            return pending.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openReviewAndSave(tester, 'Criar plano');
      await tester.pumpWidget(
        subject(
          initialDraft: initial,
          onDraftSaved: (draft) async {
            draftsB.add(draft);
            return const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1);
          },
          onSaved: () async => savedB++,
        ),
      );
      await tester.pump();
      pending.complete(const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('health-medication-primary-action')).hitTestable());
      await tester.pumpAndSettle();
      expect(draftsB, hasLength(1));
      expect(draftsB.single.requestId, draftsA.single.requestId);
      expect(savedB, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses canonical form frame and locks child when editing', (tester) async {
    var changeChildCalls = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      subject(
        medicationId: 'plan-a',
        childId: 'child-a',
        onChangeChild: () => changeChildCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Trocar de criança'), findsOneWidget);
    expect(find.byType(CoeloMedicationChildSelector), findsNothing);

    await tester.tap(find.text('Trocar de criança'));
    expect(changeChildCalls, 1);
  });

  testWidgets('create and edit expose the same medication input sections', (tester) async {
    Future<Set<String>> labelsFor(Widget page) async {
      await tester.pumpWidget(page);
      await tester.pumpAndSettle();
      final labels = <String>{};
      for (final step in const [
        'Criança e medicamento',
        'Vigência',
        'Horários e responsáveis',
        'Documento',
      ]) {
        await tester.tap(find.text(step).last);
        await tester.pumpAndSettle();
        labels.addAll(
          tester
              .widgetList<Text>(find.byType(Text))
              .map((widget) => widget.data)
              .whereType<String>()
              .where(
                (label) => const {
                  'Nome do medicamento',
                  'Dose',
                  'Unidade',
                  'Via',
                  'Imagem do medicamento',
                  'Data de início',
                  'Data de término',
                  'Horário',
                  'Dias da semana',
                  'Responsável',
                  'Prescrição',
                }.contains(label),
              ),
        );
      }
      return labels;
    }

    final createLabels = await labelsFor(subject());
    final editLabels = await labelsFor(subject(medicationId: 'plan-a', childId: 'child-a'));

    expect(createLabels, editLabels);
    expect(
      createLabels,
      containsAll(const {
        'Nome do medicamento',
        'Dose',
        'Unidade',
        'Via',
        'Imagem do medicamento',
        'Data de início',
        'Data de término',
        'Horário',
        'Dias da semana',
        'Responsável',
        'Prescrição',
      }),
    );
  });

  testWidgets('schedule uses date-only, time-only and weekday controls', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vigência'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloMedicationDateField), findsNWidgets(2));

    await tester.tap(find.text('Horários e responsáveis'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloMedicationTimeField), findsOneWidget);
    expect(find.byType(CoeloTimeField), findsOneWidget);
    expect(find.byType(CoeloMedicationWeekdaySelector), findsOneWidget);
    expect(find.byType(CoeloMedicationResponsibleSelector), findsOneWidget);
  });

  testWidgets('medication date uses the Coelo picker at 375 pixels and 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: const [HealthCareFormChoice(id: 'child-a', label: 'Ana')],
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder field(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(TextFormField));
    await tester.enterText(field('Nome do medicamento'), 'Ibuprofeno');
    await tester.enterText(field('Dose'), '5');
    await tester.enterText(field('Unidade'), 'ml');
    await tester.pump();
    final formScroll = find
        .descendant(
          of: find.byKey(const Key('health-medication-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final continueButton = find.widgetWithText(FilledButton, 'Continuar');
    await tester.scrollUntilVisible(continueButton, 200, scrollable: formScroll);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    final dateField = find.text('Selecionar data').first;
    await tester.scrollUntilVisible(dateField, 200, scrollable: formScroll);
    await tester.ensureVisible(dateField);
    await tester.pumpAndSettle();
    await tester.tap(dateField);
    await tester.pumpAndSettle();

    expect(find.byType(CoeloDateRangePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medication inputs stack before labels can be clipped at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: const [HealthCareFormChoice(id: 'child-a', label: 'Ana')],
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder field(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(CoeloFormTextField));
    expect(tester.getTopLeft(field('Nome do medicamento')).dx, tester.getTopLeft(field('Dose')).dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit hydrates its draft and blocks an end date before its start date', (
    tester,
  ) async {
    var draftSaveCalls = 0;
    var savedCalls = 0;
    final initialDraft = _draft(validFrom: DateTime(2026, 9, 10), validUntil: DateTime(2026, 9, 9));
    await tester.pumpWidget(
      subject(
        medicationId: 'plan-a',
        childId: 'child-a',
        initialDraft: initialDraft,
        onDraftSaved: (_) async {
          draftSaveCalls += 1;
          return const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1);
        },
        onSaved: () async => savedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(_textField(tester, 'Nome do medicamento').controller!.text, 'Dipirona');
    expect(_textField(tester, 'Dose').controller!.text, '5');
    expect(_textField(tester, 'Unidade').controller!.text, 'ml');
    await _openReviewAndSave(tester, 'Salvar alterações');

    expect(draftSaveCalls, 0);
    expect(savedCalls, 0);
    expect(find.byKey(const Key('health-medication-save-error')), findsOneWidget);
    expect(
      find.bySemanticsLabel('A data de término não pode ser anterior à data de início.'),
      findsOneWidget,
    );
    expect(find.text('10/09/2026 a 09/09/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an end date before today is invalid when the start date is omitted', (tester) async {
    var draftSaveCalls = 0;
    var savedCalls = 0;
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(validUntil: DateTime(2000)),
        onDraftSaved: (_) async {
          draftSaveCalls += 1;
          return const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1);
        },
        onSaved: () async => savedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await _openReviewAndSave(tester, 'Criar plano');

    expect(draftSaveCalls, 0);
    expect(savedCalls, 0);
    expect(
      find.bySemanticsLabel('A data de término não pode ser anterior à data de início.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed draft save keeps values and retries without false success', (tester) async {
    var draftSaveCalls = 0;
    var savedCalls = 0;
    final submittedDrafts = <HealthMedicationPlanFormDraft>[];
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(validFrom: DateTime(2026, 9, 10)),
        onDraftSaved: (draft) async {
          draftSaveCalls += 1;
          submittedDrafts.add(draft);
          if (draftSaveCalls == 1) throw StateError('offline');
          return const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1);
        },
        onSaved: () async => savedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await _openReviewAndSave(tester, 'Criar plano');
    await tester.pumpAndSettle();

    expect(draftSaveCalls, 1);
    expect(savedCalls, 0);
    expect(find.byKey(const Key('health-medication-save-error')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Não foi possível salvar o plano de medicação. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Tentar novamente'), findsOneWidget);
    expect(find.text('Dipirona'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
    await tester.pumpAndSettle();

    expect(draftSaveCalls, 2);
    expect(savedCalls, 1);
    expect(submittedDrafts[0].requestId, isNotNull);
    expect(submittedDrafts[1].requestId, submittedDrafts[0].requestId);
    expect(submittedDrafts[1].medicationName, 'Dipirona');
    expect(submittedDrafts[1].validFrom, DateTime(2026, 9, 10));
    expect(find.byKey(const Key('health-medication-save-error')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(validFrom: DateTime(2026, 9, 10)),
        onDraftSaved: (draft) async {
          submittedDrafts.add(draft);
          return const HealthMedicationPlanSaveReceipt(planId: 'plan-b', version: 1);
        },
        onSaved: () async {},
      ),
    );
    await tester.pumpAndSettle();
    await _openReviewAndSave(tester, 'Criar plano');

    expect(submittedDrafts[2].requestId, isNot(submittedDrafts[0].requestId));
  });

  testWidgets('editing after an ambiguous failure starts a new request intention', (tester) async {
    final repository = DevMedicationPlanRepository();
    final submittedDrafts = <HealthMedicationPlanFormDraft>[];
    var savedCalls = 0;
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(validFrom: DateTime(2026, 9, 10)),
        onDraftSaved: (draft) async {
          submittedDrafts.add(draft);
          final saved = await _saveMedicationDraft(repository, draft);
          if (submittedDrafts.length == 1) throw StateError('response lost');
          return HealthMedicationPlanSaveReceipt(planId: saved.id, version: saved.currentVersion);
        },
        onSaved: () async => savedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await _openReviewAndSave(tester, 'Criar plano');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Tentar novamente'), findsOneWidget);

    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(0);
    await tester.pumpAndSettle();
    expect(find.byType(HealthMedicationPlanFormPage), findsOneWidget);
    final visibleMedicationNameField = find
        .byKey(const Key('health-medication-name'))
        .hitTestable();
    final coeloMedicationNameField = tester.widget<CoeloFormTextField>(
      find.ancestor(of: visibleMedicationNameField, matching: find.byType(CoeloFormTextField)),
    );
    coeloMedicationNameField.controller.text = 'Dipirona atualizada';
    coeloMedicationNameField.onChanged?.call('Dipirona atualizada');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(visibleMedicationNameField).controller!.text,
      'Dipirona atualizada',
    );
    expect(find.byKey(const Key('health-medication-save-error')), findsNothing);
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(4);
    await tester.pumpAndSettle();
    expect(find.text('Dipirona atualizada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('health-medication-primary-action')).hitTestable());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(submittedDrafts, hasLength(3));
    expect(submittedDrafts[1].requestId, submittedDrafts[0].requestId);
    expect(submittedDrafts[2].requestId, isNot(submittedDrafts[0].requestId));
    expect(submittedDrafts[2].planId, isNotNull);
    expect(submittedDrafts[2].expectedVersion, 1);
    expect(submittedDrafts[2].medicationName, 'Dipirona atualizada');
    final page = await repository.fetchPage(const MedicationPlanQuery());
    final saved = await repository.fetchDetail(page.items.single.id);
    expect(page.total, 1);
    expect(saved.currentVersion, 2);
    expect(saved.medicationName, 'Dipirona atualizada');
    expect(savedCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step navigation after an ambiguous failure replays without a new revision', (
    tester,
  ) async {
    final repository = DevMedicationPlanRepository();
    final submittedDrafts = <HealthMedicationPlanFormDraft>[];
    var savedCalls = 0;
    await tester.pumpWidget(
      subject(
        initialDraft: _draft(validFrom: DateTime(2026, 9, 10)),
        onDraftSaved: (draft) async {
          submittedDrafts.add(draft);
          final saved = await _saveMedicationDraft(repository, draft);
          if (submittedDrafts.length == 1) throw StateError('response lost');
          return HealthMedicationPlanSaveReceipt(planId: saved.id, version: saved.currentVersion);
        },
        onSaved: () async => savedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await _openReviewAndSave(tester, 'Criar plano');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Tentar novamente'), findsOneWidget);

    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(0);
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(4);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-medication-primary-action')).hitTestable());
    await tester.pumpAndSettle();

    expect(submittedDrafts, hasLength(2));
    expect(submittedDrafts[1].requestId, submittedDrafts[0].requestId);
    final page = await repository.fetchPage(const MedicationPlanQuery());
    final saved = await repository.fetchDetail(page.items.single.id);
    expect(page.total, 1);
    expect(saved.currentVersion, 1);
    expect(saved.medicationName, 'Dipirona');
    expect(savedCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

HealthMedicationPlanFormDraft _draft({
  DateTime? validFrom,
  DateTime? validUntil,
  MedicationPlanEditSnapshot? editSnapshot,
}) => HealthMedicationPlanFormDraft(
  childId: 'child-a',
  medicationName: 'Dipirona',
  doseAmount: 5,
  doseUnit: 'ml',
  administrationRoute: 'oral',
  validFrom: validFrom,
  validUntil: validUntil,
  editSnapshot: editSnapshot,
  weekdays: const {1, 2, 3, 4, 5},
  responsibleIds: const {},
);

Future<MedicationPlanDetail> _saveMedicationDraft(
  DevMedicationPlanRepository repository,
  HealthMedicationPlanFormDraft draft,
) => repository.save(
  MedicationPlanSaveCommand(
    requestId: draft.requestId!,
    planId: draft.planId,
    childPersonId: draft.childId,
    expectedVersion: draft.expectedVersion,
    medicationName: draft.medicationName,
    doseAmount: draft.doseAmount,
    doseUnit: draft.doseUnit,
    administrationRoute: draft.administrationRoute,
    validFrom: draft.validFrom!,
    validUntil: draft.validUntil,
    reason: 'Teste local',
    scopeKind: 'home',
    timezone: 'America/Sao_Paulo',
    schedules: [
      MedicationScheduleDraft(
        timeOfDay: '08:00',
        weekdays: {1, 2, 3, 4, 5},
        timezone: 'America/Sao_Paulo',
      ),
    ],
  ),
);

TextFormField _textField(WidgetTester tester, String label) => tester.widget<TextFormField>(
  find.ancestor(of: find.text(label), matching: find.byType(TextFormField)),
);

Future<void> _openReviewAndSave(WidgetTester tester, String actionLabel) async {
  await tester.tap(find.text('Revisão').last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, actionLabel));
  await tester.pump();
}
