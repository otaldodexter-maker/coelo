import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/screens/support_page.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows four kanban status lanes and filters tickets', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    expect(find.byKey(const Key('support-kanban-newRequest')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-inProgress')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-waitingRequester')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-completed')), findsOneWidget);
    expect(find.byKey(const Key('support-search')), findsOneWidget);
    expect(find.byKey(const Key('support-status-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-menu-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-assignee-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-read-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-screen-filter')), findsNothing);

    await tester.tap(find.byKey(const Key('support-menu-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instituições').last);
    await tester.tap(find.text('Aplicar').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-screen-filter')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('support-search')), 'Acesso restabelecido');
    await tester.pump();
    expect(find.text('Acesso restabelecido'), findsWidgets);
    expect(find.text('Conversa não carrega'), findsNothing);
  });

  testWidgets('keeps table columns and status menu synchronized', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    controller.assignOwner('SUP-001', 'member-support');
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byTooltip('Exibir como tabela'));
    await tester.pumpAndSettle();
    for (final label in [
      'Chamado',
      'Origem',
      'Solicitante / contexto',
      'Responsável',
      'Status',
      'Anexos',
      'Não lidas',
      'Atualizado em',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.byKey(const Key('support-status-SUP-001')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em andamento').last);
    await tester.pumpAndSettle();
    expect(
      controller.tickets.singleWhere((ticket) => ticket.id == 'SUP-001').status,
      SupportTicketStatus.inProgress,
    );
  });

  testWidgets('opens details and sends a support reply', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-ticket-SUP-001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-detail-panel')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('support-composer')), 'Recebemos seu relato.');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    expect(controller.selectedTicket!.messages.last.text, 'Recebemos seu relato.');
  });

  testWidgets('uses one compact lane at a time on phone widths', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(375, 800));

    expect(find.byKey(const Key('support-compact-status')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-newRequest')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-inProgress')), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, SupportPrototypeController controller, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
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
