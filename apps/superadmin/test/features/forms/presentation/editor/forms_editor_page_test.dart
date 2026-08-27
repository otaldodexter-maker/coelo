import 'dart:ui';

import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is a static unavailable surface without autosave or success state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FormsEditorPage()));

    expect(find.text('Editor de formulários indisponível'), findsOneWidget);
    expect(find.textContaining('temporariamente indisponível'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('development editor uses the canonical wizard and saves only a local preview', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FormsEditorPage.development())));

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.text('Prévia de desenvolvimento'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.widgetWithText(FilledButton, 'Continuar'))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('forms-dev-title')), 'Autorização de passeio');
    await tester.pump();
    expect(
      tester
          .getSemantics(find.widgetWithText(TextButton, 'Limpar rascunho'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Limpar rascunho'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Autorização de passeio'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.text('Perguntas'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('forms-dev-question')),
      'A criança poderá participar?',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.text('Autorização de passeio'), findsOneWidget);
    expect(find.text('A criança poderá participar?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar rascunho local'));
    await tester.pump();
    expect(find.text('Rascunho salvo somente nesta prévia.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar rascunho'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-dev-title')), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).controller?.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('development editor keeps steps, actions and scroll at $width with 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: width == 1440 ? ThemeMode.dark : ThemeMode.light,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: FormsEditorPage.development()),
          ),
        ),
      );

      expect(find.byType(SuperadminFormFrame), findsOneWidget);
      expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
      expect(find.byKey(const Key('forms-dev-scroll')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Limpar rascunho'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
