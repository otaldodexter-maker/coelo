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

    for (final status in SupportTicketStatus.values) {
      expect(_laneFinder(status), findsOneWidget);
    }
    expect(find.byKey(const Key('support-card-SUP-001')), findsOneWidget);
    expect(find.text('Camila Rocha'), findsWidgets);
    expect(find.textContaining('Centro Horizonte > Unidade Cambui'), findsWidgets);
    final description = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('support-card-SUP-001')),
        matching: find.text('O salvamento nao conclui.'),
      ),
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

  testWidgets('shows clear filters only while a filter is active', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    expect(find.byKey(const Key('support-clear-filters')), findsNothing);

    await tester.enterText(find.byKey(const Key('support-search')), 'SUP-001');
    await tester.pump();
    expect(find.byKey(const Key('support-clear-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-clear-filters')));
    await tester.pump();
    expect(controller.hasActiveFilters, isFalse);
    expect(find.byKey(const Key('support-clear-filters')), findsNothing);
    expect(find.byKey(const Key('support-card-SUP-001')), findsOneWidget);
    expect(find.byKey(const Key('support-card-SUP-002')), findsOneWidget);
  });

  testWidgets('assigns equivalent responsibles from the kanban card menu', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-card-menu-SUP-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responsáveis').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza · Suporte').last);
    await tester.pumpAndSettle();

    expect(controller.tickets.singleWhere((ticket) => ticket.id == 'SUP-001').assigneeIds, {
      'member-support',
    });
  });

  testWidgets('card submenus use the approved raised surface', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byKey(const Key('support-card-menu-SUP-001')));
    await tester.pumpAndSettle();

    final submenu = tester.widget<SubmenuButton>(find.byType(SubmenuButton).first);
    final menuStyle = submenu.menuStyle!;
    expect(menuStyle.backgroundColor?.resolve({}), CoeloTheme.light.colorScheme.surface);
    expect(menuStyle.surfaceTintColor?.resolve({}), Colors.transparent);
    expect(menuStyle.padding?.resolve({}), const EdgeInsets.all(CoeloSpacing.space2));
  });

  testWidgets('requires a responsible when a kanban drop starts work', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    final card = find.byKey(const Key('support-card-SUP-001'));
    final target = _laneFinder(SupportTicketStatus.inProgress);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(kLongPressTimeout);
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Escolha o responsável'), findsOneWidget);
    await tester.tap(find.text('Ana Souza · Suporte').last);
    await tester.pumpAndSettle();

    final ticket = controller.tickets.singleWhere((item) => item.id == 'SUP-001');
    expect(ticket.assigneeIds, {'member-support'});
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
    expect(controller.tickets.first.assigneeIds, isEmpty);
  });

  testWidgets('card menu is accessible and assigns a responsible with keyboard', (tester) async {
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

    expect(controller.tickets.first.assigneeIds, {'member-support'});
  });

  testWidgets('card menu exposes responsible and status semantics', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    controller.setAssignees('SUP-001', {'member-support', 'member-dev'});
    await _pump(tester, controller, const Size(1280, 900));

    final menuFinder = find.byKey(const Key('support-card-menu-SUP-001'));
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responsáveis').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('support-assignee-option-SUP-001-member-support')))
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );

    expect(
      tester
          .getSemantics(find.byKey(const Key('support-assignee-option-SUP-001-member-dev')))
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

  testWidgets('opens file exports beside the view selector', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-files-export-csv')), findsOneWidget);
    expect(find.byKey(const Key('support-files-export-xlsx')), findsOneWidget);

    await tester.tap(find.byKey(const Key('support-files-export-csv')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('Exportação CSV da lista filtrada'), findsOneWidget);
  });

  testWidgets('double click opens full-screen details without firing single click', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    final card = find.byKey(const Key('support-card-SUP-001'));
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(card);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-expanded-detail')), findsOneWidget);
    expect(controller.selectedTicket?.id, 'SUP-001');
  });

  testWidgets('restores a unique table target that reopens the same ticket with Enter', (
    tester,
  ) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));

    await tester.tap(find.byTooltip('Exibir como tabela'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-table-row-background-SUP-001')).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final rowBackground = find.byKey(const Key('coelo-admin-table-row-background-SUP-001'));
    final targetFinder = find.ancestor(of: rowBackground, matching: find.byType(InkWell));
    expect(targetFinder, findsOneWidget);
    final target = tester.widget<InkWell>(targetFinder);
    expect(target.focusNode?.hasFocus, isTrue);
    expect(tester.getSemantics(find.byKey(const Key('SUP-001'))).flagsCollection.isButton, isTrue);

    final focusSurface = tester.widget<Container>(rowBackground);
    expect(
      (focusSurface.decoration! as BoxDecoration).color,
      CoeloTheme.light.colorScheme.primaryContainer,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.selectedTicket?.id, 'SUP-001');
    expect(find.byKey(const Key('support-detail-panel')), findsOneWidget);
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
    await tester.pump(kDoubleTapTimeout);
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

  testWidgets('keeps equivalent assignees in stable team order in semantics', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    controller.setAssignees('SUP-001', {'member-qa', 'member-dev', 'member-support'});
    await _pump(tester, controller, const Size(1280, 900));

    expect(
      find.bySemanticsLabel(
        RegExp(
          'Ana Souza, Suporte; Caio Lima, Desenvolvimento; Davi Reis, Qualidade',
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
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-detail-panel')), findsOneWidget);
    expect(find.text('Camila Rocha'), findsWidgets);
    expect(
      find.text('Centro Horizonte > Unidade Cambui > Turma Girassol > Oficina de Arte'),
      findsWidgets,
    );
    expect(find.byKey(const Key('support-detail-assignees')), findsOneWidget);
    expect(controller.selectedTicket!.messages.first.isReadBySupport, isTrue);

    await tester.tap(find.byKey(const Key('support-detail-assignees')));
    await tester.pumpAndSettle();
    final collaboratorOption = find.widgetWithText(MenuItemButton, 'Caio Lima · Desenvolvimento');
    expect(collaboratorOption, findsOneWidget);
    final collaboratorCheckbox = find.descendant(
      of: collaboratorOption,
      matching: find.byType(Checkbox),
    );
    await tester.tap(find.text('Ana Souza · Suporte').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caio Lima · Desenvolvimento').last);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(collaboratorCheckbox).value, isTrue);
    expect(find.text('Aplicar'), findsOneWidget);
    await tester.tap(find.text('Aplicar').last);
    await tester.pumpAndSettle();
    expect(controller.selectedTicket!.assigneeIds, {'member-support', 'member-dev'});

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
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.selectedTicket, isNull);
    expect(find.byKey(const Key('support-detail-panel')), findsNothing);
    final card = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byKey(const Key('support-card-SUP-001')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(card.focusNode?.hasFocus, isTrue);
  });

  testWidgets('uses one compact lane at a time on phone widths', (tester) async {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(375, 800));

    expect(find.byKey(const Key('coelo-admin-kanban-status-selector')), findsOneWidget);
    expect(_laneFinder(SupportTicketStatus.newRequest), findsOneWidget);
    expect(_laneFinder(SupportTicketStatus.inProgress), findsNothing);
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

Finder _laneFinder(SupportTicketStatus status) =>
    find.byKey(ValueKey<(String, SupportTicketStatus)>(('coelo-admin-kanban-lane', status)));
