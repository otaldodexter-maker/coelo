import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Criterio de fronteira acordado com a coordenacao: recarga disparada pela
/// acao do PROPRIO operador preserva o que ele ja carregou; recarga por
/// mudanca de contexto ou por negacao substitui tudo.
///
/// O envio rele a thread pela resposta normalizada do servidor, como a spec
/// exige, mas essa releitura devolve so a primeira pagina. Sem mesclar, quem
/// tinha aberto mensagens antigas as perdia ao enviar.
///
/// A mesclagem preserva apenas o que esta ALEM do alcance da pagina nova.
/// Dentro dele a pagina nova e a autoridade, senao uma mensagem revogada no
/// servidor reapareceria — que e exatamente a inconsistencia que a fronteira
/// existe para evitar.
void main() {
  testWidgets('sending keeps the older messages the reader had already opened', (tester) async {
    final repository = _PagedRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('principal-chat-load-older')));
    await tester.pumpAndSettle();
    expect(find.text('mensagem antiga'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    expect(find.text('Tudo bem?'), findsOneWidget);
    expect(find.text('mensagem antiga'), findsOneWidget);
    expect(find.text('mensagem recente'), findsOneWidget);
  });

  testWidgets('sending keeps the conversations the reader had already loaded', (tester) async {
    final repository = _PagedInboxRepository();
    await _pump(tester, repository);
    expect(find.text('Turma Margarida'), findsNothing);

    await tester.tap(find.byKey(const Key('principal-chat-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Turma Margarida'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    // A reconciliacao silenciosa devolve so a primeira pagina. Sem mesclar, as
    // conversas que o leitor abriu com "carregar mais" sumiriam por ter enviado
    // uma mensagem noutra conversa.
    expect(find.text('Turma Margarida'), findsWidgets);
    expect(find.text('Turma Girassol'), findsWidgets);
  });

  testWidgets('a message removed inside the reloaded range does not come back', (tester) async {
    final repository = _PagedRepository(dropRecentOnReload: true);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-chat-load-older')));
    await tester.pumpAndSettle();
    expect(find.text('mensagem recente'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    // A mensagem sumiu do servidor DENTRO do alcance relido: preservar aqui a
    // faria reaparecer como se existisse. A cauda antiga, fora do alcance,
    // continua.
    expect(find.text('mensagem recente'), findsNothing);
    expect(find.text('mensagem antiga'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, ChatRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: PrincipalChatPage(chatRepository: repository, onBack: () {}),
    ),
  );
  await tester.pumpAndSettle();
}

final class _PagedRepository implements ChatRepository {
  _PagedRepository({this.dropRecentOnReload = false});

  final bool dropRecentOnReload;
  var _sent = false;

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 0,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Ultima mensagem',
        contextLabel: 'Escola Horizonte',
        kind: 'group',
        unreadCount: 0,
        updatedAt: DateTime.utc(2026, 9, 9, 12),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    if (query.cursor != null) {
      return ChatThreadPage(items: [_message('message-old', 'mensagem antiga', 9)]);
    }
    return ChatThreadPage(
      items: [
        if (_sent) _message('message-sent', 'Tudo bem?', 13),
        if (!(_sent && dropRecentOnReload)) _message('message-recent', 'mensagem recente', 12),
      ],
      nextCursor: ChatCursor(DateTime.utc(2026, 9, 9, 12), 'message-recent'),
      hasMore: true,
    );
  }

  ChatMessage _message(String id, String body, int hour) => ChatMessage(
    id: id,
    conversationId: 'conversation-1',
    body: body,
    authorName: 'Marina',
    sentAt: DateTime.utc(2026, 9, 9, hour),
    isMine: false,
    kind: 'text',
  );

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    _sent = true;
    return _message('message-sent', command.body, 13);
  }

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());
}

/// Inbox com duas paginas, para separar a primeira do que o leitor acumulou.
final class _PagedInboxRepository implements ChatRepository {
  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    if (query.cursor != null) {
      return ChatInboxPage(
        totalUnread: 0,
        items: [_summary('conversation-2', 'Turma Margarida', 9)],
      );
    }
    return ChatInboxPage(
      totalUnread: 0,
      items: [_summary('conversation-1', 'Turma Girassol', 12)],
      nextCursor: ChatCursor(DateTime.utc(2026, 9, 9, 12), 'conversation-1'),
      hasMore: true,
    );
  }

  ChatConversationSummary _summary(String id, String title, int hour) => ChatConversationSummary(
    id: id,
    title: title,
    preview: 'Ultima mensagem',
    contextLabel: 'Escola Horizonte',
    kind: 'group',
    unreadCount: 0,
    updatedAt: DateTime.utc(2026, 9, 9, hour),
    isReadOnly: false,
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => ChatThreadPage(
    items: [
      ChatMessage(
        id: 'message-1',
        conversationId: query.conversationId,
        body: 'mensagem',
        authorName: 'Marina',
        sentAt: DateTime.utc(2026, 9, 9, 12),
        isMine: false,
        kind: 'text',
      ),
    ],
  );

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async => ChatMessage(
    id: 'message-sent',
    conversationId: command.conversationId,
    body: command.body,
    authorName: '',
    sentAt: DateTime.utc(2026, 9, 9, 13),
    isMine: true,
    kind: 'text',
  );

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());
}
