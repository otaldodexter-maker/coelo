import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Principal-owned action surface following the approved Institutions contract.
final class CoeloPrincipalActionCard extends StatefulWidget {
  const CoeloPrincipalActionCard({
    super.key,
    required this.onPressed,
    this.child,
    this.childBuilder,
    this.decoration,
    this.padding = const EdgeInsets.all(CoeloSpacing.space3),
    this.selected = false,
  }) : assert(child != null || childBuilder != null);

  final VoidCallback onPressed;
  final Widget? child;
  final Widget Function(BuildContext context, Set<WidgetState> states)? childBuilder;
  final WidgetStateProperty<BoxDecoration>? decoration;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  State<CoeloPrincipalActionCard> createState() => _CoeloPrincipalActionCardState();
}

final class _CoeloPrincipalActionCardState extends State<CoeloPrincipalActionCard> {
  final FocusNode _focusNode = FocusNode();
  late final WidgetStatesController _statesController;

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController()..addListener(_onStatesChanged);
    _focusNode.addListener(_syncFocusState);
  }

  void _onStatesChanged() => setState(() {});

  void _syncFocusState() =>
      _statesController.update(WidgetState.focused, _focusNode.hasFocus);

  @override
  void dispose() {
    _statesController
      ..removeListener(_onStatesChanged)
      ..dispose();
    _focusNode
      ..removeListener(_syncFocusState)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final states = <WidgetState>{
      ..._statesController.value,
      if (widget.selected) WidgetState.selected,
    };
    final highlighted =
        states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed);
    final decoration =
        widget.decoration?.resolve(states) ??
        BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(
            color: widget.selected || highlighted ? scheme.primary : scheme.outlineVariant,
            width: widget.selected || highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        );
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: TextButton(
        focusNode: _focusNode,
        statesController: _statesController,
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: Colors.transparent,
          padding: widget.padding,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(),
        ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
        child: widget.childBuilder?.call(context, states) ?? widget.child!,
      ),
    );
  }
}
