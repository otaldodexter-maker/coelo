import 'package:coelo_superadmin/app/dev_menu/development_chat_repository.dart';
import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('searches deterministic conversations by title, preview and context', () async {
    final repository = DevelopmentChatRepository.content();

    expect(
      (await repository.fetchInbox(const ChatInboxQuery(search: 'girassol'))).items.single.title,
      'Turma Girassol',
    );
    expect(
      (await repository.fetchInbox(const ChatInboxQuery(search: 'materiais'))).items.single.title,
      'Robótica',
    );
    expect(
      (await repository.fetchInbox(
        const ChatInboxQuery(search: 'unidade centro'),
      )).items.single.title,
      'Turma Girassol',
    );
    expect(
      (await repository.fetchInbox(const ChatInboxQuery(search: 'inexistente'))).items,
      isEmpty,
    );
  });

  test('keeps send and read state inside the dev session', () async {
    final repository = DevelopmentChatRepository.content();
    const conversationId = 'dev-conversation-turma-girassol';

    final sent = await repository.sendMessage(
      const ChatSendMessageCommand(
        conversationId: conversationId,
        body: '  Mensagem de teste  ',
        idempotencyKey: 'dev-send-1',
      ),
    );
    expect(sent.body, 'Mensagem de teste');
    expect(
      (await repository.fetchThread(
        const ChatThreadQuery(conversationId: conversationId),
      )).items.last.id,
      sent.id,
    );

    await repository.markRead(conversationId: conversationId, upToMessageId: sent.id);
    expect(await repository.fetchUnreadTotal(), 0);
  });
}
