import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders file toolbar previews in both themes and layouts', (tester) async {
    for (final preview in [
      institutionFileActionsPreview,
      institutionFileActionsDarkPreview,
      institutionFileActionsCompactLightPreview,
      institutionFileActionsCompactDarkPreview,
    ]) {
      await tester.pumpWidget(preview());

      expect(find.byKey(const Key('institution-files-action')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders both import steps in light and dark previews', (tester) async {
    for (final preview in [
      institutionImportSelectPreview,
      institutionImportSelectDarkPreview,
      institutionImportReviewLightPreview,
      institutionImportReviewDarkPreview,
    ]) {
      await tester.pumpWidget(preview());

      expect(find.text('Importar instituições'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows one Arquivos menu with import and export options on desktop', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    expect(find.byKey(const Key('institution-files-action')), findsOneWidget);
    expect(find.text('Arquivos'), findsOneWidget);
    expect(find.byKey(const Key('institution-import-action')), findsNothing);
    expect(find.byKey(const Key('institution-export-action')), findsNothing);

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();

    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);
  });

  testWidgets('condenses file actions into one compact menu below 768', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, compact: true));

    expect(find.byKey(const Key('institution-files-action')), findsOneWidget);
    expect(find.text('Exportar'), findsNothing);
    expect(find.text('Importar'), findsNothing);
  });

  testWidgets('runs the two-step import demo and starts background progress', (tester) async {
    final controller = SuperadminActivityController(tickInterval: const Duration(seconds: 30));
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-files-import')));
    await tester.pumpAndSettle();
    expect(find.text('Importar instituições'), findsOneWidget);
    expect(find.text('Selecionar arquivo de demonstração'), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-demo-file-picker')));
    await tester.pumpAndSettle();
    expect(find.text('instituicoes-julho.xlsx'), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-import-review')));
    await tester.pumpAndSettle();
    expect(find.text('24 linhas válidas'), findsOneWidget);
    expect(find.text('2 linhas com erro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-import-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Importar instituições'), findsNothing);
    expect(controller.activities.single.status, SuperadminActivityStatus.inProgress);
    expect(controller.activities.single.progress, 0);
    controller.dispose();
  });

  testWidgets('uses a neutral surface and prepares the demo XLSX template download', (
    tester,
  ) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-files-import')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    expect(find.byKey(const Key('institution-import-template-export')), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-import-template-export')));
    await tester.pump();

    expect(find.text('Modelo XLSX preparado para download demonstrativo.'), findsOneWidget);
  });

  testWidgets('uses a neutral surface in the dark import dialog', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, theme: CoeloTheme.dark));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-files-import')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, CoeloTheme.dark.colorScheme.surface);
  });

  testWidgets('creates a completed CSV export activity', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-files-export-csv')));
    await tester.pumpAndSettle();

    expect(controller.activities.single.fileName, 'instituicoes.csv');
    expect(controller.unreadCount, 1);
  });
}

Widget _app(SuperadminActivityController controller, {bool compact = false, ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? CoeloTheme.light,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1024, 800)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: InstitutionFileActions(activityController: controller, compact: compact),
        ),
      ),
    ),
  );
}
