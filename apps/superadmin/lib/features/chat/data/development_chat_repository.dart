import '../domain/chat_repository.dart';

/// Deterministic in-memory chat used only by the explicit `/dev` composition.
final class DevelopmentChatRepository implements ChatRepository {
  DevelopmentChatRepository({DateTime Function()? now}) : _now = now ?? DateTime.now {
    final anchor = _now().toUtc();
    _conversations.addAll(_seedConversations(anchor));
    _threads.addAll(_seedThreads(anchor));
  }

  final DateTime Function() _now;
  final List<ChatConversationSummary> _conversations = [];
  final Map<String, List<ChatMessage>> _threads = {};
  final Map<String, ChatMessage> _sendReceipts = {};
  var _nextMessage = 100;

  @override
  Future<int> fetchUnreadTotal() async =>
      _conversations.fold<int>(0, (total, conversation) => total + conversation.unreadCount);

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    final search = query.search.trim().toLowerCase();
    final matching = _conversations.where((conversation) {
      if (query.unreadOnly && conversation.unreadCount == 0) return false;
      if (search.isNotEmpty &&
          ![
            conversation.title,
            conversation.preview,
            conversation.contextLabel,
          ].any((value) => value.toLowerCase().contains(search))) {
        return false;
      }
      return true;
    }).toList();
    final cursor = query.cursor;
    final filtered =
        matching.where((conversation) {
          if (cursor == null) return true;
          final byDate = conversation.updatedAt.compareTo(cursor.timestamp);
          return byDate < 0 || (byDate == 0 && conversation.id.compareTo(cursor.id) < 0);
        }).toList()..sort((left, right) {
          final byDate = right.updatedAt.compareTo(left.updatedAt);
          return byDate != 0 ? byDate : right.id.compareTo(left.id);
        });
    final page = filtered.take(query.pageSize).toList(growable: false);
    final hasMore = filtered.length > page.length;
    return ChatInboxPage(
      items: page,
      totalUnread: await fetchUnreadTotal(),
      nextCursor: hasMore ? ChatCursor(page.last.updatedAt, page.last.id) : null,
      totalCount: matching.length,
      hasMore: hasMore,
    );
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    final source = _threads[query.conversationId];
    if (source == null) throw const ChatUnauthorizedException();
    final filtered =
        source.where((message) {
          final cursor = query.cursor;
          if (cursor == null) return true;
          final byDate = message.sentAt.compareTo(cursor.timestamp);
          return byDate < 0 || (byDate == 0 && message.id.compareTo(cursor.id) < 0);
        }).toList()..sort((left, right) {
          final byDate = right.sentAt.compareTo(left.sentAt);
          return byDate != 0 ? byDate : right.id.compareTo(left.id);
        });
    final page = filtered.take(query.pageSize).toList(growable: false);
    final hasMore = filtered.length > page.length;
    return ChatThreadPage(
      items: page,
      nextCursor: hasMore ? ChatCursor(page.last.sentAt, page.last.id) : null,
    );
  }

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    final receipt = _sendReceipts[command.idempotencyKey];
    if (receipt != null) return receipt;
    final conversationIndex = _conversations.indexWhere(
      (item) => item.id == command.conversationId,
    );
    if (conversationIndex < 0 || _conversations[conversationIndex].isReadOnly) {
      throw const ChatUnauthorizedException();
    }
    final sent = ChatMessage(
      id: 'dev-message-${_nextMessage++}',
      conversationId: command.conversationId,
      body: command.body.trim(),
      authorName: 'Owner Coelo',
      sentAt: _now().toUtc(),
      isMine: true,
      kind: 'text',
    );
    _threads[command.conversationId]!.insert(0, sent);
    final current = _conversations[conversationIndex];
    _conversations[conversationIndex] = _copyConversation(
      current,
      preview: sent.body,
      unreadCount: 0,
      updatedAt: sent.sentAt,
    );
    _sendReceipts[command.idempotencyKey] = sent;
    return sent;
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    final index = _conversations.indexWhere((item) => item.id == conversationId);
    if (index < 0 || !_threads[conversationId]!.any((message) => message.id == upToMessageId)) {
      throw const ChatUnauthorizedException();
    }
    _conversations[index] = _copyConversation(_conversations[index], unreadCount: 0);
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) async {
    final index = _conversations.indexWhere((item) => item.id == conversationId);
    if (index < 0) throw const ChatUnauthorizedException();
    final conversation = _conversations[index];
    final latest = _threads[conversationId]!.firstOrNull;
    return ChatRealtimeRefresh(
      conversationId: conversationId,
      latestMessageId: latest?.id,
      unreadCount: conversation.unreadCount,
      occurredAt: latest?.sentAt ?? conversation.updatedAt,
    );
  }
}

