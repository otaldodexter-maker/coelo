import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class SuperadminChatAvatar extends StatelessWidget {
  const SuperadminChatAvatar({
    required this.label,
    required this.initials,
    this.size = CoeloSize.avatarLg,
    this.online = false,
    super.key,
  });

  final String label;
  final String initials;
  final double size;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: online ? '$label, disponível' : label,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                child: Text(initials, style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
            if (online)
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Container(
                  width: CoeloSpacing.space3,
                  height: CoeloSpacing.space3,
                  decoration: BoxDecoration(
                    color: colors.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: CoeloSpacing.space1 / 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
