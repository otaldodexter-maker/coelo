import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
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

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => inbox;

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
