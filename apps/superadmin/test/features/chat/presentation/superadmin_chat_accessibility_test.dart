import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simetrico ao que foi fechado na superficie Principal.
///
/// O Chat administrativo tinha UM caso de 200 por cento, so em 375px, afirmando
/// apenas que o composer existia. As larguras largas, onde a composicao vira
/// duas colunas com inbox e thread lado a lado, nao tinham nenhuma prova de
/// escala de texto — e e justamente ali que texto dobrado costuma estourar.
/// Tambem faltava alvo de toque e nome acessivel.
void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('stays usable at 200 percent text scale at ${width.toInt()}px', (tester) async {
      await _pump(tester, width: width, textScale: 2);

      expect(tester.takeException(), isNull, reason: 'largura $width');
      // Texto dobrado nao pode tirar da tela o que permite ler e responder.
      expect(find.byKey(const Key('superadmin-chat-composer-field')), findsOneWidget);
      expect(find.byKey(const Key('superadmin-chat-send')), findsOneWidget);
    });
  }

  testWidgets('the send target meets the AA target size across breakpoints', (tester) async {
    for (final width in [375.0, 1440.0]) {
      await _pump(tester, width: width);
      final size = tester.getSize(find.byKey(const Key('superadmin-chat-send')));
      // WCAG 2.2 AA, criterio 2.5.8: alvo de no minimo 24 por 24 CSS pixels.
      expect(size.height, greaterThanOrEqualTo(24), reason: 'largura $width, altura ${size.height}');
      expect(size.width, greaterThanOrEqualTo(24), reason: 'largura $width, largura ${size.width}');
    }
  });

  testWidgets('the send control carries an accessible name, not only an icon', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, width: 1440);

    // Um controle so com icone nao e anunciado por leitor de tela. O nome pode
    // vir de tooltip, label semantico ou texto visivel; o teste afirma que ha
    // algum, sem exigir qual.
    final semantics = tester.getSemantics(find.byKey(const Key('superadmin-chat-send')));
    expect(
      semantics.label.trim().isNotEmpty || semantics.tooltip.trim().isNotEmpty,
      isTrue,
      reason: 'o controle de envio precisa de nome acessivel',
    );
    // O descarte precisa acontecer no corpo do teste: a verificacao de handles
    // do flutter_test roda antes dos addTearDown.
    handle.dispose();
  });
}

Future<void> _pump(WidgetTester tester, {required double width, double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: SuperadminChatPage(
        logout: unavailableSuperadminLogout,
        chatRepository: _Repository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _Repository implements ChatRepository {
  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async => ChatInboxPage(
    totalUnread: 0,
    items: [
      ChatConversationSummary(
        id: 'conversation-1',
        title: 'Turma Girassol',
        preview: 'Mensagem autorizada',
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
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());

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
