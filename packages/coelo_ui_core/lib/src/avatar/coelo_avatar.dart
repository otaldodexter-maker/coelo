import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum CoeloAvatarSize {
  small(CoeloSize.avatarSm),
  medium(CoeloSize.avatarMd),
  large(CoeloSize.avatarLg);

  const CoeloAvatarSize(this.dimension);

  final double dimension;
}

final class CoeloAvatar extends StatelessWidget {
  const CoeloAvatar({
    required this.semanticLabel,
    this.initials,
    this.image,
    this.size = CoeloAvatarSize.medium,
    super.key,
  });

  final String semanticLabel;
  final String? initials;
  final ImageProvider? image;
  final CoeloAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final dimension = size.dimension;

    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: dimension,
        child: ClipOval(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: image == null
                ? _fallback(context)
                : Image(
                    image: image!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _fallback(context),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final value = initials?.trim();
    if (value == null || value.isEmpty) {
      return const Center(child: Icon(Icons.person_outline_rounded));
    }
    final textStyle = switch (size) {
      CoeloAvatarSize.small => Theme.of(context).textTheme.labelSmall,
      CoeloAvatarSize.medium => Theme.of(context).textTheme.labelMedium,
      CoeloAvatarSize.large => Theme.of(context).textTheme.titleSmall,
    };
    return Center(child: Text(value, style: textStyle));
  }
}
