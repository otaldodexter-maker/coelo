import 'package:flutter/foundation.dart';

import '../../domain/support_requester_context.dart';
import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';

enum SupportSortColumn {
  id,
  subject,
  menu,
  requester,
  status,
  assignees,
  attachments,
  unread,
  updatedAt,
}

final class SupportPrototypeController extends ChangeNotifier {
  SupportPrototypeController({
    Iterable<SupportTicket>? initialTickets,
    DateTime Function()? clock,
    SupportRequesterContext sessionRequesterContext = defaultSessionRequesterContext,
  }) : _clock = clock ?? DateTime.now,
       _sessionRequesterContext = sessionRequesterContext {
    _tickets = List.unmodifiable(initialTickets?.toList() ?? _defaultTickets(_clock()));
  }

  static const defaultTeamMembers = <SupportTeamMember>[
    SupportTeamMember(
      id: 'member-support',
      name: 'Ana Souza',
      initials: 'AS',
      role: SupportTeamRole.support,
    ),
    SupportTeamMember(
      id: 'member-dev',
      name: 'Caio Lima',
      initials: 'CL',
      role: SupportTeamRole.development,
    ),
    SupportTeamMember(
      id: 'member-cs',
      name: 'Bia Nunes',
      initials: 'BN',
      role: SupportTeamRole.customerSuccess,
    ),
    SupportTeamMember(
      id: 'member-qa',
      name: 'Davi Reis',
      initials: 'DR',
      role: SupportTeamRole.qualityAssurance,
    ),
  ];

  static const defaultSessionRequesterContext = SupportRequesterContext(
    institution: 'Centro Horizonte',
    unit: 'Unidade Cambui',
    group: 'Turma Girassol',
  );

  final DateTime Function() _clock;
  final SupportRequesterContext _sessionRequesterContext;
  late List<SupportTicket> _tickets;
  SupportFilters _filters = SupportFilters.empty;
  String? _selectedTicketId;
  int _nextSessionNumber = 1;
  int _currentPage = 1;
  int _pageSize = 9;
  SupportSortColumn _sortColumn = SupportSortColumn.updatedAt;
  bool _sortAscending = false;

  List<SupportTicket> get tickets => _tickets;
  List<SupportTeamMember> get teamMembers => defaultTeamMembers;
  SupportFilters get filters => _filters;
  bool get hasActiveFilters => _filters.hasActiveFilters;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  SupportSortColumn get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;
  int get totalPages =>
      ((_sortedFilteredTickets.length + _pageSize - 1) ~/ _pageSize).clamp(1, 1 << 31);
  List<SupportTicket> get visibleTickets {
    final start = (_currentPage - 1) * _pageSize;
    final tickets = _sortedFilteredTickets;
    if (start >= tickets.length) {
      return const [];
    }
    return List.unmodifiable(tickets.skip(start).take(_pageSize));
  }

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
      requesterContext: _sessionRequesterContext,
      createdAt: now,
      updatedAt: now,
      status: SupportTicketStatus.newRequest,
      activities: [
        SupportActivity(
          kind: SupportActivityKind.created,
          label: 'Chamado criado',
          occurredAt: now,
        ),
      ],
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

  void assignOwner(String ticketId, String? memberId) {
    _replaceTicket(
      ticketId,
      (ticket) => ticket.copyWith(ownerId: memberId, clearOwner: memberId == null),
    );
  }

  void setCollaborators(String ticketId, Set<String> memberIds) {
    _replaceTicket(ticketId, (ticket) => ticket.copyWith(collaboratorIds: memberIds));
  }

  void setAssignees(String ticketId, Set<String> memberIds) {
    final now = _clock();
    _replaceTicket(
      ticketId,
      (ticket) => ticket.copyWith(
        clearOwner: true,
        collaboratorIds: const {},
        assigneeIds: memberIds,
        updatedAt: now,
        activities: [
          ...ticket.activities,
          SupportActivity(
            kind: SupportActivityKind.assignmentChanged,
            label: memberIds.isEmpty
                ? 'Responsáveis removidos'
                : '${memberIds.length} responsável(is) atribuído(s)',
            occurredAt: now,
          ),
        ],
      ),
    );
  }

