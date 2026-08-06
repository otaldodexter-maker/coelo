import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/platform_notice.dart';

final class NoticePopupPreview extends StatelessWidget {
  const NoticePopupPreview({
    required this.notice,
    required this.device,
    required this.checkboxChecked,
    required this.onCheckboxChanged,
    super.key,
  });

  final PlatformNotice notice;
  final NoticeTargetDevice device;
  final bool checkboxChecked;
  final ValueChanged<bool>? onCheckboxChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Pr\u00e9via do aviso em ${device.label}',
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 360 : 520),
            child: _PopupSurface(
              notice: notice,
              checkboxChecked: checkboxChecked,
              onCheckboxChanged: onCheckboxChanged,
            ),
          ),
        ),
      );
    },
  );
}

final class _PopupSurface extends StatelessWidget {
  const _PopupSurface({
    required this.notice,
    required this.checkboxChecked,
    required this.onCheckboxChanged,
  });

  final PlatformNotice notice;
  final bool checkboxChecked;
  final ValueChanged<bool>? onCheckboxChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final backgroundColor = notice.backgroundColorValue == null
        ? _backgroundFallback(colors, statusColors, notice.backgroundTone)
        : Color(notice.backgroundColorValue!);
    final textColor = notice.textColorValue == null
        ? _textFallback(colors, statusColors, notice.textTone)
        : Color(notice.textColorValue!);

    return DecoratedBox(
      key: const Key('notice-popup-surface'),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewContent(notice: notice, textColor: textColor),
            if (onCheckboxChanged != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              CoeloAdminToggleField(
                key: const Key('notice-acknowledgement'),
                label: 'Li e estou ciente deste aviso.',
                value: checkboxChecked,
                onChanged: onCheckboxChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.notice, required this.textColor});

  final PlatformNotice notice;
  final Color textColor;

  @override
  Widget build(BuildContext context) => switch (notice.contentFormat) {
    NoticeContentFormat.textBackground => Container(
      key: const Key('notice-popup-text-background'),
      width: double.infinity,
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: _NoticeCopy(notice: notice, textColor: textColor),
    ),
    NoticeContentFormat.image => _ImagePreview(notice: notice, textColor: textColor),
  };
}

final class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.notice, required this.textColor});

  final PlatformNotice notice;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final horizontal = notice.imageOrientation == NoticeImageOrientation.horizontal;
    return Container(
      key: Key(horizontal ? 'notice-popup-image-horizontal' : 'notice-popup-image-vertical'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: horizontal ? 16 / 9 : 3 / 4,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (notice.showImagePlaceholder)
                const Center(child: Icon(Icons.image_outlined, size: CoeloSize.iconLg)),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: _NoticeCopy(notice: notice, textColor: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _NoticeCopy extends StatelessWidget {
  const _NoticeCopy({required this.notice, required this.textColor});

  final PlatformNotice notice;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        notice.title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: textColor, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        notice.message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    ],
  );
}

Color _backgroundFallback(
  ColorScheme colors,
  CoeloStatusColors statusColors,
  NoticeVisualTone tone,
) => switch (tone) {
  NoticeVisualTone.brand => colors.primary,
  NoticeVisualTone.dark => colors.inverseSurface,
  NoticeVisualTone.light => colors.surface,
  NoticeVisualTone.neutral => colors.surfaceContainer,
  NoticeVisualTone.success => statusColors.successContainer,
  NoticeVisualTone.warning => statusColors.warningContainer,
  NoticeVisualTone.danger => colors.error,
};

Color _textFallback(ColorScheme colors, CoeloStatusColors statusColors, NoticeVisualTone tone) =>
    switch (tone) {
      NoticeVisualTone.brand => colors.onPrimary,
      NoticeVisualTone.dark => colors.onInverseSurface,
      NoticeVisualTone.light || NoticeVisualTone.neutral => colors.onSurface,
      NoticeVisualTone.success => statusColors.onSuccessContainer,
      NoticeVisualTone.warning => statusColors.onWarningContainer,
      NoticeVisualTone.danger => colors.onError,
    };
