import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../domain/help_center_conversation.dart';

const _demoResponse =
    'A Central de ajuda ainda é uma demonstração. Em breve, ela usará a base '
    'de conhecimento do Coelo para responder com orientações verificadas.';

class SuperadminHelpCenterPage extends StatefulWidget {
  const SuperadminHelpCenterPage({required this.logout, this.onDestinationSelected, super.key});

  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<SuperadminHelpCenterPage> createState() => _SuperadminHelpCenterPageState();
}

class _SuperadminHelpCenterPageState extends State<SuperadminHelpCenterPage> {
  final _composerController = TextEditingController();
  final _conversations = <HelpCenterConversation>[];
  String? _selectedId;
  int _nextId = 1;
  bool _historyCollapsed = false;

  HelpCenterConversation? get _selectedConversation {
    for (final conversation in _conversations) {
      if (conversation.id == _selectedId) {
        return conversation;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  void _startConversation() {
    setState(() => _selectedId = null);
    _composerController.clear();
  }

  void _selectConversation(String id) {
    if (_selectedId == id) {
      return;
    }
    setState(() => _selectedId = id);
    _composerController.clear();
  }

  void _send() {
    final question = _composerController.text.trim();
    if (question.isEmpty) {
      return;
    }

    final conversationId = _selectedId ?? 'conversation-${_nextId++}';
    final selected = _selectedConversation;
    final messages = <HelpCenterMessage>[
      ...?selected?.messages,
      HelpCenterMessage(
        id: 'message-${_nextId++}',
        author: HelpCenterMessageAuthor.user,
        content: question,
      ),
      HelpCenterMessage(
        id: 'message-${_nextId++}',
        author: HelpCenterMessageAuthor.assistant,
        content: _demoResponse,
      ),
    ];
    final updated = HelpCenterConversation(
      id: conversationId,
      title: selected?.title ?? _titleFor(question),
      messages: List.unmodifiable(messages),
    );

    setState(() {
      final index = _conversations.indexWhere((conversation) => conversation.id == conversationId);
      if (index < 0) {
        _conversations.insert(0, updated);
      } else {
        _conversations[index] = updated;
      }
      _selectedId = conversationId;
    });
    _composerController.clear();
  }

  String _titleFor(String question) {
    const limit = 44;
    if (question.length <= limit) {
      return question;
    }
    return '${question.substring(0, limit - 1).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      currentDestination: 'home',
      title: 'Home',
      subtitle: 'Tire dúvidas e encontre orientações sobre o Coelo.',
      onDestinationSelected: widget.onDestinationSelected,
      child: _HelpCenterBody(
        conversations: List.unmodifiable(_conversations),
        selectedConversation: _selectedConversation,
        composerController: _composerController,
        onNewConversation: _startConversation,
        onConversationSelected: _selectConversation,
        onSend: _send,
        historyCollapsed: _historyCollapsed,
        onHistoryCollapsedChanged: (collapsed) => setState(() => _historyCollapsed = collapsed),
      ),
    );
  }
}

class _HelpCenterBody extends StatelessWidget {
  const _HelpCenterBody({
    required this.conversations,
    required this.selectedConversation,
    required this.composerController,
    required this.onNewConversation,
    required this.onConversationSelected,
    required this.onSend,
    required this.historyCollapsed,
    required this.onHistoryCollapsedChanged,
  });

  final List<HelpCenterConversation> conversations;
  final HelpCenterConversation? selectedConversation;
  final TextEditingController composerController;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversationSelected;
  final VoidCallback onSend;
  final bool historyCollapsed;
  final ValueChanged<bool> onHistoryCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentInset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final isExpanded = viewportWidth >= CoeloBreakpoints.expanded.minWidth;
        final collapseForTextScale = MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final showCollapsedHistory = historyCollapsed || collapseForTextScale;
        final content = viewportWidth < CoeloBreakpoints.medium.minWidth
            ? Column(
                key: const Key('superadmin-help-history-stacked'),
                children: [
                  _StackedHistory(
                    conversations: conversations,
                    selectedId: selectedConversation?.id,
                    onNewConversation: onNewConversation,
                    onConversationSelected: onConversationSelected,
                  ),
                  Expanded(child: _thread()),
                ],
              )
            : Row(
                children: [
                  if (isExpanded && !showCollapsedHistory)
                    SizedBox(
                      key: const Key('superadmin-help-history-panel'),
                      width: 296,
                      child: _HistoryPanel(
                        conversations: conversations,
                        selectedId: selectedConversation?.id,
                        onNewConversation: onNewConversation,
                        onConversationSelected: onConversationSelected,
                        onCollapse: () => onHistoryCollapsedChanged(true),
                      ),
                    )
                  else if (isExpanded)
                    SizedBox(
                      key: const Key('superadmin-help-history-collapsed'),
                      width: 88,
                      child: _HistoryRail(
                        conversations: conversations,
                        selectedId: selectedConversation?.id,
                        onNewConversation: onNewConversation,
                        onConversationSelected: onConversationSelected,
                        onExpand: () => onHistoryCollapsedChanged(false),
                      ),
                    )
                  else
                    SizedBox(
                      key: const Key('superadmin-help-history-rail'),
                      width: 88,
                      child: _HistoryRail(
                        conversations: conversations,
                        selectedId: selectedConversation?.id,
                        onNewConversation: onNewConversation,
                        onConversationSelected: onConversationSelected,
                      ),
                    ),
                  VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                  Expanded(child: _thread()),
                ],
              );
        return Padding(
          key: const Key('superadmin-help-content-insets'),
          padding: EdgeInsets.all(contentInset),
          child: content,
        );
      },
    );
  }

  Widget _thread() {
    return _HelpThread(
      conversation: selectedConversation,
      composerController: composerController,
      onSend: onSend,
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.conversations,
    required this.selectedId,
    required this.onNewConversation,
    required this.onConversationSelected,
    required this.onCollapse,
  });

  final List<HelpCenterConversation> conversations;
  final String? selectedId;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversationSelected;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actionColors = theme.extension<CoeloActionColors>()!;
    return Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Nova conversa',
                  child: FilledButton.tonalIcon(
                    onPressed: onNewConversation,
                    style: _brandFilledButtonStyle(colors, actionColors),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nova conversa'),
                  ),
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              IconButton(
                tooltip: 'Recolher histórico',
                onPressed: onCollapse,
                style: _discreteIconButtonStyle(colors),
                icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space5),
          Text('Conversas', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space2),
          Expanded(
            child: conversations.isEmpty
                ? Text(
                    'Suas dúvidas desta sessão aparecerão aqui.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space1),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _ConversationTile(
                        conversation: conversation,
                        selected: conversation.id == selectedId,
                        onTap: () => onConversationSelected(conversation.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRail extends StatelessWidget {
  const _HistoryRail({
    required this.conversations,
    required this.selectedId,
    required this.onNewConversation,
    required this.onConversationSelected,
    this.onExpand,
  });

  final List<HelpCenterConversation> conversations;
  final String? selectedId;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversationSelected;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actionColors = theme.extension<CoeloActionColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
      child: Column(
        children: [
          if (onExpand != null) ...[
            IconButton(
              tooltip: 'Expandir histórico',
              onPressed: onExpand,
              style: _discreteIconButtonStyle(colors),
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
            ),
            const SizedBox(height: CoeloSpacing.space2),
          ],
          IconButton.filled(
            tooltip: 'Nova conversa',
            onPressed: onNewConversation,
            style: _brandIconButtonStyle(colors, actionColors),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Expanded(
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
                  child: Tooltip(
                    message: conversation.title,
                    child: IconButton(
                      onPressed: () => onConversationSelected(conversation.id),
                      isSelected: conversation.id == selectedId,
                      selectedIcon: const Icon(Icons.chat_rounded),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
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

class _StackedHistory extends StatelessWidget {
  const _StackedHistory({
    required this.conversations,
    required this.selectedId,
    required this.onNewConversation,
    required this.onConversationSelected,
  });

  final List<HelpCenterConversation> conversations;
  final String? selectedId;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onConversationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = conversations
        .where((conversation) => conversation.id == selectedId)
        .firstOrNull;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CoeloSpacing.space3,
          CoeloSpacing.space2,
          CoeloSpacing.space2,
          CoeloSpacing.space2,
        ),
        child: Row(
          children: [
            Expanded(
              child: MenuAnchor(
                menuChildren: [
                  for (final conversation in conversations)
                    MenuItemButton(
                      onPressed: () => onConversationSelected(conversation.id),
                      leadingIcon: Icon(
                        conversation.id == selectedId
                            ? Icons.chat_rounded
                            : Icons.chat_bubble_outline_rounded,
                      ),
                      child: Text(conversation.title),
                    ),
                ],
                builder: (context, controller, child) {
                  return TextButton.icon(
                    onPressed: conversations.isEmpty
                        ? null
                        : () => controller.isOpen ? controller.close() : controller.open(),
                    icon: const Icon(Icons.history_rounded),
                    label: Text(
                      selected?.title ?? 'Histórico da sessão',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'Nova conversa',
              onPressed: onNewConversation,
              style: _discreteIconButtonStyle(colors),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final HelpCenterConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space3,
                vertical: CoeloSpacing.space2,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: selected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(
                    child: Text(conversation.title, maxLines: 2, overflow: TextOverflow.ellipsis),
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

class _HelpThread extends StatelessWidget {
  const _HelpThread({
    required this.conversation,
    required this.composerController,
    required this.onSend,
  });

  final HelpCenterConversation? conversation;
  final TextEditingController composerController;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('superadmin-help-thread'),
      children: [
        Expanded(
          child: conversation == null
              ? _HelpEmptyState(controller: composerController)
              : _MessageList(conversation: conversation!),
        ),
        _HelpComposer(controller: composerController, onSend: onSend),
      ],
    );
  }
}

class _HelpEmptyState extends StatelessWidget {
  const _HelpEmptyState({required this.controller});

  final TextEditingController controller;

  static const suggestions = [
    'Como cadastro uma instituição?',
    'Onde encontro os planos?',
    'Como acompanho um chamado?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoeloSpacing.space5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  child: Icon(Icons.auto_awesome_rounded, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Text(
                'Como podemos ajudar?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                'Pergunte sobre recursos, rotinas e navegação do Coelo.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: CoeloSpacing.space5),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.arrow_outward_rounded, size: 18),
                      label: Text(suggestion),
                      backgroundColor: colors.primaryContainer,
                      side: BorderSide(color: colors.outlineVariant),
                      color: WidgetStatePropertyAll(colors.primaryContainer),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                      iconTheme: IconThemeData(color: colors.primary),
                      surfaceTintColor: Colors.transparent,
                      onPressed: () {
                        controller.text = suggestion;
                        controller.selection = TextSelection.collapsed(
                          offset: controller.text.length,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.conversation});

  final HelpCenterConversation conversation;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space5,
        vertical: CoeloSpacing.space6,
      ),
      itemCount: conversation.messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space4),
      itemBuilder: (context, index) {
        final message = conversation.messages[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _Message(message: message),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final HelpCenterMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUser = message.author == HelpCenterMessageAuthor.user;
    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? colors.secondaryContainer : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(CoeloRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space4,
              vertical: CoeloSpacing.space3,
            ),
            child: Text(
              message.content,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isUser ? colors.onSecondaryContainer : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpComposer extends StatefulWidget {
  const _HelpComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  State<_HelpComposer> createState() => _HelpComposerState();
}

class _HelpComposerState extends State<_HelpComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _HelpComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _insertNewLine() {
    final value = widget.controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final nextText = value.text.replaceRange(selection.start, selection.end, '\n');
    widget.controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canSend = widget.controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CoeloSpacing.space3,
          CoeloSpacing.space2,
          CoeloSpacing.space3,
          CoeloSpacing.space3,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Material(
                    color: colors.surface,
                    elevation: 2,
                    shadowColor: colors.shadow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(CoeloRadius.xl),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            _insertNewLine();
                          } else {
                            widget.onSend();
                          }
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        key: const Key('superadmin-help-composer-field'),
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Pergunte sobre o Coelo',
                          prefixIcon: const Icon(Icons.auto_awesome_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(CoeloRadius.xl),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                IconButton.filled(
                  tooltip: 'Enviar pergunta',
                  onPressed: canSend ? widget.onSend : null,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(CoeloSize.touchMin),
                    fixedSize: const Size.square(CoeloSize.touchMin),
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.primaryContainer,
                    disabledForegroundColor: colors.onPrimaryContainer,
                    overlayColor: Colors.transparent,
                  ),
                  icon: const SizedBox.square(
                    dimension: CoeloSize.iconMd,
                    child: Center(child: Icon(Icons.send_rounded)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _brandFilledButtonStyle(ColorScheme colors, CoeloActionColors actionColors) {
  return FilledButton.styleFrom(
    backgroundColor: colors.primary,
    foregroundColor: colors.onPrimary,
    disabledBackgroundColor: colors.surfaceContainer,
    disabledForegroundColor: colors.onSurfaceVariant,
    overlayColor: Colors.transparent,
  ).copyWith(backgroundColor: _brandBackgroundColor(colors, actionColors));
}

ButtonStyle _brandIconButtonStyle(ColorScheme colors, CoeloActionColors actionColors) {
  return IconButton.styleFrom(
    minimumSize: const Size.square(CoeloSize.touchMin),
    fixedSize: const Size.square(CoeloSize.touchMin),
    padding: EdgeInsets.zero,
    backgroundColor: colors.primary,
    foregroundColor: colors.onPrimary,
    disabledBackgroundColor: colors.surfaceContainer,
    disabledForegroundColor: colors.onSurfaceVariant,
    overlayColor: Colors.transparent,
  ).copyWith(backgroundColor: _brandBackgroundColor(colors, actionColors));
}

WidgetStateProperty<Color?> _brandBackgroundColor(
  ColorScheme colors,
  CoeloActionColors actionColors,
) => WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.disabled)) {
    return colors.surfaceContainer;
  }
  if (states.contains(WidgetState.pressed)) {
    return actionColors.primaryPressed;
  }
  if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
    return actionColors.primaryHover;
  }
  return colors.primary;
});

ButtonStyle _discreteIconButtonStyle(ColorScheme colors) {
  return IconButton.styleFrom(
    foregroundColor: colors.onSurfaceVariant,
    hoverColor: colors.primaryContainer,
    focusColor: colors.primaryContainer,
    highlightColor: colors.primaryContainer,
  );
}
