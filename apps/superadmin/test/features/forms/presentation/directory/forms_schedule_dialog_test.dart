import 'package:coelo_superadmin/features/forms/presentation/directory/forms_schedule_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits the approved schedule fields in a content-height dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FormsScheduleDraft? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFormsScheduleDialog(
              context: context,
              initialValue: FormsScheduleDraft(
                active: true,
                name: 'Visita pedagógica — fotos',
                startsAt: DateTime(2026, 8, 12, 8),
                endsAt: DateTime(2026, 11, 30, 18),
                frequency: FormsScheduleFrequency.weekly,
                weekdays: const {DateTime.monday, DateTime.wednesday, DateTime.friday},
                audienceLabel: 'Professores e auxiliares',
              ),
              onSave: (value) async => saved = value,
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    expect(find.text('Editar agendamento'), findsOneWidget);
    expect(find.byType(CoeloAdminToggleField), findsOneWidget);
    expect(find.byType(CoeloDateTimeField), findsNWidgets(2));
    expect(find.text('Professores e auxiliares'), findsOneWidget);
    final surface = find.descendant(of: find.byType(Dialog), matching: find.byType(Material));
    expect(tester.getSize(surface.last).height, lessThan(850));

    await tester.enterText(find.byKey(const Key('forms-schedule-name')), 'Fotos da visita');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Fotos da visita');
    expect(find.byType(CoeloAdminDialogShell), findsNothing);
  });

  testWidgets('stays overflow-free at 375 pixels and 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFormsScheduleDialog(
              context: context,
              initialValue: FormsScheduleDraft.empty(),
              onSave: (_) async {},
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-dialog-keyboard-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an end before the start', (tester) async {
    var saves = 0;
    await _pumpDialog(
      tester,
      initialValue: FormsScheduleDraft(
        active: true,
        name: 'Pesquisa semanal',
        startsAt: DateTime(2026, 9, 10, 10),
        endsAt: DateTime(2026, 9, 10, 9),
        frequency: FormsScheduleFrequency.once,
        weekdays: const {},
        audienceLabel: 'Famílias',
      ),
      onSave: (_) async => saves++,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();

    expect(find.text('A data de término deve ser igual ou posterior ao início.'), findsOneWidget);
    expect(saves, 0);
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
  });

  testWidgets('requires at least one weekday for weekly recurrence', (tester) async {
    var saves = 0;
    await _pumpDialog(
      tester,
      initialValue: FormsScheduleDraft(
        active: true,
        name: 'Pesquisa semanal',
        startsAt: DateTime(2026, 9, 10, 9),
        endsAt: DateTime(2026, 9, 10, 10),
        frequency: FormsScheduleFrequency.weekly,
        weekdays: const {},
        audienceLabel: 'Famílias',
      ),
      onSave: (_) async => saves++,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();

    expect(find.text('Selecione ao menos um dia para a recorrência semanal.'), findsOneWidget);
    expect(saves, 0);
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
  });

  testWidgets('keeps save disabled with an honest integration reason', (tester) async {
    await _pumpDialog(
      tester,
      initialValue: FormsScheduleDraft.empty(),
      unavailableReason: 'A integração de agendamentos não está disponível neste ambiente.',
    );

    expect(
      find.text('A integração de agendamentos não está disponível neste ambiente.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar')).onPressed,
      isNull,
    );
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FormsScheduleDraft initialValue,
  Future<void> Function(FormsScheduleDraft value)? onSave,
  String? unavailableReason,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showFormsScheduleDialog(
            context: context,
            initialValue: initialValue,
            onSave: onSave,
            unavailableReason: unavailableReason,
          ),
          child: const Text('Abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
