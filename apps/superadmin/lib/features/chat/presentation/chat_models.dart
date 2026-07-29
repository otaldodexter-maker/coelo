enum ChatAudience { all, institutional, people }

enum ChatContextKind { institution, unit, group, activity, person, conversationGroup }

enum ChatMessageKind { text, emoji, audio, image }

enum ChatDeliveryState { sent, delivered, read }

enum ChatAttachmentKind { file, image, video }

enum ChatFilterKind { state, institution, unit, group, activity, role, child }

final class SuperadminChatMetric {
  const SuperadminChatMetric(this.label, this.value);

  final String label;
  final int value;
}

final class SuperadminChatRoleView {
  const SuperadminChatRoleView({
    required this.label,
    required this.context,
    required this.metrics,
    this.children = const [],
  });

  final String label;
  final String context;
  final List<String> children;
  final List<SuperadminChatMetric> metrics;
}

final class SuperadminChatMember {
  const SuperadminChatMember({
    required this.id,
    required this.name,
    required this.role,
    required this.institution,
    required this.origin,
    required this.facets,
  });

  final String id;
  final String name;
  final String role;
  final String institution;
  final String origin;
  final Set<ChatAudience> facets;
}

final class SuperadminChatBulkDelivery {
  const SuperadminChatBulkDelivery({
    required this.recipientIds,
    required this.body,
    required this.attachments,
    required this.isPrivate,
  });

  final Set<String> recipientIds;
  final String body;
  final Set<ChatAttachmentKind> attachments;
  final bool isPrivate;
}

final class SuperadminChatMessage {
  const SuperadminChatMessage({
    required this.id,
    required this.body,
    required this.time,
    required this.sentByMe,
    this.author,
    this.context,
    this.kind = ChatMessageKind.text,
    this.delivery = ChatDeliveryState.sent,
  });

  final String id;
  final String body;
  final String time;
  final bool sentByMe;
  final String? author;
  final String? context;
  final ChatMessageKind kind;
  final ChatDeliveryState delivery;
}

final class SuperadminChatConversation {
  const SuperadminChatConversation({
    required this.id,
    required this.title,
    required this.initials,
    required this.preview,
    required this.timestamp,
    required this.context,
    required this.kind,
    required this.metrics,
    required this.messages,
    this.state,
    this.institution,
    this.unit,
    this.group,
    this.role,
    this.unreadCount = 0,
    this.isGroup = false,
    this.facets = const {ChatAudience.institutional},
    this.location,
    this.typeLabel,
    this.planLabel,
    this.children = const [],
    this.roleViews = const [],
    this.members = const [],
  });

  final String id;
  final String title;
  final String initials;
  final String preview;
  final String timestamp;
  final String context;
  final ChatContextKind kind;
  final List<SuperadminChatMetric> metrics;
  final List<SuperadminChatMessage> messages;
  final String? state;
  final String? institution;
  final String? unit;
  final String? group;
  final String? role;
  final int unreadCount;
  final bool isGroup;
  final Set<ChatAudience> facets;
  final String? location;
  final String? typeLabel;
  final String? planLabel;
  final List<String> children;
  final List<SuperadminChatRoleView> roleViews;
  final List<SuperadminChatMember> members;

  SuperadminChatConversation copyWith({
    String? preview,
    String? timestamp,
    List<SuperadminChatMessage>? messages,
  }) {
    return SuperadminChatConversation(
      id: id,
      title: title,
      initials: initials,
      preview: preview ?? this.preview,
      timestamp: timestamp ?? this.timestamp,
      context: context,
      kind: kind,
      metrics: metrics,
      messages: messages ?? this.messages,
      state: state,
      institution: institution,
      unit: unit,
      group: group,
      role: role,
      unreadCount: unreadCount,
      isGroup: isGroup,
      facets: facets,
      location: location,
      typeLabel: typeLabel,
      planLabel: planLabel,
      children: children,
      roleViews: roleViews,
      members: members,
    );
  }
}

final class SuperadminChatContextOption {
  const SuperadminChatContextOption({
    required this.id,
    required this.label,
    required this.kind,
    this.subtitle,
    this.children = const [],
  });

  final String id;
  final String label;
  final ChatContextKind kind;
  final String? subtitle;
  final List<SuperadminChatContextOption> children;
}