  bool changeStatus(String ticketId, SupportTicketStatus status) {
    final ticket = _ticketById(ticketId);
    if (ticket == null ||
        (status == SupportTicketStatus.inProgress && ticket.assigneeIds.isEmpty)) {
      return false;
    }
    final now = _clock();
    _replaceTicket(
      ticketId,
      (ticket) => ticket.copyWith(
        status: status,
        updatedAt: now,
        activities: [
          ...ticket.activities,
          SupportActivity(
            kind: SupportActivityKind.statusChanged,
            label: 'Status alterado para ${_statusLabel(status)}',
            occurredAt: now,
          ),
        ],
      ),
    );
    return true;
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
      return ticket.copyWith(
        updatedAt: now,
        messages: [...ticket.messages, message],
        activities: [
          ...ticket.activities,
          SupportActivity(
            kind: SupportActivityKind.replySent,
            label: 'Resposta enviada pela equipe',
            occurredAt: now,
          ),
        ],
      );
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
    _currentPage = 1;
    notifyListeners();
  }

  void clearFilters() {
    _filters = SupportFilters.empty;
    _currentPage = 1;
    notifyListeners();
  }

  void setPage(int page) {
    final nextPage = page.clamp(1, totalPages);
    if (_currentPage == nextPage) {
      return;
    }
    _currentPage = nextPage;
    notifyListeners();
  }

  void setPageSize(int pageSize) {
    if (_pageSize == pageSize) {
      return;
    }
    _pageSize = pageSize;
    _currentPage = 1;
    notifyListeners();
  }

  void setSort(SupportSortColumn column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    _currentPage = 1;
    notifyListeners();
  }

  List<SupportTicket> get _sortedFilteredTickets {
    final values = filteredTickets.toList();
    values.sort((first, second) {
      final comparison = switch (_sortColumn) {
        SupportSortColumn.id => first.id.compareTo(second.id),
        SupportSortColumn.subject => first.subject.compareTo(second.subject),
        SupportSortColumn.menu => first.menu.compareTo(second.menu),
        SupportSortColumn.requester => first.requester.compareTo(second.requester),
        SupportSortColumn.status => first.status.index.compareTo(second.status.index),
        SupportSortColumn.assignees => first.assigneeIds.length.compareTo(
          second.assigneeIds.length,
        ),
        SupportSortColumn.attachments => first.attachments.length.compareTo(
          second.attachments.length,
        ),
        SupportSortColumn.unread => _unreadCount(first).compareTo(_unreadCount(second)),
        SupportSortColumn.updatedAt => first.updatedAt.compareTo(second.updatedAt),
      };
      return _sortAscending ? comparison : -comparison;
    });
    return values;
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
      ticket.requesterContext?.breadcrumb ?? '',
      ...ticket.assigneeIds,
    ].join(' ').toLowerCase();
    return (search.isEmpty || searchableText.contains(search)) &&
        (_filters.statuses.isEmpty || _filters.statuses.contains(ticket.status)) &&
        (_filters.menus.isEmpty || _filters.menus.contains(ticket.menu)) &&
        (_filters.screens.isEmpty || _filters.screens.contains(ticket.screen)) &&
        (_filters.assigneeIds.isEmpty || ticket.assigneeIds.any(_filters.assigneeIds.contains)) &&
        (!_filters.unreadOnly || _hasUnreadRequesterMessage(ticket));
  }

  bool _hasUnreadRequesterMessage(SupportTicket ticket) {
    return ticket.messages.any(
      (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
    );
  }

  SupportTicket? _ticketById(String ticketId) {
    for (final ticket in _tickets) {
      if (ticket.id == ticketId) {
        return ticket;
      }
    }
    return null;
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
    _currentPage = _currentPage.clamp(1, totalPages);
    if (notify) {
      notifyListeners();
    }
  }
}

int _unreadCount(SupportTicket ticket) => ticket.messages
    .where(
      (message) => message.author == SupportMessageAuthor.requester && !message.isReadBySupport,
    )
    .length;

String _statusLabel(SupportTicketStatus status) => switch (status) {
  SupportTicketStatus.newRequest => 'Novo',
  SupportTicketStatus.inProgress => 'Em andamento',
  SupportTicketStatus.waitingRequester => 'Aguardando solicitante',
  SupportTicketStatus.completed => 'Concluído',
};

List<SupportTicket> _defaultTickets(DateTime now) {
  return [
    SupportTicket(
      id: 'SUP-001',
      subject: 'Nao consigo atualizar uma instituicao',
      menu: 'Instituicoes',
      screen: 'Diretorio',
      description: 'O salvamento nao conclui.',
      requester: 'Camila Rocha',
      requesterContext: const SupportRequesterContext(
        institution: 'Centro Horizonte',
        unit: 'Unidade Cambui',
        group: 'Turma Girassol',
        activity: 'Oficina de Arte',
      ),
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
      requesterContext: const SupportRequesterContext(
        institution: 'Colegio Aurora',
        unit: 'Unidade Centro',
        group: 'Turma Azul',
      ),
      ownerId: 'member-dev',
      collaboratorIds: const {'member-support'},
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
      requesterContext: const SupportRequesterContext(institution: 'Escola Semente'),
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
