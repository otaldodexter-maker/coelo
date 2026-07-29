import 'package:flutter/foundation.dart';

import 'chat_fixtures.dart';
import 'chat_models.dart';

final class SuperadminChatController extends ChangeNotifier {
  SuperadminChatController(Iterable<SuperadminChatConversation> conversations)
    : _conversations = List.of(conversations);

  final List<SuperadminChatConversation> _conversations;
  final Map<ChatFilterKind, Set<String>> _filters = {};
  final Set<String> _selectedRecipientIds = {};
  final List<String> _pinnedOrder = [];
  final Map<String, ChatFlag> _flags = {};
  String _selectedId = 'girassol';
  String _search = '';
  ChatAudience _audience = ChatAudience.all;
  int _sequence = 0;
  String? feedback;
  SuperadminChatBulkDelivery? lastBulkDelivery;

  List<SuperadminChatConversation> get conversations => List.unmodifiable(_conversations);
  Set<String> get selectedRecipientIds => Set.unmodifiable(_selectedRecipientIds);
  Set<String> get pinnedIds => Set.unmodifiable(_pinnedOrder.toSet());
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

  List<SuperadminChatConversation> get pinnedConversations {
    final visibleById = {for (final item in visibleConversations) item.id: item};
    return _pinnedOrder.map((id) => visibleById[id]).nonNulls.toList(growable: false);
  }

  List<SuperadminChatConversation> get groupConversations => visibleConversations
      .where(
        (item) => item.kind == ChatContextKind.conversationGroup && !_pinnedOrder.contains(item.id),
      )
      .toList(growable: false);

  List<SuperadminChatConversation> get regularConversations => visibleConversations
      .where(
        (item) => item.kind != ChatContextKind.conversationGroup && !_pinnedOrder.contains(item.id),
      )
      .toList(growable: false);

  List<SuperadminChatConversation> get unpinnedConversations => [
    ...groupConversations,
    ...regularConversations,
  ];

  ChatFlag flagFor(String id) => _flags[id] ?? ChatFlag.none;

