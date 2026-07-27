import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Shared operational workspace used by Admin and Superadmin list/detail flows.
final class CoeloAdminWorkspaceLayout extends StatelessWidget {
  const CoeloAdminWorkspaceLayout({
    required this.toolbar,
    required this.body,
    this.detail,
    this.detailVisible = false,
    super.key,
  });

  final Widget toolbar;
  final Widget body;
  final Widget? detail;
  final bool detailVisible;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleDetail = detailVisible && detail != null;
        late final Widget content;
        if (!visibleDetail) {
          content = SizedBox(width: constraints.maxWidth, child: body);
        } else if (constraints.maxWidth < CoeloBreakpoints.expanded.minWidth) {
          content = SizedBox(width: constraints.maxWidth, child: detail);
        } else if (constraints.maxWidth < CoeloBreakpoints.large.minWidth) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              SizedBox(width: 360, child: detail),
            ],
          );
        } else {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              SizedBox(width: 480, child: detail),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            toolbar,
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
