import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../chat_models.dart';

enum SuperadminChatHierarchySelection { single, multiple }

final class SuperadminChatHierarchySelector extends StatefulWidget {
  const SuperadminChatHierarchySelector({
    required this.options,
    required this.selectedIds,
    required this.onChanged,
    this.selection = SuperadminChatHierarchySelection.multiple,
    this.showSelectAll = true,
    super.key,
  });

  final List<SuperadminChatContextOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final SuperadminChatHierarchySelection selection;
  final bool showSelectAll;

  @override
  State<SuperadminChatHierarchySelector> createState() => _SuperadminChatHierarchySelectorState();
}

final class _SuperadminChatHierarchySelectorState extends State<SuperadminChatHierarchySelector> {
  final _search = TextEditingController();
  final _expanded = <String>{};
  ChatContextKind? _kind;
  var _guardiansOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _filterTree(widget.options, query, _kind, guardiansOnly: _guardiansOnly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoeloSearchField(
          key: const Key('superadmin-chat-hierarchy-search'),
          controller: _search,
          hintText: 'Buscar na hierarquia',
          semanticLabel: 'Buscar instituições, unidades, grupos, atividades e pessoas',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Wrap(
          spacing: CoeloSpacing.space1,
          runSpacing: CoeloSpacing.space1,
          children: [
            _category(null, 'Todos'),
            _category(ChatContextKind.institution, 'Instituições'),
            _category(ChatContextKind.unit, 'Unidades'),
            _category(ChatContextKind.group, 'Grupos'),
            _category(ChatContextKind.activity, 'Atividades'),
            _category(ChatContextKind.person, 'Pessoas'),
            _guardianCategory(),
          ],
        ),
        if (widget.showSelectAll &&
            widget.selection == SuperadminChatHierarchySelection.multiple) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                final ids = _selectableIds(visible, kind: _kind, guardiansOnly: _guardiansOnly);
                final next = Set<String>.of(widget.selectedIds);
                final allSelected = ids.isNotEmpty && ids.every(next.contains);
                allSelected ? next.removeAll(ids) : next.addAll(ids);
                widget.onChanged(next);
              },
              icon: const Icon(Icons.library_add_check_outlined),
              label: const Text('Selecionar todos'),
            ),
          ),
        ],
        const SizedBox(height: CoeloSpacing.space1),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(CoeloSpacing.space4),
            child: Text('Nenhum resultado nesta hierarquia.', textAlign: TextAlign.center),
          )
        else
          for (final option in visible) _node(option, 0),
      ],
    );
  }

  Widget _category(ChatContextKind? kind, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: !_guardiansOnly && _kind == kind,
      onSelected: (_) => setState(() {
        _guardiansOnly = false;
        _kind = kind;
      }),
    );
  }

  Widget _guardianCategory() {
    return ChoiceChip(
      label: const Text('Responsáveis'),
      selected: _guardiansOnly,
      onSelected: (_) => setState(() {
        _kind = ChatContextKind.person;
        _guardiansOnly = true;
      }),
    );
  }

  Widget _node(SuperadminChatContextOption option, int depth) {
    final descendants = _idsOf([option]);
    final selectedCount = descendants.where(widget.selectedIds.contains).length;
    final selected = selectedCount == descendants.length;
    final partial = selectedCount > 0 && !selected;
    final hasChildren = option.children.isNotEmpty;
    final expanded =
        _expanded.contains(option.id) ||
        _kind != null ||
        _guardiansOnly ||
        _search.text.trim().isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * CoeloSpacing.space3),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              key: Key('superadmin-chat-hierarchy-${option.id}'),
              value: partial ? null : selected,
              tristate: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space1),
              title: Text(option.label),
              subtitle: Text(
                _kindLabel(option.kind),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              secondary: hasChildren
                  ? IconButton(
                      tooltip: expanded ? 'Recolher ${option.label}' : 'Expandir ${option.label}',
                      onPressed: () => setState(() {
                        expanded ? _expanded.remove(option.id) : _expanded.add(option.id);
                      }),
                      icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                    )
                  : null,
              onChanged: (_) => _toggle(descendants, selected),
            ),
          ),
          if (hasChildren && expanded)
            for (final child in option.children) _node(child, depth + 1),
        ],
      ),
    );
  }

  void _toggle(Set<String> ids, bool selected) {
    if (widget.selection == SuperadminChatHierarchySelection.single) {
      widget.onChanged(selected ? <String>{} : {ids.first});
      return;
    }
    final next = Set<String>.of(widget.selectedIds);
    selected ? next.removeAll(ids) : next.addAll(ids);
    widget.onChanged(next);
  }
}

List<SuperadminChatContextOption> _filterTree(
  List<SuperadminChatContextOption> options,
  String query,
  ChatContextKind? kind, {
  required bool guardiansOnly,
}) {
  final matches = <SuperadminChatContextOption>[];
  for (final option in options) {
    final match = _filteredOption(option, query, kind, guardiansOnly: guardiansOnly);
    if (match != null) matches.add(match);
  }
  return matches;
}

SuperadminChatContextOption? _filteredOption(
  SuperadminChatContextOption option,
  String query,
  ChatContextKind? kind, {
  required bool guardiansOnly,
}) {
  final children = _filterTree(option.children, query, kind, guardiansOnly: guardiansOnly);
  final matchesQuery = query.isEmpty || option.label.toLowerCase().contains(query);
  final matchesKind = guardiansOnly
      ? option.kind == ChatContextKind.person &&
            (option.subtitle?.toLowerCase().contains('respons') ?? false)
      : kind == null || option.kind == kind;
  if ((!matchesQuery || !matchesKind) && children.isEmpty) return null;
  return SuperadminChatContextOption(
    id: option.id,
    label: option.label,
    kind: option.kind,
    subtitle: option.subtitle,
    children: children,
  );
}

Set<String> _idsOf(List<SuperadminChatContextOption> options) => {
  for (final option in options) ...{option.id, ..._idsOf(option.children)},
};

Set<String> _selectableIds(
  List<SuperadminChatContextOption> options, {
  required ChatContextKind? kind,
  required bool guardiansOnly,
}) {
  final ids = <String>{};
  for (final option in options) {
    final selectable = guardiansOnly
        ? option.kind == ChatContextKind.person &&
              (option.subtitle?.toLowerCase().contains('respons') ?? false)
        : kind == null || option.kind == kind;
    if (selectable) ids.add(option.id);
    ids.addAll(_selectableIds(option.children, kind: kind, guardiansOnly: guardiansOnly));
  }
  return ids;
}

String _kindLabel(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => 'Instituição',
  ChatContextKind.unit => 'Unidade',
  ChatContextKind.group => 'Grupo/Turma',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
  ChatContextKind.conversationGroup => 'Grupo de conversa',
};