  void setFlag(String id, ChatFlag flag) {
    if (!_conversations.any((item) => item.id == id)) return;
    if (flag == ChatFlag.none) {
      _flags.remove(id);
    } else {
      _flags[id] = flag;
    }
    notifyListeners();
  }

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
    _pinnedOrder.contains(id) ? _pinnedOrder.remove(id) : _pinnedOrder.add(id);
    notifyListeners();
  }

  void movePinned(String id, int newIndex) {
    final oldIndex = _pinnedOrder.indexOf(id);
    if (oldIndex < 0) return;
    _pinnedOrder.removeAt(oldIndex);
    _pinnedOrder.insert(newIndex.clamp(0, _pinnedOrder.length), id);
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
      const SuperadminChatMember(
        id: 'superadmin',
        name: 'Superadmin',
        role: 'Superadmin',
        institution: 'Coelo',
        origin: 'Demonstração local',
        facets: {ChatAudience.institutional, ChatAudience.people},
        groupRole: ChatGroupMemberRole.admin,
      ),
      for (final item in selected) _memberFromConversation(item),
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
        preview: '${members.length} participantes · grupo simulado',
        timestamp: 'Agora',
        context: '${institutions.length} instituições · Demonstração local',
        kind: ChatContextKind.conversationGroup,
        facets: facets,
        metrics: [
          SuperadminChatMetric('Participantes', members.length),
          SuperadminChatMetric('Instituições', institutions.length),
        ],
        messages: const [],
        members: members,
        isGroup: true,
      ),
    );
    _selectedId = id;
    feedback = 'Grupo coletivo criado apenas nesta demonstração local.';
    notifyListeners();
  }

  void inviteToGroup(String groupId, Set<String> recipientIds) {
    final group = _groupFor(groupId);
    if (group == null) return;
    final existingIds = group.members.map((item) => item.id).toSet();
    final invited = _conversations
        .where((item) => recipientIds.contains(item.id) && !existingIds.contains(item.id))
        .map(
          (item) =>
              _memberFromConversation(item, invitationStatus: ChatGroupInvitationStatus.pending),
        )
        .toList(growable: false);
    if (invited.isEmpty) return;
    _replaceGroup(group.copyWith(members: [...group.members, ...invited]));
    feedback = '${invited.length} convite(s) pendente(s) nesta demonstração local.';
    notifyListeners();
  }

  bool promoteMember(String groupId, String memberId) {
    final group = _groupFor(groupId);
    if (group == null) return false;
    final memberIndex = group.members.indexWhere((item) => item.id == memberId);
    if (memberIndex < 0) return false;
    if (group.members[memberIndex].invitationStatus != ChatGroupInvitationStatus.accepted) {
      return false;
    }
    final members = List<SuperadminChatMember>.of(group.members);
    members[memberIndex] = _copyMember(members[memberIndex], groupRole: ChatGroupMemberRole.admin);
    _replaceGroup(group.copyWith(members: members));
    feedback = 'Administrador promovido apenas nesta demonstração local.';
    notifyListeners();
    return true;
  }

  bool acceptInvite(String groupId, String memberId) {
    final group = _groupFor(groupId);
    if (group == null) return false;
    final memberIndex = group.members.indexWhere((item) => item.id == memberId);
    if (memberIndex < 0 ||
        group.members[memberIndex].invitationStatus != ChatGroupInvitationStatus.pending) {
      return false;
    }
    final members = List<SuperadminChatMember>.of(group.members);
    members[memberIndex] = _copyMember(
      members[memberIndex],
      invitationStatus: ChatGroupInvitationStatus.accepted,
    );
    _replaceGroup(group.copyWith(members: members));
    feedback = 'Convite aceito apenas nesta demonstração local.';
    notifyListeners();
    return true;
  }

  bool leaveGroup(String groupId, String memberId) {
    final group = _groupFor(groupId);
    if (group == null) return false;
    final member = group.members.where((item) => item.id == memberId).firstOrNull;
    if (member == null) return false;
    final adminCount = group.members
        .where((item) => item.groupRole == ChatGroupMemberRole.admin)
        .length;
    if (member.groupRole == ChatGroupMemberRole.admin && adminCount == 1) {
      feedback = 'Promova outro administrador antes de sair deste grupo.';
      notifyListeners();
      return false;
    }
    _replaceGroup(
      group.copyWith(members: group.members.where((item) => item.id != memberId).toList()),
    );
    feedback = 'Membro removido apenas desta demonstração local.';
    notifyListeners();
    return true;
  }

  bool promoteAndLeave(String groupId, String memberId) {
    if (memberId == 'superadmin' || !promoteMember(groupId, memberId)) return false;
    return leaveGroup(groupId, 'superadmin');
  }

  void deleteGroup(String id) {
    final index = _conversations.indexWhere(
      (item) => item.id == id && item.kind == ChatContextKind.conversationGroup,
    );
    if (index < 0) return;
    _conversations.removeAt(index);
    _pinnedOrder.remove(id);
    _flags.remove(id);
    if (_conversations.isNotEmpty && _selectedId == id) {
      _selectedId = _conversations.first.id;
    }
    feedback = 'Grupo excluído apenas desta demonstração local.';
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

  void startConversations({
    required Set<String> contextIds,
    required String body,
    required Set<ChatAttachmentKind> attachments,
  }) {
    if (contextIds.isEmpty || (body.trim().isEmpty && attachments.isEmpty)) return;
    final options = _flattenOptions(superadminChatContextOptions);
    final selected = options.where((item) => contextIds.contains(item.id)).toList(growable: false);
    final children = selected.where((item) => item.kind == ChatContextKind.child);
    final nonChild = selected.where((item) => item.kind != ChatContextKind.child).firstOrNull;
    for (final child in children) {
      _createChildConversation(child, options, body, attachments);
    }
    if (nonChild != null) _createContextConversation(nonChild, body, attachments);
    if (children.isEmpty && nonChild == null) return;
    feedback = 'Conversa local simulada. Nada foi enviado.';
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
      ChatMessageKind.audio => 'Mensagem de áudio · 0:08',
      ChatMessageKind.image => 'Imagem anexada',
      _ => 'Arquivo anexado · demonstração local',
    });
  }

  void _createChildConversation(
    SuperadminChatContextOption child,
    List<SuperadminChatContextOption> options,
    String body,
    Set<ChatAttachmentKind> attachments,
  ) {
    final guardiansById = {
      for (final option in options.where((item) => item.isGuardian)) option.id: option,
    };
    final guardians = child.guardianIds
        .map((guardianId) => guardiansById[guardianId])
        .nonNulls
        .toList(growable: false);
    final members = [
      for (final guardian in guardians)
        SuperadminChatMember(
          id: guardian.id,
          name: guardian.label,
          role: 'Responsável',
          institution: 'Instituto Aurora',
          origin: guardian.subtitle ?? 'Responsável autorizado',
          facets: const {ChatAudience.people},
        ),
    ];
    final received = [
      for (final guardian in guardians)
        SuperadminChatMessage(
          id: 'local-guardian-message-${++_sequence}',
          body: 'Acompanhamento simulado de ${child.label}.',
          time: 'Agora',
          sentByMe: false,
          author: guardian.label,
          context: 'Responsável por ${child.label}',
          delivery: ChatDeliveryState.delivered,
        ),
    ];
    final messages = [...received, ..._outgoingMessages(body, attachments)];
    final conversation = SuperadminChatConversation(
      id: 'local-child-${child.id}-${++_sequence}',
      title: child.label,
      initials: _initials(child.label),
      preview: messages.last.body,
      timestamp: 'Agora',
      context: child.subtitle ?? 'Contexto de criança',
      kind: ChatContextKind.child,
      facets: const {ChatAudience.people},
      metrics: [SuperadminChatMetric('Responsáveis autorizados', members.length)],
      messages: messages,
      members: members,
      childContextId: child.id,
      childLabel: child.label,
    );
    _conversations.insert(0, conversation);
    _selectedId = conversation.id;
  }

  void _createContextConversation(
    SuperadminChatContextOption option,
    String body,
    Set<ChatAttachmentKind> attachments,
  ) {
    final messages = _outgoingMessages(body, attachments);
    final conversation = SuperadminChatConversation(
      id: 'local-context-${option.id}-${++_sequence}',
      title: option.label,
      initials: _initials(option.label),
      preview: messages.last.body,
      timestamp: 'Agora',
      context: option.subtitle ?? 'Demonstração local',
      kind: option.kind,
      facets: option.kind == ChatContextKind.person
          ? const {ChatAudience.people}
          : const {ChatAudience.institutional},
      metrics: const [],
      messages: messages,
    );
    _conversations.insert(0, conversation);
    _selectedId = conversation.id;
  }

  List<SuperadminChatMessage> _outgoingMessages(String body, Set<ChatAttachmentKind> attachments) {
    final messages = <SuperadminChatMessage>[];
    if (body.trim().isNotEmpty) {
      messages.add(_outgoingMessage(ChatMessageKind.text, body.trim()));
    }
    for (final attachment in attachments) {
      messages.add(
        _outgoingMessage(
          attachment == ChatAttachmentKind.image ? ChatMessageKind.image : ChatMessageKind.text,
          attachment == ChatAttachmentKind.image
              ? 'Imagem anexada'
              : 'Arquivo anexado · demonstração local',
        ),
      );
    }
    return messages;
  }

  SuperadminChatMessage _outgoingMessage(ChatMessageKind kind, String body) =>
      SuperadminChatMessage(
        id: 'local-message-${++_sequence}',
        body: body,
        time: 'Agora',
        sentByMe: true,
        author: 'Superadmin',
        context: 'Demonstração local',
        kind: kind,
        delivery: ChatDeliveryState.delivered,
      );

  void _appendMessage(ChatMessageKind kind, String body) {
    final index = _conversations.indexWhere((item) => item.id == _selectedId);
    if (index < 0) return;
    final current = _conversations[index];
    final message = _outgoingMessage(kind, body);
    _conversations[index] = current.copyWith(
      preview: body,
      timestamp: 'Agora',
      messages: [...current.messages, message],
    );
    feedback = 'Mensagem simulada. Nada foi enviado.';
    notifyListeners();
  }

  SuperadminChatConversation? _groupFor(String id) => _conversations
      .where((item) => item.id == id && item.kind == ChatContextKind.conversationGroup)
      .firstOrNull;

  void _replaceGroup(SuperadminChatConversation group) {
    final index = _conversations.indexWhere((item) => item.id == group.id);
    if (index >= 0) _conversations[index] = group;
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
  ChatFilterKind.child => item.childLabel ?? item.children.firstOrNull,
};

