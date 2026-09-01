import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('renders authorised conversation data without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      _viewport(tester, width);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Turma Girassol'), findsWidgets);
      expect(find.text('Mensagem autorizada'), findsWidgets);
      expect(find.byKey(const Key('superadmin-chat-composer-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps an empty authorised inbox actionable instead of blocking it', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app(repository: _ChatRepository.empty()));
    await tester.pumpAndSettle();

    expect(find.text('Ainda não há conversas'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);
  });

  testWidgets('marks the selected thread read and sends only through the repository', (
    tester,
  ) async {
    _viewport(tester, 768);
    final repository = _ChatRepository.standard();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    expect(repository.markedConversationIds, ['conversation-1']);
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent.single.body, 'Tudo bem?');
    expect(find.text('Tudo bem?'), findsOneWidget);
  });

  testWidgets('keeps controls usable at 200 percent text scale', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app(textScale: 2));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the canonical search field in the conversation inbox', (tester) async {
    _viewport(tester, 1024);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-search')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('superadmin-chat-search'))), isA<CoeloSearchField>());
  });

  testWidgets('paginates the conversation directory with the Institutions footer', (tester) async {
    _viewport(tester, 1440);
    final repository = _PaginatedChatRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    final footer = tester.widget<SuperadminListingPaginationFooter>(
      find.byType(SuperadminListingPaginationFooter),
    );
    var pagination = footer.child as CoeloAdminPagination;
    expect(pagination.currentPage, 1);
    expect(pagination.totalPages, 2);
    expect(pagination.pageSize, 8);
    expect(pagination.pageSizeOptions, const [8, 20, 50, 100]);
    expect(footer.compactCurrentPage, 1);
    expect(footer.compactTotalPages, 2);

    footer.compactOnNext?.call();
    await tester.pumpAndSettle();

    final secondFooter = tester.widget<SuperadminListingPaginationFooter>(
      find.byType(SuperadminListingPaginationFooter),
    );
    pagination = secondFooter.child as CoeloAdminPagination;
    expect(pagination.currentPage, 2);
    expect(repository.inboxQueries, hasLength(2));
    expect(repository.inboxQueries.last.cursor, _PaginatedChatRepository.nextCursor);
    expect(find.text('Conversa da segunda página'), findsWidgets);

    secondFooter.compactOnPrevious?.call();
    await tester.pumpAndSettle();
    expect(repository.inboxQueries.last.cursor, isNull);
  });

  testWidgets('uses the compact directory inset around the chat workspace', (tester) async {
    _viewport(tester, 375);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final inset = tester.widget<Padding>(find.byKey(const Key('superadmin-chat-content-inset')));
    expect(inset.padding, const EdgeInsets.all(CoeloSpacing.space4));
  });

  testWidgets('debounces canonical inbox search before querying the repository', (tester) async {
    _viewport(tester, 1024);
    final repository = _ChatRepository.standard();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byKey(const Key('superadmin-chat-search')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'família');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.inboxQueries, hasLength(1));

    await tester.pump(const Duration(milliseconds: 250));
    expect(repository.inboxQueries.last.search, 'família');
  });

  testWidgets('ignores an older inbox response after a newer search completes', (tester) async {
    _viewport(tester, 1024);
    final repository = _ControlledSearchRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    final search = tester.widget<CoeloSearchField>(find.byKey(const Key('superadmin-chat-search')));
    search.controller.text = 'busca A';
    search.onChanged('busca A');
    await tester.pump(const Duration(milliseconds: 301));
    expect(repository.pending, contains('busca A'));

    search.controller.text = 'busca B';
    search.onChanged('busca B');
    await tester.pump(const Duration(milliseconds: 301));
    expect(repository.pending, contains('busca B'));

    repository.complete('busca B', title: 'Resultado B');
    await tester.pump();
    await tester.pump();
    expect(find.text('Resultado B'), findsWidgets);

    repository.complete('busca A', title: 'Resultado A');
    await tester.pump();
    await tester.pump();
    expect(find.text('Resultado B'), findsWidgets);
    expect(find.text('Resultado A'), findsNothing);
  });

  testWidgets('ignores an older automatic thread after a newer search completes', (tester) async {
    _viewport(tester, 1440);
    final repository = _ControlledThreadSearchRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    final search = tester.widget<CoeloSearchField>(find.byKey(const Key('superadmin-chat-search')));
    search.controller.text = 'busca A';
    search.onChanged('busca A');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    expect(repository.olderThread, isNotNull);

    search.controller.text = 'busca B';
    search.onChanged('busca B');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(repository.sharedThreadRequests, 2);

    repository.olderThread!.complete(_threadPage('Thread A'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Resultado B'), findsWidgets);
    expect(find.text('Thread A'), findsNothing);
  });

  testWidgets('repository swap clears tenant A and ignores its late search', (tester) async {
    _viewport(tester, 1440);
    final repositoryA = _ControlledSearchRepository();
    final repositoryB = _UnauthorizedChatRepository();
    await tester.pumpWidget(_app(repository: repositoryA));
    await tester.pumpAndSettle();

    final search = tester.widget<CoeloSearchField>(find.byKey(const Key('superadmin-chat-search')));
    search.controller.text = 'tenant A';
    search.onChanged('tenant A');
    await tester.pump(const Duration(milliseconds: 301));
    expect(repositoryA.pending, contains('tenant A'));

    await tester.pumpWidget(_app(repository: repositoryB));
    await tester.pump();
    await tester.pump();

    expect(repositoryB.queries, hasLength(1));
    expect(repositoryB.queries.single.search, isEmpty);
    expect(find.text('Acesso nao autorizado'), findsOneWidget);
    expect(find.text('Turma Girassol'), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-search')), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsNothing);

    repositoryA.complete('tenant A', title: 'Resultado privado A');
    await tester.pump();
    await tester.pump();
    expect(find.text('Acesso nao autorizado'), findsOneWidget);
    expect(find.text('Resultado privado A'), findsNothing);
  });

  testWidgets('late send from conversation A cannot alter conversation B', (tester) async {
    _viewport(tester, 1440);
    final repository = _ControlledSendRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('superadmin-chat-composer-field')),
      'Mensagem enviada A',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    expect(repository.sent, hasLength(1));

    await tester.tap(find.byKey(const Key('chat-real-conversation-conversation-b')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Rascunho B');

    repository.completeFirstSend();
    await tester.pump();
    await tester.pump();

    final composer = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('superadmin-chat-composer-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(composer.controller.text, 'Rascunho B');
    expect(find.text('Thread B'), findsOneWidget);
    expect(find.text('Mensagem enviada A'), findsNothing);

    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();
    expect(repository.sent, hasLength(2));
    expect(repository.sent.last.conversationId, 'conversation-b');
    expect(find.text('Rascunho B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reselecting the same conversation keeps its send single-flight', (tester) async {
    _viewport(tester, 1440);
    final repository = _ControlledSendRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Mensagem A');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    expect(repository.sent, hasLength(1));

    await tester.tap(find.byKey(const Key('chat-real-conversation-conversation-a')));
    await tester.pump();
    await tester.pump();
    expect(repository.threadRequests, 1);
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();

    expect(repository.sent, hasLength(1));
    repository.completeFirstSend();
    await tester.pump();
    await tester.pump();
    expect(find.text('Mensagem enviada A'), findsOneWidget);
  });

  testWidgets('retries an ambiguous send with the same idempotency key', (tester) async {
    _viewport(tester, 1440);
    final repository = _AmbiguousSendRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('superadmin-chat-composer-field')),
      'Mensagem única',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    await tester.pump();
    expect(repository.persistedMessages, 1);
    expect(repository.commands, hasLength(1));

    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    await tester.pump();

    expect(repository.persistedMessages, 1);
    expect(repository.commands, hasLength(2));
    expect(repository.commands[1].idempotencyKey, repository.commands[0].idempotencyKey);
    expect(find.text('Mensagem única'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing after an ambiguous send creates a new intent', (tester) async {
    _viewport(tester, 1440);
    final repository = _AmbiguousSendRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Mensagem A');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Mensagem B');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pump();
    await tester.pump();

    expect(repository.persistedMessages, 2);
    expect(repository.commands, hasLength(2));
    expect(repository.commands[1].idempotencyKey, isNot(repository.commands[0].idempotencyKey));
    expect(find.text('Mensagem B'), findsOneWidget);
  });
}

Widget _app({ChatRepository? repository, double textScale = 1}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: SuperadminChatPage(
    logout: _logout,
    chatRepository: repository ?? _ChatRepository.standard(),
  ),
);

void _viewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _ChatRepository implements ChatRepository {
  _ChatRepository._({required this.inbox, required this.thread});

  factory _ChatRepository.standard() => _ChatRepository._(
    inbox: ChatInboxPage(
      totalUnread: 1,
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
    ),
    thread: ChatThreadPage(
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
    ),
  );

  factory _ChatRepository.empty() => _ChatRepository._(
    inbox: const ChatInboxPage(items: [], totalUnread: 0),
    thread: const ChatThreadPage(items: []),
  );

  final ChatInboxPage inbox;
  final ChatThreadPage thread;
  final List<String> markedConversationIds = [];
  final List<ChatSendMessageCommand> sent = [];
  final List<ChatInboxQuery> inboxQueries = [];

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    inboxQueries.add(query);
    return inbox;
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => thread;

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {
    markedConversationIds.add(conversationId);
  }

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    sent.add(command);
    return ChatMessage(
      id: 'message-${sent.length + 1}',
      conversationId: command.conversationId,
      body: command.body,
      authorName: '',
      sentAt: DateTime.utc(2026, 8, 12, 12, sent.length),
      isMine: true,
      kind: 'text',
    );
  }
}

final class _ControlledSearchRepository implements ChatRepository {
  final _fallback = _ChatRepository.standard();
  final Map<String, Completer<ChatInboxPage>> pending = {};

  void complete(String search, {required String title}) {
    pending
        .remove(search)!
        .complete(
          ChatInboxPage(
            totalUnread: 0,
            items: [
              ChatConversationSummary(
                id: 'conversation-$search',
                title: title,
                preview: 'Resultado de $search',
                contextLabel: 'Contexto autorizado',
                kind: 'group',
                unreadCount: 0,
                updatedAt: DateTime.utc(2026, 8, 27),
                isReadOnly: false,
              ),
            ],
          ),
        );
  }

  @override
  Future<int> fetchUnreadTotal() => _fallback.fetchUnreadTotal();

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) {
    if (query.search.isEmpty) return _fallback.fetchInbox(query);
    return (pending[query.search] = Completer<ChatInboxPage>()).future;
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async =>
      const ChatThreadPage(items: []);

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) =>
      _fallback.markRead(conversationId: conversationId, upToMessageId: upToMessageId);

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      _fallback.refreshAfterRealtime(conversationId: conversationId);

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) => _fallback.sendMessage(command);
}

final class _PaginatedChatRepository implements ChatRepository {
  static final nextCursor = ChatCursor(DateTime.utc(2026, 8, 20), 'conversation-8');
  final List<ChatInboxQuery> inboxQueries = [];

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    inboxQueries.add(query);
    final secondPage = query.cursor != null;
    return ChatInboxPage(
      totalUnread: 0,
      totalCount: 12,
      hasMore: !secondPage,
      nextCursor: secondPage ? null : nextCursor,
      items: [
        _conversation(
          secondPage ? 'conversation-9' : 'conversation-1',
          secondPage ? 'Conversa da segunda página' : 'Conversa da primeira página',
        ),
      ],
    );
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => _threadPage('Mensagem');

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ControlledThreadSearchRepository implements ChatRepository {
  final _fallback = _ChatRepository.standard();
  Completer<ChatThreadPage>? olderThread;
  var _sharedThreadRequests = 0;
  int get sharedThreadRequests => _sharedThreadRequests;

  @override
  Future<int> fetchUnreadTotal() => _fallback.fetchUnreadTotal();

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    if (query.search.isEmpty) return _fallback.fetchInbox(query);
    return ChatInboxPage(
      totalUnread: 0,
      items: [
        ChatConversationSummary(
          id: 'shared-conversation',
          title: query.search == 'busca A' ? 'Resultado A' : 'Resultado B',
          preview: 'Resultado de ${query.search}',
          contextLabel: 'Contexto autorizado',
          kind: 'group',
          unreadCount: 0,
          updatedAt: DateTime.utc(2026, 8, 27),
          isReadOnly: false,
        ),
      ],
    );
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) {
    if (query.conversationId != 'shared-conversation') return _fallback.fetchThread(query);
    _sharedThreadRequests += 1;
    if (_sharedThreadRequests == 1) {
      return (olderThread = Completer<ChatThreadPage>()).future;
    }
    return Future.value(_threadPage('Thread B'));
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) =>
      _fallback.markRead(conversationId: conversationId, upToMessageId: upToMessageId);

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      _fallback.refreshAfterRealtime(conversationId: conversationId);

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) => _fallback.sendMessage(command);
}

final class _UnauthorizedChatRepository implements ChatRepository {
  final List<ChatInboxQuery> queries = [];

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) {
    queries.add(query);
    throw const ChatUnauthorizedException();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ControlledSendRepository implements ChatRepository {
  final List<ChatSendMessageCommand> sent = [];
  final Completer<ChatMessage> _firstSend = Completer<ChatMessage>();
  int threadRequests = 0;

  void completeFirstSend() {
    _firstSend.complete(
      ChatMessage(
        id: 'sent-a',
        conversationId: 'conversation-a',
        body: 'Mensagem enviada A',
        authorName: 'Owner',
        sentAt: DateTime.utc(2026, 8, 28),
        isMine: true,
        kind: 'text',
      ),
    );
  }

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 0,
    items: [
      _conversation('conversation-a', 'Conversa A'),
      _conversation('conversation-b', 'Conversa B'),
    ],
  );

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    threadRequests++;
    return _threadPage(query.conversationId == 'conversation-a' ? 'Thread A' : 'Thread B');
  }

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) {
    sent.add(command);
    if (sent.length == 1) return _firstSend.future;
    return Future.value(
      ChatMessage(
        id: 'sent-b',
        conversationId: command.conversationId,
        body: command.body,
        authorName: 'Owner',
        sentAt: DateTime.utc(2026, 8, 28, 1),
        isMine: true,
        kind: 'text',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AmbiguousSendRepository implements ChatRepository {
  final List<ChatSendMessageCommand> commands = [];
  final Map<String, ChatMessage> _receipts = {};
  int persistedMessages = 0;
  bool _dropFirstResponse = true;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async =>
      ChatInboxPage(totalUnread: 0, items: [_conversation('conversation-a', 'Conversa A')]);

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async => _threadPage('Thread A');

  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    commands.add(command);
    if (_receipts[command.idempotencyKey] case final receipt?) return receipt;
    persistedMessages++;
    final receipt = ChatMessage(
      id: 'sent-unique',
      conversationId: command.conversationId,
      body: command.body,
      authorName: 'Owner',
      sentAt: DateTime.utc(2026, 8, 28),
      isMine: true,
      kind: 'text',
    );
    _receipts[command.idempotencyKey] = receipt;
    if (_dropFirstResponse) {
      _dropFirstResponse = false;
      throw const ChatOfflineException();
    }
    return receipt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatConversationSummary _conversation(String id, String title) => ChatConversationSummary(
  id: id,
  title: title,
  preview: 'Preview $title',
  contextLabel: 'Contexto autorizado',
  kind: 'group',
  unreadCount: 0,
  updatedAt: DateTime.utc(2026, 8, 28),
  isReadOnly: false,
);

ChatThreadPage _threadPage(String body) => ChatThreadPage(
  items: [
    ChatMessage(
      id: 'message-$body',
      conversationId: 'shared-conversation',
      body: body,
      authorName: 'Marina',
      sentAt: DateTime.utc(2026, 8, 27),
      isMine: false,
      kind: 'text',
    ),
  ],
);
