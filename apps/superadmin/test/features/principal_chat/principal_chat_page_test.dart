import 'dart:io';

import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Principal chat surface imports no administrative composition', () {
    final directory = Directory('lib/features/principal_chat');
    expect(directory.existsSync(), isTrue);
    final sources = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(sources, isNotEmpty);
    for (final source in sources) {
      // Só as diretivas importam: prosa que cita o nome proibido para explicar
      // a regra não é uma dependência.
      final directives = source
          .readAsLinesSync()
          .where((line) => line.startsWith('import ') || line.startsWith('export '));
      for (final directive in directives) {
        // spec050 e PRINCIPAL.md: a familia visual Principal nao importa a
        // composicao administrativa, mesmo hospedada em apps/superadmin.
        expect(directive, isNot(contains('coelo_ui_admin')), reason: source.path);
        expect(directive, isNot(contains('superadmin_chat')), reason: source.path);
        expect(directive, isNot(contains('superadmin_shell')), reason: source.path);
      }
    }
  });

  testWidgets('renders its own Principal chrome, not the administrative page', (tester) async {
    await _pump(tester, _PrincipalChatRepository());

    expect(find.byKey(const Key('principal-chat-logo')), findsOneWidget);
    expect(find.text('Mensagens'), findsOneWidget);
    expect(find.byKey(const Key('principal-chat-inbox-list')), findsOneWidget);
    // O dock ja oferece o launcher Mensagens; repeti-lo aqui seria o segundo
    // launcher que a spec050 proibe na mesma superficie.
    expect(find.byKey(const Key('principal-global-messages')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers contextual return to the surface that opened it', (tester) async {
    var returned = 0;
    await _pump(tester, _PrincipalChatRepository(), onBack: () => returned++);

    await tester.tap(find.byKey(const Key('principal-chat-back')));
    await tester.pumpAndSettle();

    expect(returned, 1);
  });

  testWidgets('opens a conversation and marks it read only after the server authorised it', (
    tester,
  ) async {
    final repository = _PrincipalChatRepository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.text('Bom dia'), findsOneWidget);
    expect(repository.threadFetches, 1);
    expect(repository.markedRead, ['conversation-1']);
  });

  testWidgets('an unauthorised thread never reports a read receipt', (tester) async {
    final repository = _PrincipalChatRepository(threadError: const ChatUnauthorizedException());
    await _pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(repository.markedRead, isEmpty);
    expect(find.byKey(const Key('principal-chat-inbox-unauthorized')), findsOneWidget);
  });

  testWidgets('sends with an idempotency key and re-reads the normalised thread', (tester) async {
    final repository = _PrincipalChatRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('principal-chat-composer')), '  Boa tarde  ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));
    expect(repository.sent.single.body, 'Boa tarde');
    expect(repository.sent.single.idempotencyKey, isNotEmpty);
    // A thread renderizada vem de uma releitura autorizada, nao do eco local.
    expect(repository.threadFetches, 2);
  });

  testWidgets('a read-only conversation offers no composer', (tester) async {
    final repository = _PrincipalChatRepository(readOnly: true);
    await _pump(tester, repository);

    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-chat-composer')), findsNothing);
  });

  testWidgets('renders the six required inbox states', (tester) async {
    Future<void> expectState(_PrincipalChatRepository repository, Key key) async {
      await _pump(tester, repository);
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }

    await expectState(
      _PrincipalChatRepository(inbox: const ChatInboxPage(items: [], totalUnread: 0)),
      const Key('principal-chat-inbox-empty'),
    );
    await expectState(
      _PrincipalChatRepository(inboxError: const ChatUnauthorizedException()),
      const Key('principal-chat-inbox-unauthorized'),
    );
    await expectState(
      _PrincipalChatRepository(inboxError: const ChatOfflineException()),
      const Key('principal-chat-inbox-offline'),
    );
    await expectState(
      _PrincipalChatRepository(inboxError: const ChatFailureException()),
      const Key('principal-chat-inbox-failure'),
    );

    // "Sem resultados" é distinto de "vazio": depende de uma busca ativa.
    final searching = _PrincipalChatRepository();
    await _pump(tester, searching);
    searching.inbox = const ChatInboxPage(items: [], totalUnread: 0);
    await tester.enterText(find.byKey(const Key('principal-chat-search')), 'inexistente');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-chat-inbox-no-results')), findsOneWidget);
  });

  testWidgets('never claims a receipt the server did not project', (tester) async {
    final repository = _PrincipalChatRepository(withReceipts: false);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-chat-receipt-message-1')), findsNothing);
    expect(find.textContaining('Lida'), findsNothing);
  });

  testWidgets('renders the projected receipt of a sent message', (tester) async {
    final repository = _PrincipalChatRepository(withReceipts: true);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.text('Lida por 1 de 2'), findsOneWidget);
  });

  testWidgets('hosted in the shell container it draws no chrome of its own', (tester) async {
    // Decisao final do Owner de 09/09/2026 em PRINCIPAL.md: o shell/menu
    // hospedeiro e preservado no web e no mobile, e a experiencia Principal
    // fica no conteiner de conteudo. Só os elementos internos do Principal
    // podem ser suspensos; duplicar cabecalho seria o defeito vedado.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Shell hospedeiro')),
          body: PrincipalChatPage(
            chatRepository: _PrincipalChatRepository(),
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shell hospedeiro'), findsOneWidget);
    expect(find.byKey(const Key('principal-chat-logo')), findsNothing);
    expect(find.byKey(const Key('principal-chat-inbox-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow across canonical breakpoints', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await _pump(tester, _PrincipalChatRepository());
      expect(tester.takeException(), isNull, reason: 'largura $width');
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pump(
  WidgetTester tester,
  ChatRepository repository, {
  VoidCallback? onBack,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: PrincipalChatPage(chatRepository: repository, onBack: onBack ?? () {})),
  );
  await tester.pumpAndSettle();
}

final class _PrincipalChatRepository implements ChatRepository {
  _PrincipalChatRepository({
    ChatInboxPage? inbox,
    this.inboxError,
    this.threadError,
    this.readOnly = false,
    this.withReceipts = true,
  }) : inbox = inbox ?? _defaultInbox(readOnly: readOnly);

  ChatInboxPage inbox;
  final Object? inboxError;
  final Object? threadError;
  final bool readOnly;
  final bool withReceipts;

  var threadFetches = 0;
  final List<String> markedRead = [];
  final List<ChatSendMessageCommand> sent = [];

  static ChatInboxPage _defaultInbox({required bool readOnly}) => ChatInboxPage(
    totalUnread: 2,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Ultima mensagem',
        contextLabel: 'Escola Horizonte',
        kind: 'group',
        unreadCount: 2,
        updatedAt: DateTime.utc(2026, 9, 9, 10),
        isReadOnly: readOnly,
      ),
    ],
  );

  @override
  Future<int> fetchUnreadTotal() async => inbox.totalUnread;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    if (inboxError != null) throw inboxError!;
    return inbox;
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    if (threadError != null) throw threadError!;
    threadFetches++;
    return ChatThreadPage(
      items: [
        ChatMessage(
          id: 'message-1',
          conversationId: query.conversationId,
          body: 'Bom dia',
          authorName: 'Coordenacao',
          sentAt: DateTime.utc(2026, 9, 9, 10),
          isMine: true,
          kind: 'text',
          receipt: withReceipts
              ? const ChatMessageReceipt(isMine: true, recipientCount: 2, readCount: 1)
              : null,
        ),
      ],
    );
  }

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    sent.add(command);
    return ChatMessage(
      id: 'message-2',
      conversationId: command.conversationId,
      body: command.body,
      authorName: 'Voce',
      sentAt: DateTime.utc(2026, 9, 9, 11),
      isMine: true,
      kind: 'text',
    );
  }

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async =>
      markedRead.add(conversationId);

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      Future<ChatRealtimeRefresh>.error(const ChatFailureException());
}
