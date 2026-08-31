import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/dev/dev_medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_form_sections.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();
    final dateField = find.text('Selecionar data').first;
    await tester.scrollUntilVisible(
      dateField,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('health-medication-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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

HealthMedicationPlanFormDraft _draft({DateTime? validFrom, DateTime? validUntil}) =>
    HealthMedicationPlanFormDraft(
      childId: 'child-a',
      medicationName: 'Dipirona',
      doseAmount: 5,
      doseUnit: 'ml',
      administrationRoute: 'oral',
      validFrom: validFrom,
      validUntil: validUntil,
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
