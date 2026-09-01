import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloStatePanel extends StatelessWidget {
  const CoeloStatePanel({
    required this.title,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.loading = false,
    super.key,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space8),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon case final icon?) ...[
                        Icon(icon, size: CoeloSize.iconLg),
                        const SizedBox(height: CoeloSpacing.space3),
                      ],
                      Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: CoeloSpacing.space2),
                      Text(message, textAlign: TextAlign.center),
                      if (actionLabel case final actionLabel?) ...[
                        const SizedBox(height: CoeloSpacing.space3),
                        OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
