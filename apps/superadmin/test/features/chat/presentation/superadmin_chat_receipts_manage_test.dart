import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the receipt the server projected for a received message', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [
          _message(
            id: 'message-1',
            body: 'Confirmado',
            isMine: false,
            receipt: ChatMessageReceipt(
              isMine: false,
              deliveredAt: DateTime.utc(2026, 9, 9, 11),
              readAt: DateTime.utc(2026, 9, 9, 12),
            ),
          ),
        ],
      ),
    );
    await _pump(tester, repository);

    expect(find.text('Lida'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-receipt-message-1')), findsOneWidget);
  });

  testWidgets('renders the outbound receipt as read count over recipients', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [
          _message(
            id: 'message-1',
            body: 'Aviso enviado',
            isMine: true,
            receipt: const ChatMessageReceipt(
              isMine: true,
              recipientCount: 3,
              deliveredCount: 3,
              readCount: 1,
            ),
          ),
        ],
      ),
    );
    await _pump(tester, repository);

    expect(find.text('Lida por 1 de 3'), findsOneWidget);
  });

  testWidgets('renders no receipt when the gateway projected none', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(items: [_message(id: 'message-1', body: 'Sem recibo', isMine: true)]),
    );
    await _pump(tester, repository);

    expect(find.byKey(const Key('superadmin-chat-receipt-message-1')), findsNothing);
    expect(find.textContaining('Lida'), findsNothing);
  });

  testWidgets('offers no manage affordance when the server refuses management', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [_message(id: 'message-1', body: 'De outro autor', isMine: false)],
      ),
    );
    await _pump(tester, repository);

    expect(find.byKey(const Key('superadmin-chat-manage-message-1')), findsNothing);
  });

  testWidgets('edits an owned message and re-reads the persisted thread', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [_message(id: 'message-1', body: 'Texto antigo', isMine: true, canManage: true)],
      ),
    );
    repository.threadAfterCommand = ChatThreadPage(
      items: [
        _message(
          id: 'message-1',
          body: 'Texto novo',
          isMine: true,
          canManage: true,
          editedAt: DateTime.utc(2026, 9, 9, 13),
        ),
      ],
    );
    await _pump(tester, repository);

    await _openManageAction(tester, 'superadmin-chat-action-edit');
    await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), '  Texto novo  ');
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-confirm')));
    await tester.pumpAndSettle();

    expect(repository.edits, hasLength(1));
    expect(repository.edits.single.messageId, 'message-1');
    expect(repository.edits.single.body, 'Texto novo');
    expect(repository.edits.single.conversationId, 'conversation-1');
    // The rendered result is the re-read thread, never the command's echo.
    expect(repository.threadFetches, 2);
    expect(find.text('Texto novo'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-edited-message-1')), findsOneWidget);
  });

  testWidgets('revokes an owned message only after explicit confirmation', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [
          _message(id: 'message-1', body: 'Corpo revogavel', isMine: true, canManage: true),
        ],
      ),
    );
    repository.threadAfterCommand = const ChatThreadPage(items: []);
    await _pump(tester, repository);

    await _openManageAction(tester, 'superadmin-chat-action-revoke');
    expect(repository.revocations, isEmpty);

    await tester.tap(find.byKey(const Key('superadmin-chat-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(repository.revocations, ['message-1']);
    expect(find.text('Corpo revogavel'), findsNothing);
    expect(find.text('Mensagem revogada.'), findsOneWidget);
  });

  testWidgets('a refused edit explains the reason and keeps the session', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [_message(id: 'message-1', body: 'Antigo', isMine: true, canManage: true)],
      ),
      editError: const ChatConflictException(ChatConflictReason.editWindowClosed),
    );
    await _pump(tester, repository);

    await _openManageAction(tester, 'superadmin-chat-action-edit');
    await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), 'Novo');
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('O prazo de edicao desta mensagem terminou.'), findsOneWidget);
    // A refused command is not a lost session: the conversation stays open.
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Antigo'), findsOneWidget);
  });

  testWidgets('a denied revocation purges the private snapshot', (tester) async {
    final repository = _ManageChatRepository(
      thread: ChatThreadPage(
        items: [
          _message(id: 'message-1', body: 'Corpo negado', isMine: true, canManage: true),
        ],
      ),
      revokeError: const ChatUnauthorizedException(),
    );
    await _pump(tester, repository);

    await _openManageAction(tester, 'superadmin-chat-action-revoke');
    await tester.tap(find.byKey(const Key('superadmin-chat-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Corpo negado'), findsNothing);
    expect(find.text('Acesso nao autorizado'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, ChatRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openManageAction(WidgetTester tester, String actionKey) async {
  await tester.tap(find.byKey(const Key('superadmin-chat-manage-message-1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(actionKey)));
  await tester.pumpAndSettle();
}

ChatMessage _message({
  required String id,
  required String body,
  required bool isMine,
  bool canManage = false,
  ChatMessageReceipt? receipt,
  DateTime? editedAt,
}) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  body: body,
  authorName: isMine ? 'Equipe Coelo' : 'Coordenacao',
  sentAt: DateTime.utc(2026, 9, 9, 10),
  isMine: isMine,
  kind: 'text',
  receipt: receipt,
  editedAt: editedAt,
  canManage: canManage,
);

final class _EditRecord {
  const _EditRecord(this.conversationId, this.messageId, this.body);
  final String conversationId;
  final String messageId;
  final String body;
}

final class _ManageChatRepository implements ChatRepository {
  _ManageChatRepository({required this.thread, this.editError, this.revokeError});

  final ChatThreadPage thread;
  final Object? editError;
  final Object? revokeError;

  ChatThreadPage? threadAfterCommand;
  var threadFetches = 0;
  final List<_EditRecord> edits = [];
  final List<String> revocations = [];

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 0,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Mensagem',
        contextLabel: 'Unidade Centro',
        kind: 'group',
        unreadCount: 0,
        updatedAt: DateTime.utc(2026, 9, 9, 10),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    threadFetches++;
    if (threadFetches > 1 && threadAfterCommand != null) return threadAfterCommand!;
    return thread;
  }

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) async {
    if (editError != null) throw editError!;
    edits.add(_EditRecord(command.conversationId, command.messageId, command.body));
    return _message(id: command.messageId, body: command.body, isMine: true, canManage: true);
  }

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) async {
    if (revokeError != null) throw revokeError!;
    revocations.add(command.messageId);
    return ChatMessageRevocation(
      messageId: command.messageId,
      revokedAt: DateTime.utc(2026, 9, 9, 13),
    );
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      Future<ChatRealtimeRefresh>.error(const ChatFailureException());

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
