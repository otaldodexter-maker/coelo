import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/screens/support_page.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers create actions in kanban and table with table pagination', (tester) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(12));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(find.byKey(const Key('support-create-kanban')), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-view-toggle-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-create-table')), findsOneWidget);
    expect(find.byKey(const Key('support-pagination')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-row-background-SUP-010')), findsNothing);

    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-table-row-background-SUP-010')), findsOneWidget);
  });

  testWidgets('uses one responsible selector and exposes explicit fullscreen action', (
    tester,
  ) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(1));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-detail-assignees')), findsOneWidget);
    expect(find.byKey(const Key('support-detail-owner')), findsNothing);
    expect(find.byKey(const Key('support-detail-collaborators')), findsNothing);

    await tester.tap(find.byKey(const Key('support-detail-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-expanded-detail')), findsOneWidget);
  });

  testWidgets('closes the expanded detail without exposing an empty fullscreen state', (
    tester,
  ) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(1));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support-detail-expand')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support-detail-close')).last);
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('support-expanded-detail')),
        matching: find.text('Selecione um chamado'),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-expanded-detail')), findsNothing);
    expect(find.byKey(const Key('support-page-content')), findsOneWidget);
    expect(find.byKey(const Key('support-card-SUP-001')), findsOneWidget);
  });

  testWidgets('moves the expanded detail by dragging its header and keeps it in the viewport', (
    tester,
  ) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(1));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support-detail-expand')));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('support-expanded-detail'));
    final handle = find.byKey(const Key('support-detail-drag-handle'));
    final initialTopLeft = tester.getTopLeft(panel);
    await tester.drag(handle, const Offset(120, 80));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(panel), isNot(initialTopLeft));

    await tester.drag(handle, const Offset(5000, 5000));
    await tester.pumpAndSettle();
    final rect = tester.getRect(panel);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(1440));
    expect(rect.bottom, lessThanOrEqualTo(900));
  });

  testWidgets('moves and resets the expanded detail from the keyboard', (tester) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(1));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('support-detail-expand')));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('support-expanded-detail'));
    final handle = find.byKey(const Key('support-detail-drag-handle'));
    final initialTopLeft = tester.getTopLeft(panel);
    await tester.tap(handle);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(tester.getTopLeft(panel).dx, greaterThan(initialTopLeft.dx));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(tester.getTopLeft(panel), initialTopLeft);
  });

  testWidgets('labels the support workspace as Support and implementation', (tester) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(1));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(find.text('Suporte e implantação'), findsWidgets);
  });

  testWidgets('keeps Support accessible across scale, viewport, theme and reduced motion', (
    tester,
  ) async {
    await _expectResponsiveSupportMatrix(tester, textScaler: const TextScaler.linear(1.5));
    await _expectResponsiveSupportMatrix(tester, textScaler: const TextScaler.linear(2));

    final controller = SupportPrototypeController(initialTickets: _tickets(12));
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller,
      size: const Size(375, 900),
      textScaler: const TextScaler.linear(2),
      disableAnimations: true,
    );

    await tester.tap(find.byKey(const Key('support-view-toggle-table')));
    await tester.pumpAndSettle();

    final verticalTableScroll = find.ancestor(
      of: find.byKey(const Key('support-ticket-table')),
      matching: find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
      ),
    );
    expect(verticalTableScroll, findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('support-create-table')),
        matching: verticalTableScroll,
      ),
      findsNothing,
    );
    expect(
      find.ancestor(of: find.byKey(const Key('support-pagination')), matching: verticalTableScroll),
      findsNothing,
    );

    final previous = find.byKey(const Key('coelo-admin-pagination-previous'));
    final next = find.byKey(const Key('coelo-admin-pagination-next'));
    expect(tester.getSemantics(previous).label, contains('Página anterior'));
    expect(tester.getSemantics(next).label, contains('Próxima página'));
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsNothing);
    expect(find.byKey(const Key('coelo-admin-pagination-page-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

List<SupportTicket> _tickets(int count) {
  final now = DateTime.utc(2026, 7, 28, 12);
  return [
    for (var index = 1; index <= count; index++)
      SupportTicket(
        id: 'SUP-${index.toString().padLeft(3, '0')}',
        subject: 'Chamado $index',
        menu: 'Instituicoes',
        screen: 'Diretorio',
        description: 'Descricao',
        requester: 'Pessoa',
        createdAt: now,
        updatedAt: now.subtract(Duration(minutes: index)),
        status: SupportTicketStatus.newRequest,
      ),
  ];
}

Future<void> _expectResponsiveSupportMatrix(
  WidgetTester tester, {
  required TextScaler textScaler,
}) async {
  const widths = [375.0, 768.0, 1024.0, 1440.0];
  final themes = [CoeloTheme.light, CoeloTheme.dark];

  for (final theme in themes) {
    for (final width in widths) {
      final controller = SupportPrototypeController(initialTickets: _tickets(12));
      addTearDown(controller.dispose);
      await _pump(tester, controller, size: Size(width, 900), theme: theme, textScaler: textScaler);
      expect(
        tester.takeException(),
        isNull,
        reason: '${theme.brightness} at $width px and ${textScaler.scale(10) / 10}x text',
      );

      await tester.tap(find.byKey(const Key('support-view-toggle-table')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'table ${theme.brightness} at $width px and ${textScaler.scale(10) / 10}x text',
      );
      expect(find.byKey(const Key('support-create-table')), findsOneWidget);
      expect(find.byKey(const Key('support-pagination')), findsOneWidget);
    }
  }
}

Future<void> _pump(
  WidgetTester tester,
  SupportPrototypeController controller, {
  Size size = const Size(1440, 900),
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: textScaler, disableAnimations: disableAnimations),
        child: child!,
      ),
      home: SupportPage(
        controller: controller,
        logout: () async => const LogoutResult.success(),
        onInstitutionsOpen: () {},
        onCatalogOpen: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}
