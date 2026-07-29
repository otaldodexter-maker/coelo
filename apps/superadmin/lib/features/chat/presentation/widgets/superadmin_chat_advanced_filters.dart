import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_models.dart';
import 'superadmin_chat_flow_dialog.dart';
import 'superadmin_chat_hierarchy_selector.dart';

final class SuperadminChatAdvancedFilters extends StatefulWidget {
  const SuperadminChatAdvancedFilters({required this.controller, required this.options, super.key});

  final SuperadminChatController controller;
  final List<SuperadminChatContextOption> options;

  @override
  State<SuperadminChatAdvancedFilters> createState() => _SuperadminChatAdvancedFiltersState();
}

final class _SuperadminChatAdvancedFiltersState extends State<SuperadminChatAdvancedFilters> {
  late Set<String> _draftIds;

  @override
  void initState() {
    super.initState();
    final active = widget.controller.activeFilterValues;
    _draftIds = {
      for (final option in _flatten(widget.options))
        if (active.contains(option.label)) option.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.controller.audience == ChatAudience.people;
    return SuperadminChatDialogFrame(
      title: people ? 'Filtros de pessoas' : 'Filtros institucionais',
      subtitle: 'Demonstração local · As escolhas só são aplicadas ao confirmar',
      onClose: () => Navigator.pop(context),
      footer: Row(
        children: [
          TextButton(onPressed: () => setState(_draftIds.clear), child: const Text('Limpar')),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: FilledButton(onPressed: _apply, child: const Text('Aplicar')),
          ),
        ],
      ),
      child: SuperadminChatHierarchySelector(
        options: widget.options,
        selectedIds: _draftIds,
        onChanged: (value) => setState(() => _draftIds = value),
      ),
    );
  }

  void _apply() {
    final draft = <ChatFilterKind, Set<String>>{};
    for (final option in _flatten(widget.options)) {
      if (!_draftIds.contains(option.id)) continue;
      final kind = _filterKind(option.kind);
      if (kind == null) continue;
      draft.putIfAbsent(kind, () => <String>{}).add(option.label);
    }
    widget.controller.applyFilters(draft);
    Navigator.pop(context);
  }
}

List<SuperadminChatContextOption> _flatten(List<SuperadminChatContextOption> options) => [
  for (final option in options) ...[option, ..._flatten(option.children)],
];

ChatFilterKind? _filterKind(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => ChatFilterKind.institution,
  ChatContextKind.unit => ChatFilterKind.unit,
  ChatContextKind.group => ChatFilterKind.group,
  ChatContextKind.activity => ChatFilterKind.activity,
  ChatContextKind.child => null,
  ChatContextKind.person || ChatContextKind.conversationGroup => null,
};
