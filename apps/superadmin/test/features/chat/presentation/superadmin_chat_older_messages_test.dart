import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A superficie administrativa pagina a INBOX, mas nunca paginou a THREAD:
/// sempre pedia `ChatThreadQuery(conversationId: ...)` sem cursor e ignorava o
/// `nextCursor` que o servidor devolve. Numa conversa com mais mensagens que
/// uma pagina, o operador so alcancava as mais recentes, sem nenhuma forma de
/// chegar as anteriores. A RPC suporta o cursor e a superficie Principal ja o
/// usa; era so a metade administrativa que ficava sem.
void main() {
  testWidgets('reaches older messages in a long conversation', (tester) async {
    final repository = _PagedThreadRepository();
    await _pump(tester, repository);

    expect(find.text('mensagem recente'), findsOneWidget);
    expect(find.text('mensagem antiga'), findsNothing);

    await tester.tap(find.byKey(const Key('superadmin-chat-load-older')));
    await tester.pumpAndSettle();

    // A continuacao acrescenta as antigas sem descartar as que ja estavam na
    // tela: perder o que o leitor ja tinha seria pior que nao paginar.
    expect(find.text('mensagem antiga'), findsOneWidget);
    expect(find.text('mensagem recente'), findsOneWidget);
    expect(repository.cursorsRequested, ['message-recent']);
  });

  testWidgets('sending keeps the continuation the server had offered', (tester) async {
    final repository = _PagedThreadRepository(acceptSend: true);
    await _pump(tester, repository);
    expect(find.byKey(const Key('superadmin-chat-load-older')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    // Enviar acrescenta uma mensagem ao topo; nao torna o resto da conversa
    // inalcancavel. Descartar o cursor aqui faria o controle sumir e prenderia
    // o operador na pagina mais recente, sem nenhum sinal de que algo mudou.
    expect(find.text('Tudo bem?'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-load-older')), findsOneWidget);

    await tester.tap(find.byKey(const Key('superadmin-chat-load-older')));
    await tester.pumpAndSettle();
    expect(find.text('mensagem antiga'), findsOneWidget);
  });

  testWidgets('offers no continuation when the server says there is none', (tester) async {
    final repository = _PagedThreadRepository(exhausted: true);
    await _pump(tester, repository);

    // Sem cursor do servidor nao ha o que continuar. Oferecer o controle seria
    // prometer uma pagina que nao existe.
    expect(find.byKey(const Key('superadmin-chat-load-older')), findsNothing);
  });

  testWidgets('a denied continuation purges the private snapshot', (tester) async {
    final repository = _PagedThreadRepository(denyContinuation: true);
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('superadmin-chat-load-older')));
    await tester.pumpAndSettle();

    // Perder acesso durante a continuacao nao pode deixar conteudo privado na
    // tela, pela mesma regra que ja vale para inbox, thread e envio.
    expect(find.text('mensagem recente'), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, ChatRepository repository) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

final class _PagedThreadRepository implements ChatRepository {
  _PagedThreadRepository({
    this.exhausted = false,
    this.denyContinuation = false,
    this.acceptSend = false,
  });

  final bool exhausted;
  final bool denyContinuation;
  final bool acceptSend;
  final List<String> cursorsRequested = [];

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
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 0,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    final cursor = query.cursor;
    if (cursor == null) {
      return ChatThreadPage(
        items: [_message('message-recent', 'mensagem recente', 12)],
        nextCursor: exhausted ? null : ChatCursor(DateTime.utc(2026, 8, 12, 12), 'message-recent'),
        hasMore: !exhausted,
      );
    }
    cursorsRequested.add(cursor.id);
    if (denyContinuation) throw const ChatUnauthorizedException();
    return ChatThreadPage(items: [_message('message-old', 'mensagem antiga', 9)]);
  }

  ChatMessage _message(String id, String body, int hour) => ChatMessage(
    id: id,
    conversationId: 'conversation-1',
    body: body,
    authorName: 'Marina',
    sentAt: DateTime.utc(2026, 8, 12, hour),
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
    if (!acceptSend) throw const ChatFailureException();
    return _message('message-sent', command.body, 13);
  }

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());
}