List<ChatConversationSummary> _seedConversations(DateTime now) => [
  _conversation(
    id: 'dev-chat-girassol',
    title: 'Turma Girassol',
    preview: 'A reunião com as famílias foi confirmada para quinta-feira.',
    context: 'Escola Horizonte · Unidade Centro',
    kind: 'group',
    unread: 3,
    updatedAt: now.subtract(const Duration(minutes: 18)),
  ),
  _conversation(
    id: 'dev-chat-coordenacao',
    title: 'Coordenação Pedagógica',
    preview: 'O planejamento de setembro já está disponível para revisão.',
    context: 'Colégio Viver · Unidade Jardins',
    kind: 'direct',
    unread: 1,
    updatedAt: now.subtract(const Duration(hours: 2)),
  ),
  _conversation(
    id: 'dev-chat-implantacao',
    title: 'Implantação Colégio Viver',
    preview: 'Os cadastros das turmas foram validados pela equipe Coelo.',
    context: 'Colégio Viver · Todas as unidades',
    kind: 'support',
    unread: 0,
    updatedAt: now.subtract(const Duration(hours: 5)),
  ),
  _conversation(
    id: 'dev-chat-azul',
    title: 'Turma Azul — Infantil 5',
    preview: 'Enviamos o roteiro da atividade de leitura compartilhada.',
    context: 'Escola Horizonte · Unidade Centro',
    kind: 'group',
    unread: 2,
    updatedAt: now.subtract(const Duration(days: 1, hours: 1)),
  ),
  _conversation(
    id: 'dev-chat-secretaria',
    title: 'Secretaria Escolar',
    preview: 'A circular de renovação de matrícula foi revisada.',
    context: 'Colégio Viver · Unidade Jardins',
    kind: 'direct',
    unread: 0,
    updatedAt: now.subtract(const Duration(days: 2)),
  ),
  _conversation(
    id: 'dev-chat-bem-te-vi',
    title: 'Turma Bem-te-vi — 2º ano',
    preview: 'A visita à biblioteca municipal foi autorizada pelas famílias.',
    context: 'Escola Horizonte · Unidade Norte',
    kind: 'group',
    unread: 0,
    updatedAt: now.subtract(const Duration(days: 2, hours: 4)),
  ),
  _conversation(
    id: 'dev-chat-inclusao',
    title: 'Núcleo de Inclusão',
    preview: 'O plano de apoio individual recebeu as observações da equipe pedagógica.',
    context: 'Colégio Viver · Unidade Jardins',
    kind: 'direct',
    unread: 1,
    updatedAt: now.subtract(const Duration(days: 3)),
  ),
  _conversation(
    id: 'dev-chat-transporte',
    title: 'Operação de Transporte',
    preview: 'A rota da manhã terá ajuste de dez minutos a partir de segunda-feira.',
    context: 'Escola Horizonte · Todas as unidades',
    kind: 'support',
    unread: 0,
    updatedAt: now.subtract(const Duration(days: 3, hours: 7)),
  ),
  _conversation(
    id: 'dev-chat-familias-7a',
    title: 'Famílias — 7º ano A',
    preview: 'A pauta do encontro sobre transição escolar foi compartilhada.',
    context: 'Instituto Caminhos · Unidade Vila Nova',
    kind: 'group',
    unread: 4,
    updatedAt: now.subtract(const Duration(days: 4)),
  ),
  _conversation(
    id: 'dev-chat-esportes',
    title: 'Coordenação de Esportes',
    preview: 'Os horários dos jogos internos foram confirmados no calendário.',
    context: 'Instituto Caminhos · Unidade Vila Nova',
    kind: 'direct',
    unread: 0,
    updatedAt: now.subtract(const Duration(days: 5)),
  ),
  _conversation(
    id: 'dev-chat-maternal',
    title: 'Maternal Sementinha',
    preview: 'A adaptação da nova rotina de sono evoluiu bem nesta semana.',
    context: 'Centro Educacional Sementinha · Unidade Parque',
    kind: 'group',
    unread: 2,
    updatedAt: now.subtract(const Duration(days: 6)),
  ),
  _conversation(
    id: 'dev-chat-suporte-dados',
    title: 'Suporte de Dados e Acessos',
    preview: 'A revisão dos perfis de secretaria foi concluída sem pendências.',
    context: 'Rede Aprender · Administração central',
    kind: 'support',
    unread: 0,
    updatedAt: now.subtract(const Duration(days: 7)),
  ),
];

