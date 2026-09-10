import 'dart:async';

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

  testWidgets('a slow continuation cannot alter the conversation opened after it', (
    tester,
  ) async {
    final repository = _SlowContinuationRepository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('superadmin-chat-load-older')));
    await tester.pump();

    // O operador troca de conversa enquanto a continuacao ainda esta em voo.
    await tester.tap(find.text('Turma Margarida'));
    await tester.pumpAndSettle();
    expect(find.text('mensagem da margarida'), findsOneWidget);

    repository.completeContinuation();
    await tester.pumpAndSettle();

    // A resposta atrasada pertence a conversa anterior. Aplica-la aqui
    // misturaria mensagens de duas conversas na mesma thread, que e pior que
    // perder a continuacao.
    expect(find.text('mensagem antiga'), findsNothing);
    expect(find.text('mensagem da margarida'), findsOneWidget);
  });

  testWidgets('a send that lands during a continuation is not swallowed by it', (tester) async {
    final repository = _InterleavedRepository();
    await _pump(tester, repository);
    expect(find.text('mensagem recente'), findsOneWidget);

    // Continuacao em voo.
    await tester.tap(find.byKey(const Key('superadmin-chat-load-older')));
    await tester.pump();

    // O envio termina ANTES dela e acrescenta ao topo.
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    // Nao usar pumpAndSettle aqui: o indicador da continuacao em voo anima e a
    // arvore nunca fica ociosa. Bombear quadros e o suficiente para o envio.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Tudo bem?'), findsOneWidget);

    repository.completeContinuation();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // A continuacao acrescenta as antigas ao fim. Se ela reescrever a lista a
    // partir do instantaneo que capturou ANTES do envio, a mensagem enviada
    // desaparece da tela mesmo tendo sido aceita pelo servidor — o pior
    // resultado possivel, porque o operador acredita ter perdido o envio.
    expect(find.text('Tudo bem?'), findsOneWidget);
    expect(find.text('mensagem antiga'), findsOneWidget);
    expect(find.text('mensagem recente'), findsOneWidget);
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

  @override
  Future<ChatConversationPreference> setPinned({
    required String conversationId,
    required bool pinned,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setFlag({
    required String conversationId,
    required ChatConversationFlag flag,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());
}

/// Duas conversas, e a continuacao da primeira so responde quando mandarem.
final class _SlowContinuationRepository implements ChatRepository {
  final _continuation = Completer<ChatThreadPage>();

  void completeContinuation() => _continuation.complete(
    ChatThreadPage(items: [_message('message-old', 'mensagem antiga', 'conversation-1', 9)]),
  );

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 0,
    items: [
      _summary('conversation-1', 'Turma Girassol'),
      _summary('conversation-2', 'Turma Margarida'),
    ],
  );

  ChatConversationSummary _summary(String id, String title) => ChatConversationSummary(
    id: id,
    title: title,
    preview: 'Ultima mensagem',
    contextLabel: 'Unidade Cambui',
    kind: 'group',
    unreadCount: 0,
    updatedAt: DateTime.utc(2026, 8, 12, 12),
    isReadOnly: false,
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) {
    if (query.cursor != null) return _continuation.future;
    if (query.conversationId == 'conversation-2') {
      return Future.value(
        ChatThreadPage(
          items: [_message('message-m', 'mensagem da margarida', 'conversation-2', 11)],
        ),
      );
    }
    return Future.value(
      ChatThreadPage(
        items: [_message('message-recent', 'mensagem recente', 'conversation-1', 12)],
        nextCursor: ChatCursor(DateTime.utc(2026, 8, 12, 12), 'message-recent'),
        hasMore: true,
      ),
    );
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setPinned({
    required String conversationId,
    required bool pinned,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setFlag({
    required String conversationId,
    required ChatConversationFlag flag,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());
}

ChatMessage _message(String id, String body, String conversationId, int hour) => ChatMessage(
  id: id,
  conversationId: conversationId,
  body: body,
  authorName: 'Marina',
  sentAt: DateTime.utc(2026, 8, 12, hour),
  isMine: false,
  kind: 'text',
);

/// Continuacao lenta e envio rapido, para exercitar o entrelacamento.
final class _InterleavedRepository implements ChatRepository {
  final _continuation = Completer<ChatThreadPage>();

  void completeContinuation() => _continuation.complete(
    ChatThreadPage(items: [_message('message-old', 'mensagem antiga', 'conversation-1', 9)]),
  );

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
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) {
    if (query.cursor != null) return _continuation.future;
    return Future.value(
      ChatThreadPage(
        items: [_message('message-recent', 'mensagem recente', 'conversation-1', 12)],
        nextCursor: ChatCursor(DateTime.utc(2026, 8, 12, 12), 'message-recent'),
        hasMore: true,
      ),
    );
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async =>
      _message('message-sent', command.body, command.conversationId, 13);

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setPinned({
    required String conversationId,
    required bool pinned,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());

  @override
  Future<ChatConversationPreference> setFlag({
    required String conversationId,
    required ChatConversationFlag flag,
  }) => Future<ChatConversationPreference>.error(const ChatFailureException());
}
