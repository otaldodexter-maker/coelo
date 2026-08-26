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
    this.onPrimaryPressed,
    this.onClose,
    super.key,
  });

  final PlatformNotice notice;
  final NoticeTargetDevice device;
  final bool checkboxChecked;
  final ValueChanged<bool>? onCheckboxChanged;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fullscreen = notice.popupSize == NoticePopupSize.fullscreen;
      final maxWidth = _previewWidth(notice.popupSize, device, constraints.maxWidth);
      final inset = notice.hasOuterInset && !fullscreen;
      final surface = ConstrainedBox(
        key: Key('notice-popup-size-${notice.popupSize.name}'),
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          minHeight: fullscreen && constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        ),
        child: _PopupSurface(
          notice: notice,
          checkboxChecked: checkboxChecked,
          onCheckboxChanged: onCheckboxChanged,
          onPrimaryPressed: onPrimaryPressed,
          onClose: onClose,
          fullscreen: fullscreen,
        ),
      );

      return Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Prévia do aviso em ${device.label}',
        child: Center(
          child: inset
              ? Padding(
                  key: const Key('notice-popup-outer-inset'),
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: surface,
                )
              : surface,
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
    required this.onPrimaryPressed,
    required this.onClose,
    required this.fullscreen,
  });

  final PlatformNotice notice;
  final bool checkboxChecked;
  final ValueChanged<bool>? onCheckboxChanged;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onClose;
  final bool fullscreen;

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
    final buttonColor = notice.buttonColorValue == null
        ? colors.primary
        : Color(notice.buttonColorValue!);
    final buttonForeground = _bestForeground(buttonColor);
    final requiresCheckbox = notice.behavior == NoticeBehavior.checkboxConfirmation;
    final buttonEnabled = !requiresCheckbox || checkboxChecked;

    return Material(
      key: const Key('notice-popup-surface'),
      color: backgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fullscreen ? 0 : CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          mainAxisSize: fullscreen ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onClose != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  key: const Key('notice-popup-close'),
                  tooltip: notice.mandatory ? 'Sair da simulação' : 'Fechar aviso',
                  onPressed: onClose,
                  style:
                      IconButton.styleFrom(
                        foregroundColor: colors.error,
                        minimumSize: const Size.square(CoeloSize.touchMin),
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused) ||
                                  states.contains(WidgetState.pressed)
                              ? colors.errorContainer
                              : Colors.transparent,
                        ),
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                key: const Key('notice-popup-body-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PreviewContent(notice: notice, textColor: textColor),
                    if (requiresCheckbox) ...[
                      const SizedBox(height: CoeloSpacing.space4),
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
            ),
            const SizedBox(height: CoeloSpacing.space4),
            FilledButton(
              key: const Key('notice-popup-primary-action'),
              onPressed: buttonEnabled ? (onPrimaryPressed ?? () {}) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                backgroundColor: buttonColor,
                foregroundColor: buttonForeground,
                disabledBackgroundColor: buttonColor.withValues(alpha: 0.38),
                disabledForegroundColor: buttonForeground.withValues(alpha: 0.7),
              ),
              child: Text(
                notice.behavior == NoticeBehavior.dismissible ? 'Fechar' : notice.buttonLabel,
              ),
            ),
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
    NoticeContentFormat.textBackground => _NoticeCopy(
      key: const Key('notice-popup-text-background'),
      notice: notice,
      textColor: textColor,
    ),
    NoticeContentFormat.image => Column(
      key: Key(
        notice.imageOrientation == NoticeImageOrientation.horizontal
            ? 'notice-popup-image-horizontal'
            : 'notice-popup-image-vertical',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'A imagem não está disponível na prévia.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _NoticeCopy(notice: notice, textColor: textColor),
      ],
    ),
  };
}

final class _NoticeCopy extends StatelessWidget {
  const _NoticeCopy({required this.notice, required this.textColor, super.key});

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

double _previewWidth(NoticePopupSize size, NoticeTargetDevice device, double availableWidth) {
  final presetWidth = switch (size) {
    NoticePopupSize.compact => 360.0,
    NoticePopupSize.standard => 520.0,
    NoticePopupSize.large => 880.0,
    NoticePopupSize.fullscreen => availableWidth,
  };
  final deviceWidth = switch (device) {
    NoticeTargetDevice.mobile => 375.0,
    NoticeTargetDevice.tablet => 768.0,
    NoticeTargetDevice.web || NoticeTargetDevice.all => availableWidth,
  };
  return presetWidth.clamp(0, deviceWidth.clamp(0, availableWidth));
}

Color _bestForeground(Color background) {
  final blackContrast = _contrastRatio(background, Colors.black);
  final whiteContrast = _contrastRatio(background, Colors.white);
  return blackContrast >= whiteContrast ? Colors.black : Colors.white;
}

double _contrastRatio(Color first, Color second) {
  final high = first.computeLuminance() > second.computeLuminance() ? first : second;
  final low = identical(high, first) ? second : first;
  return (high.computeLuminance() + 0.05) / (low.computeLuminance() + 0.05);
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
