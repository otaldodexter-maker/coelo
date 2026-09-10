import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metade ADMINISTRATIVA de `chat.list`, `chat.open` e `chat.send` exercida pela
/// ROTA REAL `/communication/conversations`, e não por injeção direta da página.
///
/// A cobertura de widget dessas três ações já era densa em
/// `test/features/chat/presentation/superadmin_chat_page_test.dart`, mas toda
/// ela monta `SuperadminChatPage` diretamente. Montar a composição pela rota
/// prova composição, não comportamento; exercitar o comportamento fora da rota
/// não prova que a rota entrega as dependências certas. Estes casos fecham a
/// junção: a rota protegida lista, abre, marca leitura, envia e projeta o
/// recibo do servidor usando o repositório que o router injetou.
void main() {
  testWidgets('the real conversations route lists, opens, reads and sends', (tester) async {
    _viewport(tester);
    final repository = _RecordingChatRepository();
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      chatRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.conversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    // chat.list pela rota real: o inbox veio do repositório injetado pelo
    // router, e não de um estado vazio que pareceria "sem conversas".
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.conversations);
    expect(repository.inboxQueries, isNotEmpty);
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.text('Nao foi possivel carregar'), findsNothing);

    // chat.open pela rota real: a thread foi buscada e a leitura só é marcada
    // depois que o servidor autorizou a thread daquela conversa.
    expect(repository.threadQueries.single.conversationId, 'conversation-1');
    expect(repository.markedConversationIds, ['conversation-1']);

    // chat.receipts pela rota real: o recibo projetado pelo servidor chega à
    // renderização; a ausência de recibo não é inventada como "não lida".
    expect(find.text('Lida por 2 de 3'), findsOneWidget);

    // chat.send pela rota real: o envio passa somente pelo repositório
    // injetado, com chave de idempotência, e a bolha vem da releitura
    // normalizada, não do eco local.
    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    expect(repository.sent.single.body, 'Tudo bem?');
    expect(repository.sent.single.conversationId, 'conversation-1');
    expect(repository.sent.single.idempotencyKey, isNotEmpty);
    expect(find.text('Tudo bem?'), findsOneWidget);
  });

  testWidgets('the real conversations route fails closed instead of showing an empty inbox', (
    tester,
  ) async {
    _viewport(tester);
    final session = SuperadminSession()..signInForTesting();
    // Sem `chatRepository`, o router injeta a implementação fail-closed. Um
    // inbox vazio aqui seria pior que um erro: diria ao operador que não há
    // conversas, quando na verdade não há backend autorizado.
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.conversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Nao foi possivel carregar'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsNothing);
  });

  testWidgets('a denial on the real route purges the private snapshot and the composer', (
    tester,
  ) async {
    _viewport(tester);
    final repository = _RecordingChatRepository(denySend: true);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: (_) async => const LoginResult.success(),
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      chatRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.conversations);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('superadmin-chat-composer-field')), 'Tudo bem?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('superadmin-chat-send')));
    await tester.pumpAndSettle();

    // Reautorização pós-lock exercida pela rota: perder acesso durante o envio
    // não pode deixar conteúdo privado na tela nem oferecer nova tentativa.
    expect(find.text('Mensagem autorizada'), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsNothing);
  });
}

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

final class _RecordingChatRepository implements ChatRepository {
  _RecordingChatRepository({this.denySend = false});

  final bool denySend;
  final List<ChatInboxQuery> inboxQueries = [];
  final List<ChatThreadQuery> threadQueries = [];
  final List<String> markedConversationIds = [];
  final List<ChatSendMessageCommand> sent = [];

  @override
  Future<int> fetchUnreadTotal() async => 1;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    inboxQueries.add(query);
    return ChatInboxPage(
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
    );
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async {
    threadQueries.add(query);
    return ChatThreadPage(
      items: [
        ChatMessage(
          id: 'message-1',
          conversationId: 'conversation-1',
          body: 'Mensagem autorizada',
          authorName: 'Marina',
          sentAt: DateTime.utc(2026, 8, 12, 12),
          isMine: true,
          kind: 'text',
          receipt: const ChatMessageReceipt(
            isMine: true,
            recipientCount: 3,
            deliveredCount: 3,
            readCount: 2,
          ),
        ),
      ],
    );
  }

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
    if (denySend) {
      throw const ChatUnauthorizedException();
    }
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

  @override
  Future<ChatMessage> editMessage(ChatEditMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

  @override
  Future<ChatMessageRevocation> revokeMessage(ChatRevokeMessageCommand command) =>
      Future<ChatMessageRevocation>.error(const ChatFailureException());
}
