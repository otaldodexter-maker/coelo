import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';

final class InstitutionStatusChip extends StatelessWidget {
  const InstitutionStatusChip({required this.status, super.key});

  final InstitutionStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = institutionStatusColors(context, status);
    return CoeloStatusChip(
      label: status.label,
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

final class ExpandableInstitutionStatusIndicator extends StatefulWidget {
  const ExpandableInstitutionStatusIndicator({
    required this.itemId,
    required this.status,
    super.key,
  });

  final String itemId;
  final InstitutionStatus status;

  @override
  State<ExpandableInstitutionStatusIndicator> createState() =>
      _ExpandableInstitutionStatusIndicatorState();
}

final class _ExpandableInstitutionStatusIndicatorState
    extends State<ExpandableInstitutionStatusIndicator> {
  bool _hovered = false;
  bool _focused = false;
  bool _expandedByTap = false;

  bool get _expanded => _hovered || _focused || _expandedByTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = institutionStatusColors(context, widget.status);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: Semantics(
          button: true,
          label: 'Status: ${widget.status.label}',
          child: GestureDetector(
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: TweenAnimationBuilder<double>(
              key: Key('institution-status-${widget.itemId}'),
              tween: Tween(begin: 0, end: _expanded ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Container(
                width: 24 + (math.max(56, 24 + widget.status.label.length * 6.5) - 24) * progress,
                height: CoeloSpacing.space6,
                padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space2 * progress),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(CoeloRadius.full),
                  border: Border.all(
                    color: foreground.withValues(alpha: _focused ? 0.48 : 0.28),
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: progress == 0
                    ? null
                    : Opacity(
                        opacity: progress,
                        child: Text(
                          widget.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

(Color, Color) institutionStatusColors(BuildContext context, InstitutionStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  final colors = theme.colorScheme;
  return switch (status) {
    InstitutionStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
    InstitutionStatus.onboarding => (statusColors.infoContainer, statusColors.onInfoContainer),
    InstitutionStatus.suspended => (statusColors.errorContainer, statusColors.onErrorContainer),
    InstitutionStatus.draft => (statusColors.warningContainer, statusColors.onWarningContainer),
    InstitutionStatus.inactive ||
    InstitutionStatus.archived => (colors.surfaceContainer, colors.onSurfaceVariant),
  };
}
