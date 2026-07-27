import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum CoeloAdminContextKind { institution, unit, group, activity }

extension CoeloAdminContextKindLabel on CoeloAdminContextKind {
  String get label => switch (this) {
    CoeloAdminContextKind.institution => 'Instituição',
    CoeloAdminContextKind.unit => 'Unidade',
    CoeloAdminContextKind.group => 'Grupo/Turma',
    CoeloAdminContextKind.activity => 'Atividade',
  };

  IconData get icon => switch (this) {
    CoeloAdminContextKind.institution => Icons.account_balance_outlined,
    CoeloAdminContextKind.unit => Icons.apartment_outlined,
    CoeloAdminContextKind.group => Icons.groups_outlined,
    CoeloAdminContextKind.activity => Icons.sports_outlined,
  };
}

final class CoeloAdminContextOption {
  const CoeloAdminContextOption({
    required this.id,
    required this.label,
    required this.kind,
    this.subtitle,
    List<CoeloAdminContextOption> children = const [],
  }) : _children = children;

  final String id;
  final String label;
  final String? subtitle;
  final CoeloAdminContextKind kind;
  final List<CoeloAdminContextOption> _children;

  List<CoeloAdminContextOption> get children => List.unmodifiable(_children);
}

final class CoeloAdminContextPicker extends StatefulWidget {
  const CoeloAdminContextPicker({required this.options, required this.onSelected, super.key});

  final List<CoeloAdminContextOption> options;
  final ValueChanged<List<CoeloAdminContextOption>> onSelected;

  @override
  State<CoeloAdminContextPicker> createState() => _CoeloAdminContextPickerState();
}

final class _CoeloAdminContextPickerState extends State<CoeloAdminContextPicker> {
  final _searchController = TextEditingController();
  final _path = <CoeloAdminContextOption>[];
  CoeloAdminContextOption? _pending;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoeloAdminContextOption> get _levelOptions {
    if (_path.isEmpty) {
      return List.unmodifiable(widget.options);
    }
    return _path.last.children;
  }

  void _select(CoeloAdminContextOption option) {
    setState(() {
      _pending = option;
    });
  }

  void _open(CoeloAdminContextOption option) {
    setState(() {
      _searchController.clear();
      _pending = null;
      _path.add(option);
    });
  }

  void _navigateTo(int pathLength) {
    setState(() {
      _searchController.clear();
      _pending = null;
      _path.removeRange(pathLength, _path.length);
    });
  }

  String _childrenLabel(CoeloAdminContextOption option) {
    final children = option.children;
    if (children.isEmpty) {
      return '';
    }
    final count = children.length;
    final noun = switch (children.first.kind) {
      CoeloAdminContextKind.institution => count == 1 ? 'instituição' : 'instituições',
      CoeloAdminContextKind.unit => count == 1 ? 'unidade' : 'unidades',
      CoeloAdminContextKind.group => count == 1 ? 'grupo' : 'grupos',
      CoeloAdminContextKind.activity => count == 1 ? 'atividade' : 'atividades',
    };
    return '$count $noun';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleOptions = _levelOptions
        .where(
          (option) =>
              query.isEmpty ||
              option.label.toLowerCase().contains(query) ||
              (option.subtitle?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
    final selectionPath = [..._path, ?_pending];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton(onPressed: () => _navigateTo(0), child: const Text('Instituições')),
              for (var index = 0; index < _path.length; index++) ...[
                const Icon(Icons.chevron_right, size: CoeloSize.iconSm),
                TextButton(
                  onPressed: () => _navigateTo(index + 1),
                  child: Text(_path[index].label),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        CoeloSearchField(
          controller: _searchController,
          onChanged: (_) => setState(() => _pending = null),
          semanticLabel: 'Buscar no nível atual',
          hintText: 'Buscar neste nível',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Expanded(
          child: visibleOptions.isEmpty
              ? const CoeloStatePanel(
                  title: 'Nenhum contexto encontrado',
                  message: 'Ajuste a busca neste nível da hierarquia.',
                  icon: Icons.search_off_outlined,
                )
              : ListView.separated(
                  itemCount: visibleOptions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = visibleOptions[index];
                    final selected = option.id == _pending?.id;
                    final childrenLabel = _childrenLabel(option);
                    return ListTile(
                      key: Key('coelo-context-select-${option.id}'),
                      selected: selected,
                      leading: Icon(option.kind.icon),
                      title: Text(option.label),
                      subtitle: Text(
                        [
                          option.kind.label,
                          if (option.subtitle case final subtitle? when subtitle.isNotEmpty)
                            subtitle,
                          if (childrenLabel.isNotEmpty) childrenLabel,
                        ].join(' · '),
                      ),
                      trailing: option.children.isEmpty
                          ? Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            )
                          : SizedBox(
                              width: CoeloSize.touchMin * 2,
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  IconButton(
                                    key: Key('coelo-context-open-${option.id}'),
                                    tooltip: 'Ver ${_childrenLabel(option)} de ${option.label}',
                                    onPressed: () => _open(option),
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ),
                      onTap: () => _select(option),
                    );
                  },
                ),
        ),
        if (_pending != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selectionPath.map((item) => item.label).join(' / '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  FilledButton(
                    onPressed: () => widget.onSelected(List.unmodifiable(selectionPath)),
                    child: const Text('Selecionar contexto'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
