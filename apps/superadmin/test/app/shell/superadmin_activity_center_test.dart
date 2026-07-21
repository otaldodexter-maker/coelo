import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_activity_center.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('makes a long activity list scrollable with inset dividers', (tester) async {
    final controller = SuperadminActivityController.seeded(_fourActivities());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-activity-scrollbar')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-activity-divider-0')), findsOneWidget);
    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('superadmin-activity-scrollbar')),
    );
    expect(scrollbar.thumbVisibility, isTrue);
  });

  testWidgets('keeps the scrollbar thumb hidden for a short activity list', (tester) async {
    final controller = SuperadminActivityController.seeded(_fourActivities().take(3));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('superadmin-activity-scrollbar')),
    );
    expect(scrollbar.thumbVisibility, isFalse);
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
    var animatedStatus = tester.widget<AnimatedContainer>(
      find.descendant(of: status, matching: find.byType(AnimatedContainer)),
    );
    expect(animatedStatus.child, isA<SizedBox>());
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(status));
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);
    animatedStatus = tester.widget<AnimatedContainer>(
      find.descendant(of: status, matching: find.byType(AnimatedContainer)),
    );
    expect(animatedStatus.child, isA<Text>());

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);
    await gesture.removePointer();
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
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
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
    expect(Focus.of(tester.element(trigger)).hasFocus, isTrue);
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

Widget _app(SuperadminActivityController controller, {Size size = const Size(800, 600)}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: SuperadminActivityCenter(controller: controller),
        ),
      ),
    ),
  );
}
