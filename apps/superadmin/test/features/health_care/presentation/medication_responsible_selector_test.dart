import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_form_sections.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _name = 'Mariana de Albuquerque dos Santos';
const _options = [HealthCareFormChoice(id: 'responsible-a', label: _name)];

void main() {
  testWidgets('missing selected responsible stays removable without exposing its id', (
    tester,
  ) async {
    var selected = <String>{'unavailable-person-id'};
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CoeloMedicationResponsibleSelector(
              options: const [],
              selectedIds: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Responsável indisponível'), findsOneWidget);
    expect(find.text('unavailable-person-id'), findsNothing);
    tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('realistic responsible can be added and removed at 375 and 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setState) => CoeloMedicationResponsibleSelector(
                options: _options,
                selectedIds: selected,
                onChanged: (next) => setState(() => selected = next),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Adicionar'));
    await tester.pumpAndSettle();
    expect(selected, {'responsible-a'});
    expect(tester.takeException(), isNull);
    expect(find.text(_name), findsOneWidget);
    tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form review preserves recipient and labels an unavailable responsible honestly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    HealthMedicationPlanFormDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
          onDraftSaved: (draft) async {
            submitted = draft;
            return const HealthMedicationPlanSaveReceipt(planId: 'plan-a', version: 1);
          },
          childOptions: const [HealthCareFormChoice(id: 'child-a', label: 'Criança sintética')],
          responsibleOptions: _options,
          initialDraft: HealthMedicationPlanFormDraft(
            childId: 'child-a',
            medicationName: 'Medicamento sintético',
            doseAmount: 1,
            doseUnit: 'unidade',
            administrationRoute: 'oral',
            validFrom: DateTime(2026, 9, 12),
            weekdays: const {1},
            responsibleIds: const {'responsible-a', 'unavailable-person-id'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(4);
    await tester.pumpAndSettle();
    expect(find.text('$_name, Responsável indisponível'), findsOneWidget);
    expect(find.textContaining('unavailable-person-id'), findsNothing);
    expect(tester.takeException(), isNull);
    final save = find.byKey(const Key('health-medication-primary-action'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(submitted?.responsibleIds, {'responsible-a', 'unavailable-person-id'});
    expect(tester.takeException(), isNull);
  });
}
