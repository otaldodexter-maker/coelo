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
    final descendants = _descendantIds(widget.options);
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
            _category(ChatContextKind.child, 'Crianças'),
          ],
        ),
        if (widget.selection == SuperadminChatHierarchySelection.multiple) ...[
          const SizedBox(height: CoeloSpacing.space2),
          _selectionSummary(),
        ],
        if (widget.showSelectAll &&
            widget.selection == SuperadminChatHierarchySelection.multiple) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('superadmin-chat-hierarchy-select-visible'),
              onPressed: () {
                final ids = _selectableIds(visible, kind: _kind, guardiansOnly: _guardiansOnly);
                final next = Set<String>.of(widget.selectedIds);
                final allSelected = ids.isNotEmpty && ids.every(next.contains);
                allSelected ? next.removeAll(ids) : next.addAll(ids);
                widget.onChanged(next);
              },
              icon: const Icon(Icons.library_add_check_outlined),
              label: Text(_bulkLabel(_kind, _guardiansOnly)),
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
          for (final option in visible) _node(option, 0, descendants),
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

  Widget _selectionSummary() {
    final selected = _flatten(
      widget.options,
    ).where((option) => widget.selectedIds.contains(option.id));
    final labels = <String>[];
    for (final category in _summaryCategories) {
      final count = selected.where(category.matches).length;
      if (count > 0) labels.add('$count ${count == 1 ? category.singular : category.plural}');
    }
    return Semantics(
      liveRegion: true,
      child: Wrap(
        key: const Key('superadmin-chat-hierarchy-selection-summary'),
        spacing: CoeloSpacing.space1,
        runSpacing: CoeloSpacing.space1,
        children: labels.isEmpty
            ? const [Text('Nenhum contexto selecionado')]
            : [for (final label in labels) Chip(label: Text(label))],
      ),
    );
  }

  Widget _node(
    SuperadminChatContextOption option,
    int depth,
    Map<String, Set<String>> descendants,
  ) {
    final ids = descendants[option.id] ?? {option.id};
    final selectedCount = ids.where(widget.selectedIds.contains).length;
    final selected = selectedCount == ids.length;
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
              onChanged: (_) => _toggle(option, ids, selected),
            ),
          ),
          if (hasChildren && expanded)
            for (final child in option.children) _node(child, depth + 1, descendants),
        ],
      ),
    );
  }

  void _toggle(SuperadminChatContextOption option, Set<String> ids, bool selected) {
    if (widget.selection == SuperadminChatHierarchySelection.single) {
      widget.onChanged(selected ? <String>{} : {option.id});
      return;
    }
    final next = Set<String>.of(widget.selectedIds);
    selected ? next.removeAll(ids) : next.addAll(ids);
    widget.onChanged(next);
  }
}

final class _SummaryCategory {
  const _SummaryCategory(this.singular, this.plural, this.matches);

  final String singular;
  final String plural;
  final bool Function(SuperadminChatContextOption option) matches;
}

final _summaryCategories = [
  _SummaryCategory(
    'instituição',
    'instituições',
    (option) => option.kind == ChatContextKind.institution,
  ),
  _SummaryCategory('unidade', 'unidades', (option) => option.kind == ChatContextKind.unit),
  _SummaryCategory('grupo', 'grupos', (option) => option.kind == ChatContextKind.group),
  _SummaryCategory('atividade', 'atividades', (option) => option.kind == ChatContextKind.activity),
  _SummaryCategory(
    'pessoa',
    'pessoas',
    (option) => option.kind == ChatContextKind.person && !option.isGuardian,
  ),
  _SummaryCategory(
    'responsável',
    'responsáveis',
    (option) => option.kind == ChatContextKind.person && option.isGuardian,
  ),
  _SummaryCategory('criança', 'crianças', (option) => option.kind == ChatContextKind.child),
];

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
      ? option.kind == ChatContextKind.person && option.isGuardian
      : kind == null || option.kind == kind;
  if ((!matchesQuery || !matchesKind) && children.isEmpty) return null;
  return SuperadminChatContextOption(
    id: option.id,
    label: option.label,
    kind: option.kind,
    subtitle: option.subtitle,
    isGuardian: option.isGuardian,
    guardianIds: option.guardianIds,
    children: children,
  );
}

Map<String, Set<String>> _descendantIds(List<SuperadminChatContextOption> options) {
  final result = <String, Set<String>>{};
  Set<String> visit(SuperadminChatContextOption option) {
    final ids = <String>{option.id};
    for (final child in option.children) {
      ids.addAll(visit(child));
    }
    result[option.id] = ids;
    return ids;
  }

  for (final option in options) {
    visit(option);
  }
  return result;
}

List<SuperadminChatContextOption> _flatten(List<SuperadminChatContextOption> options) => [
  for (final option in options) ...[option, ..._flatten(option.children)],
];

Set<String> _selectableIds(
  List<SuperadminChatContextOption> options, {
  required ChatContextKind? kind,
  required bool guardiansOnly,
}) => {
  for (final option in options) ...[
    if (guardiansOnly
        ? option.kind == ChatContextKind.person && option.isGuardian
        : kind == null || option.kind == kind)
      option.id,
    ..._selectableIds(option.children, kind: kind, guardiansOnly: guardiansOnly),
  ],
};

String _bulkLabel(ChatContextKind? kind, bool guardiansOnly) {
  if (guardiansOnly) return 'Selecionar todos os responsáveis';
  return switch (kind) {
    ChatContextKind.institution => 'Selecionar todas as instituições',
    ChatContextKind.unit => 'Selecionar todas as unidades',
    ChatContextKind.group => 'Selecionar todos os grupos',
    ChatContextKind.activity => 'Selecionar todas as atividades',
    ChatContextKind.person => 'Selecionar todas as pessoas',
    ChatContextKind.child => 'Selecionar todas as crianças',
    _ => 'Selecionar todos',
  };
}

String _kindLabel(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => 'Instituição',
  ChatContextKind.unit => 'Unidade',
  ChatContextKind.group => 'Grupo (Turma)',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
  ChatContextKind.child => 'Criança',
  ChatContextKind.conversationGroup => 'Grupo de conversa',
};
