enum ChatAudience { contexts, people }

enum ChatContextKind { institution, unit, group, activity, person }

enum ChatMessageKind { text, emoji, audio, image }

enum ChatDeliveryState { sent, delivered, read }

final class SuperadminChatMetric {
  const SuperadminChatMetric(this.label, this.value);

  final String label;
  final int value;
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
