import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';
import 'chat_catalog_fixtures.dart';

Map<String, CatalogFoundation> buildChatFoundationRegistry() {
  const coreIds = [
    'core.chat-avatar',
    'core.conversation-tile',
    'core.conversation-header',
    'core.message-bubble',
    'core.chat-composer',
  ];
  return {
    'pattern.chat-admin': CatalogFoundation(
      id: 'pattern.chat-admin',
      referencedComponentIds: const [
        ...coreIds,
        'admin.context-picker',
        'admin.chat-context-summary',
      ],
      builder: (_) => const _AdministrativeChatFoundation(),
    ),
    'pattern.chat-principal-mobile': CatalogFoundation(
      id: 'pattern.chat-principal-mobile',
      referencedComponentIds: coreIds,
      builder: (_) => const _PrincipalChatFoundation(),
    ),
    'pattern.chat-principal-web': CatalogFoundation(
      id: 'pattern.chat-principal-web',
      referencedComponentIds: coreIds,
      builder: (_) => const _WebChatLauncherFoundation(),
    ),
    'pattern.chat-states': CatalogFoundation(
      id: 'pattern.chat-states',
      referencedComponentIds: const ['core.state-panel'],
      builder: (_) => const _ChatStatesFoundation(),
    ),
  };
}

final class _AdministrativeChatFoundation extends StatefulWidget {
  const _AdministrativeChatFoundation();

  @override
  State<_AdministrativeChatFoundation> createState() => _AdministrativeChatFoundationState();
}

final class _AdministrativeChatFoundationState extends State<_AdministrativeChatFoundation> {
  var _selected = 1;
  var _selectedFilter = 'Todas';
  var _inboxCollapsed = false;
  bool? _contextCollapsed;
  var _compactPane = _AdministrativeChatPane.inbox;
  var _launcherOpen = false;