Map<String, List<ChatMessage>> _seedThreads(DateTime now) => {
  'dev-chat-girassol': [
    _message(
      id: 'dev-message-girassol-3',
      conversationId: 'dev-chat-girassol',
      body: 'A reunião com as famílias foi confirmada para quinta-feira.',
      author: 'Marina Duarte',
      sentAt: now.subtract(const Duration(minutes: 18)),
    ),
    _message(
      id: 'dev-message-girassol-2',
      conversationId: 'dev-chat-girassol',
      body: 'Podemos enviar o lembrete no início da manhã?',
      author: 'Paulo Mendes',
      sentAt: now.subtract(const Duration(minutes: 42)),
    ),
  ],
  'dev-chat-coordenacao': [
    _message(
      id: 'dev-message-coordenacao-2',
      conversationId: 'dev-chat-coordenacao',
      body: 'O planejamento de setembro já está disponível para revisão.',
      author: 'Helena Martins',
      sentAt: now.subtract(const Duration(hours: 2)),
    ),
  ],
  'dev-chat-implantacao': [
    _message(
      id: 'dev-message-implantacao-1',
      conversationId: 'dev-chat-implantacao',
      body: 'Os cadastros das turmas foram validados pela equipe Coelo.',
      author: 'Rafael Nogueira',
      sentAt: now.subtract(const Duration(hours: 5)),
    ),
  ],
  'dev-chat-azul': [
    _message(
      id: 'dev-message-azul-1',
      conversationId: 'dev-chat-azul',
      body: 'Enviamos o roteiro da atividade de leitura compartilhada.',
      author: 'Ana Souza',
      sentAt: now.subtract(const Duration(days: 1, hours: 1)),
    ),
  ],
  'dev-chat-secretaria': [
    _message(
      id: 'dev-message-secretaria-1',
      conversationId: 'dev-chat-secretaria',
      body: 'A circular de renovação de matrícula foi revisada.',
      author: 'Carla Melo',
      sentAt: now.subtract(const Duration(days: 2)),
    ),
  ],
  'dev-chat-bem-te-vi': [
    _message(
      id: 'dev-message-bem-te-vi-1',
      conversationId: 'dev-chat-bem-te-vi',
      body: 'A visita à biblioteca municipal foi autorizada pelas famílias.',
      author: 'Luciana Prado',
      sentAt: now.subtract(const Duration(days: 2, hours: 4)),
    ),
  ],
  'dev-chat-inclusao': [
    _message(
      id: 'dev-message-inclusao-1',
      conversationId: 'dev-chat-inclusao',
      body: 'O plano de apoio individual recebeu as observações da equipe pedagógica.',
      author: 'Renata Alves',
      sentAt: now.subtract(const Duration(days: 3)),
    ),
  ],
  'dev-chat-transporte': [
    _message(
      id: 'dev-message-transporte-1',
      conversationId: 'dev-chat-transporte',
      body: 'A rota da manhã terá ajuste de dez minutos a partir de segunda-feira.',
      author: 'Diego Campos',
      sentAt: now.subtract(const Duration(days: 3, hours: 7)),
    ),
  ],
  'dev-chat-familias-7a': [
    _message(
      id: 'dev-message-familias-7a-1',
      conversationId: 'dev-chat-familias-7a',
      body: 'A pauta do encontro sobre transição escolar foi compartilhada.',
      author: 'Fernanda Reis',
      sentAt: now.subtract(const Duration(days: 4)),
    ),
  ],
  'dev-chat-esportes': [
    _message(
      id: 'dev-message-esportes-1',
      conversationId: 'dev-chat-esportes',
      body: 'Os horários dos jogos internos foram confirmados no calendário.',
      author: 'Gustavo Leal',
      sentAt: now.subtract(const Duration(days: 5)),
    ),
  ],
  'dev-chat-maternal': [
    _message(
      id: 'dev-message-maternal-1',
      conversationId: 'dev-chat-maternal',
      body: 'A adaptação da nova rotina de sono evoluiu bem nesta semana.',
      author: 'Beatriz Lima',
      sentAt: now.subtract(const Duration(days: 6)),
    ),
  ],
  'dev-chat-suporte-dados': [
    _message(
      id: 'dev-message-suporte-dados-1',
      conversationId: 'dev-chat-suporte-dados',
      body: 'A revisão dos perfis de secretaria foi concluída sem pendências.',
      author: 'Caio Moreira',
      sentAt: now.subtract(const Duration(days: 7)),
    ),
  ],
};

ChatConversationSummary _conversation({
  required String id,
  required String title,
  required String preview,
  required String context,
  required String kind,
  required int unread,
  required DateTime updatedAt,
}) => ChatConversationSummary(
  id: id,
  title: title,
  preview: preview,
  contextLabel: context,
  kind: kind,
  unreadCount: unread,
  updatedAt: updatedAt,
  isReadOnly: false,
);

ChatConversationSummary _copyConversation(
  ChatConversationSummary source, {
  String? preview,
  int? unreadCount,
  DateTime? updatedAt,
}) => ChatConversationSummary(
  id: source.id,
  title: source.title,
  preview: preview ?? source.preview,
  contextLabel: source.contextLabel,
  kind: source.kind,
  unreadCount: unreadCount ?? source.unreadCount,
  updatedAt: updatedAt ?? source.updatedAt,
  isReadOnly: source.isReadOnly,
);

ChatMessage _message({
  required String id,
  required String conversationId,
  required String body,
  required String author,
  required DateTime sentAt,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  body: body,
  authorName: author,
  sentAt: sentAt,
  isMine: false,
  kind: 'text',
);
