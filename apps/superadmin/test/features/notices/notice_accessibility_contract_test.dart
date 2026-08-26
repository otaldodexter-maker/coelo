import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_audience_selector.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_popup_preview.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_preview_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('audience selector accessibility', () {
    testWidgets('exposes 48px targets and supports select-all from the keyboard', (tester) async {
      final semantics = tester.ensureSemantics();
      var selection = const NoticeAudiencePickerSelection.explicit();
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => NoticeAudienceSelector(
              options: const [
                NoticeAudienceOption(
                  id: 'institution-1',
                  label: 'Aurora',
                  groupLabel: 'Instituições',
                ),
              ],
              selection: selection,
              onChanged: (value) => setState(() => selection = value),
            ),
          ),
        ),
      );

      final selectAll = find.byKey(const Key('notice-audience-select-all'));
      final option = find.byKey(const Key('notice-audience-option-institution-1'));
      expect(tester.getSize(selectAll).height, greaterThanOrEqualTo(CoeloSize.touchMin));
      expect(tester.getSize(option).height, greaterThanOrEqualTo(CoeloSize.touchMin));
      expect(find.bySemanticsLabel('Selecionar todos os 1 resultados filtrados'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notice-audience-search')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(selection.allMatching, isTrue);
      semantics.dispose();
    });

    testWidgets('remains usable at 200 percent text on 375px', (tester) async {
      _setViewport(tester, const Size(375, 900));
      await tester.pumpWidget(
        _app(
          const SingleChildScrollView(
            child: NoticeAudienceSelector(
              options: [
                NoticeAudienceOption(
                  id: 'person-1',
                  label: 'Maria da Silva',
                  groupLabel: 'Pessoas',
                  description: 'Responsável · Unidade Centro',
                ),
              ],
              selection: NoticeAudiencePickerSelection.explicit(),
            ),
          ),
          textScale: 2,
        ),
      );

      expect(find.text('Maria da Silva'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('popup accessibility and geometry', () {
    testWidgets('applies size presets with device clamping', (tester) async {
      _setViewport(tester, const Size(1440, 1000));

      for (final expectation in [
        (NoticePopupSize.compact, NoticeTargetDevice.web, 360.0),
        (NoticePopupSize.standard, NoticeTargetDevice.web, 520.0),
        (NoticePopupSize.large, NoticeTargetDevice.web, 880.0),
        (NoticePopupSize.large, NoticeTargetDevice.tablet, 768.0),
        (NoticePopupSize.large, NoticeTargetDevice.mobile, 375.0),
      ]) {
        await _pumpPreview(
          tester,
          _notice(popupSize: expectation.$1, hasOuterInset: false),
          device: expectation.$2,
        );

        final surface = find.byKey(Key('notice-popup-size-${expectation.$1.name}'));
        expect(tester.getSize(surface).width, expectation.$3, reason: '$expectation');
      }
    });

    testWidgets('fullscreen fills the viewport and keeps 48px actions', (tester) async {
      _setViewport(tester, const Size(1024, 768));
      await _pumpPreview(
        tester,
        _notice(popupSize: NoticePopupSize.fullscreen, hasOuterInset: true),
      );

      final size = tester.getSize(find.byKey(const Key('notice-popup-size-fullscreen')));
      expect(size, const Size(1024, 768));
      expect(
        tester.getSize(find.byKey(const Key('notice-popup-primary-action'))).height,
        greaterThanOrEqualTo(CoeloSize.touchMin),
      );
      expect(find.byKey(const Key('notice-popup-outer-inset')), findsNothing);
    });

    testWidgets('supports 200 percent text and reduced motion on compact mobile', (tester) async {
      _setViewport(tester, const Size(375, 900));
      await _pumpPreview(
        tester,
        _notice(popupSize: NoticePopupSize.compact, hasOuterInset: true),
        device: NoticeTargetDevice.mobile,
        textScale: 2,
        disableAnimations: true,
      );

      final title = find.text('Atualização importante');
      expect(title, findsOneWidget);
      expect(MediaQuery.disableAnimationsOf(tester.element(title)), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('close action uses semantic error hover and focus states', (tester) async {
      await _pumpPreview(
        tester,
        _notice(popupSize: NoticePopupSize.standard, hasOuterInset: true),
        onClose: () {},
      );

      final close = tester.widget<IconButton>(find.byKey(const Key('notice-popup-close')));
      final colors = Theme.of(
        tester.element(find.byKey(const Key('notice-popup-close'))),
      ).colorScheme;
      expect(close.style?.foregroundColor?.resolve({}), colors.error);
      for (final state in [WidgetState.hovered, WidgetState.focused]) {
        expect(close.style?.backgroundColor?.resolve({state}), colors.errorContainer);
        expect(close.style?.foregroundColor?.resolve({state}), colors.error);
        expect(close.style?.overlayColor?.resolve({state}), Colors.transparent);
      }
    });

    testWidgets('dialog closes with Escape', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showNoticePreview(
                context,
                _notice(popupSize: NoticePopupSize.standard, hasOuterInset: true),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notice-popup-primary-action')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notice-preview-dialog')), findsNothing);
    });
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
}

Widget _app(Widget child, {double textScale = 1, bool disableAnimations = false}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(body: child),
);

Future<void> _pumpPreview(
  WidgetTester tester,
  PlatformNotice notice, {
  NoticeTargetDevice device = NoticeTargetDevice.web,
  double textScale = 1,
  bool disableAnimations = false,
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    _app(
      NoticePopupPreview(
        notice: notice,
        device: device,
        checkboxChecked: false,
        onCheckboxChanged: null,
        onClose: onClose,
      ),
      textScale: textScale,
      disableAnimations: disableAnimations,
    ),
  );
  await tester.pump();
}

PlatformNotice _notice({required NoticePopupSize popupSize, required bool hasOuterInset}) =>
    PlatformNotice(
      id: 'notice-1',
      title: 'Atualização importante',
      message: 'Confira as novas orientações.',
      priority: NoticePriority.important,
      status: NoticeStatus.draft,
      startsAt: DateTime(2026, 8, 11),
      endsAt: null,
      audience: NoticeAudience.everyone,
      audienceLabel: 'Todos',
      behavior: NoticeBehavior.confirmation,
      targetDevice: NoticeTargetDevice.all,
      reach: 0,
      buttonLabel: 'Entendi',
      buttonColorValue: const Color(0xFF146C43).toARGB32(),
      popupSize: popupSize,
      hasOuterInset: hasOuterInset,
    );
