import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_form_sections.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject({String? medicationId, String? childId, VoidCallback? onChangeChild}) =>
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          medicationId: medicationId,
          childId: childId,
          childOptions: const [
            HealthCareFormChoice(id: 'child-a', label: 'Ana'),
            HealthCareFormChoice(id: 'child-b', label: 'Bia'),
          ],
          onChangeChild: onChangeChild,
          onCancel: () {},
          onSaved: () async {},
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
    expect(find.byType(CoeloMedicationWeekdaySelector), findsOneWidget);
    expect(find.byType(CoeloMedicationResponsibleSelector), findsOneWidget);
  });
}
