import 'package:flutter/foundation.dart';

import 'chat_models.dart';

final class SuperadminChatController extends ChangeNotifier {
  SuperadminChatController(Iterable<SuperadminChatConversation> conversations)
    : _conversations = List.of(conversations);

  final List<SuperadminChatConversation> _conversations;
  final Map<ChatFilterKind, Set<String>> _filters = {};
  final Set<String> _selectedRecipientIds = {};
  final Set<String> _pinnedIds = {};
  String _selectedId = 'girassol';
  String _search = '';
  ChatAudience _audience = ChatAudience.all;
  int _sequence = 0;
  String? feedback;
  SuperadminChatBulkDelivery? lastBulkDelivery;

  List<SuperadminChatConversation> get conversations => List.unmodifiable(_conversations);
  Set<String> get selectedRecipientIds => Set.unmodifiable(_selectedRecipientIds);
  Set<String> get pinnedIds => Set.unmodifiable(_pinnedIds);
  ChatAudience get audience => _audience;
  String get search => _search;
  Map<ChatFilterKind, Set<String>> get activeFilters => Map.unmodifiable({
    for (final entry in _filters.entries) entry.key: Set.unmodifiable(entry.value),
  });
  Set<String> get activeFilterValues => {for (final values in _filters.values) ...values};
  List<String> get visibleFilters => activeFilterValues.take(2).toList(growable: false);
  int get hiddenFilterCount => (activeFilterValues.length - 2).clamp(0, activeFilterValues.length);

  SuperadminChatConversation get selectedConversation => _conversations.firstWhere(
    (item) => item.id == _selectedId,
    orElse: () => _conversations.first,
  );

  List<SuperadminChatConversation> get visibleConversations {
    final query = _search.trim().toLowerCase();
    return _conversations
        .where((item) {
          final matchesAudience = _audience == ChatAudience.all || item.facets.contains(_audience);
          final matchesSearch =
              query.isEmpty ||
              '${item.title} ${item.preview} ${item.context}'.toLowerCase().contains(query);
          return matchesAudience && matchesSearch && _matchesFilters(item, _filters);
        })
        .toList(growable: false);
  }

  List<SuperadminChatConversation> get pinnedConversations =>
      visibleConversations.where((item) => _pinnedIds.contains(item.id)).toList(growable: false);

  List<SuperadminChatConversation> get unpinnedConversations =>
      visibleConversations.where((item) => !_pinnedIds.contains(item.id)).toList(growable: false);

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setAudience(ChatAudience value) {
    _audience = value;
    _filters.removeWhere((kind, _) => !_filterKindsForAudience(value).contains(kind));
    notifyListeners();
  }

