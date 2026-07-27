import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloConversationTile extends StatelessWidget {
  const CoeloConversationTile({
    required this.avatar,
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.onPressed,
    this.unreadCount = 0,
    this.selected = false,
    super.key,
  });

  final Widget avatar;
  final String title;
  final String preview;
  final String timestamp;
  final VoidCallback onPressed;
  final int unreadCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantics = [
      title,
      preview,
      timestamp,
      if (unreadCount > 0)
        '$unreadCount ${unreadCount == 1 ? 'mensagem não lida' : 'mensagens não lidas'}',
    ].join('. ');

    return Semantics(
      label: semantics,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space3,
                vertical: CoeloSpacing.space2,
              ),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: CoeloSpacing.space1),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timestamp,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: CoeloSpacing.space1),
                      if (unreadCount > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: CoeloSpacing.space5),
                          padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space1),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(CoeloRadius.full),
                          ),
                          child: Text(
                            '$unreadCount',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: colors.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
