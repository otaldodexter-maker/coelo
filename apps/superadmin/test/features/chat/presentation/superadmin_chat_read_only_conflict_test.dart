import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma conversa somente leitura nao e perda de acesso.
///
/// As duas superficies ja tratam `isReadOnly` como estado normal: escondem o
/// composer e mostram o cadeado. Logo, uma recusa `CHAT_READ_ONLY` no envio so
/// acontece quando a conversa virou somente leitura DEPOIS que o instantaneo
/// local foi carregado — instantaneo velho, a mesma categoria do conflito de
/// versao em Avisos, e nao sessao perdida.
///
/// Tratar isso como negacao apaga a pagina inteira do operador: `_denyAccess`
/// zera inbox, thread, selecao e busca. Ele perde a lista de conversas porque
/// UMA delas foi fechada para escrita.
void main() {
  testWidgets('a read-only refusal keeps the operator inbox and thread', (tester) async {
    final repository = _ReadOnlyOnSendRepository();
    await _pump(tester, repository);

    expect(find.text('Turma Girassol'), findsWidgets);
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));

    // A recusa e da conversa, nao da sessao: a lista e a conversa continuam
    // visiveis. Perder tudo aqui seria a mesma categoria de erro do zero
    // silencioso no badge: um estado inventado a partir de outro.
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Mensagem autorizada'), findsWidgets);
  });

  testWidgets('a read-only refusal reloads instead of dead-ending on the same key', (
    tester,
  ) async {
    final repository = _ReadOnlyOnSendRepository();
    await _pump(tester, repository);
    final inboxReadsBefore = repository.inboxReads;

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    // Sem reler o inbox, `isReadOnly` continuaria falso no instantaneo local, o
    // composer seguiria oferecido e o operador repetiria a mesma intencao contra
    // uma conversa que nunca vai aceita-la. A thread NAO e relida de proposito:
    // a conversa e a mesma e `_select` preserva o que ja foi autorizado.
    expect(repository.inboxReads, greaterThan(inboxReadsBefore));
    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsNothing);
    expect(find.text('Mensagem autorizada'), findsWidgets);
  });
  testWidgets('the reload after a refusal does not swap the conversation under the operator', (
    tester,
  ) async {
    final repository = _TwoConversationRepository();
    await _pump(tester, repository);

    // O operador abre a SEGUNDA conversa, que nao e a primeira da lista.
    await tester.tap(find.text('Turma Margarida'));
    await tester.pumpAndSettle();
    expect(find.text('mensagem da margarida'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    // A recusa dispara releitura do inbox. Se essa releitura resselecionar o
    // primeiro item, o operador perde a conversa que estava lendo por causa de
    // uma recusa em OUTRA. Trocar a conversa na mao de alguem e pior que o
    // preview desatualizado que a releitura conserta.
    expect(find.text('mensagem da margarida'), findsOneWidget);
    expect(find.text('mensagem da girassol'), findsNothing);
  });

  testWidgets('the Principal surface treats a read-only refusal the same way', (tester) async {
    final repository = _ReadOnlyOnSendRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: PrincipalChatPage(chatRepository: repository, embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A superficie Principal nao auto-seleciona: o leitor escolhe a conversa.
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    final inboxReadsBefore = repository.inboxReads;
    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));
    // A familia visual e outra, o invariante e o mesmo: a conversa recusou, a
    // sessao nao. A inbox e relida e a conversa continua na tela.
    expect(repository.inboxReads, greaterThan(inboxReadsBefore));
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Mensagem autorizada'), findsWidgets);
  });
}

Future<void> _pump(WidgetTester tester, ChatRepository repository) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: CoeloTheme.light, home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository)),
  );
  await tester.pumpAndSettle();
}

final class _ReadOnlyOnSendRepository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
  final List<ChatSendMessageCommand> sent = [];
  var threadReads = 0;
  var inboxReads = 0;
  var _readOnly = false;

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    inboxReads++;
    return ChatInboxPage(
    totalUnread: 0,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Mensagem autorizada',
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 0,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        isReadOnly: _readOnly,
      ),
    ],
    );
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    threadReads++;
    return ChatThreadPage(
      items: [
        ChatMessage(
          id: 'message-1',
          conversationId: 'conversation-1',
          body: 'Mensagem autorizada',
          authorName: 'Marina',
          sentAt: DateTime.utc(2026, 8, 12, 12),
          isMine: false,
          kind: 'text',
        ),
      ],
    );
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) {
    sent.add(command);
    // O servidor fechou a conversa para escrita entre a leitura e o envio.
    _readOnly = true;
    return Future<ChatMessage>.error(const ChatConflictException(ChatConflictReason.readOnly));
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

/// Duas conversas, a segunda recusando o envio por somente leitura.
final class _TwoConversationRepository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
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
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => ChatThreadPage(
    items: [
      ChatMessage(
        id: 'message-${query.conversationId}',
        conversationId: query.conversationId,
        body: query.conversationId == 'conversation-2'
            ? 'mensagem da margarida'
            : 'mensagem da girassol',
        authorName: 'Marina',
        sentAt: DateTime.utc(2026, 8, 12, 12),
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
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatConflictException(ChatConflictReason.readOnly));

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