ChatFilterKind _inferFilterKind(String value) {
  if (RegExp(r'^[A-Z]{2}$').hasMatch(value)) return ChatFilterKind.state;
  if (value.startsWith('Unidade ')) return ChatFilterKind.unit;
  if (value.startsWith('Turma ') || value.startsWith('Grupo ')) return ChatFilterKind.group;
  if (value.endsWith('ores') || value.endsWith('áveis') || value == 'Outros') {
    return ChatFilterKind.role;
  }
  return ChatFilterKind.institution;
}

SuperadminChatMember _memberFromConversation(
  SuperadminChatConversation item, {
  ChatGroupInvitationStatus invitationStatus = ChatGroupInvitationStatus.accepted,
}) => SuperadminChatMember(
  id: item.id,
  name: item.title,
  role: item.role ?? _kindLabel(item.kind),
  institution: item.institution ?? 'Coelo',
  origin: item.context,
  facets: item.facets,
  invitationStatus: invitationStatus,
);

SuperadminChatMember _copyMember(
  SuperadminChatMember member, {
  ChatGroupMemberRole? groupRole,
  ChatGroupInvitationStatus? invitationStatus,
}) => SuperadminChatMember(
  id: member.id,
  name: member.name,
  role: member.role,
  institution: member.institution,
  origin: member.origin,
  facets: member.facets,
  groupRole: groupRole ?? member.groupRole,
  invitationStatus: invitationStatus ?? member.invitationStatus,
);

List<SuperadminChatContextOption> _flattenOptions(Iterable<SuperadminChatContextOption> options) =>
    [
      for (final option in options) ...[option, ..._flattenOptions(option.children)],
    ];

String _kindLabel(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => 'Instituição',
  ChatContextKind.unit => 'Unidade',
  ChatContextKind.group => 'Grupo (Turma)',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
  ChatContextKind.child => 'Criança',
  ChatContextKind.conversationGroup => 'Grupo de conversa',
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
