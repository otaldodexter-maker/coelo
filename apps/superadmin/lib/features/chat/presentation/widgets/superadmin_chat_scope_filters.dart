import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../chat_fixtures.dart';

enum SuperadminChatScopeKind { concept, institution, unit, group, activity, child }

extension SuperadminChatScopeKindLabel on SuperadminChatScopeKind {
  String get id => name;

  String get label => switch (this) {
    SuperadminChatScopeKind.concept => 'Todas',
    SuperadminChatScopeKind.institution => 'Instituição',
    SuperadminChatScopeKind.unit => 'Unidade',
    SuperadminChatScopeKind.group => 'Grupo/Turma',
    SuperadminChatScopeKind.activity => 'Atividade',
    SuperadminChatScopeKind.child => 'Criança',
  };
}

const _conceptLabels = <String, String>{
  'all': 'Todas',
  'institutions-units': 'Instituições e unidades',
  'groups': 'Turmas',
  'activities': 'Atividades',
};

final class SuperadminChatScopeFilters extends StatelessWidget {
  const SuperadminChatScopeFilters({required this.selections, required this.onChanged, super.key});

  final Map<SuperadminChatScopeKind, String> selections;
  final void Function(SuperadminChatScopeKind kind, String? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
      child: Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final kind in SuperadminChatScopeKind.values)
            _ScopeFilterButton(
              key: Key('superadmin-chat-filter-${kind.id}'),
              label: selections[kind] == null
                  ? kind.label
                  : superadminChatScopeOptionLabel(kind, selections[kind]!),
              semanticLabel: selections[kind] == null
                  ? 'Filtrar por ${kind.label}'
                  : '${kind.label}: ${superadminChatScopeOptionLabel(kind, selections[kind]!)}',
              selectedValue: selections[kind],
              options: superadminChatScopeOptions(kind, selections),
              optionLabel: (value) => superadminChatScopeOptionLabel(kind, value),
              onSelected: (value) => onChanged(kind, value),
            ),
        ],
      ),
    );
  }
}

