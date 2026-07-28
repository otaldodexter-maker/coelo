import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../chat_fixtures.dart';
import '../widgets/superadmin_chat_context_panel.dart';
import '../widgets/superadmin_chat_recipient_picker.dart';
import '../widgets/superadmin_chat_scope_filters.dart';
import '../widgets/superadmin_chat_thread_body.dart';

final class SuperadminChatPage extends StatefulWidget {
  const SuperadminChatPage({
    required this.logout,
    this.onDestinationSelected,
    this.onBack,
    this.contextOptions = superadminChatContextOptions,
    super.key,
  });

  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onBack;
  final List<CoeloAdminContextOption> contextOptions;

  @override
  State<SuperadminChatPage> createState() => _SuperadminChatPageState();
}

final class _SuperadminChatPageState extends State<SuperadminChatPage> {
  final _expandInboxFocusNode = FocusNode(debugLabel: 'Expandir conversas');
  final _newConversationFocusNode = FocusNode(debugLabel: 'Nova conversa');
  final _collapsedContextPanelFocusNode = FocusNode(debugLabel: 'Mostrar detalhes do contexto');
  final _expandedContextPanelFocusNode = FocusNode(debugLabel: 'Recolher painel contextual');
  final _conversations = [...superadminChatConversations];
  var _selectedIndex = 0;
  var _bulkSequence = 0;
  var _mobileThreadOpen = false;
  var _inboxCollapsed = false;
  bool? _contextPanelCollapsedOverride;
  final _scopeSelections = <SuperadminChatScopeKind, String>{};

  SuperadminChatConversation get _selected => _conversations[_selectedIndex];
  List<SuperadminChatConversation> get _filteredConversations => _conversations
      .where((conversation) => matchesSuperadminChatScope(conversation, _scopeSelections))
      .toList(growable: false);

  @override
  void dispose() {
    _expandInboxFocusNode.dispose();
    _newConversationFocusNode.dispose();
    _collapsedContextPanelFocusNode.dispose();
    _expandedContextPanelFocusNode.dispose();
    super.dispose();
  }

  void _selectConversation(SuperadminChatConversation conversation, {required bool mobile}) {
    setState(() {
      _selectedIndex = _conversations.indexOf(conversation);
      _mobileThreadOpen = mobile;
    });
  }

  void _updateScope(SuperadminChatScopeKind kind, String? value) {
    final next = updatedSuperadminChatScope(_scopeSelections, kind, value);
    setState(() {
      _scopeSelections
        ..clear()
        ..addAll(next);
    });
  }

