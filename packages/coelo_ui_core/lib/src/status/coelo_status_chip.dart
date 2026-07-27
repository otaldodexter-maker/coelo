import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloStatusChip extends StatelessWidget {
  const CoeloStatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Chip(
      avatar: icon == null ? null : Icon(icon, color: foregroundColor, size: CoeloSize.iconSm),
      label: Text(label),
      backgroundColor: backgroundColor,
      labelStyle: textTheme.labelSmall?.copyWith(color: foregroundColor),
      side: BorderSide(color: foregroundColor.withValues(alpha: 0.28)),
      visualDensity: VisualDensity.compact,
    );
  }
}
