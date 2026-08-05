import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class CoeloAdminMultiSelectField<T> extends StatefulWidget {
  const CoeloAdminMultiSelectField({
    required this.label,
    required this.options,
    required this.selectedValues,
    required this.optionLabel,
    required this.onChanged,
    this.prefixIcon = Icons.checklist_rounded,
    this.errorText,
    this.enabled = true,
    this.isLoading = false,
    this.searchable,
    this.searchHintText,
    this.emptyLabel = 'Selecionar',
    super.key,
  });

  final String label;
  final List<T> options;
  final Set<T> selectedValues;
  final String Function(T value) optionLabel;
  final ValueChanged<Set<T>> onChanged;
  final IconData prefixIcon;
  final String? errorText;
  final bool enabled;
  final bool isLoading;
  final bool? searchable;
  final String? searchHintText;
  final String emptyLabel;

  @override
  State<CoeloAdminMultiSelectField<T>> createState() => _CoeloAdminMultiSelectFieldState<T>();
}

final class _CoeloAdminMultiSelectFieldState<T> extends State<CoeloAdminMultiSelectField<T>> {
  final _menuController = MenuController();
  final _triggerFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  late Set<T> _draftValues = Set.of(widget.selectedValues);
  String _query = '';
  bool _appliedWhileOpen = false;

  bool get _canInteract => widget.enabled && !widget.isLoading;
  bool get _isSearchable => widget.searchable ?? widget.options.length > 8;

  List<T> get _visibleOptions {
    final query = _normalize(_query);
    if (!_isSearchable || query.isEmpty) {
      return widget.options;
    }
    return widget.options
        .where((option) => _normalize(widget.optionLabel(option)).contains(query))
        .toList(growable: false);
  }

  String get _valueLabel {
    if (widget.selectedValues.isEmpty) {
      return widget.emptyLabel;
    }
    if (widget.selectedValues.length == 1) {
      final selected = widget.selectedValues.first;
      return widget.options.contains(selected) ? widget.optionLabel(selected) : widget.emptyLabel;
    }
    return '${widget.selectedValues.length} selecionados';
  }

  @override
  void didUpdateWidget(covariant CoeloAdminMultiSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_menuController.isOpen && !_setsEqual(oldWidget.selectedValues, widget.selectedValues)) {
      _draftValues = Set.of(widget.selectedValues);
    }
  }

  @override
  void dispose() {
    _triggerFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _open() {
    _appliedWhileOpen = false;
    _searchController.clear();
    setState(() {
      _query = '';
      _draftValues = Set.of(widget.selectedValues);
    });
    if (_isSearchable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _close() {
    _searchController.clear();
    _query = '';
    if (_appliedWhileOpen) {
      _appliedWhileOpen = false;
      return;
    }
    if (!_setsEqual(_draftValues, widget.selectedValues)) {
      setState(() => _draftValues = Set.of(widget.selectedValues));
    }
  }

  void _closeAndRestoreFocus() {
    _menuController.close();
    _triggerFocusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _closeAndRestoreFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggle(T value) {
    setState(() {
      _draftValues = Set.of(_draftValues);
      if (!_draftValues.add(value)) {
        _draftValues.remove(value);
      }
    });
  }

  void _clear() => setState(() => _draftValues = {});

  void _apply() {
    final result = Set<T>.unmodifiable(_draftValues);
    _appliedWhileOpen = true;
    _closeAndRestoreFocus();
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final optionsHeight = math.max(
          CoeloSize.touchMin,
          math.min(_visibleOptions.length, 6) * CoeloSize.touchMin,
        );
        final menuHeight =
            optionsHeight +
            (_isSearchable ? CoeloSize.touchMin + CoeloSpacing.space4 : 0) +
            CoeloSize.touchMin +
            (CoeloSpacing.space2 * 2) +
            1;

        return MenuAnchor(
          controller: _menuController,
          childFocusNode: _triggerFocusNode,
          crossAxisUnconstrained: false,
          alignmentOffset: const Offset(0, CoeloSpacing.space1),
          onOpen: _open,
          onClose: _close,
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colors.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(CoeloElevation.level3),
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(Size(width, menuHeight)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                side: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
          menuChildren: [
            Focus(
              autofocus: !_isSearchable,
              onKeyEvent: _handleKeyEvent,
              child: SizedBox(
                width: width,
                height: menuHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSearchable)
                      Padding(
                        padding: const EdgeInsets.all(CoeloSpacing.space2),
                        child: SizedBox(
                          height: CoeloSize.touchMin,
                          child: TextField(
                            key: const Key('coelo-admin-multi-select-search'),
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (value) => setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText:
                                  widget.searchHintText ?? 'Buscar ${widget.label.toLowerCase()}',
                              prefixIcon: const Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: _visibleOptions.isEmpty
                          ? const Center(child: Text('Nenhuma op\u00e7\u00e3o encontrada.'))
                          : ListView(
                              primary: false,
                              padding: EdgeInsets.zero,
                              children: [
                                for (final option in _visibleOptions) _optionButton(option, colors),
                              ],
                            ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(CoeloSpacing.space2),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _draftValues.isEmpty ? null : _clear,
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
          builder: (context, menu, child) => Semantics(
            enabled: _canInteract,
            label: widget.label,
            value: _valueLabel,
            hint: widget.errorText,
            child: InkWell(
              focusNode: _triggerFocusNode,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              onTap: _canInteract
                  ? () => menu.isOpen ? _closeAndRestoreFocus() : menu.open()
                  : null,
              child: InputDecorator(
                isFocused: menu.isOpen,
                isEmpty: widget.selectedValues.isEmpty,
                decoration: InputDecoration(
                  enabled: _canInteract,
                  errorText: widget.errorText,
                  labelText: widget.label,
                  prefixIcon: Icon(widget.prefixIcon),
                  suffixIcon: widget.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(CoeloSpacing.space3),
                          child: SizedBox.square(
                            dimension: CoeloSize.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(
                          menu.isOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                child: Text(_valueLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _optionButton(T option, ColorScheme colors) {
    final selected = _draftValues.contains(option);
    return Semantics(
      container: true,
      button: true,
      label: widget.optionLabel(option),
      checked: selected,
      enabled: true,
      child: ExcludeSemantics(
        child: MenuItemButton(
          closeOnActivate: false,
          onPressed: () => _toggle(option),
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
            shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              final highlighted =
                  states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
              return highlighted ? colors.primaryContainer : colors.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final highlighted =
                  states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
              return selected || highlighted ? colors.primary : colors.onSurface;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          leadingIcon: ExcludeSemantics(
            child: IgnorePointer(
              child: Checkbox(
                value: selected,
                onChanged: (_) {},
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                splashRadius: 0,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          child: Text(widget.optionLabel(option)),
        ),
      ),
    );
  }
}

bool _setsEqual<T>(Set<T> first, Set<T> second) =>
    first.length == second.length && first.containsAll(second);

String _normalize(String value) {
  var result = value.toLowerCase().trim();
  const replacements = <String, String>{
    '\u00e1': 'a',
    '\u00e0': 'a',
    '\u00e2': 'a',
    '\u00e3': 'a',
    '\u00e9': 'e',
    '\u00ea': 'e',
    '\u00ed': 'i',
    '\u00f3': 'o',
    '\u00f4': 'o',
    '\u00f5': 'o',
    '\u00fa': 'u',
    '\u00e7': 'c',
  };
  for (final replacement in replacements.entries) {
    result = result.replaceAll(replacement.key, replacement.value);
  }
  return result;
}
