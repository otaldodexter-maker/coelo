import 'package:flutter/foundation.dart';

import '../../domain/support_ticket.dart';

final class SupportPrototypeController extends ChangeNotifier {
  SupportPrototypeController({Iterable<SupportTicket>? initialTickets, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _tickets = List.unmodifiable(initialTickets?.toList() ?? _defaultTickets(_clock()));
  }

  final DateTime Function() _clock;
  late List<SupportTicket> _tickets;
  SupportFilters _filters = SupportFilters.empty;
  String? _selectedTicketId;
  int _nextSessionNumber = 1;

  List<SupportTicket> get tickets => _tickets;
  SupportFilters get filters => _filters;
  bool get hasActiveFilters => _filters.hasActiveFilters;

  List<SupportTicket> get filteredTickets {
    if (!hasActiveFilters) {
      return _tickets;
    }
    return List.unmodifiable(_tickets.where(_matchesFilters));
  }

  SupportTicket? get selectedTicket {
    final selectedTicketId = _selectedTicketId;
    if (selectedTicketId == null) {
      return null;
    }
    for (final ticket in _tickets) {
      if (ticket.id == selectedTicketId) {
        return ticket;
      }
    }
    return null;
  }

  SupportTicket submitReport(SupportReportDraft draft) {
    final now = _clock();
    final ticket = SupportTicket(
      id: _nextSessionId(),
      subject: draft.subject,
      menu: draft.menu,
      screen: draft.screen,
      description: draft.description,
      requester: draft.requester,
      createdAt: now,
      updatedAt: now,
      status: SupportTicketStatus.newRequest,
      attachments: draft.includeDemoAttachment
          ? const [
              SupportAttachment(
                id: 'demo-attachment',
                fileName: 'captura-de-tela-demonstracao.png',
              ),
            ]
          : const [],
    );
    _tickets = List.unmodifiable([..._tickets, ticket]);
    notifyListeners();
    return ticket;
  }

  void changeStatus(String ticketId, SupportTicketStatus status) {
    _replaceTicket(ticketId, (ticket) => ticket.copyWith(status: status, updatedAt: _clock()));
  }

  void selectTicket(String? ticketId) {
    if (ticketId == null || !_tickets.any((ticket) => ticket.id == ticketId)) {
      if (_selectedTicketId != null) {
        _selectedTicketId = null;
        notifyListeners();
      }
      return;
    }
    _selectedTicketId = ticketId;
    markIncomingRead(ticketId, notify: false);
    notifyListeners();
  }

  void closeTicket([String? ticketId]) {
    final targetId = ticketId ?? _selectedTicketId;
    if (targetId != null) {
      changeStatus(targetId, SupportTicketStatus.completed);
    }
  }

  void sendReply(String ticketId, String replyText) {
    final trimmedReply = replyText.trim();
    if (trimmedReply.isEmpty) {
      return;
    }
    final now = _clock();
    _replaceTicket(ticketId, (ticket) {
      final message = SupportMessage(
        id: '${ticket.id}-message-${ticket.messages.length + 1}',
        author: SupportMessageAuthor.support,
        text: trimmedReply,
        sentAt: now,
      );
      return ticket.copyWith(updatedAt: now, messages: [...ticket.messages, message]);
    });
  }

  void markIncomingRead(String ticketId, {bool notify = true}) {
    _replaceTicket(
      ticketId,
      (ticket) => ticket.copyWith(
        updatedAt: _clock(),
        messages: [
          for (final message in ticket.messages)
            if (message.author == SupportMessageAuthor.requester && !message.isReadBySupport)
              message.copyWith(isReadBySupport: true)
            else
              message,
        ],
      ),
      notify: notify,
      onlyIfChanged: (ticket) => ticket.messages.any(
        (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
      ),
    );
  }

  void updateFilters(SupportFilters filters) {
    _filters = filters;
    notifyListeners();
  }

  void clearFilters() {
    _filters = SupportFilters.empty;
    notifyListeners();
  }

  bool _matchesFilters(SupportTicket ticket) {
    final search = _filters.search.trim().toLowerCase();
    final searchableText = [
      ticket.id,
      ticket.subject,
      ticket.description,
      ticket.requester,
      ticket.menu,
      ticket.screen,
    ].join(' ').toLowerCase();
    return (search.isEmpty || searchableText.contains(search)) &&
        (_filters.statuses.isEmpty || _filters.statuses.contains(ticket.status)) &&
        (_filters.menus.isEmpty || _filters.menus.contains(ticket.menu)) &&
        (_filters.screens.isEmpty || _filters.screens.contains(ticket.screen)) &&
        (!_filters.unreadOnly || _hasUnreadRequesterMessage(ticket));
  }

  bool _hasUnreadRequesterMessage(SupportTicket ticket) {
    return ticket.messages.any(
      (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
    );
  }

  String _nextSessionId() {
    while (true) {
      final id = 'support-session-${_nextSessionNumber.toString().padLeft(3, '0')}';
      _nextSessionNumber += 1;
      if (_tickets.every((ticket) => ticket.id != id)) {
        return id;
      }
    }
  }

  void _replaceTicket(
    String ticketId,
    SupportTicket Function(SupportTicket ticket) transform, {
    bool notify = true,
    bool Function(SupportTicket ticket)? onlyIfChanged,
  }) {
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0 || (onlyIfChanged != null && !onlyIfChanged(_tickets[index]))) {
      return;
    }
    final updated = transform(_tickets[index]);
    _tickets = List.unmodifiable([..._tickets.take(index), updated, ..._tickets.skip(index + 1)]);
    if (notify) {
      notifyListeners();
    }
  }
}

List<SupportTicket> _defaultTickets(DateTime now) {
  return [
    SupportTicket(
      id: 'SUP-001',
      subject: 'Nao consigo atualizar uma instituicao',
      menu: 'Instituicoes',
      screen: 'Diretorio',
      description: 'O salvamento nao conclui.',
      requester: 'Camila Rocha',
      createdAt: now.subtract(const Duration(hours: 4)),
      updatedAt: now.subtract(const Duration(hours: 1)),
      status: SupportTicketStatus.newRequest,
      attachments: const [
        SupportAttachment(id: 'SUP-001-attachment', fileName: 'erro-salvamento.png'),
      ],
      messages: [
        SupportMessage(
          id: 'SUP-001-message-1',
          author: SupportMessageAuthor.requester,
          text: 'Preciso concluir hoje.',
          sentAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    ),
    SupportTicket(
      id: 'SUP-002',
      subject: 'Conversa nao carrega',
      menu: 'Conversas',
      screen: 'Lista de conversas',
      description: 'A lista fica vazia.',
      requester: 'Joao Mendes',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(minutes: 30)),
      status: SupportTicketStatus.inProgress,
      messages: [
        SupportMessage(
          id: 'SUP-002-message-1',
          author: SupportMessageAuthor.support,
          text: 'Estamos verificando.',
          sentAt: now.subtract(const Duration(minutes: 30)),
          deliveryState: SupportMessageDeliveryState.read,
          isReadBySupport: true,
        ),
      ],
    ),
    SupportTicket(
      id: 'SUP-003',
      subject: 'Aguardando comprovacao',
      menu: 'Pessoas',
      screen: 'Perfil',
      description: 'Precisamos de mais detalhes.',
      requester: 'Lia Farias',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 5)),
      status: SupportTicketStatus.waitingRequester,
    ),
    SupportTicket(
      id: 'SUP-004',
      subject: 'Acesso restabelecido',
      menu: 'Configuracoes',
      screen: 'Acesso',
      description: 'O acesso foi normalizado.',
      requester: 'Rafa Silva',
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 1)),
      status: SupportTicketStatus.completed,
    ),
  ];
}
