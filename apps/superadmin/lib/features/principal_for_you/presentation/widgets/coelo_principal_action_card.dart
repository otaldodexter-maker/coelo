import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Principal-owned action surface following the approved Institutions contract.
final class CoeloPrincipalActionCard extends StatefulWidget {
  const CoeloPrincipalActionCard({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.all(CoeloSpacing.space3),
    this.selected = false,
  });

  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  State<CoeloPrincipalActionCard> createState() => _CoeloPrincipalActionCardState();
}

final class _CoeloPrincipalActionCardState extends State<CoeloPrincipalActionCard> {
  bool _highlighted = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emphasized = widget.selected || _highlighted;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(
          color: emphasized ? scheme.primary : scheme.outlineVariant,
          width: emphasized ? 2 : 1,
        ),
        boxShadow: _highlighted
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      clipBehavior: Clip.antiAlias,
      child: MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: TextButton(
          focusNode: _focusNode,
          onFocusChange: (value) => setState(() => _highlighted = value),
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            backgroundColor: Colors.transparent,
            padding: widget.padding,
            minimumSize: const Size(48, 48),
            shape: const RoundedRectangleBorder(),
          ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
          child: widget.child,
        ),
      ),
    );
  }
}
