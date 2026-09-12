import 'dart:io';

import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('received attachment metadata is visible even without a canonical asset', (
    tester,
  ) async {
    await _pump(
      tester,
      _PrincipalChatRepository(
        attachments: const [
          ChatAttachment(
            id: 'binding-1',
            fileName: 'imagem-recebida.png',
            mediaType: 'image/png',
            byteSize: 100,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();
    expect(find.text('imagem-recebida.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      final directives = source.readAsLinesSync().where(
        (line) => line.startsWith('import ') || line.startsWith('export '),
      );
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
          body: PrincipalChatPage(chatRepository: _PrincipalChatRepository(), embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shell hospedeiro'), findsOneWidget);
    expect(find.byKey(const Key('principal-chat-logo')), findsNothing);
    expect(find.byKey(const Key('principal-chat-inbox-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaches older conversations without losing the ones already read', (tester) async {
    final repository = _PrincipalChatRepository(
      inbox: ChatInboxPage(
        totalUnread: 0,
        nextCursor: ChatCursor(DateTime.utc(2026, 9, 9, 9), 'conversation-1'),
        items: [_summary('conversation-1', 'Turma Girassol')],
      ),
    );
    repository.nextInbox = ChatInboxPage(
      totalUnread: 0,
      items: [_summary('conversation-2', 'Turma Bem-te-vi')],
    );
    await _pump(tester, repository);

    expect(find.text('Turma Bem-te-vi'), findsNothing);
    await tester.tap(find.byKey(const Key('principal-chat-load-more')));
    await tester.pumpAndSettle();

    // A continuação acrescenta, não substitui.
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Turma Bem-te-vi'), findsOneWidget);
    // Sem cursor novo, a afordância some em vez de prometer mais páginas.
    expect(find.byKey(const Key('principal-chat-load-more')), findsNothing);
    expect(repository.inboxQueries.last.cursor?.id, 'conversation-1');
  });

  testWidgets('carries the active search into the continuation', (tester) async {
    final repository = _PrincipalChatRepository(
      inbox: ChatInboxPage(
        totalUnread: 0,
        nextCursor: ChatCursor(DateTime.utc(2026, 9, 9, 9), 'conversation-1'),
        items: [_summary('conversation-1', 'Turma Girassol')],
      ),
    );
    repository.nextInbox = const ChatInboxPage(items: [], totalUnread: 0);
    await _pump(tester, repository);

    await tester.enterText(find.byKey(const Key('principal-chat-search')), 'girassol');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-chat-load-more')));
    await tester.pumpAndSettle();

    // Continuar sem a busca traria outro conjunto de conversas.
    expect(repository.inboxQueries.last.search, 'girassol');
  });

  testWidgets('a denied continuation purges the private snapshot', (tester) async {
    final repository = _PrincipalChatRepository(
      inbox: ChatInboxPage(
        totalUnread: 0,
        nextCursor: ChatCursor(DateTime.utc(2026, 9, 9, 9), 'conversation-1'),
        items: [_summary('conversation-1', 'Turma Girassol')],
      ),
      continuationError: const ChatUnauthorizedException(),
    );
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('principal-chat-load-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-chat-inbox-unauthorized')), findsOneWidget);
    expect(find.text('Turma Girassol'), findsNothing);
  });

  testWidgets('reaches older messages in a long conversation', (tester) async {
    final repository = _PrincipalChatRepository(pagedThread: true);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.text('Mensagem antiga'), findsNothing);
    await tester.tap(find.byKey(const Key('principal-chat-load-older')));
    await tester.pumpAndSettle();

    expect(find.text('Bom dia'), findsOneWidget);
    expect(find.text('Mensagem antiga'), findsOneWidget);
    expect(find.byKey(const Key('principal-chat-load-older')), findsNothing);
    expect(repository.threadQueries.last.cursor?.id, 'message-1');
  });

  testWidgets('swapping the repository leaves no trace of the previous actor', (tester) async {
    final first = _PrincipalChatRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalChatPage(chatRepository: first, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'rascunho privado');
    await tester.enterText(find.byKey(const Key('principal-chat-search')), 'girassol');
    await tester.pump();

    // Trocar o repositório troca o ator autorizado: nada do contexto anterior
    // pode sobreviver, nem rascunho, nem busca, nem thread aberta.
    final second = _PrincipalChatRepository(inbox: const ChatInboxPage(items: [], totalUnread: 0));
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalChatPage(chatRepository: second, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('rascunho privado'), findsNothing);
    expect(find.text('girassol'), findsNothing);
    expect(find.text('Bom dia'), findsNothing);
    expect(find.byKey(const Key('principal-chat-inbox-empty')), findsOneWidget);
  });

  testWidgets('an empty thread by absence never looks like an empty thread by permission', (
    tester,
  ) async {
    // Mesmo princípio do zero silencioso que recusei no badge, um nível acima:
    // "não há mensagens" e "você não pode ver as mensagens" não podem produzir
    // a mesma tela. O servidor distingue os dois, e a UI precisa preservar isso.
    final absent = _PrincipalChatRepository(emptyThread: true);
    await _pump(tester, absent);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-chat-thread-empty')), findsOneWidget);
    expect(find.byKey(const Key('principal-chat-inbox-unauthorized')), findsNothing);
    // Uma conversa vazia mas autorizada continua permitindo escrever.
    expect(find.byKey(const Key('principal-chat-composer')), findsOneWidget);

    final denied = _PrincipalChatRepository(threadError: const ChatUnauthorizedException());
    await _pump(tester, denied);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-chat-thread-empty')), findsNothing);
    expect(find.byKey(const Key('principal-chat-inbox-unauthorized')), findsOneWidget);
    // Negação purga o composer junto com o resto do instantâneo privado.
    expect(find.byKey(const Key('principal-chat-composer')), findsNothing);
  });

  testWidgets('reconciles the inbox after sending, without blanking it', (tester) async {
    final repository = _PrincipalChatRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();
    final fetchesBeforeSend = repository.inboxQueries.length;

    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'Nova mensagem');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    // A lista mostra a última mensagem de cada conversa: sem reconciliar, o
    // preview continuaria anterior ao que acabou de ser enviado.
    expect(repository.inboxQueries.length, fetchesBeforeSend + 1);
    // E a reconciliação é silenciosa: a inbox nunca vira painel de carregamento.
    expect(find.byKey(const Key('principal-chat-inbox-loading')), findsNothing);
    expect(find.byKey(const Key('principal-chat-inbox-list')), findsOneWidget);
  });

  testWidgets('a silent reconciliation failure keeps the list the reader already has', (
    tester,
  ) async {
    final repository = _PrincipalChatRepository(failInboxAfterFirst: true);
    await _pump(tester, repository);
    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('principal-chat-composer')), 'Nova mensagem');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-chat-send')));
    await tester.pumpAndSettle();

    // Trocar uma lista válida por um painel de falha seria pior que mantê-la.
    expect(find.byKey(const Key('principal-chat-inbox-failure')), findsNothing);
    expect(find.byKey(const Key('principal-chat-inbox-list')), findsOneWidget);
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

Future<void> _pump(WidgetTester tester, ChatRepository repository, {VoidCallback? onBack}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PrincipalChatPage(chatRepository: repository, onBack: onBack ?? () {}),
    ),
  );
  await tester.pumpAndSettle();
}

ChatConversationSummary _summary(String id, String title) => ChatConversationSummary(
  id: id,
  title: title,
  preview: 'Ultima mensagem',
  contextLabel: 'Escola Horizonte',
  kind: 'group',
  unreadCount: 0,
  updatedAt: DateTime.utc(2026, 9, 9, 10),
  isReadOnly: false,
);

final class _PrincipalChatRepository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
  _PrincipalChatRepository({
    ChatInboxPage? inbox,
    this.inboxError,
    this.threadError,
    this.readOnly = false,
    this.withReceipts = true,
    this.continuationError,
    this.pagedThread = false,
    this.emptyThread = false,
    this.failInboxAfterFirst = false,
    this.attachments = const [],
  }) : inbox = inbox ?? _defaultInbox(readOnly: readOnly);

  ChatInboxPage inbox;
  final Object? inboxError;
  final Object? threadError;
  final bool readOnly;
  final bool withReceipts;
  final Object? continuationError;
  final bool pagedThread;
  final bool emptyThread;
  final bool failInboxAfterFirst;
  final List<ChatAttachment> attachments;

  final List<ChatThreadQuery> threadQueries = [];
  ChatInboxPage? nextInbox;
  final List<ChatInboxQuery> inboxQueries = [];
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
    inboxQueries.add(query);
    if (failInboxAfterFirst && inboxQueries.length > 1) {
      throw const ChatFailureException();
    }
    if (query.cursor != null) {
      if (continuationError != null) throw continuationError!;
      return nextInbox ?? const ChatInboxPage(items: [], totalUnread: 0);
    }
    if (inboxError != null) throw inboxError!;
    return inbox;
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    if (threadError != null) throw threadError!;
    threadQueries.add(query);
    threadFetches++;
    if (emptyThread) return const ChatThreadPage(items: []);
    if (query.cursor != null) {
      return ChatThreadPage(
        items: [
          ChatMessage(
            id: 'message-0',
            conversationId: query.conversationId,
            body: 'Mensagem antiga',
            authorName: 'Coordenacao',
            sentAt: DateTime.utc(2026, 9, 9, 8),
            isMine: false,
            kind: 'text',
          ),
        ],
      );
    }
    return ChatThreadPage(
      nextCursor: pagedThread ? ChatCursor(DateTime.utc(2026, 9, 9, 10), 'message-1') : null,
      items: [
        ChatMessage(
          id: 'message-1',
          conversationId: query.conversationId,
          body: attachments.isEmpty ? 'Bom dia' : '',
          attachments: attachments,
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
