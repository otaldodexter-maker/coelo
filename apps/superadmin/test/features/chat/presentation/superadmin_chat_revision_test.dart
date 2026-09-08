import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `chat.edit` and `chat.revoke`.
///
/// Authorisation is decided by the server through profile, hierarchy and RLS.
/// The client renders an affordance only when the authorised projection already
/// granted it, never deriving it from authorship. Editing is a server
/// re-projection, not a local rewrite; revocation is a tombstone proved by
/// re-reading the thread, not a row dropped on this device.
void main() {
  // The default surface is deliberate: the shell renders extra chrome at wider
  // widths that is unrelated to message revision.
  Future<void> pump(WidgetTester tester, ChatRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder menu() => find.byKey(const Key('superadmin-chat-message-menu-message-1'));

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(menu());
    await tester.pumpAndSettle();
  }

  testWidgets('offers nothing while the projection grants neither action', (tester) async {
    await pump(tester, _RevisableChatRepository(message: _message()));

    expect(find.text('Corpo original'), findsOneWidget);
    // Not a disabled affordance: with nothing granted there is no menu at all.
    expect(menu(), findsNothing);
  });

  testWidgets('offers exactly what the projection granted, one action at a time', (tester) async {
    await pump(tester, _RevisableChatRepository(message: _message(canEdit: true)));

    await openMenu(tester);
    expect(find.byKey(const Key('superadmin-chat-message-edit')), findsOneWidget);
    expect(
      find.byKey(const Key('superadmin-chat-message-revoke')),
      findsNothing,
      reason: 'granting an edit must never imply a revocation',
    );
  });

  testWidgets('a tombstone keeps its place and is never revised again', (tester) async {
    await pump(
      tester,
      _RevisableChatRepository(
        message: _message(canEdit: true, canRevoke: true, isRevoked: true, body: ''),
      ),
    );

    expect(find.text('Mensagem removida'), findsOneWidget);
    // The grants travelled with the projection, but a tombstone withdraws the
    // menu regardless: a removed message is never revised again.
    expect(menu(), findsNothing);
  });

  testWidgets('an empty edited body is refused before any round trip', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canEdit: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.edits, isEmpty, reason: 'an invalid body must not reach the server');
    expect(find.text('A mensagem nao pode ficar vazia.'), findsOneWidget);
  });

  testWidgets('a body past the server cap is refused before any round trip', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canEdit: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('superadmin-chat-edit-field')),
      'a' * (ChatMessageBodyPolicy.maximumCharacters + 1),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.edits, isEmpty);
    expect(
      find.text('A mensagem passa de ${ChatMessageBodyPolicy.maximumCharacters} caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling an edit sends nothing', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canEdit: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), 'Corpo novo');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-cancel')));
    await tester.pumpAndSettle();

    expect(repository.edits, isEmpty);
    expect(find.text('Corpo original'), findsOneWidget);
  });

  testWidgets('a confirmed edit renders the server projection, not the typed text', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canEdit: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), 'Corpo digitado');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.edits.single.messageId, 'message-1');
    expect(repository.edits.single.conversationId, 'conversation-1');
    expect(repository.edits.single.body, 'Corpo digitado');
    // The double answers with a different body on purpose: only the server's
    // re-projection may reach the screen, never the locally typed string.
    expect(find.text('Corpo normalizado pelo servidor'), findsOneWidget);
    expect(find.text('Corpo digitado'), findsNothing);
    expect(find.textContaining('editada'), findsOneWidget);
  });

  testWidgets('a retried edit replays the same intent instead of writing twice', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canEdit: true), editFails: true);
    await pump(tester, repository);

    for (var attempt = 0; attempt < 2; attempt++) {
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('superadmin-chat-message-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), 'Corpo novo');
      await tester.pump();
      await tester.tap(find.byKey(const Key('superadmin-chat-edit-save')));
      await tester.pumpAndSettle();
    }

    expect(repository.edits.length, 2);
    expect(
      repository.edits.first.idempotencyKey,
      repository.edits.last.idempotencyKey,
      reason: 'the same edit must replay, not create a second revision',
    );
  });

  testWidgets('an edit stays unavailable when the repository has no revision transport', (
    tester,
  ) async {
    final repository = _PlainChatRepository(message: _message(canEdit: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-edit-field')), 'Corpo novo');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('A edicao de mensagens aguarda o servico autorizado.'), findsOneWidget);
    // Unavailable is not permission, and it is not a local rewrite either.
    expect(find.text('Corpo original'), findsOneWidget);
    expect(find.text('Corpo novo'), findsNothing);
  });

  testWidgets('cancelling a revocation sends nothing', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canRevoke: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-revoke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-revoke-cancel')));
    await tester.pumpAndSettle();

    expect(repository.revocations, isEmpty);
    expect(find.text('Corpo original'), findsOneWidget);
  });

  testWidgets('a confirmed revocation is proved by re-reading the thread', (tester) async {
    final repository = _RevisableChatRepository(message: _message(canRevoke: true));
    await pump(tester, repository);
    final readsBefore = repository.threadReads;

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-revoke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(repository.revocations.single.messageId, 'message-1');
    expect(repository.revocations.single.conversationId, 'conversation-1');
    expect(
      repository.threadReads,
      readsBefore + 1,
      reason: 'the tombstone comes from the server, not from dropping the row here',
    );
    expect(find.text('Mensagem removida'), findsOneWidget);
    expect(find.text('Corpo original'), findsNothing);
  });

  testWidgets('a revocation stays unavailable without a revision transport', (tester) async {
    final repository = _PlainChatRepository(message: _message(canRevoke: true));
    await pump(tester, repository);

    await openMenu(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-message-revoke')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-chat-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('A remocao de mensagens aguarda o servico autorizado.'), findsOneWidget);
    expect(find.text('Corpo original'), findsOneWidget);
  });
}

ChatMessage _message({
  bool canEdit = false,
  bool canRevoke = false,
  bool isRevoked = false,
  String body = 'Corpo original',
}) => ChatMessage(
  id: 'message-1',
  conversationId: 'conversation-1',
  body: body,
  authorName: 'Marina',
  sentAt: DateTime.utc(2026, 8, 11, 10),
  isMine: true,
  kind: 'text',
  canEdit: canEdit,
  canRevoke: canRevoke,
  isRevoked: isRevoked,
);

ChatInboxPage _inbox() => ChatInboxPage(
  totalUnread: 0,
  items: [
    ChatConversationSummary(
      id: 'conversation-1',
      title: 'Turma Girassol',
      preview: 'Previa da conversa',
      contextLabel: 'Unidade Cambui',
      kind: 'group',
      unreadCount: 0,
      updatedAt: DateTime.utc(2026, 8, 11),
      isReadOnly: false,
    ),
  ],
);

/// A repository with no authorised revision transport at all: the surface must
/// report the action as unavailable, never as permitted or refused.
final class _PlainChatRepository implements ChatRepository {
  _PlainChatRepository({required this.message});

  final ChatMessage message;

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => _inbox();

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async =>
      ChatThreadPage(items: [message]);

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) =>
      Future<ChatAttachment>.error(const ChatAttachmentUnavailableException());
}

