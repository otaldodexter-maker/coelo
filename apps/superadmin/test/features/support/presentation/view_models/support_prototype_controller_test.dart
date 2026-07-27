import 'package:coelo_superadmin/features/support/domain/support_requester_context.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/domain/support_team_member.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 7, 27, 10);

  SupportTicket ticket({
    required String id,
    required SupportTicketStatus status,
    String menu = 'Instituicoes',
    String screen = 'Diretorio',
    String subject = 'Preciso de ajuda',
    String description = 'Descricao do chamado',
    String requester = 'Ana Responsavel',
    String? ownerId,
    Set<String> collaboratorIds = const {},
    SupportRequesterContext? requesterContext,
    List<SupportMessage> messages = const [],
  }) {
    return SupportTicket(
      id: id,
      subject: subject,
      menu: menu,
      screen: screen,
      description: description,
      requester: requester,
      ownerId: ownerId,
      collaboratorIds: collaboratorIds,
      requesterContext: requesterContext,
      createdAt: fixedNow,
      updatedAt: fixedNow,
      status: status,
      messages: messages,
    );
  }

  test('builds requester context without empty breadcrumb levels', () {
    const context = SupportRequesterContext(
      institution: 'Centro Horizonte',
      unit: 'Unidade Cambui',
      group: 'Turma Girassol',
    );

    expect(context.labels, ['Centro Horizonte', 'Unidade Cambui', 'Turma Girassol']);
    expect(context.breadcrumb, 'Centro Horizonte > Unidade Cambui > Turma Girassol');
  });

  test('omits unavailable requester context levels from its breadcrumb', () {
    const context = SupportRequesterContext(
      institution: 'Centro Horizonte',
      group: 'Turma Girassol',
    );

    expect(context.labels, ['Centro Horizonte', 'Turma Girassol']);
    expect(context.breadcrumb, 'Centro Horizonte > Turma Girassol');
  });

  test('defines immutable support team members', () {
    const member = SupportTeamMember(
      id: 'member-support',
      name: 'Marina Alves',
      initials: 'MA',
      role: SupportTeamRole.support,
    );

    expect(member.id, 'member-support');
    expect(member.role, SupportTeamRole.support);
  });

  test('keeps support collaborators and assignee filters immutable', () {
    final item = ticket(
      id: 'SUP-1',
      status: SupportTicketStatus.newRequest,
      ownerId: 'member-support',
      collaboratorIds: {'member-qa'},
    );
    final filters = SupportFilters(assigneeIds: {'member-support'});

    expect(() => item.collaboratorIds.add('member-dev'), throwsUnsupportedError);
    expect(() => filters.assigneeIds.add('member-dev'), throwsUnsupportedError);
  });

  test('preserves requester context and ownership when copying a ticket', () {
    const requesterContext = SupportRequesterContext(
      institution: 'Centro Horizonte',
      unit: 'Unidade Cambui',
    );
    final item = ticket(
      id: 'SUP-1',
      status: SupportTicketStatus.newRequest,
      requesterContext: requesterContext,
      ownerId: 'member-support',
      collaboratorIds: {'member-qa'},
    );

    final copied = item.copyWith(status: SupportTicketStatus.inProgress);

    expect(copied.requesterContext, same(requesterContext));
    expect(copied.ownerId, 'member-support');
    expect(copied.collaboratorIds, {'member-qa'});
  });

  test('removes a ticket owner when copyWith clears it', () {
    final item = ticket(
      id: 'SUP-1',
      status: SupportTicketStatus.newRequest,
      ownerId: 'member-support',
    );

    final copied = item.copyWith(clearOwner: true);

    expect(copied.ownerId, isNull);
  });

  test('creates a new session ticket from a report draft', () {
    final controller = SupportPrototypeController(initialTickets: [], clock: () => fixedNow);
    addTearDown(controller.dispose);

    final created = controller.submitReport(
      const SupportReportDraft(
        menu: 'Conversas',
        screen: 'Lista de conversas',
        subject: 'Nao consigo abrir uma conversa',
        description: 'A tela permanece carregando.',
        requester: 'Marina Alves',
        includeDemoAttachment: true,
      ),
    );

    expect(created.id, 'support-session-001');
    expect(created.status, SupportTicketStatus.newRequest);
    expect(created.createdAt, fixedNow);
    expect(created.attachments, hasLength(1));
    expect(controller.tickets.single, created);
  });

  test('skips supplied session ids when creating a report ticket', () {
    final controller = SupportPrototypeController(
      initialTickets: [ticket(id: 'support-session-001', status: SupportTicketStatus.completed)],
      clock: () => fixedNow,
    );
    addTearDown(controller.dispose);

    final created = controller.submitReport(
      const SupportReportDraft(
        menu: 'Conversas',
        screen: 'Lista de conversas',
        subject: 'Relato novo',
        description: 'Descricao nova.',
        requester: 'Marina Alves',
      ),
    );

    expect(created.id, 'support-session-002');
    expect(controller.tickets.map((ticket) => ticket.id).toSet(), hasLength(2));
  });

  test('gives equal filter sets the same hash regardless of insertion order', () {
    final first = SupportFilters(
      statuses: {SupportTicketStatus.newRequest, SupportTicketStatus.inProgress},
      menus: {'Conversas', 'Pessoas'},
    );
    final second = SupportFilters(
      statuses: {SupportTicketStatus.inProgress, SupportTicketStatus.newRequest},
      menus: {'Pessoas', 'Conversas'},
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('exposes immutable collections from tickets and controller', () {
    final controller = SupportPrototypeController(
      initialTickets: [ticket(id: 'SUP-1', status: SupportTicketStatus.newRequest)],
    );
    addTearDown(controller.dispose);

    expect(
      () => controller.tickets.add(ticket(id: 'SUP-2', status: SupportTicketStatus.completed)),
      throwsUnsupportedError,
    );
    expect(
      () => controller.tickets.single.messages.add(
        SupportMessage(
          id: 'message-1',
          author: SupportMessageAuthor.requester,
          text: 'Oi',
          sentAt: fixedNow,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('intersects search, status, menu, screen, and unread filters', () {
    final controller = SupportPrototypeController(
      initialTickets: [
        ticket(
          id: 'SUP-1',
          status: SupportTicketStatus.inProgress,
          menu: 'Conversas',
          screen: 'Lista',
          subject: 'Falha no chat',
          messages: [
            SupportMessage(
              id: 'message-1',
              author: SupportMessageAuthor.requester,
              text: 'Ainda preciso de ajuda',
              sentAt: fixedNow,
            ),
          ],
        ),
        ticket(
          id: 'SUP-2',
          status: SupportTicketStatus.inProgress,
          menu: 'Conversas',
          screen: 'Lista',
          subject: 'Falha no chat',
        ),
        ticket(
          id: 'SUP-3',
          status: SupportTicketStatus.completed,
          menu: 'Pessoas',
          screen: 'Perfil',
        ),
      ],
    );
    addTearDown(controller.dispose);

    controller.updateFilters(
      SupportFilters(
        search: 'chat',
        statuses: {SupportTicketStatus.inProgress},
        menus: {'Conversas'},
        screens: {'Lista'},
        unreadOnly: true,
      ),
    );

    expect(controller.filteredTickets.map((value) => value.id), ['SUP-1']);
    expect(controller.hasActiveFilters, isTrue);
  });

  test('changes and closes a ticket status', () {
    final controller = SupportPrototypeController(
      initialTickets: [ticket(id: 'SUP-1', status: SupportTicketStatus.newRequest)],
      clock: () => fixedNow,
    );
    addTearDown(controller.dispose);

    controller.changeStatus('SUP-1', SupportTicketStatus.inProgress);
    controller.closeTicket('SUP-1');

    expect(controller.tickets.single.status, SupportTicketStatus.completed);
    expect(controller.tickets.single.updatedAt, fixedNow);
  });

  test('selecting a ticket marks requester messages as read by support', () {
    final controller = SupportPrototypeController(
      initialTickets: [
        ticket(
          id: 'SUP-1',
          status: SupportTicketStatus.newRequest,
          messages: [
            SupportMessage(
              id: 'incoming',
              author: SupportMessageAuthor.requester,
              text: 'Pode me responder?',
              sentAt: fixedNow,
            ),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);

    controller.selectTicket('SUP-1');

    expect(controller.selectedTicket?.id, 'SUP-1');
    expect(controller.selectedTicket?.messages.single.isReadBySupport, isTrue);
  });

  test('trims a support reply and ignores an empty reply', () {
    final controller = SupportPrototypeController(
      initialTickets: [ticket(id: 'SUP-1', status: SupportTicketStatus.inProgress)],
      clock: () => fixedNow,
    );
    addTearDown(controller.dispose);

    controller.sendReply('SUP-1', '  Estamos verificando.  ');
    controller.sendReply('SUP-1', '   ');

    final messages = controller.tickets.single.messages;
    expect(messages, hasLength(1));
    expect(messages.single.text, 'Estamos verificando.');
    expect(messages.single.author, SupportMessageAuthor.support);
    expect(messages.single.deliveryState, SupportMessageDeliveryState.sent);
  });

  test('clears every active filter', () {
    final controller = SupportPrototypeController(
      initialTickets: [ticket(id: 'SUP-1', status: SupportTicketStatus.newRequest)],
    );
    addTearDown(controller.dispose);
    controller.updateFilters(SupportFilters(search: 'SUP-1', unreadOnly: true));

    controller.clearFilters();

    expect(controller.filters, SupportFilters.empty);
    expect(controller.hasActiveFilters, isFalse);
    expect(controller.filteredTickets, controller.tickets);
  });
}
