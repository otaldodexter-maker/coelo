import 'dart:ui' show SemanticsAction;

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_activity_center.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders deterministic light and dark activity previews', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final configuration in [
      (preview: superadminActivityStatesLightPreview, brightness: Brightness.light),
      (preview: superadminActivityStatesDarkPreview, brightness: Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(const Size(400, 520));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(configuration.preview());

      final scrollable = find.byType(Scrollable).first;
      for (final id in [
        'preview-import',
        'preview-success',
        'preview-partial',
        'preview-error',
        'preview-announcement',
      ]) {
        final tile = find.byKey(Key('superadmin-activity-$id'));
        await tester.scrollUntilVisible(tile, 120, scrollable: scrollable);
        expect(
          find.descendant(of: tile, matching: find.text('21/07/2026 · 14:35')),
          findsOneWidget,
        );
      }
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme?.brightness,
        configuration.brightness,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders the empty activity preview in light and dark', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final configuration in [
      (preview: superadminActivityEmptyLightPreview, brightness: Brightness.light),
      (preview: superadminActivityEmptyDarkPreview, brightness: Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(const Size(400, 176));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(configuration.preview());

      expect(find.text('Nenhuma notificação por enquanto.'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme?.brightness,
        configuration.brightness,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('opens an empty responsive notification center', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(controller, size: const Size(375, 800)));
    expect(MediaQuery.sizeOf(tester.element(find.byType(SuperadminActivityCenter))).width, 375);

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Nenhuma notificação por enquanto.'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('superadmin-activity-panel'))).width, 343);
  });

  testWidgets('shows and clears the unread badge when the center opens', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.csv);
    await tester.pumpWidget(_app(controller));

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(controller.unreadCount, 0);
    expect(find.text('instituicoes.csv'), findsOneWidget);
    final status = find.byKey(const Key('superadmin-activity-status-demo-export-0'));
    final semanticsLabels = find
        .descendant(of: status, matching: find.byType(Semantics))
        .evaluate()
        .map((element) => (element.widget as Semantics).properties.label);
    expect(semanticsLabels, contains('Status: Concluída'));
  });

  testWidgets('updates the notification action label without duplicate tooltip semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.csv);
    await tester.pumpWidget(_app(controller));

    expect(find.bySemanticsLabel('Abrir notificações, 1 não lidas'), findsOneWidget);
    expect(find.bySemanticsLabel('Notificações'), findsNothing);

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Fechar notificações'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Abrir notificações')), findsNothing);
    semantics.dispose();
  });

  testWidgets('opens and closes notifications from the semantic tap action', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    final openAction = find.bySemanticsLabel('Abrir notificações');
    var data = tester.getSemantics(openAction).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.performAction(
      find.semantics.byLabel('Abrir notificações'),
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-activity-panel')), findsOneWidget);
    final closeAction = find.bySemanticsLabel('Fechar notificações');
    data = tester.getSemantics(closeAction).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.performAction(
      find.semantics.byLabel('Fechar notificações'),
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-activity-panel')), findsNothing);
    semantics.dispose();
  });

  testWidgets('closes the previous controller when an open center changes controller', (
    tester,
  ) async {
    final first = SuperadminActivityController();
    final second = SuperadminActivityController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var controller = first;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: SuperadminActivityCenter(controller: controller),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    rebuild(() => controller = second);
    await tester.pump();

    first.completeDemoExport(SuperadminExportFormat.csv);
    second.completeDemoExport(SuperadminExportFormat.xlsx);
    await tester.pump();

    expect(first.unreadCount, 1);
    expect(second.unreadCount, 0);
  });

  testWidgets('shows a deterministic timestamp under an activity', (tester) async {
    final now = DateTime(2026, 7, 21, 14, 35);
    final controller = SuperadminActivityController(now: () => now);
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.xlsx);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('21/07/2026 · 14:35'), findsOneWidget);
  });

  testWidgets('formats UTC timestamps in local time with a four-digit year', (tester) async {
    final createdAt = DateTime.utc(26, 7, 21, 14, 35);
    final controller = SuperadminActivityController.seeded([
      SuperadminActivity(
        id: 'utc-export',
        kind: SuperadminActivityKind.export,
        status: SuperadminActivityStatus.succeeded,
        subject: 'Instituições',
        summary: 'Arquivo preparado',
        createdAt: createdAt,
        fileName: 'instituicoes.xlsx',
      ),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(find.text(_expectedLocalTimestamp(createdAt)), findsOneWidget);
  });

  testWidgets('shows the thumb when three scaled activities overflow a low viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SuperadminActivityController.seeded(_fourActivities().take(3));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(controller, size: const Size(375, 320), textScaler: const TextScaler.linear(1.5)),
    );

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('superadmin-activity-panel'))).height, 288);
    expect(find.byKey(const Key('superadmin-activity-scrollbar')), findsOneWidget);
    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('superadmin-activity-scrollbar')),
    );
    expect(scrollbar.controller?.position.maxScrollExtent, greaterThan(0));
    expect(scrollbar.thumbVisibility, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pump();
    expect(find.byKey(const Key('superadmin-activity-divider-0')), findsOneWidget);
  });

  testWidgets('keeps the thumb hidden when a short list fits a high viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SuperadminActivityController.seeded(_fourActivities().take(1));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, size: const Size(800, 900)));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('superadmin-activity-scrollbar')),
    );
    expect(scrollbar.controller?.position.maxScrollExtent, 0);
    expect(scrollbar.thumbVisibility, isFalse);
  });

  testWidgets('updates the thumb from scroll metrics when open content grows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = SuperadminActivityController.seeded(_fourActivities().take(1));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, size: const Size(800, 900)));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Scrollbar>(find.byKey(const Key('superadmin-activity-scrollbar')))
          .thumbVisibility,
      isFalse,
    );

    controller
      ..completeDemoExport(SuperadminExportFormat.csv)
      ..completeDemoExport(SuperadminExportFormat.xlsx)
      ..completeDemoExport(SuperadminExportFormat.csv);
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('superadmin-activity-scrollbar')),
    );
    expect(scrollbar.controller?.position.maxScrollExtent, greaterThan(0));
    expect(scrollbar.thumbVisibility, isTrue);
  });

  testWidgets('highlights and prepares a demonstrative activity download', (tester) async {
    final controller = SuperadminActivityController.seeded(_fourActivities());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final exportTile = find.byKey(const Key('superadmin-activity-demo-export'));
    final tileInk = tester.widget<InkWell>(
      find.descendant(of: exportTile, matching: find.byType(InkWell)),
    );
    expect(tileInk.hoverColor, CoeloTheme.light.colorScheme.primaryContainer);
    expect(tileInk.focusColor, CoeloTheme.light.colorScheme.primaryContainer);
    expect(tileInk.borderRadius, BorderRadius.circular(CoeloRadius.md));
    final panelRect = tester.getRect(find.byKey(const Key('superadmin-activity-panel')));
    final tileRect = tester.getRect(exportTile);
    expect(tileRect.left, greaterThan(panelRect.left));
    expect(tileRect.right, lessThan(panelRect.right));
    final iconSurface = tester.widget<Container>(
      find.byKey(const Key('superadmin-activity-icon-demo-export')),
    );
    final iconDecoration = iconSurface.decoration! as BoxDecoration;
    expect(iconDecoration.color, isNot(CoeloTheme.light.colorScheme.primaryContainer));

    final announcementInk = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('superadmin-activity-announcement-1')),
        matching: find.byType(InkWell),
      ),
    );
    expect(announcementInk.onTap, isNull);

    await tester.tap(exportTile);
    await tester.pump();

    expect(find.text('Download demonstrativo de instituicoes.xlsx preparado.'), findsOneWidget);
  });

  testWidgets('uses the light semantic container for the collapsed status marker', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.xlsx);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final marker = tester.widget<Container>(
      find.byKey(const Key('superadmin-activity-status-surface-demo-export-0')),
    );
    final decoration = marker.decoration! as BoxDecoration;
    expect(decoration.color, CoeloTheme.light.extension<CoeloStatusColors>()!.successContainer);
  });

  testWidgets('keeps a file activity without a filename inert', (tester) async {
    final controller = SuperadminActivityController.seeded([
      SuperadminActivity(
        id: 'export-without-file',
        kind: SuperadminActivityKind.export,
        status: SuperadminActivityStatus.failed,
        subject: 'Instituições',
        summary: 'Nenhum arquivo foi gerado',
        createdAt: DateTime(2026, 7, 21, 14, 35),
      ),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final tileInk = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('superadmin-activity-export-without-file')),
        matching: find.byType(InkWell),
      ),
    );

    expect(tileInk.onTap, isNull);
  });

  testWidgets('expands an activity status with mouse and touch', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.xlsx);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final status = find.byKey(const Key('superadmin-activity-status-demo-export-0'));
    expect(tester.getSize(status).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(tester.getSize(status).width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(find.descendant(of: status, matching: find.byType(AnimatedContainer)), findsNothing);
    expect(find.descendant(of: status, matching: find.text('Concluída')), findsNothing);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(status));
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('toggles status with Enter and Space without starting the tile download', (
    tester,
  ) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.xlsx);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final status = find.byKey(const Key('superadmin-activity-status-demo-export-0'));
    final detector = tester.widget<FocusableActionDetector>(
      find.descendant(of: status, matching: find.byType(FocusableActionDetector)),
    );
    expect(detector.focusNode, isNotNull);
    detector.focusNode!.requestFocus();
    await tester.pump();
    expect(detector.focusNode!.hasPrimaryFocus, isTrue);

    final statusLabel = find.descendant(of: status, matching: find.text('Concluída'));
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      expect(statusLabel, findsNothing);
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(statusLabel, findsOneWidget);
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(statusLabel, findsNothing);
    }

    expect(find.text('Download demonstrativo de instituicoes.xlsx preparado.'), findsNothing);
  });

  testWidgets('keeps one exact status label and semantic tap action while expanded', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    controller.completeDemoExport(SuperadminExportFormat.xlsx);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final status = find.byKey(const Key('superadmin-activity-status-demo-export-0'));
    Finder statusSemantics() => find.bySemanticsLabel(RegExp('^Status: Concluída'));
    var data = tester.getSemantics(statusSemantics()).getSemanticsData();
    expect(data.label, 'Status: Concluída');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.performAction(
      find.semantics.byLabel('Status: Concluída'),
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();

    expect(find.descendant(of: status, matching: find.text('Concluída')), findsOneWidget);
    data = tester.getSemantics(statusSemantics()).getSemanticsData();
    expect(data.label, 'Status: Concluída');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.performAction(
      find.semantics.byLabel('Status: Concluída'),
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();

    expect(find.descendant(of: status, matching: find.text('Concluída')), findsNothing);
    semantics.dispose();
  });

  testWidgets('closes with Escape and returns focus to the notification trigger', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    final trigger = find.byKey(const Key('superadmin-notifications'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-activity-panel')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-activity-panel')), findsNothing);
    expect(tester.widget<IconButton>(trigger).focusNode?.hasPrimaryFocus, isTrue);
  });

  testWidgets('closes with the close button and returns focus to the notification trigger', (
    tester,
  ) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    final trigger = find.byKey(const Key('superadmin-notifications'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-activity-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-activity-panel')), findsNothing);
    expect(tester.widget<IconButton>(trigger).focusNode?.hasPrimaryFocus, isTrue);
  });
}

