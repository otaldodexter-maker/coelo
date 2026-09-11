import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lista de conversas mostra a ULTIMA mensagem de cada conversa. A superficie
/// administrativa recarregava so a thread depois de enviar, editar ou revogar,
/// entao o preview continuava mostrando o estado anterior pelo resto da sessao.
///
/// O caso de revogar e o mais grave e nao e cosmetico: o servidor ja exclui a
/// mensagem revogada do preview — o lateral de `latest_message_text` filtra
/// `deleted_at is null` desde a baseline de 01/09 —, entao quem mantem o corpo
/// revogado na tela e exclusivamente o cliente, por nao reler. Revogar existe
/// para tirar a mensagem da conversa; deixa-la no preview desfaz o efeito na
/// superficie que o operador mais olha.
///
/// A reconciliacao precisa preservar a conversa aberta. Resselecionar o
/// primeiro item trocaria a conversa na mao do operador, que e pior que o
/// preview velho — foi por esse risco que a reconciliacao ficou retida ate
/// existir `preserveSelection`.
void main() {
  testWidgets('revoking the last message clears it from the conversation preview', (tester) async {
    final repository = _ReconcilingRepository();
    await _pump(tester, repository);

    expect(find.text('mensagem secreta'), findsWidgets);

    await tester.tap(find.byKey(const Key('superadmin-chat-manage-message-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-action-revoke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(repository.revoked, hasLength(1));
    expect(find.text('mensagem secreta'), findsNothing);
  });

  testWidgets('editing the last message updates the conversation preview too', (tester) async {
    final repository = _ReconcilingRepository(acceptEdit: true);
    await _pump(tester, repository);
    expect(find.text('mensagem secreta'), findsWidgets);

    await tester.tap(find.byKey(const Key('superadmin-chat-manage-message-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'texto corrigido');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-confirm')));
    await tester.pumpAndSettle();

    // Editar tambem muda a ultima mensagem da conversa. Se o preview ficasse no
    // texto antigo, a lista continuaria afirmando algo que a conversa ja nao diz.
    expect(repository.edited, hasLength(1));
    expect(find.text('mensagem secreta'), findsNothing);
  });

  testWidgets('the reconciliation does not blink the conversation list', (tester) async {
    final repository = _ReconcilingRepository(conversations: 2, slowInbox: true);
    await _pump(tester, repository);
    await tester.tap(find.text('Turma Margarida'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Reconciliar nao pode custar a lista que o operador ja tem. Trocar a inbox
    // por um painel de carregamento a cada envio e pior que o preview velho que
    // a reconciliacao veio consertar.
    expect(find.text('Carregando conversas'), findsNothing);
    expect(find.text('Turma Girassol'), findsWidgets);

    repository.releaseInbox();
    await tester.pumpAndSettle();
  });

  testWidgets('sending reconciles the preview without swapping the open conversation', (
    tester,
  ) async {
    final repository = _ReconcilingRepository(conversations: 2);
    await _pump(tester, repository);

    await tester.tap(find.text('Turma Margarida'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    // O preview reflete o envio, e a conversa aberta continua sendo a que o
    // operador escolheu.
    expect(repository.inboxReads, greaterThan(1));
    expect(find.text('Tudo bem?'), findsWidgets);
    expect(find.text('mensagem da margarida'), findsOneWidget);
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

final class _ReconcilingRepository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
  _ReconcilingRepository({
    this.conversations = 1,
    this.slowInbox = false,
    this.acceptEdit = false,
  });

  final int conversations;
  final bool slowInbox;
  final bool acceptEdit;
  final List<String> edited = [];
  String? _editedBody;
  Completer<void>? _inboxGate;

  void releaseInbox() => _inboxGate?.complete();
  final List<String> revoked = [];
  var inboxReads = 0;
  String? _lastSent;

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    inboxReads++;
    if (slowInbox && inboxReads > 1) {
      _inboxGate = Completer<void>();
      await _inboxGate!.future;
    }
    return ChatInboxPage(
      totalUnread: 0,
      items: [
        for (var index = 1; index <= conversations; index++)
          ChatConversationSummary(
            id: 'conversation-$index',
            title: index == 1 ? 'Turma Girassol' : 'Turma Margarida',
            // O servidor recalcula o preview: mensagem revogada sai, mensagem
            // enviada entra.
            preview: index == conversations
                ? (_lastSent ??
                      _editedBody ??
                      (revoked.isEmpty ? 'mensagem secreta' : ''))
                : 'Ultima mensagem',
            contextLabel: 'Unidade Cambui',
            kind: 'group',
            unreadCount: 0,
            updatedAt: DateTime.utc(2026, 8, 12, 12),
            isReadOnly: false,
          ),
      ],
    );
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    final isLast = query.conversationId == 'conversation-$conversations';
    if (isLast && revoked.isNotEmpty) return const ChatThreadPage(items: []);
    return ChatThreadPage(
      items: [
        ChatMessage(
          id: 'message-1',
          conversationId: query.conversationId,
          body: isLast
              ? (_editedBody ??
                    (conversations == 1 ? 'mensagem secreta' : 'mensagem da margarida'))
              : 'mensagem da girassol',
          authorName: 'Marina',
          sentAt: DateTime.utc(2026, 8, 12, 12),
          isMine: true,
          kind: 'text',
          canManage: true,
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
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    _lastSent = command.body;
    return ChatMessage(
      id: 'message-sent',
      conversationId: command.conversationId,
      body: command.body,
      authorName: '',
      sentAt: DateTime.utc(2026, 8, 12, 13),
      isMine: true,
      kind: 'text',
    );
  }

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) async {
    if (!acceptEdit) throw const ChatFailureException();
    edited.add(command.messageId);
    _editedBody = command.body;
    return ChatMessage(
      id: command.messageId,
      conversationId: command.conversationId,
      body: command.body,
      authorName: 'Marina',
      sentAt: DateTime.utc(2026, 8, 12, 12),
      isMine: true,
      kind: 'text',
      canManage: true,
    );
  }

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) async {
    revoked.add(command.messageId);
    return ChatMessageRevocation(
      messageId: command.messageId,
      revokedAt: DateTime.utc(2026, 8, 12, 14),
    );
  }

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