  void _collapseInbox() {
    setState(() => _inboxCollapsed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _expandInboxFocusNode.requestFocus();
      }
    });
  }

  bool _contextPanelCollapsed({required bool byDefault}) {
    return _contextPanelCollapsedOverride ?? byDefault;
  }

  void _toggleContextPanel(bool collapsed) {
    setState(() => _contextPanelCollapsedOverride = !collapsed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final successor = collapsed
          ? _expandedContextPanelFocusNode
          : _collapsedContextPanelFocusNode;
      successor.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      title: 'Conversas',
      subtitle: 'Comunicação contextual, privada e auditável.',
      currentDestination: 'conversations',
      onDestinationSelected: widget.onDestinationSelected,
      child: Column(
        children: [
          _ChatContextToolbar(selections: _scopeSelections, onChanged: _updateScope),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
                  if (!_mobileThreadOpen) {
                    return _ConversationInbox(
                      key: const Key('superadmin-chat-inbox'),
                      conversations: _filteredConversations,
                      selectedId: _selected.id,
                      onSelected: (conversation) => _selectConversation(conversation, mobile: true),
                      onNewConversation: _openNewConversation,
                      newConversationFocusNode: _newConversationFocusNode,
                      onBack: widget.onBack,
                    );
                  }

                  final contextPanelCollapsed = _contextPanelCollapsed(byDefault: true);
                  if (!contextPanelCollapsed) {
                    return SuperadminChatContextPanel(
                      conversation: _selected,
                      collapsed: false,
                      toggleFocusNode: _expandedContextPanelFocusNode,
                      onToggle: () => _toggleContextPanel(contextPanelCollapsed),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: _ChatThread(
                          key: const Key('superadmin-chat-thread'),
                          conversation: _selected,
                          onBack: () => setState(() => _mobileThreadOpen = false),
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: CoeloSize.touchMin + CoeloSpacing.space4,
                        child: SuperadminChatContextPanel(
                          conversation: _selected,
                          collapsed: true,
                          toggleFocusNode: _collapsedContextPanelFocusNode,
                          onToggle: () => _toggleContextPanel(contextPanelCollapsed),
                        ),
                      ),
                    ],
                  );
                }

                if (constraints.maxWidth < CoeloBreakpoints.expanded.minWidth) {
                  final contextPanelCollapsed = _contextPanelCollapsed(byDefault: true);
                  return Row(
                    children: [
                      _ConversationRail(
                        key: const Key('superadmin-chat-rail'),
                        conversations: _filteredConversations,
                        selectedId: _selected.id,
                        onSelected: (conversation) =>
                            _selectConversation(conversation, mobile: false),
                        onNewConversation: _openNewConversation,
                        newConversationFocusNode: _newConversationFocusNode,
                        onBack: widget.onBack,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _ChatThread(
                          key: const Key('superadmin-chat-thread'),
                          conversation: _selected,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: contextPanelCollapsed
                            ? CoeloSize.touchMin + CoeloSpacing.space4
                            : CoeloSize.touchMin * 6,
                        child: SuperadminChatContextPanel(
                          conversation: _selected,
                          collapsed: contextPanelCollapsed,
                          toggleFocusNode: contextPanelCollapsed
                              ? _collapsedContextPanelFocusNode
                              : _expandedContextPanelFocusNode,
                          onToggle: () => _toggleContextPanel(contextPanelCollapsed),
                        ),
                      ),
                    ],
                  );
                }

                final contextPanelCollapsed = _contextPanelCollapsed(byDefault: false);
                return Row(
                  children: [
                    if (_inboxCollapsed)
                      _ConversationRail(
                        key: const Key('superadmin-chat-inbox-rail'),
                        conversations: _filteredConversations,
                        selectedId: _selected.id,
                        onSelected: (conversation) =>
                            _selectConversation(conversation, mobile: false),
                        onNewConversation: _openNewConversation,
                        newConversationFocusNode: _newConversationFocusNode,
                        onBack: widget.onBack,
                        onExpand: () => setState(() => _inboxCollapsed = false),
                        expandFocusNode: _expandInboxFocusNode,
                      )
                    else
                      SizedBox(
                        width: 336,
                        child: _ConversationInbox(
                          key: const Key('superadmin-chat-inbox'),
                          conversations: _filteredConversations,
                          selectedId: _selected.id,
                          onSelected: (conversation) =>
                              _selectConversation(conversation, mobile: false),
                          onNewConversation: _openNewConversation,
                          newConversationFocusNode: _newConversationFocusNode,
                          onBack: widget.onBack,
                          onCollapse: _collapseInbox,
                        ),
                      ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _ChatThread(
                        key: const Key('superadmin-chat-thread'),
                        conversation: _selected,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: contextPanelCollapsed
                          ? CoeloSize.touchMin + CoeloSpacing.space4
                          : CoeloSize.touchMin * 6,
                      child: SuperadminChatContextPanel(
                        conversation: _selected,
                        collapsed: contextPanelCollapsed,
                        toggleFocusNode: contextPanelCollapsed
                            ? _collapsedContextPanelFocusNode
                            : _expandedContextPanelFocusNode,
                        onToggle: () => _toggleContextPanel(contextPanelCollapsed),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewConversation() async {
    final selectedRecipients = await showDialog<List<SuperadminChatRecipientSelection>>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(CoeloSpacing.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nova conversa',
                          style: Theme.of(dialogContext).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar nova conversa',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style:
                            IconButton.styleFrom(
                              foregroundColor: Theme.of(dialogContext).colorScheme.error,
                              minimumSize: const Size.square(CoeloSize.touchMin),
                              maximumSize: const Size.square(CoeloSize.touchMin),
                              shape: const CircleBorder(),
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.hovered) ||
                                        states.contains(WidgetState.focused)
                                    ? Theme.of(dialogContext).colorScheme.errorContainer
                                    : Colors.transparent,
                              ),
                              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                            ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openAuditedPersonSearch(dialogContext),
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Pesquisar pessoa · Acesso auditado'),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SuperadminChatRecipientPicker(
                      options: widget.contextOptions,
                      onConfirmed: (selection) => Navigator.of(dialogContext).pop(selection),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) {
      return;
    }

    if (selectedRecipients != null && selectedRecipients.isNotEmpty) {
      _addLocalBulkConversation(selectedRecipients);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _newConversationFocusNode.requestFocus();
      }
    });
  }

  void _addLocalBulkConversation(List<SuperadminChatRecipientSelection> recipients) {
    final count = recipients.length;
    final commonPath = _commonRecipientPath(recipients);
    final recipient = count == 1 ? recipients.single.recipient : null;
    final title = recipient?.label ?? 'Envio em massa · $count destinatários';
    final institution = _pathOption(commonPath, CoeloAdminContextKind.institution);
    final unit = _pathOption(commonPath, CoeloAdminContextKind.unit);
    final group = _pathOption(commonPath, CoeloAdminContextKind.group);
    final activity = _pathOption(commonPath, CoeloAdminContextKind.activity);
    final state = _commonInstitutionState(recipients);
    final pathLabel = commonPath.map((option) => option.label).join(' / ');
    final localInitialMessage = count == 1
        ? 'Demonstração local · mensagem preparada para ${recipient!.label}; nenhum envio real foi realizado.'
        : 'Demonstração local · mensagem preparada para $count destinatários; nenhum envio real foi realizado.';
    final conversation = SuperadminChatConversation(
      id: 'bulk-local-${++_bulkSequence}',
      title: title,
      initials: count == 1 ? _initials(recipient!.label) : 'EM',
      preview: localInitialMessage,
      timestamp: 'Agora',
      context: [
        if (pathLabel.isNotEmpty) pathLabel,
        if (count > 1) '$count destinatários',
        'Demonstração local',
      ].join(' · '),
      institution: institution?.label ?? 'Múltiplas instituições',
      targetKind: commonPath.isEmpty ? CoeloAdminContextKind.institution : commonPath.last.kind,
      metrics: [
        CoeloAdminChatMetric('Destinatários', count),
        const CoeloAdminChatMetric('Mensagens', 1),
      ],
      state: state,
      unit: unit?.label,
      group: group?.label,
      activity: activity?.label,
      localInitialMessage: localInitialMessage,
    );

    setState(() {
      _conversations.insert(0, conversation);
      _selectedIndex++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Demonstração local · nenhum envio real foi realizado.')),
      );
  }

  Future<void> _openAuditedPersonSearch(BuildContext dialogContext) {
    return showDialog<void>(
      context: dialogContext,
      builder: (context) => const _AuditedPersonSearchDialog(),
    );
  }
}

final class _ChatContextToolbar extends StatelessWidget {
  const _ChatContextToolbar({required this.selections, required this.onChanged});

  final Map<SuperadminChatScopeKind, String> selections;
  final void Function(SuperadminChatScopeKind kind, String? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
      child: SuperadminChatScopeFilters(selections: selections, onChanged: onChanged),
    );
  }
}

final class _AuditedPersonSearchDialog extends StatefulWidget {
  const _AuditedPersonSearchDialog();

  @override
  State<_AuditedPersonSearchDialog> createState() => _AuditedPersonSearchDialogState();
}

final class _AuditedPersonSearchDialogState extends State<_AuditedPersonSearchDialog> {
  final _reasonController = TextEditingController();
  var _showRelationships = false;
  String? _selectedRelationship;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showRelationships) {
      return AlertDialog(
        title: const Text('Pesquisa auditada de pessoa'),
        content: TextField(
          controller: _reasonController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Motivo da pesquisa',
            hintText: 'Informe por que este contato é necessário',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: _reasonController.text.trim().isEmpty
                ? null
                : () => setState(() => _showRelationships = true),
            child: const Text('Continuar'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Selecione um vínculo válido'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListTile(
          selected: _selectedRelationship == 'marina-girassol',
          leading: const CircleAvatar(child: Text('MA')),
          title: const Text('Marina Alves'),
          subtitle: const Text('Professora · Centro Horizonte / Unidade Cambuí / Turma Girassol'),
          trailing: Icon(
            _selectedRelationship == 'marina-girassol'
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          onTap: () => setState(() => _selectedRelationship = 'marina-girassol'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _showRelationships = false;
            _selectedRelationship = null;
          }),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: _selectedRelationship == null ? null : () => Navigator.of(context).pop(),
          child: const Text('Iniciar conversa'),
        ),
      ],
    );
  }
}

final class _ConversationInbox extends StatefulWidget {
  const _ConversationInbox({
    required this.conversations,
    required this.selectedId,
    required this.onSelected,
    required this.onNewConversation,
    required this.newConversationFocusNode,
    this.onBack,
    this.onCollapse,
    super.key,
  });

  final List<SuperadminChatConversation> conversations;
  final String selectedId;
  final ValueChanged<SuperadminChatConversation> onSelected;
  final VoidCallback onNewConversation;
  final FocusNode newConversationFocusNode;
  final VoidCallback? onBack;
  final VoidCallback? onCollapse;

  @override
  State<_ConversationInbox> createState() => _ConversationInboxState();
}

final class _ConversationInboxState extends State<_ConversationInbox> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Row(
            children: [
              Expanded(
                child: CoeloSearchField(
                  controller: _searchController,
                  semanticLabel: 'Buscar conversas',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              IconButton.filledTonal(
                tooltip: 'Nova conversa',
                onPressed: widget.onNewConversation,
                focusNode: widget.newConversationFocusNode,
                icon: const Icon(Icons.edit_outlined),
              ),
              if (widget.onCollapse != null) ...[
                const SizedBox(width: CoeloSpacing.space1),
                IconButton(
                  tooltip: 'Recolher conversas',
                  onPressed: widget.onCollapse,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _visibleConversations.isEmpty
              ? const CoeloStatePanel(
                  title: 'Nenhuma conversa neste contexto',
                  message: 'Ajuste os filtros para ver outros vínculos autorizados.',
                  icon: Icons.filter_alt_off_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space2),
                  children: [
                    _ConversationInboxSection(
                      title: 'Grupos',
                      conversations: _visibleConversations
                          .where(
                            (conversation) =>
                                conversation.targetKind == CoeloAdminContextKind.group,
                          )
                          .toList(growable: false),
                      selectedId: widget.selectedId,
                      onSelected: widget.onSelected,
                    ),
                    _ConversationInboxSection(
                      title: 'Pessoas',
                      conversations: _visibleConversations
                          .where(
                            (conversation) =>
                                conversation.targetKind != CoeloAdminContextKind.group,
                          )
                          .toList(growable: false),
                      selectedId: widget.selectedId,
                      onSelected: widget.onSelected,
                    ),
                  ],
                ),
        ),
        if (widget.onBack != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space2),
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar à tela anterior'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<SuperadminChatConversation> get _visibleConversations {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.conversations;
    }
    return widget.conversations
        .where(
          (conversation) =>
              conversation.title.toLowerCase().contains(query) ||
              conversation.context.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }
}

final class _ConversationInboxSection extends StatelessWidget {
  const _ConversationInboxSection({
    required this.title,
    required this.conversations,
    required this.selectedId,
    required this.onSelected,
  });

  final String title;
  final List<SuperadminChatConversation> conversations;
  final String selectedId;
  final ValueChanged<SuperadminChatConversation> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        key: PageStorageKey(title),
        initiallyExpanded: true,
        maintainState: true,
        title: Text(title),
        children: [
          for (final conversation in conversations)
            CoeloConversationTile(
              key: Key('superadmin-chat-conversation-${conversation.id}'),
              avatar: CoeloChatAvatar(
                label: conversation.title,
                initials: conversation.initials,
                nowState: conversation.nowState,
                presence: conversation.presence,
              ),
              title: conversation.title,
              preview: conversation.preview,
              timestamp: conversation.timestamp,
              unreadCount: conversation.unreadCount,
              selected: conversation.id == selectedId,
              onPressed: () => onSelected(conversation),
            ),
        ],
      ),
    );
  }
}

final class _ConversationRail extends StatelessWidget {
  const _ConversationRail({
    required this.conversations,
    required this.selectedId,
    required this.onSelected,
    required this.onNewConversation,
    required this.newConversationFocusNode,
    this.onBack,
    this.onExpand,
    this.expandFocusNode,
    super.key,
  });

  final List<SuperadminChatConversation> conversations;
  final String selectedId;
  final ValueChanged<SuperadminChatConversation> onSelected;
  final VoidCallback onNewConversation;
  final FocusNode newConversationFocusNode;
  final VoidCallback? onBack;
  final VoidCallback? onExpand;
  final FocusNode? expandFocusNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          if (onExpand != null)
            Padding(
              padding: const EdgeInsets.only(top: CoeloSpacing.space2),
              child: IconButton(
                tooltip: 'Expandir conversas',
                onPressed: onExpand,
                focusNode: expandFocusNode,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: onExpand == null ? CoeloSpacing.space2 : 0),
            child: IconButton(
              tooltip: 'Nova conversa',
              onPressed: onNewConversation,
              focusNode: newConversationFocusNode,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Expanded(
            child: ListView(
              children: [
                for (final conversation in conversations)
                  Builder(
                    builder: (context) {
                      final selected = conversation.id == selectedId;
                      final colors = Theme.of(context).colorScheme;
                      return Semantics(
                        key: Key('superadmin-chat-rail-conversation-${conversation.id}'),
                        container: true,
                        selected: selected,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
                          child: Center(
                            child: Container(
                              key: Key(
                                'superadmin-chat-rail-conversation-${conversation.id}-surface',
                              ),
                              padding: const EdgeInsets.all(CoeloSpacing.spaceHalf),
                              decoration: BoxDecoration(
                                color: selected ? colors.primaryContainer : Colors.transparent,
                                shape: BoxShape.circle,
                                border: selected ? Border.all(color: colors.primary) : null,
                              ),
                              child: CoeloChatAvatar(
                                label: conversation.title,
                                initials: conversation.initials,
                                nowState: conversation.nowState,
                                presence: conversation.presence,
                                onProfilePressed: () => onSelected(conversation),
                                onNowPressed: () => onSelected(conversation),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: IconButton(
                tooltip: 'Voltar à tela anterior',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
        ],
      ),
    );
  }
}

final class _ChatThread extends StatelessWidget {
  const _ChatThread({required this.conversation, this.onBack, super.key});

  final SuperadminChatConversation conversation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CoeloConversationHeader(
          avatar: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Voltar para conversas',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              CoeloChatAvatar(
                label: conversation.title,
                initials: conversation.initials,
                nowState: conversation.nowState,
                presence: conversation.presence,
                onProfilePressed: () => _showProfile(context, conversation),
                onNowPressed: () => _showNow(context, conversation),
              ),
            ],
          ),
          title: conversation.title,
          subtitle: conversation.context,
          onProfilePressed: () => _showProfile(context, conversation),
        ),
        Expanded(child: SuperadminChatThreadBody(conversation: conversation)),
      ],
    );
  }

  static Future<void> _showProfile(BuildContext context, SuperadminChatConversation conversation) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conversation.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: CoeloSpacing.space2),
              const Text('Vínculos autorizados'),
              const SizedBox(height: CoeloSpacing.space2),
              Text(conversation.context),
              const SizedBox(height: CoeloSpacing.space4),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shield_outlined),
                title: Text('Escopo vigente'),
                subtitle: Text('Apenas a subárvore institucional autorizada.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showNow(BuildContext context, SuperadminChatConversation conversation) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Now · ${conversation.title}'),
        content: const Text('O visualizador completo de Now será integrado em uma próxima etapa.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }
}

String _initials(String label) {
  final words = label.trim().split(RegExp(r'\s+'));
  return words.take(2).where((word) => word.isNotEmpty).map((word) => word[0].toUpperCase()).join();
}

List<CoeloAdminContextOption> _commonRecipientPath(
  List<SuperadminChatRecipientSelection> recipients,
) {
  if (recipients.isEmpty) {
    return const [];
  }
  final shortestLength = recipients
      .map((selection) => selection.path.length)
      .reduce((first, second) => first < second ? first : second);
  final common = <CoeloAdminContextOption>[];
  for (var index = 0; index < shortestLength; index++) {
    final candidate = recipients.first.path[index];
    if (recipients.every((selection) => selection.path[index].id == candidate.id)) {
      common.add(candidate);
    } else {
      break;
    }
  }
  return List.unmodifiable(common);
}

CoeloAdminContextOption? _pathOption(
  List<CoeloAdminContextOption> path,
  CoeloAdminContextKind kind,
) {
  for (final option in path) {
    if (option.kind == kind) {
      return option;
    }
  }
  return null;
}

String? _commonInstitutionState(List<SuperadminChatRecipientSelection> recipients) {
  final states = recipients
      .map((selection) {
        final institution = _pathOption(selection.path, CoeloAdminContextKind.institution);
        return institution == null ? null : superadminChatInstitutionStateById[institution.id];
      })
      .toList(growable: false);
  if (states.any((state) => state == null)) {
    return null;
  }
  final distinctStates = states.whereType<String>().toSet();
  return distinctStates.length == 1 ? distinctStates.single : null;
}
