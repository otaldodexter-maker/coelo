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
    final group = controller.groupConversations.single;
    expect(group.title, 'Rede de acolhimento');
    expect(group.kind, ChatContextKind.conversationGroup);
    expect(group.facets, {ChatAudience.institutional, ChatAudience.people});
    expect(group.members.map((item) => item.institution).toSet(), {
      'Coelo',
      'Centro Horizonte',
      'Instituto Aurora',
    });

    controller.deleteGroup(group.id);
    expect(controller.conversations.any((item) => item.id == group.id), isFalse);
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

  test('manual group starts in Grupos and is not pinned', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller.createGroup('Equipe', {'aurora', 'marina'});

    final group = controller.groupConversations.single;
    expect(group.title, 'Equipe');
    expect(controller.pinnedIds, isNot(contains(group.id)));
    expect(controller.regularConversations.map((item) => item.id), isNot(contains(group.id)));
  });

  test('reorders only explicitly pinned conversations and leaves unpinned order unchanged', () {
    final controller = SuperadminChatController(superadminChatConversations);
    final unpinnedBefore = controller.unpinnedConversations.map((item) => item.id).toList();

    controller
      ..togglePinned('girassol')
      ..togglePinned('cambui')
      ..movePinned('cambui', 0);

    expect(controller.pinnedConversations.map((item) => item.id), ['cambui', 'girassol']);
    expect(controller.unpinnedConversations.map((item) => item.id), unpinnedBefore.skip(2));
  });

  test('empty, red, yellow, and green flags are independent from pinning and order', () {
    final controller = SuperadminChatController(superadminChatConversations)
      ..togglePinned('girassol')
      ..togglePinned('cambui')
      ..movePinned('cambui', 0);
    final pinnedBefore = controller.pinnedConversations.map((item) => item.id).toList();
    final unpinnedBefore = controller.unpinnedConversations.map((item) => item.id).toList();

    expect(controller.flagFor('girassol'), ChatFlag.none);
    controller
      ..setFlag('girassol', ChatFlag.red)
      ..setFlag('cambui', ChatFlag.yellow)
      ..setFlag('natacao', ChatFlag.green)
      ..setFlag('marina', ChatFlag.none);

    expect(controller.flagFor('girassol'), ChatFlag.red);
    expect(controller.flagFor('cambui'), ChatFlag.yellow);
    expect(controller.flagFor('natacao'), ChatFlag.green);
    expect(controller.flagFor('marina'), ChatFlag.none);
    expect(controller.pinnedConversations.map((item) => item.id), pinnedBefore);
    expect(controller.unpinnedConversations.map((item) => item.id), unpinnedBefore);
  });

  test('selecting Lia and Theo starts one child-context conversation for each child', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller.startConversations(
      contextIds: {'child-lia', 'child-theo'},
      body: 'Olá',
      attachments: const {},
    );

    final childThreads = controller.conversations
        .where((item) => item.kind == ChatContextKind.child)
        .toList();
    expect(childThreads, hasLength(2));
    expect(childThreads.map((item) => item.childContextId).toSet(), {'child-lia', 'child-theo'});
    expect(childThreads.every((item) => item.messages.last.author == 'Superadmin'), isTrue);
  });

  test('child threads identify authorized guardians as the actual message authors', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller.startConversations(contextIds: {'child-lia'}, body: 'Olá', attachments: const {});

    final childThread = controller.conversations.singleWhere(
      (item) => item.childContextId == 'child-lia',
    );
    expect(childThread.members.map((item) => item.id).toSet(), {'paula', 'renata'});
    expect(
      childThread.messages.where((item) => !item.sentByMe).map((item) => item.author),
      everyElement(isIn({'Paula Souza', 'Renata Lima'})),
    );
  });

  test('manual group includes Superadmin as an accepted administrator', () {
    final controller = SuperadminChatController(superadminChatConversations);

    controller.createGroup('Equipe', {'aurora'});

    final creator = controller.groupConversations.single.members.singleWhere(
      (item) => item.id == 'superadmin',
    );
    expect(creator.groupRole, ChatGroupMemberRole.admin);
    expect(creator.invitationStatus, ChatGroupInvitationStatus.accepted);
  });

  test('inviting a context from another hierarchy creates a pending member', () {
    final controller = SuperadminChatController(superadminChatConversations)
      ..createGroup('Equipe', {'aurora'});
    final groupId = controller.groupConversations.single.id;

    controller.inviteToGroup(groupId, {'marina'});

    final invited = controller.groupConversations.single.members.singleWhere(
      (item) => item.id == 'marina',
    );
    expect(invited.groupRole, ChatGroupMemberRole.member);
    expect(invited.invitationStatus, ChatGroupInvitationStatus.pending);
  });

  test('an administrator can promote a member and then leave the group', () {
    final controller = SuperadminChatController(superadminChatConversations)
      ..createGroup('Equipe', {'aurora'});
    final groupId = controller.groupConversations.single.id;

    expect(controller.promoteMember(groupId, 'aurora'), isTrue);
    expect(controller.promoteAndLeave(groupId, 'aurora'), isTrue);

    final group = controller.groupConversations.single;
    expect(group.members.map((item) => item.id), isNot(contains('superadmin')));
    expect(
      group.members.singleWhere((item) => item.id == 'aurora').groupRole,
      ChatGroupMemberRole.admin,
    );
  });

  test('a common member can leave but the final administrator must promote before leaving', () {
    final controller = SuperadminChatController(superadminChatConversations)
      ..createGroup('Equipe', {'aurora'});
    final groupId = controller.groupConversations.single.id;

    expect(controller.leaveGroup(groupId, 'aurora'), isTrue);
    expect(controller.leaveGroup(groupId, 'superadmin'), isFalse);
    expect(
      controller.groupConversations.single.members.map((item) => item.id),
      contains('superadmin'),
    );
  });
}
