import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/principal_chat/presentation/principal_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A superficie Principal de Chat nasceu com prova de estados, de paginacao e
/// de largura, mas sem nenhuma prova de escala de texto nem de alvo de toque.
/// Ausencia de cobertura nao e estado neutro: a superficie administrativa
/// vizinha tem o caso de 200 por cento e esta nao tinha.
///
/// A spec 050 e o design system pedem WCAG 2.2 AA e alvos de toque adequados.
/// O criterio AA de tamanho de alvo e 24 CSS pixels; o minimo interativo do
/// Material, 48, e mais folgado e e o que o resto do app pratica. Estes casos
/// afirmam o criterio AA, que e o obrigatorio, para nao transformar uma
/// preferencia de plataforma em falha de acessibilidade.
void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('stays usable at 200 percent text scale at ${width.toInt()}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester, textScale: 2);

      // Texto dobrado nao pode estourar a composicao nem tirar da tela o que
      // permite ler e responder.
      expect(tester.takeException(), isNull, reason: 'largura $width');
      expect(find.byKey(const Key('principal-chat-search')), findsOneWidget);
      expect(find.text('Turma Girassol'), findsWidgets);
    });
  }

  testWidgets('the conversation and send targets meet the AA target size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester);

    // Em 375px a lista da o lugar a thread ao abrir a conversa, entao o alvo
    // da conversa e medido antes do toque e o de envio depois.
    _expectTarget(tester, const ValueKey('principal-chat-conversation-conversation-1'));

    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    _expectTarget(tester, const Key('principal-chat-send'));
  });

  testWidgets('the send control carries an accessible name, not only an icon', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('principal-chat-conversation-conversation-1')));
    await tester.pumpAndSettle();

    // Um controle so com icone nao e anunciado por leitor de tela. O nome pode
    // vir de tooltip, label semantico ou texto visivel; o teste afirma que ha
    // algum, sem exigir qual.
    final semantics = tester.getSemantics(find.byKey(const Key('principal-chat-send')));
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

void _expectTarget(WidgetTester tester, Key key) {
  final size = tester.getSize(find.byKey(key));
  // WCAG 2.2 AA, criterio 2.5.8: alvo de no minimo 24 por 24 CSS pixels.
  expect(size.height, greaterThanOrEqualTo(24), reason: 'alvo $key com altura ${size.height}');
  expect(size.width, greaterThanOrEqualTo(24), reason: 'alvo $key com largura ${size.width}');
}

Future<void> _pump(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PrincipalChatPage(chatRepository: _Repository(), onBack: () {}),
    ),
  );
  await tester.pumpAndSettle();
}

final class _Repository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
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
        contextLabel: 'Escola Horizonte',
        kind: 'group',
        unreadCount: 0,
        updatedAt: DateTime.utc(2026, 9, 9, 10),
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
        sentAt: DateTime.utc(2026, 9, 9, 10),
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
