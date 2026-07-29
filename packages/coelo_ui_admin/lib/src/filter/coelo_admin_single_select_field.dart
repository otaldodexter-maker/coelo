import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloAdminSingleSelectField<T> extends StatefulWidget {
  const CoeloAdminSingleSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.prefixIcon = Icons.tune_rounded,
    this.errorText,
    this.enabled = true,
    this.isLoading = false,
    this.searchable,
    this.searchHintText,
    super.key,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T> onChanged;
  final IconData prefixIcon;
  final String? errorText;
  final bool enabled;
  final bool isLoading;

  /// Overrides the automatic search field shown when there are more than eight
  /// options.
  final bool? searchable;
  final String? searchHintText;

  @override
  State<CoeloAdminSingleSelectField<T>> createState() => _CoeloAdminSingleSelectFieldState<T>();
}

final class _CoeloAdminSingleSelectFieldState<T> extends State<CoeloAdminSingleSelectField<T>> {
  final _triggerFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  final _optionsScrollController = ScrollController();
  final _anchorKey = GlobalKey();
  String _query = '';
  double? _menuMaxHeight;

  bool get _canInteract => widget.enabled && !widget.isLoading;
  bool get _isSearchable => widget.searchable ?? widget.options.length > 8;

  List<T> get _visibleOptions {
    final normalizedQuery = _query.trim().toLowerCase();
    if (!_isSearchable || normalizedQuery.isEmpty) {
      return widget.options;
    }
    return widget.options
        .where((option) => widget.optionLabel(option).toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  @override
  void dispose() {
    _triggerFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _optionsScrollController.dispose();
    super.dispose();
  }

  void _handleOpen() {
    if (!_isSearchable) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _handleClose() {
    if (_query.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
    }
    if (_optionsScrollController.hasClients) {
      _optionsScrollController.jumpTo(0);
    }
    _triggerFocusNode.requestFocus();
  }

  Future<void> _openMenu(MenuController menu) async {
    final anchorContext = _anchorKey.currentContext;
    if (_availableBelow(context) < _preferredMenuHeight && anchorContext != null) {
      await Scrollable.ensureVisible(
        anchorContext,
        alignment: 0.25,
        duration: CoeloMotion.fast,
        curve: Curves.easeOut,
      );
      if (!mounted) {
        return;
      }
    }

    final minimumUsableHeight =
        (_isSearchable ? CoeloSize.touchMin + (CoeloSpacing.space2 * 2) : 0) + CoeloSize.touchMin;
    final availableBelow = _availableBelow(
      context,
    ).clamp(minimumUsableHeight, _preferredMenuHeight);
    setState(() => _menuMaxHeight = availableBelow.toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        menu.open();
      }
    });
  }

  double _availableBelow(BuildContext context) {
    final anchorBox = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final media = MediaQuery.of(context);
    final anchorBottom =
        anchorBox?.localToGlobal(Offset(0, anchorBox.size.height)).dy ?? media.size.height / 2;
    final viewportBottom = media.size.height - media.padding.bottom - media.viewInsets.bottom;
    return viewportBottom - anchorBottom - CoeloSpacing.space1;
  }

  double get _preferredMenuHeight =>
      (_isSearchable ? CoeloSize.touchMin + (CoeloSpacing.space2 * 2) : 0) +
      (CoeloSize.touchMin * _visibleOptions.length.clamp(1, 6));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuHeight = _menuMaxHeight ?? _preferredMenuHeight;
        return MenuAnchor(
          childFocusNode: _triggerFocusNode,
          crossAxisUnconstrained: false,
          alignmentOffset: const Offset(0, CoeloSpacing.space1),
          onOpen: _handleOpen,
          onClose: _handleClose,
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colors.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(CoeloElevation.level3),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, menuHeight)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                side: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
          menuChildren: [
            SizedBox(
              width: constraints.maxWidth,
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
                          key: const Key('coelo-admin-single-select-search'),
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (query) => setState(() => _query = query),
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
                    child: Scrollbar(
                      key: const Key('coelo-admin-single-select-options-scrollbar'),
                      controller: _optionsScrollController,
                      thumbVisibility: _visibleOptions.length > 6,
                      child: SingleChildScrollView(
                        key: const Key('coelo-admin-single-select-options-scroll'),
                        controller: _optionsScrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_visibleOptions.isEmpty)
                              const MenuItemButton(
                                onPressed: null,
                                child: Text('Nenhuma opção encontrada.'),
                              )
                            else
                              for (final option in _visibleOptions) _optionButton(option, colors),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          builder: (context, menu, child) => Semantics(
            enabled: _canInteract,
            label: widget.label,
            value: widget.optionLabel(widget.value),
            hint: widget.errorText,
            child: InkWell(
              focusNode: _triggerFocusNode,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              onTap: _canInteract ? () => menu.isOpen ? menu.close() : _openMenu(menu) : null,
              child: InputDecorator(
                key: _anchorKey,
                isFocused: menu.isOpen,
                isEmpty: widget.optionLabel(widget.value).isEmpty,
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
                child: Text(widget.optionLabel(widget.value)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _optionButton(T option, ColorScheme colors) {
    return MenuItemButton(
      onPressed: () => widget.onChanged(option),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              option == widget.value ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? colors.primary
              : colors.onSurface,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              option == widget.value ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? colors.primaryContainer
              : colors.surface,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      child: Text(widget.optionLabel(option)),
    );
  }
}
