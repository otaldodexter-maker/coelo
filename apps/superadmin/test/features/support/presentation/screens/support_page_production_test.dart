import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/data/support_repository.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/screens/support_page.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regra do MVP (ADR 0034): a rota normal abre sem fixture nem fail-closed.
// Com repositório produtivo o diretório de Suporte nasce vazio, mostra falha
// honesta quando o backend nega e o botão de Bug avisa o resultado real.
void main() {
  test('controller com repositório nasce sem chamados fictícios', () {
    final controller = SupportPrototypeController(repository: _FakeSupportRepository());
    addTearDown(controller.dispose);
    expect(controller.tickets, isEmpty);
    expect(controller.loadState, SupportLoadState.idle);
  });

  test('controller sem repositório mantém o protótipo local', () {
    final controller = SupportPrototypeController();
    addTearDown(controller.dispose);
    expect(controller.tickets, isNotEmpty);
  });

  test('falha do backend vira estado de falha, sem dados fictícios', () async {
    final repository = _FakeSupportRepository(listError: StateError('internal_actor_required'));
    final controller = SupportPrototypeController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadFromRepository();
    expect(controller.loadState, SupportLoadState.failure);
    expect(controller.loadError, contains('internal_actor_required'));
    expect(controller.tickets, isEmpty);
  });

  test('carga do backend preenche o diretório', () async {
    final repository = _FakeSupportRepository(tickets: [_ticket('t-1')]);
    final controller = SupportPrototypeController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadFromRepository();
    expect(controller.loadState, SupportLoadState.ready);
    expect(controller.tickets.single.id, 't-1');
  });

  test('submitReportToBackend cria no backend e recarrega; falha propaga', () async {
    final repository = _FakeSupportRepository();
    final controller = SupportPrototypeController(repository: repository);
    addTearDown(controller.dispose);
    await controller.submitReportToBackend(_draft);
    expect(repository.created, hasLength(1));
    expect(repository.listCalls, 1);

    final failing = _FakeSupportRepository(createError: StateError('permission_denied'));
    final failingController = SupportPrototypeController(repository: failing);
    addTearDown(failingController.dispose);
    await expectLater(failingController.submitReportToBackend(_draft), throwsStateError);
    expect(failingController.tickets, isEmpty, reason: 'nada otimista fica no diretório');
  });

  testWidgets('página mostra falha honesta com o Criar à frente e sem chamados do protótipo', (
    tester,
  ) async {
    final repository = _FakeSupportRepository(listError: StateError('internal_actor_required'));
    final controller = SupportPrototypeController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadFromRepository();
    await _pump(tester, controller);

    expect(find.byKey(const Key('support-state-failure')), findsOneWidget);
    expect(find.byKey(const Key('support-create-state')), findsOneWidget);
    expect(find.text('Suporte indisponível'), findsOneWidget);
    expect(find.textContaining('SUP-001'), findsNothing);
    expect(find.byKey(const Key('support-toolbar-scroll')).evaluate().isNotEmpty ||
        find.byType(TextField).evaluate().isNotEmpty, isTrue,
        reason: 'busca e filtros continuam visíveis no estado de falha');

    repository.listError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-state-failure')), findsNothing);
  });

  testWidgets('botão de Bug avisa quando o envio ao backend falha', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell(
          logout: () async => const LogoutResult.success(),
          currentDestination: 'institutions',
          onBugReportSubmitted: (_) async => throw StateError('permission_denied'),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('superadmin-bug-description')),
      'A tabela não atualizou após o filtro.',
    );
    final submit = find.byKey(const Key('superadmin-bug-submit'));
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Não foi possível enviar o relato. Tente novamente.'), findsOneWidget);
    expect(find.text('Relato enviado com sucesso.'), findsNothing);
  });
}

const _draft = SupportReportDraft(
  subject: 'Botão de Bug',
  menu: 'Estrutura',
  screen: 'Instituições',
  description: 'Tela travou ao salvar',
  requester: 'QA Superadmin',
);

SupportTicket _ticket(String id) => SupportTicket(
  id: id,
  subject: 'Chamado $id',
  menu: 'Estrutura',
  screen: 'Instituições',
  description: 'Descrição',
  requester: 'QA',
  createdAt: DateTime(2026, 9, 10, 22),
  updatedAt: DateTime(2026, 9, 10, 22),
  status: SupportTicketStatus.newRequest,
);

Future<void> _pump(WidgetTester tester, SupportPrototypeController controller) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1000);
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

final class _FakeSupportRepository implements SupportRepository {
  _FakeSupportRepository({List<SupportTicket> tickets = const [], this.listError, this.createError})
    : _tickets = List.of(tickets);

  final List<SupportTicket> _tickets;
  Object? listError;
  Object? createError;
  final created = <SupportReportDraft>[];
  int listCalls = 0;

  @override
  Future<SupportTicketPage> list(SupportFilters filters, {int page = 1, int pageSize = 25}) async {
    listCalls++;
    final error = listError;
    if (error != null) throw error;
    return SupportTicketPage(tickets: _tickets, totalItems: _tickets.length, page: page, pageSize: pageSize);
  }

  @override
  Future<SupportTicket> get(String ticketId) async => _tickets.firstWhere((t) => t.id == ticketId);

  @override
  Future<SupportTicket> create(SupportReportDraft draft) async {
    final error = createError;
    if (error != null) throw error;
    created.add(draft);
    final ticket = _ticket('t-${created.length}');
    _tickets.add(ticket);
    return ticket;
  }

  @override
  Future<SupportTicket> reply(String ticketId, String message, int expectedRevision) async =>
      get(ticketId);

  @override
  Future<SupportTicket> setStatus(String ticketId, SupportTicketStatus status, int expectedRevision) async =>
      get(ticketId);
}
