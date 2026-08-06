import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Canonical interactive surface for administrative directory cards.
///
/// Visual decisions are intentionally not configurable. This prevents feature
/// code from reintroducing rectangular gray Material hover states.
final class CoeloAdminInteractiveCard extends StatefulWidget {
  const CoeloAdminInteractiveCard({
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.surfaceKey,
    this.minHeight,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Key? surfaceKey;
  final double? minHeight;

  @override
  State<CoeloAdminInteractiveCard> createState() => _CoeloAdminInteractiveCardState();
}

final class _CoeloAdminInteractiveCardState extends State<CoeloAdminInteractiveCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emphasized = _hovered || _focused;
    final radius = BorderRadius.circular(CoeloRadius.lg);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final surface = AnimatedContainer(
      key: widget.surfaceKey,
      duration: disableAnimations ? CoeloMotion.instant : CoeloMotion.standard,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(
          color: emphasized ? colors.primary.withValues(alpha: 0.5) : colors.outlineVariant,
          width: emphasized ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: emphasized
                ? colors.primary.withValues(alpha: 0.15)
                : colors.shadow.withValues(alpha: 0.03),
            blurRadius: emphasized ? 12 : 8,
            spreadRadius: emphasized ? 2 : 0,
            offset: Offset(0, emphasized ? 4 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          onFocusChange: (value) => setState(() => _focused = value),
          borderRadius: radius,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: widget.child,
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onPressed == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: widget.semanticLabel == null
          ? surface
          : Semantics(
              label: widget.semanticLabel,
              button: widget.onPressed != null,
              onTap: widget.onPressed,
              container: true,
              child: ExcludeSemantics(child: surface),
            ),
    );
  }
}
