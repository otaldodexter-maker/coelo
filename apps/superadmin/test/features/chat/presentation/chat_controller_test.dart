import 'package:coelo_superadmin/features/chat/presentation/chat_controller.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts in Todos and filters conversations by institutional and people facets', () {
    final controller = SuperadminChatController(superadminChatConversations);

    expect(controller.audience, ChatAudience.all);
    expect(controller.visibleConversations.length, superadminChatConversations.length);

    controller
      ..setSearch('Paula')
      ..setAudience(ChatAudience.institutional);

    expect(controller.visibleConversations, isEmpty);

    controller.setAudience(ChatAudience.people);
    expect(controller.visibleConversations.map((item) => item.id), ['paula']);
  });

  test('applies typed filters and prunes incompatible descendants', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller.applyFilters({
      ChatFilterKind.institution: {'Centro Horizonte'},
      ChatFilterKind.unit: {'Unidade Cambuí'},
      ChatFilterKind.group: {'Turma Girassol'},
    });
    expect(controller.activeFilterValues, {'Centro Horizonte', 'Unidade Cambuí', 'Turma Girassol'});

    controller.applyFilters({
      ChatFilterKind.institution: {'Instituto Aurora'},
      ChatFilterKind.unit: {'Unidade Cambuí'},
      ChatFilterKind.group: {'Turma Girassol'},
    });
    expect(controller.activeFilterValues, {'Instituto Aurora'});
  });

  test('pins per audience and creates a visible cross-tenant conversation group', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller
      ..togglePinned('girassol')
      ..togglePinned('marina');
    expect(controller.pinnedConversations.map((item) => item.id), ['girassol', 'marina']);

    controller.setAudience(ChatAudience.institutional);
    expect(controller.pinnedConversations.map((item) => item.id), ['girassol']);

    controller.createGroup('Rede de acolhimento', {'marina', 'aurora'});
    expect(controller.conversations.first.title, 'Rede de acolhimento');
    expect(controller.conversations.first.kind, ChatContextKind.conversationGroup);
    expect(controller.conversations.first.facets, {
      ChatAudience.institutional,
      ChatAudience.people,
    });
    expect(controller.conversations.first.members.map((item) => item.institution).toSet(), {
      'Centro Horizonte',
      'Instituto Aurora',
    });

    final groupId = controller.conversations.first.id;
    controller.deleteGroup(groupId);
    expect(controller.conversations.any((item) => item.id == groupId), isFalse);
  });

  test('keeps bulk delivery private and separate from collective group history', () {
    final controller = SuperadminChatController(superadminChatConversations);
    final before = {for (final item in controller.conversations) item.id: item.messages.length};

    controller.simulateBulkSend(
      recipientIds: {'girassol', 'marina'},
      body: 'Comunicado de teste',
      attachments: {ChatAttachmentKind.file},
    );

    expect(controller.lastBulkDelivery?.recipientIds, {'girassol', 'marina'});
    expect(controller.lastBulkDelivery?.isPrivate, isTrue);
    expect(
      controller.conversations.every((item) => item.messages.length == before[item.id]),
      isTrue,
    );
    expect(controller.feedback, contains('privadas'));
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
