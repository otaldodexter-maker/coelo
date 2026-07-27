import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../chat_fixtures.dart';
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
  var _selectedIndex = 0;
  var _mobileThreadOpen = false;
  var _inboxCollapsed = false;
  final _scopeSelections = <SuperadminChatScopeKind, String>{};

  SuperadminChatConversation get _selected => superadminChatConversations[_selectedIndex];
  List<SuperadminChatConversation> get _filteredConversations => superadminChatConversations
      .where((conversation) => matchesSuperadminChatScope(conversation, _scopeSelections))
      .toList(growable: false);

  void _selectConversation(int index, {required bool mobile}) {
    setState(() {
      _selectedIndex = index;
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
                  return _mobileThreadOpen
                      ? _ChatThread(
                          key: const Key('superadmin-chat-thread'),
                          conversation: _selected,
                          onBack: () => setState(() => _mobileThreadOpen = false),
                        )
                      : _ConversationInbox(
                          key: const Key('superadmin-chat-inbox'),
                          conversations: _filteredConversations,
                          selectedIndex: _selectedIndex,
                          onSelected: (index) => _selectConversation(index, mobile: true),
                          onNewConversation: _openNewConversation,
                          onBack: widget.onBack,
                        );
                }

                if (constraints.maxWidth < CoeloBreakpoints.expanded.minWidth) {
                  return Row(
                    children: [
                      _ConversationRail(
                        key: const Key('superadmin-chat-rail'),
                        conversations: _filteredConversations,
                        selectedIndex: _selectedIndex,
                        onSelected: (index) => _selectConversation(index, mobile: false),
                        onNewConversation: _openNewConversation,
                        onBack: widget.onBack,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _ChatThread(
                          key: const Key('superadmin-chat-thread'),
                          conversation: _selected,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    if (_inboxCollapsed)
                      _ConversationRail(
                        key: const Key('superadmin-chat-inbox-rail'),
                        conversations: _filteredConversations,
                        selectedIndex: _selectedIndex,
                        onSelected: (index) => _selectConversation(index, mobile: false),
                        onNewConversation: _openNewConversation,
                        onBack: widget.onBack,
                        onExpand: () => setState(() => _inboxCollapsed = false),
                      )
                    else
                      SizedBox(
                        width: 336,
                        child: _ConversationInbox(
                          key: const Key('superadmin-chat-inbox'),
                          conversations: _filteredConversations,
                          selectedIndex: _selectedIndex,
                          onSelected: (index) => _selectConversation(index, mobile: false),
                          onNewConversation: _openNewConversation,
                          onBack: widget.onBack,
                          onCollapse: () => setState(() => _inboxCollapsed = true),
                        ),
                      ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _ChatThread(
                        key: const Key('superadmin-chat-thread'),
                        conversation: _selected,
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

  Future<void> _openNewConversation() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
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
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(dialogContext).colorScheme.error,
                          hoverColor: Theme.of(dialogContext).colorScheme.errorContainer,
                          focusColor: Theme.of(dialogContext).colorScheme.errorContainer,
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
                    child: CoeloAdminContextPicker(
                      options: widget.contextOptions,
                      onSelected: (_) => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    required this.selectedIndex,
    required this.onSelected,
    required this.onNewConversation,
    this.onBack,
    this.onCollapse,
    super.key,
  });

  final List<SuperadminChatConversation> conversations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewConversation;
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
                      selectedIndex: widget.selectedIndex,
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
                      selectedIndex: widget.selectedIndex,
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
    required this.selectedIndex,
    required this.onSelected,
  });

  final String title;
  final List<SuperadminChatConversation> conversations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

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
              selected: superadminChatConversations.indexOf(conversation) == selectedIndex,
              onPressed: () => onSelected(superadminChatConversations.indexOf(conversation)),
            ),
        ],
      ),
    );
  }
}

final class _ConversationRail extends StatelessWidget {
  const _ConversationRail({
    required this.conversations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onNewConversation,
    this.onBack,
    this.onExpand,
    super.key,
  });

  final List<SuperadminChatConversation> conversations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewConversation;
  final VoidCallback? onBack;
  final VoidCallback? onExpand;

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
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: onExpand == null ? CoeloSpacing.space2 : 0),
            child: IconButton(
              tooltip: 'Nova conversa',
              onPressed: onNewConversation,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Expanded(
            child: ListView(
              children: [
                for (final conversation in conversations)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
                    child: Center(
                      child: CoeloChatAvatar(
                        label: conversation.title,
                        initials: conversation.initials,
                        nowState: conversation.nowState,
                        presence: conversation.presence,
                        onProfilePressed: () =>
                            onSelected(superadminChatConversations.indexOf(conversation)),
                        onNowPressed: () =>
                            onSelected(superadminChatConversations.indexOf(conversation)),
                      ),
                    ),
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
