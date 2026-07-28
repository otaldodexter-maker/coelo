import 'package:coelo_superadmin/features/chat/presentation/chat_controller.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters inbox with search, audience and at most two visible filters', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller
      ..setSearch('Marina')
      ..setAudience(ChatAudience.contexts)
      ..toggleFilter('CE')
      ..toggleFilter('Centro Horizonte')
      ..toggleFilter('Turma Girassol');

    expect(controller.visibleConversations.map((item) => item.id), ['girassol']);
    expect(controller.visibleFilters, ['CE', 'Centro Horizonte']);
    expect(controller.hiddenFilterCount, 1);
  });

  test('selects recipients, creates and deletes simulated groups', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller.selectAllRecipients(['a', 'b', 'c']);
    expect(controller.selectedRecipientIds, {'a', 'b', 'c'});

    controller.createGroup('Equipe de acolhimento', {'a', 'b'});
    expect(controller.conversations.first.title, 'Equipe de acolhimento');
    expect(controller.conversations.first.isGroup, isTrue);

    final groupId = controller.conversations.first.id;
    controller.deleteConversation(groupId);
    expect(controller.conversations.any((item) => item.id == groupId), isFalse);
  });

  test('sends text, emoji, audio and image only to local state', () {
    final controller = SuperadminChatController(superadminChatConversations);
    final initialCount = controller.selectedConversation.messages.length;

    controller
      ..sendText('Olá')
      ..sendEmoji('🙂')
      ..sendAttachment(ChatMessageKind.audio)
      ..sendAttachment(ChatMessageKind.image);

    final messages = controller.selectedConversation.messages;
    expect(messages.length, initialCount + 4);
    expect(messages.last.kind, ChatMessageKind.image);
    expect(controller.feedback, contains('simulada'));
  });
}