  Future<void> _openContextPicker() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 560,
          height: 680,
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: CoeloAdminContextPicker(
              options: catalogAdminContextOptions,
              onSelected: (_) => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('catalog-admin-chat-pattern'),
      height: 700,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final conversation = catalogChatConversations[_selected];
          final content = _buildResponsiveContent(width: width, conversation: conversation);
          final launcherDocked = width >= CoeloBreakpoints.large.minWidth && _launcherOpen;
          return Stack(
            children: [
              Column(
                children: [
                  _AdministrativeChatToolbar(
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) => setState(() => _selectedFilter = filter),
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                  Expanded(child: content),
                ],
              ),
              if (!launcherDocked)
                Positioned(
                  right: _launcherRightInset(width),
                  bottom: CoeloSpacing.space24,
                  child: _AdministrativeLauncherButton(onPressed: () => _openLauncher(width)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResponsiveContent({
    required double width,
    required CatalogChatConversation conversation,
  }) {
    if (width < CoeloBreakpoints.medium.minWidth) {
      return switch (_compactPane) {
        _AdministrativeChatPane.inbox => _buildInbox(),
        _AdministrativeChatPane.thread => _ConversationThread(
          conversation: conversation,
          showAdministrativeActions: true,
          onBack: () => setState(() => _compactPane = _AdministrativeChatPane.inbox),
          onContext: () => setState(() => _compactPane = _AdministrativeChatPane.context),
        ),
        _AdministrativeChatPane.context => _buildContextSummary(
          conversation: conversation,
          collapsed: false,
          compact: true,
        ),
      };
    }

    if (width < CoeloBreakpoints.expanded.minWidth) {
      return Row(
        children: [
          SizedBox(
            width: CoeloSpacing.space20,
            child: _AdministrativeConversationRail(
              selected: _selected,
              onSelected: _selectConversation,
              onExpand: () {},
              onNewConversation: _openContextPicker,
            ),
          ),
          VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(
            child: _compactPane == _AdministrativeChatPane.context
                ? _buildContextSummary(conversation: conversation, collapsed: false, compact: true)
                : _ConversationThread(
                    conversation: conversation,
                    showAdministrativeActions: true,
                    onContext: () => setState(() => _compactPane = _AdministrativeChatPane.context),
                  ),
          ),
        ],
      );
    }

    final launcherDocked = width >= CoeloBreakpoints.large.minWidth && _launcherOpen;
    final inboxCollapsed = launcherDocked || _inboxCollapsed;
    final contextCollapsed =
        launcherDocked || (_contextCollapsed ?? width < CoeloBreakpoints.large.minWidth);
    return Row(
      children: [
        SizedBox(
          width: inboxCollapsed ? CoeloSpacing.space20 : 336,
          child: inboxCollapsed
              ? _AdministrativeConversationRail(
                  selected: _selected,
                  onSelected: _selectConversation,
                  onExpand: () => setState(() => _inboxCollapsed = false),
                  onNewConversation: _openContextPicker,
                )
              : _buildInbox(onCollapse: () => setState(() => _inboxCollapsed = true)),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(
          child: _ConversationThread(conversation: conversation, showAdministrativeActions: true),
        ),
        SizedBox(
          width: contextCollapsed ? CoeloSize.avatarXl : 288,
          child: _buildContextSummary(
            conversation: conversation,
            collapsed: contextCollapsed,
            compact: false,
          ),
        ),
        if (launcherDocked) ...[
          VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          SizedBox(
            key: const Key('catalog-admin-chat-launcher-dock'),
            width: 460,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 600,
                child: _AdministrativeLauncherPreview(
                  selected: _selected,
                  onSelected: (index) => setState(() => _selected = index),
                  onClose: () => setState(() => _launcherOpen = false),
                  onNewConversation: _openContextPicker,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _launcherRightInset(double width) {
    if (width < CoeloBreakpoints.expanded.minWidth) {
      return CoeloSpacing.space4;
    }
    final contextCollapsed = _contextCollapsed ?? width < CoeloBreakpoints.large.minWidth;
    return (contextCollapsed ? CoeloSize.avatarXl : 288) + CoeloSpacing.space4;
  }

  Widget _buildInbox({VoidCallback? onCollapse}) {
    return _ConversationInbox(
      selected: _selected,
      onSelected: _selectConversation,
      onNewConversation: _openContextPicker,
      onCollapse: onCollapse,
    );
  }

  Future<void> _openLauncher(double width) async {
    if (width >= CoeloBreakpoints.large.minWidth) {
      setState(() => _launcherOpen = true);
      return;
    }
    final overlay = Theme.of(context).extension<CoeloOverlayColors>()!;
    await showDialog<void>(
      context: context,
      barrierColor: overlay.scrim,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return Dialog(
          key: const Key('catalog-admin-chat-launcher-dialog'),
          insetPadding: const EdgeInsets.all(CoeloSpacing.space4),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
            child: SizedBox(
              width: 460,
              height: 600,
              child: _AdministrativeLauncherPreview(
                selected: _selected,
                onSelected: (index) {
                  _selectConversation(index);
                  Navigator.of(dialogContext).pop();
                },
                onClose: () => Navigator.of(dialogContext).pop(),
                onNewConversation: () {
                  Navigator.of(dialogContext).pop();
                  _openContextPicker();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContextSummary({
    required CatalogChatConversation conversation,
    required bool collapsed,
    required bool compact,
  }) {
    return CoeloAdminChatContextSummary(
      title: conversation.title,
      subtitle: conversation.context,
      metrics: _catalogContextMetrics,
      collapsed: collapsed,
      onToggle: () => setState(() {
        if (compact) {
          _compactPane = _AdministrativeChatPane.thread;
        } else {
          _contextCollapsed = !collapsed;
        }
      }),
      expandedToggleIcon: compact ? Icons.arrow_back : Icons.chevron_right,
      expandedToggleTooltip: compact ? 'Voltar para a conversa' : 'Recolher painel contextual',
      image: CoeloChatAvatar(
        label: conversation.title,
        initials: conversation.initials,
        size: CoeloSize.avatarXl,
      ),
      footer: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: CoeloSize.iconSm,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: CoeloSpacing.space2),
          const Expanded(child: Text('Dados simulados')),
        ],
      ),
    );
  }

  void _selectConversation(int index) {
    setState(() {
      _selected = index;
      _compactPane = _AdministrativeChatPane.thread;
      _launcherOpen = false;
    });
  }
}

enum _AdministrativeChatPane { inbox, thread, context }

const _catalogContextMetrics = [
  CoeloAdminChatMetric('Professores', 3),
  CoeloAdminChatMetric('Crianças', 18),
  CoeloAdminChatMetric('Responsáveis', 27),
  CoeloAdminChatMetric('Atividades', 4),
];

final class _AdministrativeChatToolbar extends StatelessWidget {
  const _AdministrativeChatToolbar({required this.selectedFilter, required this.onSelected});

  final String selectedFilter;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      child: Row(
        children: [
          Text('Conversas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in const ['Todas', 'Instituição', 'Unidade', 'Pessoas']) ...[
                    _AdministrativeFilter(
                      label: filter,
                      selected: selectedFilter == filter,
                      onPressed: () => onSelected(filter),
                    ),
                    const SizedBox(width: CoeloSpacing.space2),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AdministrativeFilter extends StatelessWidget {
  const _AdministrativeFilter({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    bool isEmphasized(Set<WidgetState> states) =>
        selected || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
    return Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton(
        key: Key('catalog-admin-filter-$label'),
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, CoeloSize.touchMin)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => isEmphasized(states) ? colors.primaryContainer : colors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => isEmphasized(states) ? colors.primary : colors.onSurface,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: isEmphasized(states) ? colors.primary : colors.outlineVariant,
              width: isEmphasized(states) ? 2 : 1,
            ),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: Text(label),
      ),
    );
  }
}

final class _AdministrativeLauncherButton extends StatelessWidget {
  const _AdministrativeLauncherButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    bool isEmphasized(Set<WidgetState> states) =>
        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
    return FilledButton.icon(
      key: const Key('catalog-admin-chat-launcher'),
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(CoeloSize.touchMin, CoeloSize.touchMin)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => isEmphasized(states) ? colors.primary : colors.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => isEmphasized(states) ? colors.onPrimary : colors.onSurface,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) =>
              BorderSide(color: isEmphasized(states) ? colors.primary : colors.outlineVariant),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text('Mensagens 3'),
    );
  }
}

final class _AdministrativeLauncherPreview extends StatelessWidget {
  const _AdministrativeLauncherPreview({
    required this.selected,
    required this.onSelected,
    required this.onClose,
    required this.onNewConversation,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('catalog-admin-chat-launcher-preview'),
      elevation: CoeloElevation.level3,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: _ConversationInbox(
        selected: selected,
        onSelected: onSelected,
        onClose: onClose,
        onNewConversation: onNewConversation,
      ),
    );
  }
}

final class _AdministrativeConversationRail extends StatelessWidget {
  const _AdministrativeConversationRail({
    required this.selected,
    required this.onSelected,
    required this.onExpand,
    required this.onNewConversation,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onExpand;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('catalog-admin-chat-rail'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          IconButton(
            tooltip: 'Expandir conversas',
            onPressed: onExpand,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Nova conversa',
            onPressed: onNewConversation,
            icon: const Icon(Icons.edit_square),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: catalogChatConversations.length,
              itemBuilder: (context, index) {
                final conversation = catalogChatConversations[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
                  child: Semantics(
                    selected: selected == index,
                    button: true,
                    label: conversation.title,
                    child: IconButton(
                      tooltip: conversation.title,
                      onPressed: () => onSelected(index),
                      icon: CoeloChatAvatar(
                        label: conversation.title,
                        initials: conversation.initials,
                        size: CoeloSize.avatarLg,
                        nowState: conversation.nowState,
                        presence: conversation.presence,
                        presenceLabel: conversation.presence == CoeloChatPresence.available
                            ? 'Equipe disponível'
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _PrincipalChatFoundation extends StatelessWidget {
  const _PrincipalChatFoundation();

  Future<void> _showNow(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Preview de Now'),
        content: AspectRatio(
          aspectRatio: 9 / 16,
          child: ColoredBox(
            color: Colors.black87,
            child: Center(child: Icon(Icons.auto_stories_outlined, color: Colors.white, size: 48)),
          ),
        ),
      ),
    );
  }

  Future<void> _showProfile(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(CoeloSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vínculos autorizados'),
              SizedBox(height: CoeloSpacing.space2),
              Text('Centro Horizonte / Unidade Cambuí / Turma Girassol'),
              SizedBox(height: CoeloSpacing.space2),
              Text('Criança relacionada: Lia'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 700,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: ListTile(
              leading: const CoeloChatAvatar(label: 'Coelo oficial', initials: 'C', size: 40),
              title: const Text('Coelo'),
              subtitle: const Text('Assistente oficial · Em breve'),
              trailing: const Icon(Icons.verified_outlined),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Coelo'),
                  content: Text('O assistente de dúvidas chegará em breve.'),
                ),
              ),
            ),
          ),
          CoeloConversationHeader(
            avatar: CoeloChatAvatar(
              key: const Key('catalog-chat-avatar-now'),
              label: 'Turma Girassol',
              initials: 'TG',
              nowState: CoeloNowState.unseen,
              presence: CoeloChatPresence.available,
              presenceLabel: 'Equipe disponível',
              onNowPressed: () => _showNow(context),
              onProfilePressed: () => _showProfile(context),
            ),
            title: 'Turma Girassol',
            subtitle: 'Centro Horizonte · Unidade Cambuí',
            onProfilePressed: () => _showProfile(context),
          ),
          const Expanded(child: _MessageHistory()),
          const _CatalogComposer(),
          NavigationBar(
            selectedIndex: 2,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Flow'),
              NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Rotina'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
            ],
          ),
        ],
      ),
    );
  }
}

final class _WebChatLauncherFoundation extends StatefulWidget {
  const _WebChatLauncherFoundation();

  @override
  State<_WebChatLauncherFoundation> createState() => _WebChatLauncherFoundationState();
}

final class _WebChatLauncherFoundationState extends State<_WebChatLauncherFoundation> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 680,
      child: Stack(
        children: [
          const Center(
            child: CoeloStatePanel(
              title: 'Suas mensagens',
              message: 'Escolha uma conversa ou inicie uma nova.',
              icon: Icons.chat_bubble_outline,
            ),
          ),
          Positioned(
            right: CoeloSpacing.space4,
            bottom: CoeloSpacing.space4,
            child: _open
                ? Material(
                    elevation: CoeloElevation.level3,
                    borderRadius: BorderRadius.circular(CoeloRadius.lg),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 340,
                      height: 460,
                      child: _ConversationInbox(
                        selected: 1,
                        onSelected: (_) {},
                        onClose: () => setState(() => _open = false),
                        onNewConversation: () {},
                      ),
                    ),
                  )
                : FilledButton.tonalIcon(
                    key: const Key('catalog-chat-launcher'),
                    onPressed: () => setState(() => _open = true),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Mensagens 3'),
                  ),
          ),
        ],
      ),
    );
  }
}

final class _ConversationInbox extends StatelessWidget {
  const _ConversationInbox({
    required this.selected,
    required this.onSelected,
    required this.onNewConversation,
    this.onClose,
    this.onCollapse,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewConversation;
  final VoidCallback? onClose;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
          ),
          child: Row(
            children: [
              Expanded(child: Text('Conversas', style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                tooltip: 'Nova conversa',
                onPressed: onNewConversation,
                icon: const Icon(Icons.edit_square),
              ),
              if (onCollapse != null)
                IconButton(
                  tooltip: 'Recolher conversas',
                  onPressed: onCollapse,
                  icon: const Icon(Icons.chevron_left),
                ),
              if (onClose != null)
                IconButton(
                  key: const Key('catalog-admin-chat-launcher-close'),
                  tooltip: 'Fechar conversas',
                  onPressed: onClose,
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
                    foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.error),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) =>
                          states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)
                          ? Theme.of(context).colorScheme.errorContainer
                          : Colors.transparent,
                    ),
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar conversas',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Expanded(
          child: ListView.builder(
            itemCount: catalogChatConversations.length,
            itemBuilder: (context, index) {
              final conversation = catalogChatConversations[index];
              return CoeloConversationTile(
                avatar: CoeloChatAvatar(
                  label: conversation.title,
                  initials: conversation.initials,
                  nowState: conversation.nowState,
                  presence: conversation.presence,
                  presenceLabel: conversation.presence == CoeloChatPresence.available
                      ? 'Equipe disponível'
                      : null,
                ),
                title: conversation.title,
                preview: conversation.preview,
                timestamp: conversation.timestamp,
                unreadCount: conversation.unreadCount,
                selected: selected == index,
                onPressed: () => onSelected(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _ConversationThread extends StatelessWidget {
  const _ConversationThread({
    this.conversation,
    this.showAdministrativeActions = false,
    this.onBack,
    this.onContext,
  });

  final CatalogChatConversation? conversation;
  final bool showAdministrativeActions;
  final VoidCallback? onBack;
  final VoidCallback? onContext;

  @override
  Widget build(BuildContext context) {
    final selected = conversation ?? catalogChatConversations[1];
    return Container(
      key: const Key('catalog-admin-chat-thread'),
      child: Column(
        children: [
          CoeloConversationHeader(
            avatar: CoeloChatAvatar(
              label: selected.title,
              initials: selected.initials,
              size: CoeloSize.avatarLg,
            ),
            title: selected.title,
            subtitle: selected.context,
            onProfilePressed: () => _showAuthorizedRelationships(context),
            actions: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Voltar para conversas',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              if (showAdministrativeActions)
                IconButton(
                  tooltip: 'Ver vínculos',
                  onPressed: () => _showAuthorizedRelationships(context),
                  icon: const Icon(Icons.account_tree_outlined),
                ),
              if (onContext != null)
                IconButton(
                  tooltip: 'Ver contexto',
                  onPressed: onContext,
                  icon: const Icon(Icons.info_outline),
                ),
            ],
          ),
          const Expanded(child: _MessageHistory()),
          const _CatalogComposer(),
        ],
      ),
    );
  }

  Future<void> _showAuthorizedRelationships(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vínculos autorizados'),
        content: const Text('Centro Horizonte / Unidade Cambuí / Turma Girassol'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }
}

final class _MessageHistory extends StatelessWidget {
  const _MessageHistory();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      children: const [
        Center(child: Text('Hoje, 16:30')),
        CoeloMessageBubble(
          direction: CoeloMessageDirection.received,
          authorLabel: 'Marina · Professora',
          contextLabel: 'Turma Girassol',
          childLabels: ['Lia'],
          body: 'A atividade de hoje termina às 17h.',
          timestamp: '16:32',
        ),
        CoeloMessageBubble(
          direction: CoeloMessageDirection.sent,
          body: 'Obrigada pelo aviso.',
          timestamp: '16:34',
          deliveryState: CoeloMessageDeliveryState.read,
        ),
      ],
    );
  }
}

final class _CatalogComposer extends StatefulWidget {
  const _CatalogComposer();

  @override
  State<_CatalogComposer> createState() => _CatalogComposerState();
}

final class _CatalogComposerState extends State<_CatalogComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoeloChatComposer(
      controller: _controller,
      onSend: _controller.clear,
      showAudioAction: true,
      showMediaAction: true,
      onAudioPressed: () => _showSimulation(context, 'Gravando áudio…'),
      onMediaPressed: () => _showSimulation(context, 'Carregando mídia…'),
    );
  }

  void _showSimulation(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _ChatStatesFoundation extends StatelessWidget {
  const _ChatStatesFoundation();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space4,
      runSpacing: CoeloSpacing.space4,
      children: const [
        _StatePreview(
          title: 'Carregando conversas',
          message: 'Buscando apenas os contextos autorizados.',
          icon: Icons.hourglass_top_outlined,
        ),
        _StatePreview(
          title: 'Sem conversas',
          message: 'Inicie uma conversa dentro de um contexto autorizado.',
          icon: Icons.chat_bubble_outline,
        ),
        _StatePreview(
          title: 'Sem conexão',
          message: 'Verifique sua internet e tente novamente.',
          icon: Icons.cloud_off_outlined,
        ),
        _StatePreview(
          title: 'Não foi possível carregar',
          message: 'Tente novamente sem perder o contexto selecionado.',
          icon: Icons.error_outline,
        ),
        _StatePreview(
          title: 'Somente leitura',
          message: 'Este vínculo terminou. O histórico continua disponível.',
          icon: Icons.lock_outline,
        ),
        _StatePreview(
          title: 'Acesso bloqueado',
          message: 'Você não possui permissão para ver esta conversa.',
          icon: Icons.block_outlined,
        ),
        _StatePreview(
          title: 'Acesso revogado',
          message: 'O fio saiu da inbox e permanece no histórico somente leitura.',
          icon: Icons.history_toggle_off_outlined,
        ),
        _StatePreview(
          title: 'Coelo · Em breve',
          message: 'O assistente oficial ainda não está disponível.',
          icon: Icons.smart_toy_outlined,
        ),
      ],
    );
  }
}

final class _StatePreview extends StatelessWidget {
  const _StatePreview({required this.title, required this.message, required this.icon});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 304,
      child: Card(
        child: CoeloStatePanel(title: title, message: message, icon: icon),
      ),
    );
  }
}