  void applyFilters(Map<ChatFilterKind, Set<String>> draft) {
    final next = <ChatFilterKind, Set<String>>{};
    for (final kind in _filterOrder) {
      final requested = draft[kind];
      if (requested == null || requested.isEmpty) continue;
      final accepted = requested.where((value) {
        return _conversations.any(
          (item) =>
              _matchesAudience(item) &&
              _valueFor(item, kind) == value &&
              _matchesFilters(item, next),
        );
      }).toSet();
      if (accepted.isNotEmpty) next[kind] = accepted;
    }
    _filters
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void toggleFilter(String value) {
    final kind = _inferFilterKind(value);
    final draft = {for (final entry in _filters.entries) entry.key: Set<String>.of(entry.value)};
    final values = draft.putIfAbsent(kind, () => {});
    values.contains(value) ? values.remove(value) : values.add(value);
    applyFilters(draft);
  }

  void clearFilters() {
    _filters.clear();
    notifyListeners();
  }

  void togglePinned(String id) {
    if (!_conversations.any((item) => item.id == id)) return;
    _pinnedIds.contains(id) ? _pinnedIds.remove(id) : _pinnedIds.add(id);
    notifyListeners();
  }

  void selectConversation(String id) {
    if (_conversations.any((item) => item.id == id)) {
      _selectedId = id;
      notifyListeners();
    }
  }

  void toggleRecipient(String id) {
    _selectedRecipientIds.contains(id)
        ? _selectedRecipientIds.remove(id)
        : _selectedRecipientIds.add(id);
    notifyListeners();
  }

  void selectAllRecipients(Iterable<String> ids) {
    _selectedRecipientIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void clearRecipients() {
    _selectedRecipientIds.clear();
    notifyListeners();
  }

  void createGroup(String name, Set<String> recipientIds) {
    final normalized = name.trim();
    final selected = _conversations
        .where((item) => recipientIds.contains(item.id))
        .toList(growable: false);
    if (normalized.isEmpty || selected.isEmpty) return;

    final members = [
      for (final item in selected)
        SuperadminChatMember(
          id: item.id,
          name: item.title,
          role: item.role ?? _kindLabel(item.kind),
          institution: item.institution ?? 'Coelo',
          origin: item.context,
          facets: item.facets,
        ),
    ];
    final institutions = members.map((item) => item.institution).toSet();
    final facets = {for (final member in members) ...member.facets};
    final id = 'local-group-${++_sequence}';
    _conversations.insert(
      0,
      SuperadminChatConversation(
        id: id,
        title: normalized,
        initials: _initials(normalized),
        preview: '${members.length} participantes Â· grupo simulado',
        timestamp: 'Agora',
        context: '${institutions.length} instituiÃ§Ãµes Â· DemonstraÃ§Ã£o local',
        kind: ChatContextKind.conversationGroup,
        facets: facets,
        metrics: [
          SuperadminChatMetric('Participantes', members.length),
          SuperadminChatMetric('InstituiÃ§Ãµes', institutions.length),
        ],
        messages: const [],
        members: members,
        isGroup: true,
      ),
    );
    _selectedId = id;
    _pinnedIds.add(id);
    feedback = 'Grupo coletivo criado apenas nesta demonstraÃ§Ã£o local.';
    notifyListeners();
  }

  void deleteGroup(String id) {
    final index = _conversations.indexWhere(
      (item) => item.id == id && item.kind == ChatContextKind.conversationGroup,
    );
    if (index < 0) return;
    _conversations.removeAt(index);
    _pinnedIds.remove(id);
    if (_conversations.isNotEmpty && _selectedId == id) {
      _selectedId = _conversations.first.id;
    }
    feedback = 'Grupo excluÃ­do apenas desta demonstraÃ§Ã£o local.';
    notifyListeners();
  }

  void deleteConversation(String id) => deleteGroup(id);

  void simulateBulkSend({
    required Set<String> recipientIds,
    required String body,
    required Set<ChatAttachmentKind> attachments,
  }) {
    if (recipientIds.isEmpty || (body.trim().isEmpty && attachments.isEmpty)) return;
    lastBulkDelivery = SuperadminChatBulkDelivery(
      recipientIds: Set.unmodifiable(recipientIds),
      body: body.trim(),
      attachments: Set.unmodifiable(attachments),
      isPrivate: true,
    );
    feedback = '${recipientIds.length} entregas privadas simuladas. Nada foi enviado.';
    notifyListeners();
  }

  void startSingleConversation({
    required String recipientId,
    required String body,
    required Set<ChatAttachmentKind> attachments,
  }) {
    selectConversation(recipientId);
    if (body.trim().isNotEmpty) sendText(body);
    for (final attachment in attachments) {
      sendAttachment(
        attachment == ChatAttachmentKind.image ? ChatMessageKind.image : ChatMessageKind.text,
      );
    }
    feedback = 'Conversa individual simulada. Nada foi enviado.';
    notifyListeners();
  }

  void sendText(String value) {
    final body = value.trim();
    if (body.isEmpty) return;
    _appendMessage(ChatMessageKind.text, body);
  }

  void sendEmoji(String emoji) => _appendMessage(ChatMessageKind.emoji, emoji);

  void sendAttachment(ChatMessageKind kind) {
    assert(
      kind == ChatMessageKind.audio ||
          kind == ChatMessageKind.image ||
          kind == ChatMessageKind.text,
    );
    _appendMessage(kind, switch (kind) {
      ChatMessageKind.audio => 'Mensagem de Ã¡udio Â· 0:08',
      ChatMessageKind.image => 'Imagem anexada',
      _ => 'Arquivo anexado Â· demonstraÃ§Ã£o local',
    });
  }

  void _appendMessage(ChatMessageKind kind, String body) {
    final index = _conversations.indexWhere((item) => item.id == _selectedId);
    if (index < 0) return;
    final current = _conversations[index];
    final message = SuperadminChatMessage(
      id: 'local-message-${++_sequence}',
      body: body,
      time: 'Agora',
      sentByMe: true,
      author: 'Superadmin',
      context: 'DemonstraÃ§Ã£o local',
      kind: kind,
      delivery: ChatDeliveryState.delivered,
    );
    _conversations[index] = current.copyWith(
      preview: body,
      timestamp: 'Agora',
      messages: [...current.messages, message],
    );
    feedback = 'Mensagem simulada. Nada foi enviado.';
    notifyListeners();
  }

  bool _matchesAudience(SuperadminChatConversation item) {
    return _audience == ChatAudience.all || item.facets.contains(_audience);
  }
}

const _filterOrder = [
  ChatFilterKind.state,
  ChatFilterKind.institution,
  ChatFilterKind.unit,
  ChatFilterKind.group,
  ChatFilterKind.activity,
  ChatFilterKind.role,
  ChatFilterKind.child,
];

Set<ChatFilterKind> _filterKindsForAudience(ChatAudience audience) => switch (audience) {
  ChatAudience.all => ChatFilterKind.values.toSet(),
  ChatAudience.institutional => {
    ChatFilterKind.state,
    ChatFilterKind.institution,
    ChatFilterKind.unit,
    ChatFilterKind.group,
    ChatFilterKind.activity,
  },
  ChatAudience.people => {ChatFilterKind.institution, ChatFilterKind.role, ChatFilterKind.child},
};

bool _matchesFilters(SuperadminChatConversation item, Map<ChatFilterKind, Set<String>> filters) {
  for (final entry in filters.entries) {
    if (entry.value.isEmpty) continue;
    final actual = _valueFor(item, entry.key);
    if (actual == null || !entry.value.contains(actual)) return false;
  }
  return true;
}

String? _valueFor(SuperadminChatConversation item, ChatFilterKind kind) => switch (kind) {
  ChatFilterKind.state => item.state,
  ChatFilterKind.institution => item.institution,
  ChatFilterKind.unit => item.unit,
  ChatFilterKind.group => item.group,
  ChatFilterKind.activity =>
    item.kind == ChatContextKind.activity ? item.title.replaceFirst('Atividade ', '') : null,
  ChatFilterKind.role => item.role,
  ChatFilterKind.child => item.children.firstOrNull,
};

ChatFilterKind _inferFilterKind(String value) {
  if (RegExp(r'^[A-Z]{2}$').hasMatch(value)) return ChatFilterKind.state;
  if (value.startsWith('Unidade ')) return ChatFilterKind.unit;
  if (value.startsWith('Turma ') || value.startsWith('Grupo ')) {
    return ChatFilterKind.group;
  }
  if (value.endsWith('ores') || value.endsWith('Ã¡veis') || value == 'Outros') {
    return ChatFilterKind.role;
  }
  return ChatFilterKind.institution;
}

String _kindLabel(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => 'InstituiÃ§Ã£o',
  ChatContextKind.unit => 'Unidade',
  ChatContextKind.group => 'Grupo/Turma',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
  ChatContextKind.conversationGroup => 'Grupo de conversa',
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
