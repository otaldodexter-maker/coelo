import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `chat.attach`: choose, validate, send, cancel, fail and
/// focus. The authorised gateway is still pending, so the production adapter
/// fails closed and these cases run against a faithful double.
void main() {
  ChatAttachmentDraft image({int bytes = 1024, String mediaType = 'image/png'}) =>
      ChatAttachmentDraft(
        fileName: 'registro.png',
        mediaType: mediaType,
        bytes: List<int>.filled(bytes, 1),
      );

  Future<void> pump(
    WidgetTester tester, {
    required _AttachmentChatRepository repository,
    ChatAttachmentDraft? picked,
    bool pickerReturnsNull = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminChatPage(
          logout: () async => const LogoutResult.success(),
          chatRepository: repository,
          attachmentPicker: () async => pickerReturnsNull ? null : picked,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turma Girassol').last);
    await tester.pumpAndSettle();
  }

  Future<void> attach(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Adicionar imagem'));
    await tester.pumpAndSettle();
  }

  testWidgets('chooses, uploads and sends the attachment with the message', (tester) async {
    final repository = _AttachmentChatRepository();
    await pump(tester, repository: repository, picked: image());

    await attach(tester);

    expect(find.byKey(const Key('superadmin-chat-attachment-pending')), findsOneWidget);
    expect(find.text('registro.png'), findsOneWidget);
    expect(find.text('pronto para enviar'), findsOneWidget);
    expect(repository.uploads, hasLength(1));
    expect(repository.uploads.single.conversationId, 'conversation-1');

    await tester.enterText(
      find.byKey(const Key('superadmin-chat-composer-field')),
      'Segue o registro',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent.single.attachmentIds, ['asset-1']);
    expect(repository.sent.single.body, 'Segue o registro');
    expect(find.byKey(const Key('superadmin-chat-attachment-pending')), findsNothing);
  });

  testWidgets('sends an attachment without any text', (tester) async {
    final repository = _AttachmentChatRepository();
    await pump(tester, repository: repository, picked: image());

    await attach(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent.single.body, isEmpty);
    expect(repository.sent.single.attachmentIds, ['asset-1']);
  });

  testWidgets('refuses an unsupported type before reaching the gateway', (tester) async {
    final repository = _AttachmentChatRepository();
    await pump(
      tester,
      repository: repository,
      picked: ChatAttachmentDraft(
        fileName: 'planilha.xlsx',
        mediaType: 'application/vnd.ms-excel',
        bytes: List<int>.filled(16, 1),
      ),
    );

    await attach(tester);

    expect(repository.uploads, isEmpty);
    expect(find.text('Formato nao aceito. Use JPG, PNG, WebP ou PDF.'), findsOneWidget);
    final retry = tester.widget<TextButton>(
      find.byKey(const Key('superadmin-chat-attachment-retry')),
    );
    expect(retry.onPressed, isNull, reason: 'an invalid file must not offer a retry');
    expect(
      tester.widget<IconButton>(find.byKey(const Key('superadmin-chat-send'))).onPressed,
      isNull,
    );
  });

  testWidgets('refuses a file above the approved size for its type', (tester) async {
    final repository = _AttachmentChatRepository();
    await pump(
      tester,
      repository: repository,
      picked: image(bytes: 10 * 1024 * 1024 + 1),
    );

    await attach(tester);

    expect(repository.uploads, isEmpty);
    expect(find.text('Arquivo acima do limite permitido.'), findsOneWidget);
  });

  testWidgets('cancelling the picker keeps the composer clean and focused', (tester) async {
    final repository = _AttachmentChatRepository();
    await pump(tester, repository: repository, pickerReturnsNull: true);

    await attach(tester);

    expect(find.byKey(const Key('superadmin-chat-attachment-pending')), findsNothing);
    expect(repository.uploads, isEmpty);
    final field = tester.widget<TextField>(find.byKey(const Key('superadmin-chat-composer-field')));
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('removing a ready attachment restores focus and disables send', (tester) async {
    final repository = _AttachmentChatRepository();
    await pump(tester, repository: repository, picked: image());

    await attach(tester);
    await tester.tap(find.byKey(const Key('superadmin-chat-attachment-remove')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-attachment-pending')), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('superadmin-chat-send'))).onPressed,
      isNull,
    );
    final field = tester.widget<TextField>(find.byKey(const Key('superadmin-chat-composer-field')));
    expect(field.focusNode?.hasFocus, isTrue);
  });

  testWidgets('a failed upload stays retryable and does not fake a message', (tester) async {
    final repository = _AttachmentChatRepository(failFirstUpload: true);
    await pump(tester, repository: repository, picked: image());

    await attach(tester);

    expect(find.text('Nao foi possivel anexar agora. Tente novamente.'), findsOneWidget);
    expect(repository.sent, isEmpty);

    await tester.tap(find.byKey(const Key('superadmin-chat-attachment-retry')));
    await tester.pumpAndSettle();

    expect(repository.uploads, hasLength(2));
    expect(find.text('pronto para enviar'), findsOneWidget);
  });

  testWidgets('an unavailable gateway is reported honestly', (tester) async {
    final repository = _AttachmentChatRepository(unavailable: true);
    await pump(tester, repository: repository, picked: image());

    await attach(tester);

    expect(find.text('Anexos aguardam o gateway autorizado.'), findsOneWidget);
    expect(repository.sent, isEmpty);
    expect(find.byKey(const Key('superadmin-chat-attachment-pending')), findsOneWidget);
    final retry = tester.widget<TextButton>(
      find.byKey(const Key('superadmin-chat-attachment-retry')),
    );
    expect(retry.onPressed, isNull, reason: 'retrying cannot help without a gateway');
  });

  testWidgets('a denied upload purges the private chat state', (tester) async {
    final repository = _AttachmentChatRepository(denyUpload: true);
    await pump(tester, repository: repository, picked: image());

    await attach(tester);

    expect(find.byKey(const Key('superadmin-chat-attachment-pending')), findsNothing);
    expect(find.text('Mensagem autorizada'), findsNothing);
    expect(repository.sent, isEmpty);
  });
}

final class _AttachmentChatRepository implements ChatRepository {
  _AttachmentChatRepository({
    this.failFirstUpload = false,
    this.unavailable = false,
    this.denyUpload = false,
  });

  final bool failFirstUpload;
  final bool unavailable;
  final bool denyUpload;
  final List<ChatAttachmentUploadCommand> uploads = [];
  final List<ChatSendMessageCommand> sent = [];

  @override
  Future<ChatAttachment> uploadAttachment(ChatAttachmentUploadCommand command) async {
    uploads.add(command);
    if (denyUpload) throw const ChatUnauthorizedException();
    if (unavailable) throw const ChatAttachmentUnavailableException();
    if (failFirstUpload && uploads.length == 1) throw const ChatFailureException();
    return ChatAttachment(
      id: 'asset-${uploads.length}',
      fileName: command.draft.fileName,
      mediaType: command.draft.mediaType,
      byteSize: command.draft.bytes.length,
      assetId: '11111111-1111-4111-8111-11111111111${uploads.length}',
    );
  }

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 1,
    totalCount: 1,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Mensagem autorizada',
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 1,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        isReadOnly: false,
      ),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => ChatThreadPage(
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

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    sent.add(command);
    return ChatMessage(
      id: 'message-${sent.length + 1}',
      conversationId: command.conversationId,
      body: command.body,
      authorName: '',
      sentAt: DateTime.utc(2026, 8, 12, 13),
      isMine: true,
      kind: 'text',
    );
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      Future<ChatRealtimeRefresh>.error(const ChatFailureException());
}
