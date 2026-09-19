import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../superadmin_notice.dart';
import 'superadmin_tour_scope.dart';

class ShellOnboardingTourButton extends StatefulWidget {
  const ShellOnboardingTourButton({super.key, required this.collapsed});

  final bool collapsed;

  @override
  State<ShellOnboardingTourButton> createState() => ShellOnboardingTourButtonState();
}

class ShellOnboardingTourButtonState extends State<ShellOnboardingTourButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _rotation;
  late final Animation<double> _glow;
  Timer? _restTimer;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 835),
    );
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 7.3 * math.pi / 180), weight: 20),
      TweenSequenceItem(
        tween: Tween(begin: 7.3 * math.pi / 180, end: -7.3 * math.pi / 180),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -7.3 * math.pi / 180, end: 3.65 * math.pi / 180),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 3.65 * math.pi / 180, end: -3.65 * math.pi / 180),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween(begin: -3.65 * math.pi / 180, end: 0), weight: 15),
    ]).animate(_animationController);
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
    ]).animate(_animationController);
    _animationController.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion == reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    _cancelTimer();
    _animationController.stop();
    _animationController.reset();
    if (!reduceMotion) {
      _scheduleNextCycle();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleNextCycle();
    }
  }

  void _scheduleNextCycle() {
    _cancelTimer();
    if (_reduceMotion == true) {
      return;
    }
    _restTimer = Timer(const Duration(milliseconds: 3500), () {
      _restTimer = null;
      if (mounted && _reduceMotion != true) {
        _animationController.forward(from: 0);
      }
    });
  }

  void _cancelTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = context.coeloVisualColors;
    return CoeloAdminFlyout<String>(
      items: shellTourFlyoutItems,
      onSelected: (selection) {
        final tour = SuperadminTourScope.maybeOf(context);
        if (tour == null) {
          showSuperadminNotice(context, 'O tour n\u00e3o est\u00e1 dispon\u00edvel nesta tela.');
          return;
        }
        switch (selection) {
          case 'screen':
            unawaited(
              tour.startScreenTour().then((started) {
                if (!started && context.mounted) {
                  showSuperadminNotice(context, 'Esta tela ainda n\u00e3o tem tour.');
                }
              }),
            );
          case 'complete':
            unawaited(tour.startCompleteTour());
          default:
            unawaited(tour.startMenuTour());
        }
      },
      alignmentOffset: Offset(
        widget.collapsed ? CoeloSize.touchMin + CoeloSpacing.space4 + CoeloSpacing.space1 : 252,
        0,
      ),
      builder: (context, controller) {
        final content = Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('superadmin-onboarding-tour'),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
            child: SizedBox(
              width: widget.collapsed ? CoeloSize.touchMin : double.infinity,
              height: CoeloSize.touchMin,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useCompactLayout = widget.collapsed || constraints.maxWidth < 180;
                  return Row(
                    mainAxisAlignment: useCompactLayout
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (!useCompactLayout) const SizedBox(width: CoeloSpacing.space3),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            key: const Key('superadmin-onboarding-egg-motion'),
                            angle: _rotation.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: CoeloPalette.orange300.withValues(
                                      alpha: 0.38 * _glow.value,
                                    ),
                                    blurRadius: CoeloSpacing.space5 * _glow.value,
                                    spreadRadius: CoeloSpacing.space2 * _glow.value,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: SizedBox.square(
                          dimension: CoeloSize.iconMd,
                          child: CustomPaint(
                            key: const Key('superadmin-onboarding-egg'),
                            painter: _FlatEggPainter(
                              baseColor: visual.eggBase,
                              ornamentColor: visual.eggOrnament,
                            ),
                          ),
                        ),
                      ),
                      if (!useCompactLayout) ...[
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(child: Text('Fazer tour', style: theme.textTheme.labelLarge)),
                        Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                        const SizedBox(width: CoeloSpacing.space2),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
        return CoeloTourAnchor(
          id: 'tour-button',
          child: Tooltip(message: 'Iniciar onboarding', child: content),
        );
      },
    );
  }
}

const shellTourFlyoutItems = <CoeloAdminFlyoutItem<String>>[
  CoeloAdminFlyoutItem<String>(
    value: 'screen',
    label: 'Tour desta tela',
    icon: Icons.web_asset_outlined,
  ),
  CoeloAdminFlyoutItem<String>(value: 'menu', label: 'Tour do menu', icon: Icons.menu_open_rounded),
  CoeloAdminFlyoutItem<String>(
    value: 'complete',
    label: 'Tour completo',
    icon: Icons.play_circle_outline_rounded,
  ),
];

class _FlatEggPainter extends CustomPainter {
  const _FlatEggPainter({required this.baseColor, required this.ornamentColor});

  final Color baseColor;
  final Color ornamentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final egg = Path()
      ..moveTo(size.width * 0.5, 0)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.08,
        size.width,
        size.height * 0.5,
        size.width * 0.84,
        size.height * 0.82,
      )
      ..cubicTo(
        size.width * 0.7,
        size.height,
        size.width * 0.3,
        size.height,
        size.width * 0.16,
        size.height * 0.82,
      )
      ..cubicTo(0, size.height * 0.5, size.width * 0.22, size.height * 0.08, size.width * 0.5, 0)
      ..close();
    canvas.drawPath(egg, Paint()..color = baseColor);
    canvas
      ..save()
      ..clipPath(egg);
    final wave = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.62)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.45,
        size.width * 0.34,
        size.height * 0.8,
        size.width * 0.58,
        size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.44,
        size.width * 0.9,
        size.height * 0.7,
        size.width * 1.08,
        size.height * 0.54,
      );
    canvas
      ..drawPath(
        wave,
        Paint()
          ..color = ornamentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, size.height * 0.1)
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
    final dots = Paint()..color = ornamentColor;
    for (final center in [
      Offset(size.width * 0.3, size.height * 0.28),
      Offset(size.width * 0.5, size.height * 0.24),
      Offset(size.width * 0.7, size.height * 0.28),
    ]) {
      canvas.drawCircle(center, size.width * 0.06, dots);
    }
  }

  @override
  bool shouldRepaint(covariant _FlatEggPainter oldDelegate) {
    return baseColor != oldDelegate.baseColor || ornamentColor != oldDelegate.ornamentColor;
  }
}
