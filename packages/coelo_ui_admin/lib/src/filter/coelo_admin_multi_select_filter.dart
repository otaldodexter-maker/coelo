import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class CoeloAdminMultiSelectFilter<T> extends StatefulWidget {
  const CoeloAdminMultiSelectFilter({
    required this.label,
    required this.options,
    required this.selectedValues,
    required this.optionLabel,
    required this.onChanged,
    this.searchHintText,
    super.key,
  });

  final String label;
  final List<T> options;
  final Set<T> selectedValues;
  final String Function(T value) optionLabel;
  final ValueChanged<Set<T>> onChanged;
  final String? searchHintText;

  @override
  State<CoeloAdminMultiSelectFilter<T>> createState() => _CoeloAdminMultiSelectFilterState<T>();
}

class _CoeloAdminMultiSelectFilterState<T> extends State<CoeloAdminMultiSelectFilter<T>> {
  final MenuController _menuController = MenuController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _triggerFocusNode = FocusNode();
  late Set<T> _draftValues = Set.of(widget.selectedValues);
  String _searchQuery = '';
  bool _appliedWhileOpen = false;

  @override
  void didUpdateWidget(covariant CoeloAdminMultiSelectFilter<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_menuController.isOpen && !_setsEqual(oldWidget.selectedValues, widget.selectedValues)) {
      _draftValues = Set.of(widget.selectedValues);
    }
    if (oldWidget.options != widget.options && _searchQuery.isNotEmpty) {
      _clearSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _triggerFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    if (_searchQuery.isNotEmpty && mounted) {
      setState(() => _searchQuery = '');
    }
  }

  void _open() {
    _appliedWhileOpen = false;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _draftValues = Set.of(widget.selectedValues);
    });
  }

  void _close() {
    _clearSearch();
    if (_appliedWhileOpen) {
      _appliedWhileOpen = false;
      return;
    }
    if (!_setsEqual(_draftValues, widget.selectedValues)) {
      setState(() => _draftValues = Set.of(widget.selectedValues));
    }
  }

  void _closeAndRestoreFocus() {
    if (!_menuController.isOpen) {
      return;
    }
    _menuController.close();
    _triggerFocusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_menuController.isOpen ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _closeAndRestoreFocus();
    return KeyEventResult.handled;
  }

  void _toggle(T value) {
    setState(() {
      _draftValues = Set.of(_draftValues);
      if (!_draftValues.add(value)) {
        _draftValues.remove(value);
      }
    });
  }

  void _clearDraft() {
    if (_draftValues.isNotEmpty) {
      setState(() => _draftValues = {});
    }
  }

  void _apply() {
    final result = Set<T>.unmodifiable(_draftValues);
    _appliedWhileOpen = true;
    _menuController.close();
    _triggerFocusNode.requestFocus();
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final searchHintText = widget.searchHintText;
    final selectedLabel = switch (widget.selectedValues.length) {
      0 => widget.label,
      1 =>
        widget.options.where(widget.selectedValues.contains).map(widget.optionLabel).firstOrNull ??
            widget.label,
      _ => '${widget.selectedValues.length} selecionados',
    };
    final query = _normalize(_searchQuery);
    final visibleOptions = query.isEmpty
        ? widget.options
        : widget.options
              .where((option) => _normalize(widget.optionLabel(option)).contains(query))
              .toList(growable: false);
    final menuHeight = math.min(
      360.0,
      (searchHintText == null ? 0 : CoeloSpacing.space16) +
          math.max(CoeloSize.touchMin, visibleOptions.length * CoeloSize.touchMin) +
          CoeloSpacing.space16,
    );

    return MenuAnchor(
      controller: _menuController,
      onOpen: _open,
      onClose: _close,
      alignmentOffset: const Offset(0, CoeloSpacing.space1),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        maximumSize: const WidgetStatePropertyAll(Size(320, 360)),
      ),
      menuChildren: [
        Focus(
          autofocus: searchHintText == null,
          onKeyEvent: _handleKeyEvent,
          child: SizedBox(
            width: 300,
            height: menuHeight,
            child: Column(
              children: [
                if (searchHintText != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CoeloSpacing.space2,
                      CoeloSpacing.space2,
                      CoeloSpacing.space2,
                      CoeloSpacing.space1,
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: _searchDecoration(context, searchHintText),
                    ),
                  ),
                Expanded(
                  child: visibleOptions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space4),
                            child: Text(
                              'Nenhuma opção encontrada.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView(
                          primary: false,
                          padding: EdgeInsets.zero,
                          children: visibleOptions
                              .map((option) {
                                final selected = _draftValues.contains(option);
                                return Semantics(
                                  checked: selected,
                                  enabled: true,
                                  child: MenuItemButton(
                                    closeOnActivate: false,
                                    onPressed: () => _toggle(option),
                                    style: _optionStyle(colors, selected: selected),
                                    leadingIcon: ExcludeSemantics(
                                      child: IgnorePointer(
                                        child: Checkbox(
                                          value: selected,
                                          onChanged: (_) {},
                                          overlayColor: const WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
                                          splashRadius: 0,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    child: Text(widget.optionLabel(option)),
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _draftValues.isEmpty ? null : _clearDraft,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                          ),
                          child: const Text('Limpar'),
                        ),
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(
                        child: FilledButton(
                          onPressed: _setsEqual(_draftValues, widget.selectedValues)
                              ? null
                              : _apply,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                          ),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        final menuOpen = controller.isOpen;
        return OutlinedButton(
          focusNode: _triggerFocusNode,
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style:
              OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
                shape: const StadiumBorder(),
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => menuOpen ? colors.primaryContainer : Colors.transparent,
                ),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  final active =
                      menuOpen ||
                      states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.pressed);
                  return active ? colors.primary : colors.onSurfaceVariant;
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  final focused = menuOpen || states.contains(WidgetState.focused);
                  return BorderSide(
                    color: focused ? colors.primary : colors.outlineVariant,
                    width: focused ? 2 : 1,
                  );
                }),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
              ),
          child: Row(
            children: [
              Expanded(child: Text(selectedLabel, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: CoeloSpacing.space1),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        );
      },
    );
  }
}

bool _setsEqual<T>(Set<T> first, Set<T> second) =>
    first.length == second.length && first.containsAll(second);

InputDecoration _searchDecoration(BuildContext context, String hintText) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(CoeloRadius.full),
    borderSide: BorderSide(color: colors.outline),
  );
  return InputDecoration(
    hintText: hintText,
    prefixIcon: const Icon(Icons.search_rounded),
    isDense: true,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.primary, width: 2)),
  );
}

String _normalize(String value) {
  var result = value.toLowerCase().trim();
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  for (final replacement in replacements.entries) {
    result = result.replaceAll(replacement.key, replacement.value);
  }
  return result;
}

ButtonStyle _optionStyle(ColorScheme colors, {required bool selected}) {
  return MenuItemButton.styleFrom().copyWith(
    shape: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(highlighted ? 0 : CoeloRadius.md),
      );
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return selected || highlighted ? colors.primary : colors.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return selected || highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return highlighted ? colors.primaryContainer : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}
