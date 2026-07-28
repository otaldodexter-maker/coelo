import 'package:flutter/foundation.dart';

import 'chat_models.dart';

final class SuperadminChatController extends ChangeNotifier {
  SuperadminChatController(Iterable<SuperadminChatConversation> conversations)
    : _conversations = List.of(conversations);

  final List<SuperadminChatConversation> _conversations;
  final Set<String> _filters = {};
  final Set<String> _selectedRecipientIds = {};
  String _selectedId = 'girassol';
  String _search = '';
  ChatAudience _audience = ChatAudience.contexts;
  int _sequence = 0;
  String? feedback;

  List<SuperadminChatConversation> get conversations => List.unmodifiable(_conversations);
  Set<String> get selectedRecipientIds => Set.unmodifiable(_selectedRecipientIds);
  ChatAudience get audience => _audience;
  String get search => _search;
  Set<String> get activeFilters => Set.unmodifiable(_filters);
  List<String> get visibleFilters => _filters.take(2).toList(growable: false);
  int get hiddenFilterCount => (_filters.length - 2).clamp(0, _filters.length);

  SuperadminChatConversation get selectedConversation => _conversations.firstWhere(
    (item) => item.id == _selectedId,
    orElse: () => _conversations.first,
  );

  List<SuperadminChatConversation> get visibleConversations {
    final query = _search.trim().toLowerCase();
    return _conversations
        .where((item) {
          final matchesAudience = _audience == ChatAudience.contexts
              ? item.kind != ChatContextKind.person
              : item.kind == ChatContextKind.person;
          final matchesSearch =
              query.isEmpty ||
              '${item.title} ${item.preview} ${item.context}'.toLowerCase().contains(query);
          final searchable = {
            item.state,
            item.institution,
            item.unit,
            item.group,
            item.role,
          }.whereType<String>().toSet();
          final matchesFilters = _filters.every(searchable.contains);
          return matchesAudience && matchesSearch && matchesFilters;
        })
        .toList(growable: false);
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setAudience(ChatAudience value) {
    _audience = value;
    notifyListeners();
  }

  void toggleFilter(String value) {
    _filters.contains(value) ? _filters.remove(value) : _filters.add(value);
    notifyListeners();
  }

  void clearFilters() {
    _filters.clear();
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
    if (normalized.isEmpty || recipientIds.isEmpty) return;
    final id = 'local-group-${++_sequence}';
    _conversations.insert(
      0,
      SuperadminChatConversation(
        id: id,
        title: normalized,
        initials: _initials(normalized),
        preview: '${recipientIds.length} pessoas · grupo simulado',
        timestamp: 'Agora',
        context: 'Criado localmente',
        kind: ChatContextKind.group,
        metrics: [
          SuperadminChatMetric('Pessoas', recipientIds.length),
          const SuperadminChatMetric('Mensagens', 0),
        ],
        messages: const [],
        isGroup: true,
      ),
    );
    _selectedId = id;
    feedback = 'Grupo criado apenas nesta simulação.';
    notifyListeners();
  }

  void deleteConversation(String id) {
    final index = _conversations.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _conversations.removeAt(index);
    if (_conversations.isNotEmpty && _selectedId == id) {
      _selectedId = _conversations.first.id;
    }
    feedback = 'Conversa excluída apenas desta simulação.';
    notifyListeners();
  }

  void sendText(String value) {
    final body = value.trim();
    if (body.isEmpty) return;
    _appendMessage(ChatMessageKind.text, body);
  }

  void sendEmoji(String emoji) => _appendMessage(ChatMessageKind.emoji, emoji);

  void sendAttachment(ChatMessageKind kind) {
    assert(kind == ChatMessageKind.audio || kind == ChatMessageKind.image);
    _appendMessage(
      kind,
      kind == ChatMessageKind.audio ? 'Mensagem de áudio · 0:08' : 'Imagem anexada',
    );
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
      context: 'Demonstração local',
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
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
