import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `chat.attach` esta bloqueado pela plataforma comum de midia: nao existe
/// funcao que insira em chat_attachment_metadata, o gateway de chat-media nao
/// existe, e o catalogo privado de R2 nao tem um kind de chat. Enquanto isso, a
/// tela mantem as afordancias de anexo com indisponibilidade honesta.
///
/// O contrato da Etapa 2 exige exatamente isso — botao visivel, indisponibilidade
/// honesta, sem picker, parser, job nem persistencia — e nada afirmava esse
/// comportamento. Sem prova, alguem pode remover a mensagem, ou pior, ligar um
/// picker que nao tem para onde enviar, e nenhum teste reclama.
void main() {
  testWidgets('the attachment affordances stay visible and refuse honestly', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const ['Gravar áudio', 'Adicionar imagem']) {
      // A afordancia continua VISIVEL: esconder seria fingir que a acao nao
      // existe no produto, e o contrato pede indisponibilidade honesta.
      final action = find.byTooltip(label).hitTestable();
      expect(action, findsOneWidget, reason: 'a acao "$label" precisa continuar visivel');

      await tester.tap(action);
      await tester.pumpAndSettle();

      // E ela DIZ por que nao pode, em vez de nao fazer nada em silencio.
      expect(find.text('Anexos aguardam o gateway R2 autorizado.'), findsOneWidget);
      expect(
        repository.sent,
        isEmpty,
        reason: 'nenhuma mensagem pode sair por causa de um toque em anexo',
      );
    }
  });
}

final class _Repository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
  final List<ChatSendMessageCommand> sent = [];

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 0,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Ultima mensagem',
        contextLabel: 'Unidade Cambui',
        kind: 'group',
        unreadCount: 0,
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
  Future<void> markRead({required String conversationId, required String upToMessageId}) async {}

  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) async {
    sent.add(command);
    throw const ChatFailureException();
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
