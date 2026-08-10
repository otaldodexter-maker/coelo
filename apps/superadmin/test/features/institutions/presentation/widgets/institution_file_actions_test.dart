import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('names the current directory view in the export preview', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: InstitutionFileActions(activityController: controller, viewLabel: 'Grupos'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Exportar CSV'));
    await tester.pump();

    expect(controller.activities.single.subject, 'Instituições · Grupos');
    expect(controller.activities.single.fileName, 'instituicoes-grupos.csv');
  });

  testWidgets('renders file toolbar previews in both themes and layouts', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final configuration in [
      (
        preview: institutionFileActionsPreview,
        size: const Size(320, 64),
        brightness: Brightness.light,
      ),
      (
        preview: institutionFileActionsDarkPreview,
        size: const Size(320, 64),
        brightness: Brightness.dark,
      ),
      (
        preview: institutionFileActionsCompactLightPreview,
        size: const Size(72, 64),
        brightness: Brightness.light,
      ),
      (
        preview: institutionFileActionsCompactDarkPreview,
        size: const Size(72, 64),
        brightness: Brightness.dark,
      ),
    ]) {
      await tester.binding.setSurfaceSize(configuration.size);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(configuration.preview());

      expect(find.byKey(const Key('institution-files-action')), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byKey(const Key('institution-files-action')))).brightness,
        configuration.brightness,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders both import steps in light and dark previews', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final configuration in [
      (
        preview: institutionImportSelectPreview,
        size: const Size(600, 420),
        brightness: Brightness.light,
        reviewing: false,
      ),
      (
        preview: institutionImportSelectDarkPreview,
        size: const Size(600, 420),
        brightness: Brightness.dark,
        reviewing: false,
      ),
      (
        preview: institutionImportReviewLightPreview,
        size: const Size(600, 460),
        brightness: Brightness.light,
        reviewing: true,
      ),
      (
        preview: institutionImportReviewDarkPreview,
        size: const Size(600, 460),
        brightness: Brightness.dark,
        reviewing: true,
      ),
    ]) {
      await tester.binding.setSurfaceSize(configuration.size);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(configuration.preview());

      expect(find.text('Importar instituições'), findsOneWidget);
      if (configuration.reviewing) {
        expect(find.text('Etapa 2 de 2 · Revisar'), findsOneWidget);
        expect(find.text('24 linhas válidas'), findsOneWidget);
        expect(find.text('Etapa 1 de 2 · Arquivo'), findsNothing);
      } else {
        expect(find.text('Etapa 1 de 2 · Arquivo'), findsOneWidget);
        expect(find.text('Etapa 2 de 2 · Revisar'), findsNothing);
        expect(find.text('24 linhas válidas'), findsNothing);
      }
      expect(Theme.of(tester.element(find.byType(Dialog))).brightness, configuration.brightness);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows one Arquivos menu with import and export options on desktop', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    expect(find.byKey(const Key('institution-files-action')), findsOneWidget);
    expect(find.byType(CoeloAdminFileActions), findsOneWidget);
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

  testWidgets('runs the two-step import and starts background progress', (tester) async {
    final controller = SuperadminActivityController(tickInterval: const Duration(seconds: 30));
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Importar instituições'), findsOneWidget);
    expect(find.text('Importar arquivo'), findsOneWidget);

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

  testWidgets('uses a neutral surface and prepares the XLSX template download', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    expect(find.byKey(const Key('institution-import-template-export')), findsOneWidget);
    expect(find.text('Exportar modelo .xlsx'), findsOneWidget);
    expect(find.text('Importar arquivo'), findsOneWidget);
    expect(
      tester.widget<Widget>(find.byKey(const Key('institution-demo-file-picker'))),
      isA<FilledButton>(),
    );
    expect(
      tester.widget<Widget>(find.byKey(const Key('institution-import-template-export'))),
      isA<OutlinedButton>(),
    );

    await tester.tap(find.byKey(const Key('institution-import-template-export')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Modelo XLSX pronto para download.'), findsOneWidget);
    expect(find.textContaining('demonstra'), findsNothing);
    final notice = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(notice.duration, const Duration(seconds: 6));
    expect(notice.behavior, SnackBarBehavior.floating);
    expect(notice.action, isNull);
  });

  testWidgets('shows a six-second informational notice when an export starts', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Exportar XLSX'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('A exportação está em andamento. Acompanhe pelo sininho.'), findsOneWidget);
    final notice = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(notice.duration, const Duration(seconds: 6));
    expect(notice.behavior, SnackBarBehavior.floating);
    expect(notice.action, isNull);
  });

  testWidgets('keeps the compact files menu anchored inside the viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, compact: true, size: const Size(375, 800)));

    final trigger = find.byKey(const Key('institution-files-action'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final firstItem = find.ancestor(
      of: find.text('Importar'),
      matching: find.byType(MenuItemButton),
    );
    final menuRect = tester.getRect(firstItem);
    expect(menuRect.left, greaterThanOrEqualTo(16));
    expect(menuRect.right, lessThanOrEqualTo(359));
    expect(menuRect.top, greaterThanOrEqualTo(tester.getBottomLeft(trigger).dy));
  });

  testWidgets('uses a neutral surface in the dark import dialog', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, theme: CoeloTheme.dark));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, CoeloTheme.dark.colorScheme.surface);
  });

  testWidgets('fits selection and review at 375 with scaled text in light and dark', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
      final controller = SuperadminActivityController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          controller,
          theme: theme,
          size: const Size(375, 800),
          textScaler: const TextScaler.linear(1.5),
        ),
      );

      await tester.tap(find.byKey(const Key('institution-files-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();

      final dialogBarrier = find.byWidgetPredicate(
        (widget) => widget is ModalBarrier && widget.color == Colors.black.withValues(alpha: 0.54),
      );
      expect(dialogBarrier, findsOneWidget);
      final barrier = tester.widget<ModalBarrier>(dialogBarrier);
      expect(barrier.dismissible, isTrue);
      expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, theme.colorScheme.surface);
      expect(tester.takeException(), isNull, reason: 'select / ${theme.brightness}');

      await tester.tap(find.byKey(const Key('institution-demo-file-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institution-import-review')));
      await tester.pumpAndSettle();

      expect(find.text('24 linhas válidas'), findsOneWidget);
      expect(find.text('Importar 26 linhas'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'review / ${theme.brightness}');
    }
  });

  testWidgets('creates a completed CSV export activity', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Exportar CSV'));
    await tester.pumpAndSettle();

    expect(controller.activities.single.fileName, 'instituicoes.csv');
    expect(controller.unreadCount, 1);
  });
}

Widget _app(
  SuperadminActivityController controller, {
  bool compact = false,
  ThemeData? theme,
  Size size = const Size(1024, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: theme ?? CoeloTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: textScaler),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Align(
            alignment: compact ? Alignment.topLeft : Alignment.topRight,
            child: InstitutionFileActions(activityController: controller, compact: compact),
          ),
        ),
      ),
    ),
  );
}
