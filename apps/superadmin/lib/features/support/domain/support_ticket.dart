import 'support_requester_context.dart';

enum SupportTicketStatus { newRequest, inProgress, waitingRequester, completed }

enum SupportMessageAuthor { support, requester }

enum SupportMessageDeliveryState { sent, delivered, read }

final class SupportAttachment {
  const SupportAttachment({required this.id, required this.fileName, this.byteLength});

  final String id;
  final String fileName;
  final int? byteLength;
}

final class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
    this.deliveryState = SupportMessageDeliveryState.sent,
    this.isReadBySupport = false,
  });

  final String id;
  final SupportMessageAuthor author;
  final String text;
  final DateTime sentAt;
  final SupportMessageDeliveryState deliveryState;
  final bool isReadBySupport;

  SupportMessage copyWith({SupportMessageDeliveryState? deliveryState, bool? isReadBySupport}) {
    return SupportMessage(
      id: id,
      author: author,
      text: text,
      sentAt: sentAt,
      deliveryState: deliveryState ?? this.deliveryState,
      isReadBySupport: isReadBySupport ?? this.isReadBySupport,
    );
  }
}

final class SupportTicket {
  SupportTicket({
    required this.id,
    required this.subject,
    required this.menu,
    required this.screen,
    required this.description,
    required this.requester,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.requesterContext,
    this.ownerId,
    Set<String> collaboratorIds = const {},
    List<SupportAttachment> attachments = const [],
    List<SupportMessage> messages = const [],
  }) : collaboratorIds = Set.unmodifiable(collaboratorIds),
       attachments = List.unmodifiable(attachments),
       messages = List.unmodifiable(messages);

  final String id;
  final String subject;
  final String menu;
  final String screen;
  final String description;
  final String requester;
  final SupportRequesterContext? requesterContext;
  final String? ownerId;
  final Set<String> collaboratorIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SupportTicketStatus status;
  final List<SupportAttachment> attachments;
  final List<SupportMessage> messages;

  SupportTicket copyWith({
    DateTime? updatedAt,
    SupportTicketStatus? status,
    SupportRequesterContext? requesterContext,
    String? ownerId,
    bool clearOwner = false,
    Set<String>? collaboratorIds,
    List<SupportAttachment>? attachments,
    List<SupportMessage>? messages,
  }) {
    return SupportTicket(
      id: id,
      subject: subject,
      menu: menu,
      screen: screen,
      description: description,
      requester: requester,
      requesterContext: requesterContext ?? this.requesterContext,
      ownerId: clearOwner ? null : ownerId ?? this.ownerId,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      messages: messages ?? this.messages,
    );
  }
}

final class SupportFilters {
  SupportFilters({
    this.search = '',
    Set<SupportTicketStatus> statuses = const {},
    Set<String> menus = const {},
    Set<String> screens = const {},
    Set<String> assigneeIds = const {},
    this.unreadOnly = false,
  }) : statuses = Set.unmodifiable(statuses),
       menus = Set.unmodifiable(menus),
       screens = Set.unmodifiable(screens),
       assigneeIds = Set.unmodifiable(assigneeIds);

  const SupportFilters._empty()
    : search = '',
      statuses = const {},
      menus = const {},
      screens = const {},
      assigneeIds = const {},
      unreadOnly = false;

  static const empty = SupportFilters._empty();

  final String search;
  final Set<SupportTicketStatus> statuses;
  final Set<String> menus;
  final Set<String> screens;
  final Set<String> assigneeIds;
  final bool unreadOnly;

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      menus.isNotEmpty ||
      screens.isNotEmpty ||
      assigneeIds.isNotEmpty ||
      unreadOnly;

  @override
  bool operator ==(Object other) {
    return other is SupportFilters &&
        other.search == search &&
        _setsEqual(other.statuses, statuses) &&
        _setsEqual(other.menus, menus) &&
        _setsEqual(other.screens, screens) &&
        _setsEqual(other.assigneeIds, assigneeIds) &&
        other.unreadOnly == unreadOnly;
  }

  @override
  int get hashCode => Object.hash(
    search,
    _setHash(statuses),
    _setHash(menus),
    _setHash(screens),
    _setHash(assigneeIds),
    unreadOnly,
  );
}

final class SupportReportDraft {
  const SupportReportDraft({
    required this.menu,
    required this.screen,
    required this.subject,
    required this.description,
    required this.requester,
    this.includeDemoAttachment = false,
  });

  final String menu;
  final String screen;
  final String subject;
  final String description;
  final String requester;
  final bool includeDemoAttachment;
}

bool _setsEqual<T>(Set<T> first, Set<T> second) {
  return first.length == second.length && first.containsAll(second);
}

int _setHash<T>(Set<T> values) {
  return values.fold(0, (hash, value) => hash ^ value.hashCode);
}
