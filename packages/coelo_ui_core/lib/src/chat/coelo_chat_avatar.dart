import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'coelo_chat_types.dart';

final class CoeloChatAvatar extends StatelessWidget {
  const CoeloChatAvatar({
    required this.label,
    required this.initials,
    this.image,
    this.size = CoeloSize.avatarLg,
    this.nowState = CoeloNowState.none,
    this.presence = CoeloChatPresence.none,
    this.presenceLabel,
    this.onProfilePressed,
    this.onNowPressed,
    super.key,
  });

  final String label;
  final String initials;
  final ImageProvider<Object>? image;
  final double size;
  final CoeloNowState nowState;
  final CoeloChatPresence presence;
  final String? presenceLabel;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onNowPressed;

  String get _semanticLabel {
    final parts = <String>[label];
    switch (nowState) {
      case CoeloNowState.unseen:
        parts.add('Now não visto');
      case CoeloNowState.seen:
        parts.add('Now visto');
      case CoeloNowState.none:
        break;
    }
    if (presenceLabel case final value? when value.isNotEmpty) {
      parts.add(value);
    }
    return parts.join('. ');
  }

  VoidCallback? get _activation {
    if (nowState != CoeloNowState.none && onNowPressed != null) {
      return onNowPressed;
    }
    return onProfilePressed;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ringColors = Theme.of(context).extension<CoeloChatColors>()!;
    final ringSpace = nowState == CoeloNowState.none ? 0.0 : CoeloSpacing.space2;
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: colors.surfaceContainerHighest,
      backgroundImage: image,
      child: image == null
          ? Text(
              initials,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            )
          : null,
    );

    return Semantics(
      label: _semanticLabel,
      button: _activation != null,
      excludeSemantics: true,
      child: InkResponse(
        onTap: _activation,
        radius: (size + CoeloSpacing.space2) / 2,
        containedInkWell: true,
        customBorder: const CircleBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: CoeloSize.touchMin,
            minHeight: CoeloSize.touchMin,
          ),
          child: SizedBox.square(
            dimension: size + ringSpace,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (nowState != CoeloNowState.none)
                  CustomPaint(
                    key: const Key('coelo-chat-avatar-now-ring'),
                    size: Size.square(size + ringSpace),
                    painter: _NowRingPainter(
                      primary: nowState == CoeloNowState.unseen
                          ? ringColors.nowRingPrimary
                          : colors.outline,
                      secondary: nowState == CoeloNowState.unseen
                          ? ringColors.nowRingSecondary
                          : colors.outlineVariant,
                      showGlow: nowState == CoeloNowState.unseen,
                    ),
                  ),
                avatar,
                if (presence != CoeloChatPresence.none)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ExcludeSemantics(
                      child: Container(
                        key: const Key('coelo-chat-avatar-presence'),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: presence == CoeloChatPresence.available
                              ? Theme.of(context).extension<CoeloStatusColors>()!.success
                              : colors.outline,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _NowRingPainter extends CustomPainter {
  const _NowRingPainter({required this.primary, required this.secondary, required this.showGlow});

  final Color primary;
  final Color secondary;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (showGlow) {
      canvas.drawCircle(
        center,
        size.shortestSide / 2 - 2,
        Paint()
          ..color = primary.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas
      ..drawCircle(
        center,
        size.shortestSide / 2 - 2,
        Paint()
          ..color = primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawCircle(
        center,
        size.shortestSide / 2 - 5,
        Paint()
          ..color = secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(covariant _NowRingPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        showGlow != oldDelegate.showGlow;
  }
}
