import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class HealthCareResponsiveSurface extends StatelessWidget {
  const HealthCareResponsiveSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final usesCleanLightSurface =
          theme.brightness == Brightness.light &&
          constraints.maxWidth < CoeloBreakpoints.expanded.minWidth;
      if (!usesCleanLightSurface) return child;

      final surface = theme.colorScheme.surface;
      return Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: surface,
          canvasColor: surface,
          appBarTheme: theme.appBarTheme.copyWith(
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        child: child,
      );
    },
  );
}

extension HealthCareResponsiveSurfaceExtension on Widget {
  Widget withHealthCareResponsiveSurface() => HealthCareResponsiveSurface(child: this);
}
