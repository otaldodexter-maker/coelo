import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

@immutable
final class CoeloAdminAssigneeItem {
  const CoeloAdminAssigneeItem({
    required this.label,
    required this.initials,
    required this.roleLabel,
    this.image,
  });

  final String label;
  final String initials;
  final String roleLabel;
  final ImageProvider? image;
}

/// Compact presentation-only stack. Caller order is preserved.
final class CoeloAdminAssigneeStack extends StatelessWidget {
  const CoeloAdminAssigneeStack({required this.items, super.key});

  final List<CoeloAdminAssigneeItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final visible = items.take(3).toList(growable: false);
    final hidden = items.length - visible.length;
    const step = CoeloSize.avatarSm - CoeloSpacing.space2;
    final width =
        CoeloSize.avatarSm +
        step * (visible.length - 1) +
        (hidden > 0 ? step + CoeloSize.avatarSm : 0);
    final semantics = items.map((item) => '${item.label}, ${item.roleLabel}').join('; ');
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: CoeloSize.avatarSm,
          child: Stack(
            children: [
              for (var index = 0; index < visible.length; index++)
                Positioned(
                  left: index * step,
                  child: CircleAvatar(
                    radius: CoeloSize.avatarSm / 2,
                    backgroundColor: colors.surfaceContainerHighest,
                    backgroundImage: visible[index].image,
                    child: visible[index].image == null
                        ? Text(
                            visible[index].initials,
                            style: Theme.of(context).textTheme.labelSmall,
                          )
                        : null,
                  ),
                ),
              if (hidden > 0)
                Positioned(
                  left: visible.length * step,
                  child: Container(
                    width: CoeloSize.avatarSm,
                    height: CoeloSize.avatarSm,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface),
                    ),
                    child: Text('+$hidden', style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
