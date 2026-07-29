import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// App-local composition approved by the Institutions listing.
///
/// It deliberately stays private to Superadmin and does not create a public
/// Design System API.
final class SuperadminListingPaginationFooter extends StatelessWidget {
  const SuperadminListingPaginationFooter({
    required this.horizontalPadding,
    required this.child,
    this.semanticKey,
    super.key,
  });

  final double horizontalPadding;
  final Widget child;
  final Key? semanticKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRect(
      key: semanticKey,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: CoeloSpacing.space2, sigmaY: CoeloSpacing.space2),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            CoeloSpacing.space3,
            horizontalPadding,
            CoeloSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}
