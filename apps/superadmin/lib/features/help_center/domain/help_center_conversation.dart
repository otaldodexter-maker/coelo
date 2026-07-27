enum HelpCenterMessageAuthor { user, assistant }

final class HelpCenterMessage {
  const HelpCenterMessage({required this.id, required this.author, required this.content});

  final String id;
  final HelpCenterMessageAuthor author;
  final String content;
}

final class HelpCenterConversation {
  HelpCenterConversation({
    required this.id,
    required this.title,
    List<HelpCenterMessage> messages = const [],
  }) : messages = List.unmodifiable(messages);

  final String id;
  final String title;
  final List<HelpCenterMessage> messages;

  bool get isEmpty => messages.isEmpty;

  HelpCenterConversation copyWith({String? title, List<HelpCenterMessage>? messages}) {
    return HelpCenterConversation(
      id: id,
      title: title ?? this.title,
      messages: List.unmodifiable(messages ?? this.messages),
    );
  }
}