List<SuperadminActivity> _fourActivities() => [
  SuperadminActivity(
    id: 'demo-export',
    kind: SuperadminActivityKind.export,
    status: SuperadminActivityStatus.succeeded,
    subject: 'Instituições',
    summary: 'Arquivo preparado',
    createdAt: DateTime(2026, 7, 21, 14, 35),
    fileName: 'instituicoes.xlsx',
    progress: 100,
  ),
  SuperadminActivity(
    id: 'demo-import',
    kind: SuperadminActivityKind.import,
    status: SuperadminActivityStatus.partial,
    subject: 'Instituições',
    summary: '24 importadas, 2 rejeitadas',
    createdAt: DateTime(2026, 7, 21, 14),
    fileName: 'instituicoes-julho.xlsx',
    progress: 100,
  ),
  SuperadminActivity.announcement(
    id: 'announcement-1',
    subject: 'Novidade no Superadmin',
    summary: 'Uma nova função está disponível.',
    createdAt: DateTime(2026, 7, 21, 13, 30),
  ),
  SuperadminActivity.announcement(
    id: 'announcement-2',
    subject: 'Manutenção concluída',
    summary: 'Todos os serviços estão disponíveis.',
    createdAt: DateTime(2026, 7, 21, 13),
  ),
];

String _expectedLocalTimestamp(DateTime value) {
  final localValue = value.toLocal();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(localValue.day)}/${twoDigits(localValue.month)}/'
      '${localValue.year.toString().padLeft(4, '0')}'
      ' · ${twoDigits(localValue.hour)}:${twoDigits(localValue.minute)}';
}

Widget _app(
  SuperadminActivityController controller, {
  Size size = const Size(800, 600),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: textScaler),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: SuperadminActivityCenter(controller: controller),
        ),
      ),
    ),
  );
}
