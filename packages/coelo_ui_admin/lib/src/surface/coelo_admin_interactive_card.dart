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
  final FocusNode _focusNode = FocusNode(debugLabel: 'CoeloAdminInteractiveCard');
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emphasized = _hovered || _focused;
    final radius = BorderRadius.circular(CoeloRadius.lg);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    // So o realce (hover/foco) anima localmente; as cores do tema sao lidas a
    // cada frame, entao a troca claro/escuro segue a transicao global sem
    // cauda propria (baseline de Instituicoes).
    final surface = TweenAnimationBuilder<double>(
      key: widget.surfaceKey,
      tween: Tween(begin: 0, end: emphasized ? 1 : 0),
      duration: disableAnimations ? CoeloMotion.instant : CoeloMotion.standard,
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Container(
        constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(
            color: Color.lerp(
              colors.outlineVariant,
              colors.primary.withValues(alpha: 0.5),
              progress,
            )!,
            width: 1 + 0.5 * progress,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(
                colors.shadow.withValues(alpha: 0.03),
                colors.primary.withValues(alpha: 0.15),
                progress,
              )!,
              blurRadius: 8 + 4 * progress,
              spreadRadius: 2 * progress,
              offset: Offset(0, 2 + 2 * progress),
            ),
          ],
        ),
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: _focusNode,
          onTap: widget.onPressed,
          onFocusChange: (value) => setState(() => _focused = value),
          borderRadius: radius,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: widget.child,
        ),
      ),
    );

    return MouseRegion(
      onEnter: widget.onPressed == null ? null : (_) => setState(() => _hovered = true),
      onExit: widget.onPressed == null ? null : (_) => setState(() => _hovered = false),
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
