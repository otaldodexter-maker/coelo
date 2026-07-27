import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloConversationHeader extends StatelessWidget {
  const CoeloConversationHeader({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.onProfilePressed,
    this.actions = const [],
    super.key,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final VoidCallback onProfilePressed;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(
                child: InkWell(
                  onTap: onProfilePressed,
                  borderRadius: BorderRadius.circular(CoeloRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