/// Plays the authorised server: it is the side that grants the affordances and
/// answers with its own projection.
final class _RevisableChatRepository implements ChatRepository, ChatMessageRevisionRepository {
  _RevisableChatRepository({required this.message, this.editFails = false});

  final ChatMessage message;
  final bool editFails;
  final List<ChatEditMessageCommand> edits = [];
  final List<ChatRevokeMessageCommand> revocations = [];
  var threadReads = 0;
  ChatMessage? _current;

  ChatMessage get _projected => _current ?? message;

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => _inbox();

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    threadReads++;
    return ChatThreadPage(items: [_projected]);
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
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) =>
      Future<ChatAttachment>.error(const ChatAttachmentUnavailableException());

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) async {
    edits.add(command);
    if (editFails) throw const ChatFailureException();
    // Deliberately not the body it was sent: proves the screen renders the
    // server projection instead of the text typed here.
    final revised = ChatMessage(
      id: command.messageId,
      conversationId: command.conversationId,
      body: 'Corpo normalizado pelo servidor',
      authorName: message.authorName,
      sentAt: message.sentAt,
      isMine: message.isMine,
      kind: message.kind,
      canEdit: message.canEdit,
      canRevoke: message.canRevoke,
      isEdited: true,
      editedAt: DateTime.utc(2026, 8, 11, 12),
    );
    _current = revised;
    return revised;
  }

  @override
  Future<void> revokeMessage(ChatRevokeMessageCommand command) async {
    revocations.add(command);
    _current = ChatMessage(
      id: command.messageId,
      conversationId: command.conversationId,
      body: '',
      authorName: message.authorName,
      sentAt: message.sentAt,
      isMine: message.isMine,
      kind: message.kind,
      isRevoked: true,
      revokedAt: DateTime.utc(2026, 8, 11, 12),
    );
  }
}
