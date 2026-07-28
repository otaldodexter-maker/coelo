import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';

final class SuperadminChatInbox extends StatefulWidget {
  const SuperadminChatInbox({
    required this.controller,
    required this.onOpenConversation,
    required this.onFilter,
    required this.onNewMessage,
    this.onCollapse,
    this.onBack,
    super.key,
  });

  final SuperadminChatController controller;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback onFilter;
  final VoidCallback onNewMessage;
  final VoidCallback? onCollapse;
  final VoidCallback? onBack;

  @override
  State<SuperadminChatInbox> createState() => _SuperadminChatInboxState();
}

final class _SuperadminChatInboxState extends State<SuperadminChatInbox> {
  final _search = TextEditingController();
  var _groupsExpanded = true;
  var _peopleExpanded = true;
  var _selectionMode = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final conversations = controller.visibleConversations;
    final selectedId = controller.selectedConversation.id;
    final groups = conversations.where((item) => item.kind != ChatContextKind.person).toList();
    final people = conversations.where((item) => item.kind == ChatContextKind.person).toList();
    return Material(
      key: const Key('superadmin-chat-inbox'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space4,
              CoeloSpacing.space4,
              CoeloSpacing.space3,
              CoeloSpacing.space2,
            ),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text('Conversas', style: Theme.of(context).textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: _selectionMode ? 'Concluir seleção' : 'Selecionar conversas',
                  onPressed: () => setState(() => _selectionMode = !_selectionMode),
                  icon: Icon(_selectionMode ? Icons.done_rounded : Icons.checklist_rounded),
                ),
                if (widget.onCollapse != null)
                  IconButton(
                    tooltip: 'Recolher conversas',
                    onPressed: widget.onCollapse,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar conversas',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _search.clear();
                          controller.setSearch('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CoeloRadius.xl),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CoeloRadius.xl),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                controller.setSearch(value);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            child: SegmentedButton<ChatAudience>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ChatAudience.contexts, label: Text('Contextos')),
                ButtonSegment(value: ChatAudience.people, label: Text('Pessoas')),
              ],
              selected: {controller.audience},
              onSelectionChanged: (value) => controller.setAudience(value.first),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onFilter,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Filtrar'),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in controller.visibleFilters)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: CoeloSpacing.space1),
                            child: InputChip(
                              label: Text(filter),
                              onDeleted: () => controller.toggleFilter(filter),
                            ),
                          ),
                        if (controller.hiddenFilterCount > 0)
                          Text('+${controller.hiddenFilterCount}'),
                      ],
                    ),
                  ),
                ),
                if (controller.visibleFilters.isNotEmpty)
                  TextButton(onPressed: controller.clearFilters, child: const Text('Limpar')),
              ],
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
              children: [
                _SectionHeader(
                  title: 'Grupos',
                  expanded: _groupsExpanded,
                  onToggle: () => setState(() => _groupsExpanded = !_groupsExpanded),
                  action: IconButton(
                    tooltip: 'Criar grupo',
                    onPressed: _openCreateGroup,
                    icon: const Icon(Icons.group_add_outlined),
                  ),
                ),
                if (_groupsExpanded)
                  for (final conversation in groups)
                    _ConversationItem(
                      conversation: conversation,
                      selected: selectedId == conversation.id,
                      selectionMode: _selectionMode,
                      selectedForAction: controller.selectedRecipientIds.contains(conversation.id),
                      onSelectAction: () => controller.toggleRecipient(conversation.id),
                      onOpen: () => widget.onOpenConversation(conversation.id),
                      onDelete: () => _confirmDelete(conversation),
                    ),
                _SectionHeader(
                  title: 'Pessoas',
                  expanded: _peopleExpanded,
                  onToggle: () => setState(() => _peopleExpanded = !_peopleExpanded),
                ),
                if (_peopleExpanded)
                  for (final conversation in people)
                    _ConversationItem(
                      conversation: conversation,
                      selected: selectedId == conversation.id,
                      selectionMode: _selectionMode,
                      selectedForAction: controller.selectedRecipientIds.contains(conversation.id),
                      onSelectAction: () => controller.toggleRecipient(conversation.id),
                      onOpen: () => widget.onOpenConversation(conversation.id),
                      onDelete: () => _confirmDelete(conversation),
                    ),
                if (conversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(CoeloSpacing.space5),
                    child: Text(
                      'Nenhuma conversa corresponde à busca e aos filtros.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            child: FilledButton.icon(
              onPressed: widget.onNewMessage,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(CoeloSize.touchMin)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Envio em massa'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(SuperadminChatConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(conversation.isGroup ? 'Excluir grupo?' : 'Excluir conversa?'),
        content: const Text('A exclusão é local e serve apenas para avaliar este protótipo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.controller.deleteConversation(conversation.id);
  }

  Future<void> _openCreateGroup() async {
    final name = TextEditingController();
    final selected = <String>{};
    final people = widget.controller.conversations
        .where((item) => item.kind == ChatContextKind.person)
        .toList();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Criar grupo'),
          content: SizedBox(
            width: CoeloSize.touchMin * 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome do grupo'),
                ),
                const SizedBox(height: CoeloSpacing.space3),
                for (final person in people)
                  CheckboxListTile(
                    value: selected.contains(person.id),
                    title: Text(person.title),
                    onChanged: (value) => setDialogState(() {
                      value == true ? selected.add(person.id) : selected.remove(person.id);
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Criar grupo'),
            ),
          ],
        ),
      ),
    );
    if (created == true) widget.controller.createGroup(name.text, selected);
    name.dispose();
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.action,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space4,
        CoeloSpacing.space3,
        CoeloSpacing.space2,
        CoeloSpacing.space1,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                    Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

final class _ConversationItem extends StatelessWidget {
  const _ConversationItem({
    required this.conversation,
    required this.selected,
    required this.selectionMode,
    required this.selectedForAction,
    required this.onSelectAction,
    required this.onOpen,
    required this.onDelete,
  });

  final SuperadminChatConversation conversation;
  final bool selected;
  final bool selectionMode;
  final bool selectedForAction;
  final VoidCallback onSelectAction;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${conversation.title}. ${conversation.preview}. ${conversation.timestamp}. '
          '${conversation.unreadCount} não lidas',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space2,
          vertical: CoeloSpacing.space1,
        ),
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: InkWell(
            key: Key('superadmin-chat-conversation-${conversation.id}'),
            onTap: selectionMode ? onSelectAction : onOpen,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space2),
              child: Row(
                children: [
                  if (selectionMode)
                    Checkbox(value: selectedForAction, onChanged: (_) => onSelectAction())
                  else
                    SuperadminChatAvatar(
                      label: conversation.title,
                      initials: conversation.initials,
                      online: conversation.kind == ChatContextKind.person,
                    ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              conversation.timestamp,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: CoeloSpacing.space1),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                            if (conversation.unreadCount > 0)
                              Container(
                                constraints: const BoxConstraints(minWidth: CoeloSpacing.space5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: CoeloSpacing.space1,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(CoeloRadius.full),
                                ),
                                child: Text(
                                  '${conversation.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(color: colors.onPrimary),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Ações de ${conversation.title}',
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(conversation.isGroup ? 'Excluir grupo' : 'Excluir conversa'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
