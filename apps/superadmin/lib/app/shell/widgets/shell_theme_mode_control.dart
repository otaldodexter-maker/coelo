import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../theme/superadmin_theme_mode_scope.dart';

class ShellThemeModeControl extends StatelessWidget {
  const ShellThemeModeControl({super.key, required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final scope = SuperadminThemeModeScope.maybeOf(context);
    final mode = scope?.mode ?? ThemeMode.system;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && theme.brightness == Brightness.dark);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 420);

    void toggle() => scope?.onChanged(isDark ? ThemeMode.light : ThemeMode.dark);

    return SizedBox(
      width: collapsed ? CoeloSize.touchMin : double.infinity,
      height: collapsed ? 80 : CoeloSize.touchMin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useCompactLayout =
              collapsed ||
              constraints.maxWidth < 180 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          return Tooltip(
            message: isDark ? 'Ativar tema claro' : 'Ativar tema escuro',
            child: Semantics(
              button: true,
              toggled: isDark,
              label: isDark ? 'Tema escuro ativo' : 'Tema claro ativo',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('superadmin-theme-mode-control'),
                  onTap: toggle,
                  borderRadius: BorderRadius.circular(
                    useCompactLayout ? CoeloRadius.full : CoeloRadius.lg,
                  ),
                  overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
                  child: Container(
                    key: const Key('superadmin-theme-mode-surface'),
                    padding: EdgeInsets.symmetric(
                      horizontal: useCompactLayout ? CoeloSpacing.space1 : CoeloSpacing.space3,
                      vertical: CoeloSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        useCompactLayout ? CoeloRadius.full : CoeloRadius.lg,
                      ),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: useCompactLayout
                        ? _CollapsedCarrotSwitch(isDark: isDark, duration: duration, colors: colors)
                        : Row(
                            children: [
                              Expanded(child: Text('Aparência', style: theme.textTheme.labelLarge)),
                              AnimatedSwitcher(
                                duration: duration,
                                switchInCurve: Curves.easeInOut,
                                switchOutCurve: Curves.easeInOut,
                                child: Row(
                                  key: ValueKey(isDark),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                                      size: CoeloSize.iconSm,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: CoeloSpacing.space1),
                                    Text(
                                      isDark ? 'Escuro' : 'Claro',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: CoeloSpacing.space2),
                              _HorizontalCarrotSwitch(
                                isDark: isDark,
                                duration: duration,
                                colors: colors,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollapsedCarrotSwitch extends StatelessWidget {
  const _CollapsedCarrotSwitch({
    required this.isDark,
    required this.duration,
    required this.colors,
  });

  final bool isDark;
  final Duration duration;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: CoeloSpacing.space2,
          left: 0,
          right: 0,
          child: Icon(Icons.light_mode_outlined, size: CoeloSize.iconSm),
        ),
        const Positioned(
          bottom: CoeloSpacing.space2,
          left: 0,
          right: 0,
          child: Icon(Icons.dark_mode_outlined, size: CoeloSize.iconSm),
        ),
        AnimatedAlign(
          duration: duration,
          curve: Curves.easeInOut,
          alignment: isDark ? Alignment.bottomCenter : Alignment.topCenter,
          child: _CarrotThumb(colors: colors),
        ),
      ],
    );
  }
}

class _HorizontalCarrotSwitch extends StatelessWidget {
  const _HorizontalCarrotSwitch({
    required this.isDark,
    required this.duration,
    required this.colors,
  });

  final bool isDark;
  final Duration duration;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CoeloSpacing.space16,
      height: CoeloSpacing.space8,
      padding: const EdgeInsets.all(CoeloSpacing.space1),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.full),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeInOut,
        alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
        child: _CarrotThumb(colors: colors, size: CoeloSpacing.space6),
      ),
    );
  }
}

class _CarrotThumb extends StatelessWidget {
  const _CarrotThumb({required this.colors, this.size = CoeloSpacing.space8});

  final ColorScheme colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = context.coeloVisualColors;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(CoeloSpacing.space1),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: colors.primary.withValues(alpha: 0.12), blurRadius: CoeloSpacing.space1),
        ],
      ),
      child: CustomPaint(
        key: const Key('superadmin-theme-carrot'),
        painter: _FlatCarrotPainter(
          bodyColor: colors.primary,
          markColor: colors.onPrimary,
          leafColor: visual.carrotLeaf,
          leafAccentColor: visual.carrotLeafAccent,
        ),
      ),
    );
  }
}

class _FlatCarrotPainter extends CustomPainter {
  const _FlatCarrotPainter({
    required this.bodyColor,
    required this.markColor,
    required this.leafColor,
    required this.leafAccentColor,
  });

  final Color bodyColor;
  final Color markColor;
  final Color leafColor;
  final Color leafAccentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final carrot = Path()
      ..moveTo(size.width * 0.28, size.height * 0.31)
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.24,
        size.width * 0.68,
        size.height * 0.27,
        size.width * 0.73,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.6,
        size.width * 0.48,
        size.height * 0.85,
        size.width * 0.35,
        size.height * 0.97,
      )
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.72,
        size.width * 0.16,
        size.height * 0.43,
        size.width * 0.28,
        size.height * 0.31,
      )
      ..close();
    canvas.drawPath(carrot, Paint()..color = bodyColor);
    final leftLeaf = Path()
      ..moveTo(size.width * 0.39, size.height * 0.31)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.1,
        size.height * 0.2,
        size.width * 0.12,
        size.height * 0.03,
      )
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.06,
        size.width * 0.43,
        size.height * 0.19,
        size.width * 0.39,
        size.height * 0.31,
      )
      ..close();
    final middleLeaf = Path()
      ..moveTo(size.width * 0.41, size.height * 0.3)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.16,
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.49,
        0,
      )
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.14,
        size.width * 0.53,
        size.height * 0.25,
        size.width * 0.41,
        size.height * 0.3,
      )
      ..close();
    final rightLeaf = Path()
      ..moveTo(size.width * 0.43, size.height * 0.31)
      ..cubicTo(
        size.width * 0.5,
        size.height * 0.18,
        size.width * 0.64,
        size.height * 0.08,
        size.width * 0.79,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.29,
        size.width * 0.57,
        size.height * 0.36,
        size.width * 0.43,
        size.height * 0.31,
      )
      ..close();
    canvas
      ..drawPath(leftLeaf, Paint()..color = leafColor)
      ..drawPath(middleLeaf, Paint()..color = leafAccentColor)
      ..drawPath(rightLeaf, Paint()..color = leafColor);
    final marks = Paint()
      ..color = markColor
      ..strokeWidth = math.max(1, size.width * 0.055)
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(size.width * 0.38, size.height * 0.44),
        Offset(size.width * 0.58, size.height * 0.41),
        marks,
      )
      ..drawLine(
        Offset(size.width * 0.34, size.height * 0.58),
        Offset(size.width * 0.5, size.height * 0.55),
        marks,
      )
      ..drawLine(
        Offset(size.width * 0.34, size.height * 0.72),
        Offset(size.width * 0.43, size.height * 0.7),
        marks,
      );
  }

  @override
  bool shouldRepaint(covariant _FlatCarrotPainter oldDelegate) {
    return bodyColor != oldDelegate.bodyColor ||
        markColor != oldDelegate.markColor ||
        leafColor != oldDelegate.leafColor ||
        leafAccentColor != oldDelegate.leafAccentColor;
  }
}