final class _ScopeFilterButton extends StatefulWidget {
  const _ScopeFilterButton({
    required this.label,
    required this.semanticLabel,
    required this.selectedValue,
    required this.options,
    required this.optionLabel,
    required this.onSelected,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final String? selectedValue;
  final List<String> options;
  final String Function(String value) optionLabel;
  final ValueChanged<String?> onSelected;

  @override
  State<_ScopeFilterButton> createState() => _ScopeFilterButtonState();
}

final class _ScopeFilterButtonState extends State<_ScopeFilterButton> {
  final _controller = MenuController();
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _open || widget.selectedValue != null;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, CoeloSpacing.spaceHalf),
      onOpen: () => setState(() => _open = true),
      onClose: () => setState(() => _open = false),
      menuChildren: [
        MenuItemButton(
          onPressed: () => widget.onSelected(null),
          style: _menuItemStyle(context, widget.selectedValue == null),
          child: const Text('Todos'),
        ),
        for (final option in widget.options)
          MenuItemButton(
            onPressed: () => widget.onSelected(option),
            style: _menuItemStyle(context, widget.selectedValue == option),
            child: Text(widget.optionLabel(option)),
          ),
      ],
      builder: (context, controller, _) {
        return Semantics(
          button: true,
          label: widget.semanticLabel,
          child: Material(
            color: active ? colors.primaryContainer : colors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: _open ? colors.primary : colors.outlineVariant,
                width: _open ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: controller.isOpen ? controller.close : controller.open,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: CoeloSize.touchMin, maxWidth: 240),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: active
                              ? Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(color: colors.primary)
                              : null,
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space1),
                      Icon(
                        controller.isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: CoeloSize.iconSm,
                        color: active ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _menuItemStyle(BuildContext context, bool selected) {
    final colors = Theme.of(context).colorScheme;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(224, CoeloSize.touchMin)),
      foregroundColor: WidgetStatePropertyAll(selected ? colors.primary : colors.onSurface),
      backgroundColor: WidgetStatePropertyAll(
        selected ? colors.primaryContainer : Colors.transparent,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
            ? colors.primaryContainer
            : Colors.transparent,
      ),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
  }
}

String superadminChatScopeOptionLabel(SuperadminChatScopeKind kind, String value) {
  if (kind == SuperadminChatScopeKind.concept) {
    return _conceptLabels[value] ?? 'Todas';
  }
  return value;
}

List<String> superadminChatScopeOptions(
  SuperadminChatScopeKind kind,
  Map<SuperadminChatScopeKind, String> selections,
) {
  if (kind == SuperadminChatScopeKind.concept) {
    return _conceptLabels.keys.skip(1).toList(growable: false);
  }
  final compatible = superadminChatConversations.where((conversation) {
    bool matches(SuperadminChatScopeKind parent, String? actual) {
      final selected = selections[parent];
      return selected == null || selected == actual;
    }

    return switch (kind) {
      SuperadminChatScopeKind.institution => true,
      SuperadminChatScopeKind.unit => matches(
        SuperadminChatScopeKind.institution,
        conversation.institution,
      ),
      SuperadminChatScopeKind.group =>
        matches(SuperadminChatScopeKind.institution, conversation.institution) &&
            matches(SuperadminChatScopeKind.unit, conversation.unit),
      SuperadminChatScopeKind.activity =>
        matches(SuperadminChatScopeKind.institution, conversation.institution) &&
            matches(SuperadminChatScopeKind.unit, conversation.unit) &&
            matches(SuperadminChatScopeKind.group, conversation.group),
      SuperadminChatScopeKind.child =>
        matches(SuperadminChatScopeKind.institution, conversation.institution) &&
            matches(SuperadminChatScopeKind.unit, conversation.unit) &&
            matches(SuperadminChatScopeKind.group, conversation.group) &&
            matches(SuperadminChatScopeKind.activity, conversation.activity),
      SuperadminChatScopeKind.concept => true,
    };
  });

  final values = <String>{};
  for (final conversation in compatible) {
    switch (kind) {
      case SuperadminChatScopeKind.institution:
        values.add(conversation.institution);
      case SuperadminChatScopeKind.unit:
        if (conversation.unit case final value?) values.add(value);
      case SuperadminChatScopeKind.group:
        if (conversation.group case final value?) values.add(value);
      case SuperadminChatScopeKind.activity:
        if (conversation.activity case final value?) values.add(value);
      case SuperadminChatScopeKind.child:
        values.addAll(conversation.children);
      case SuperadminChatScopeKind.concept:
        break;
    }
  }
  return values.toList(growable: false);
}

Map<SuperadminChatScopeKind, String> updatedSuperadminChatScope(
  Map<SuperadminChatScopeKind, String> current,
  SuperadminChatScopeKind kind,
  String? value,
) {
  final next = Map<SuperadminChatScopeKind, String>.of(current);
  if (value == null) {
    next.remove(kind);
  } else {
    next[kind] = value;
  }
  final descendants = switch (kind) {
    SuperadminChatScopeKind.concept => const <SuperadminChatScopeKind>[],
    SuperadminChatScopeKind.institution => const [
      SuperadminChatScopeKind.unit,
      SuperadminChatScopeKind.group,
      SuperadminChatScopeKind.activity,
      SuperadminChatScopeKind.child,
    ],
    SuperadminChatScopeKind.unit => const [
      SuperadminChatScopeKind.group,
      SuperadminChatScopeKind.activity,
      SuperadminChatScopeKind.child,
    ],
    SuperadminChatScopeKind.group => const [
      SuperadminChatScopeKind.activity,
      SuperadminChatScopeKind.child,
    ],
    SuperadminChatScopeKind.activity => const [SuperadminChatScopeKind.child],
    SuperadminChatScopeKind.child => const <SuperadminChatScopeKind>[],
  };
  for (final descendant in descendants) {
    next.remove(descendant);
  }
  return next;
}

bool matchesSuperadminChatScope(
  SuperadminChatConversation conversation,
  Map<SuperadminChatScopeKind, String> selections,
) {
  for (final entry in selections.entries) {
    final matches = switch (entry.key) {
      SuperadminChatScopeKind.concept => switch (entry.value) {
        'institutions-units' =>
          conversation.targetKind == CoeloAdminContextKind.institution ||
              conversation.targetKind == CoeloAdminContextKind.unit,
        'groups' => conversation.targetKind == CoeloAdminContextKind.group,
        'activities' => conversation.targetKind == CoeloAdminContextKind.activity,
        _ => true,
      },
      SuperadminChatScopeKind.institution => conversation.institution == entry.value,
      SuperadminChatScopeKind.unit => conversation.unit == entry.value,
      SuperadminChatScopeKind.group => conversation.group == entry.value,
      SuperadminChatScopeKind.activity => conversation.activity == entry.value,
      SuperadminChatScopeKind.child => conversation.children.contains(entry.value),
    };
    if (!matches) return false;
  }
  return true;
}
