import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A superficie Principal tinha caso para os seis estados do inbox; a
/// administrativa exercitava dois. Os seis existem no codigo, entao a diferenca
/// era de cobertura e nao de implementacao — e cobertura ausente nao e estado
/// neutro.
///
/// O que estes casos afirmam nao e o texto de cada painel, e sim o que separa um
/// estado do outro na pratica: se o operador tem uma saida e QUAL saida. Um
/// painel sem acao onde deveria haver retentativa, ou com retentativa onde nao
/// ha o que tentar, e o defeito que interessa.
void main() {
  testWidgets('an empty authorised inbox offers a refresh, not a retry', (tester) async {
    await _pump(tester, _StatefulRepository(mode: _Mode.empty));
    expect(find.text('Ainda não há conversas'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);
  });

  testWidgets('a search with no results offers to clear the search', (tester) async {
    final repository = _StatefulRepository(mode: _Mode.noResults);
    await _pump(tester, repository);
    final field = find.descendant(
      of: find.byKey(const Key('superadmin-chat-search')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'termo improvavel');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Vazio por BUSCA e diferente de vazio por ausencia: a saida util aqui e
    // limpar o filtro, nao recarregar o mesmo filtro.
    expect(find.text('Nenhuma conversa encontrada'), findsOneWidget);
    expect(find.text('Limpar busca'), findsOneWidget);
  });

  testWidgets('a denial offers no retry, because retrying cannot help', (tester) async {
    await _pump(tester, _StatefulRepository(mode: _Mode.unauthorized));
    expect(find.text('Acesso nao autorizado'), findsOneWidget);
    // Oferecer "tentar novamente" numa negacao seria prometer que insistir
    // resolve. Nao resolve, e o operador ficaria repetindo.
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('an empty thread by absence does not look like one by permission', (tester) async {
    await _pump(tester, _StatefulRepository(mode: _Mode.emptyThread));

    // Conversa autorizada e sem mensagens continua operavel: o composer fica,
    // porque nao ha nada errado em ser a primeira mensagem. Se este estado
    // parecesse negacao, o operador concluiria que perdeu acesso a uma conversa
    // que ele pode usar.
    expect(find.text('Turma Girassol'), findsWidgets);
    expect(find.byKey(const Key('superadmin-chat-composer-field')), findsOneWidget);
    expect(find.text('Acesso nao autorizado'), findsNothing);
  });

  testWidgets('offline and failure are distinct states, both with a retry', (tester) async {
    await _pump(tester, _StatefulRepository(mode: _Mode.offline));
    expect(find.text('Sem conexao'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await _pump(tester, _StatefulRepository(mode: _Mode.failure));
    // Falha generica nao pode se apresentar como falta de conexao: a acao do
    // operador e diferente em cada caso.
    expect(find.text('Nao foi possivel carregar'), findsOneWidget);
    expect(find.text('Sem conexao'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, ChatRepository repository) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: SuperadminChatPage(logout: unavailableSuperadminLogout, chatRepository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

enum _Mode { empty, noResults, unauthorized, offline, failure, emptyThread }

final class _StatefulRepository implements ChatRepository {
  @override
  Future<ChatGroupCreated> createGroup(ChatCreateGroupCommand command) =>
      Future<ChatGroupCreated>.error(const ChatFailureException());
  _StatefulRepository({required this.mode});

  final _Mode mode;

  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) async {
    switch (mode) {
      case _Mode.unauthorized:
        throw const ChatUnauthorizedException();
      case _Mode.offline:
        throw const ChatOfflineException();
      case _Mode.failure:
        throw const ChatFailureException();
      case _Mode.emptyThread:
        return ChatInboxPage(
          totalUnread: 0,
          items: [
            ChatConversationSummary(
              id: 'conversation-1',
              title: 'Turma Girassol',
              preview: '',
              contextLabel: 'Unidade Cambui',
              kind: 'group',
              unreadCount: 0,
              updatedAt: DateTime.utc(2026, 8, 12, 12),
              isReadOnly: false,
            ),
          ],
        );
      case _Mode.empty:
      case _Mode.noResults:
        // Sem busca a lista tem conteudo; com busca ela volta vazia, que e o
        // que distingue "sem resultados" de "ainda nao ha conversas".
        if (mode == _Mode.noResults && query.search.trim().isEmpty) {
          return ChatInboxPage(
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
        }
        return const ChatInboxPage(items: [], totalUnread: 0);
    }
  }

  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) async =>
      const ChatThreadPage(items: []);

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
