import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/screens/support_page.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers create actions in kanban and table with table pagination', (tester) async {
    final controller = SupportPrototypeController(initialTickets: _tickets(12));
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(find.byKey(const Key('support-create-kanban')), findsOneWidget);

    await tester.tap(find.byTooltip('Exibir como tabela'));
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
    expect(find.byType(Dialog), findsOneWidget);
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

Future<void> _pump(WidgetTester tester, SupportPrototypeController controller) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
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
