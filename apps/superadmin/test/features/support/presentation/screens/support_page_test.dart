import 'dart:ui' show CheckedState, Tristate;

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
  testWidgets('shows operational kanban anatomy and filters tickets', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    expect(find.byKey(const Key('support-kanban-newRequest')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-inProgress')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-waitingRequester')), findsOneWidget);
    expect(find.byKey(const Key('support-kanban-completed')), findsOneWidget);
    expect(find.byKey(const Key('support-card-SUP-001')), findsOneWidget);
    expect(find.text('Camila Rocha'), findsWidgets);
    expect(find.textContaining('Centro Horizonte > Unidade Cambui'), findsWidgets);
    final description = tester.widget<Text>(
      find.byKey(const Key('support-card-description-SUP-001')),
    );
    expect(description.data, 'O salvamento nao conclui.');
    expect(description.maxLines, 2);
    expect(description.overflow, TextOverflow.ellipsis);
    expect(
      find.text('Atualizado em ${_dateTime(controller.tickets.first.updatedAt)}'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('support-search')), findsOneWidget);
    expect(find.byKey(const Key('support-status-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-menu-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-assignee-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-read-filter')), findsOneWidget);
    expect(find.byKey(const Key('support-screen-filter')), findsNothing);

    await tester.tap(find.byKey(const Key('support-menu-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instituições').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-screen-filter')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('support-search')),
      'Nao consigo atualizar uma instituicao',
    );
    await tester.pump();
    expect(find.text('Nao consigo atualizar uma instituicao'), findsWidgets);
    expect(find.text('Conversa não carrega'), findsNothing);
  });

  testWidgets('assigns an owner from the kanban card menu', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-card-menu-SUP-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atribuir responsável').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza · Suporte').last);
    await tester.pumpAndSettle();

    expect(
      controller.tickets.singleWhere((ticket) => ticket.id == 'SUP-001').ownerId,
      'member-support',
    );
  });

  testWidgets('requires an owner when a kanban drop starts work', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    final card = find.byKey(const Key('support-card-SUP-001'));
    final target = find.byKey(const Key('support-kanban-inProgress'));
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Escolha o responsável'), findsOneWidget);
    await tester.tap(find.text('Ana Souza · Suporte').last);
    await tester.pumpAndSettle();

    final ticket = controller.tickets.singleWhere((item) => item.id == 'SUP-001');
    expect(ticket.ownerId, 'member-support');
    expect(ticket.status, SupportTicketStatus.inProgress);
  });

  testWidgets('keeps status new while owner picker is open and after cancel', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-card-menu-SUP-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Em andamento'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha o responsável'), findsOneWidget);
    expect(controller.tickets.first.status, SupportTicketStatus.newRequest);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Escolha o responsável'), findsNothing);
    expect(controller.tickets.first.status, SupportTicketStatus.newRequest);
    expect(controller.tickets.first.ownerId, isNull);
  });

  testWidgets('card menu is accessible and assigns owner with keyboard', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    final menuFinder = find.byKey(const Key('support-card-menu-SUP-001'));
    final menuButton = tester.widget<IconButton>(menuFinder);
    expect(menuButton.constraints?.minWidth, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(menuButton.constraints?.minHeight, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(
      menuButton.style?.backgroundColor?.resolve({WidgetState.focused}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );
    expect(
      menuButton.style?.foregroundColor?.resolve({WidgetState.focused}),
      CoeloTheme.light.colorScheme.primary,
    );

    menuButton.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.tickets.first.ownerId, 'member-support');
  });

  testWidgets('card menu exposes owner status and collaborator semantics', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    controller.assignOwner('SUP-001', 'member-support');
    controller.setCollaborators('SUP-001', {'member-dev'});
    await _pump(tester, controller, const Size(1280, 900));

    final menuFinder = find.byKey(const Key('support-card-menu-SUP-001'));
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atribuir responsável').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('support-owner-option-SUP-001-member-support')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colaboradores').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('support-collaborator-option-SUP-001-member-dev')))
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('support-status-option-SUP-001-newRequest')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
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

  testWidgets('restores focus to the exact table row that opened detail', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byTooltip('Exibir como tabela'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-table-row-background-SUP-001')).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final rowFocus = tester.widgetList<Focus>(
      find.byKey(const Key('support-table-row-focus-SUP-001')),
    );
    expect(rowFocus.any((focus) => focus.focusNode?.hasFocus ?? false), isTrue);
  });

  testWidgets('falls back to read filter when opening marks card filtered out', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-read-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não lidas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar').last);
    await tester.pumpAndSettle();
    expect(controller.filters.unreadOnly, isTrue);
    expect(find.byKey(const Key('support-card-SUP-001')), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-card-SUP-001')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final readFilterButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const Key('support-read-filter')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(readFilterButton.focusNode?.hasFocus, isTrue);
  });

  testWidgets('keeps the principal assignee before collaborators in semantics', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    controller.assignOwner('SUP-001', 'member-dev');
    controller.setCollaborators('SUP-001', {'member-qa', 'member-support'});
    await _pump(tester, controller, const Size(1280, 900));

    expect(
      find.bySemanticsLabel(
        RegExp(
          'Caio Lima, Desenvolvimento; Ana Souza, Suporte; Davi Reis, Qualidade',
          dotAll: true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows complete detail, updates team, reads and replies', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-detail-panel')), findsOneWidget);
    expect(find.text('Camila Rocha'), findsWidgets);
    expect(
      find.text('Centro Horizonte > Unidade Cambui > Turma Girassol > Oficina de Arte'),
      findsWidgets,
    );
    expect(find.byKey(const Key('support-detail-owner')), findsOneWidget);
    expect(find.byKey(const Key('support-detail-collaborators')), findsOneWidget);
    expect(controller.selectedTicket!.messages.first.isReadBySupport, isTrue);

    await tester.tap(find.byKey(const Key('support-detail-owner')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza · Suporte').last);
    await tester.pumpAndSettle();
    expect(controller.selectedTicket!.ownerId, 'member-support');

    await tester.tap(find.byKey(const Key('support-detail-collaborators')));
    await tester.pumpAndSettle();
    final collaboratorOption = find.widgetWithText(MenuItemButton, 'Caio Lima · Desenvolvimento');
    expect(collaboratorOption, findsOneWidget);
    final collaboratorCheckbox = find.descendant(
      of: collaboratorOption,
      matching: find.byType(Checkbox),
    );
    await tester.tap(find.text('Caio Lima · Desenvolvimento').last);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(collaboratorCheckbox).value, isTrue);
    expect(find.text('Aplicar'), findsOneWidget);
    await tester.tap(find.text('Aplicar').last);
    await tester.pumpAndSettle();
    expect(controller.selectedTicket!.collaboratorIds, {'member-dev'});

    await tester.scrollUntilVisible(
      find.text('erro-salvamento.png'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('support-detail-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('erro-salvamento.png'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('support-composer')), 'Recebemos seu relato.');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensagem'));
    await tester.pump();
    expect(controller.selectedTicket!.messages.last.text, 'Recebemos seu relato.');
  });

  testWidgets('Escape closes detail and restores focus to its card', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-card-SUP-001')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.selectedTicket, isNull);
    expect(find.byKey(const Key('support-detail-panel')), findsNothing);
    final card = tester.widget<InkWell>(find.byKey(const Key('support-card-SUP-001')));
    expect(card.focusNode?.hasFocus, isTrue);
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

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
