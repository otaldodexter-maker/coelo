import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses an administrative card instead of a popup for non-notice types', (
    tester,
  ) async {
    for (final type in [
      CommunicationType.content,
      CommunicationType.highlight,
      CommunicationType.forYou,
    ]) {
      await _openPreview(tester, _notice(type: type));
      expect(find.byKey(const Key('communication-card-preview')), findsOneWidget);
      expect(find.byKey(const Key('notice-popup-surface')), findsNothing);
      expect(find.text(type.label), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('renders text background preview without image', (tester) async {
    await _openPreview(tester, _notice());

    expect(find.byKey(const Key('notice-popup-text-background')), findsOneWidget);
    expect(find.byKey(const Key('notice-popup-image-horizontal')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not render an inert notice link', (tester) async {
    await _openPreview(tester, _notice(linkLabel: 'Read more'));

    expect(find.text('Read more'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('uses status container fallbacks for success and warning previews', (tester) async {
    await _openPreview(
      tester,
      _notice(behavior: NoticeBehavior.dismissible, backgroundTone: NoticeVisualTone.success),
    );
    expect(_surfaceColor(tester), CoeloStatusColors.light.successContainer);

    await tester.tap(find.widgetWithText(FilledButton, 'Fechar'));
    await tester.pumpAndSettle();
    await _openPreview(tester, _notice(backgroundTone: NoticeVisualTone.warning));
    expect(_surfaceColor(tester), CoeloStatusColors.light.warningContainer);
  });

  testWidgets('exposes web mobile and tablet preview semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final device in [
      NoticeTargetDevice.web,
      NoticeTargetDevice.mobile,
      NoticeTargetDevice.tablet,
    ]) {
      await _openPreview(
        tester,
        _notice(behavior: NoticeBehavior.dismissible, targetDevice: device),
      );
      expect(find.bySemanticsLabel('Pr\u00e9via do aviso em ${device.label}'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Fechar'));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
  });
  testWidgets('renders image orientations without overflow', (tester) async {
    await _openPreview(
      tester,
      _notice(
        behavior: NoticeBehavior.dismissible,
        contentFormat: NoticeContentFormat.image,
        imageOrientation: NoticeImageOrientation.horizontal,
      ),
    );
    expect(find.byKey(const Key('notice-popup-image-horizontal')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Fechar aviso'));
    await tester.pumpAndSettle();
    await _openPreview(
      tester,
      _notice(
        contentFormat: NoticeContentFormat.image,
        imageOrientation: NoticeImageOrientation.vertical,
      ),
    );
    expect(find.byKey(const Key('notice-popup-image-vertical')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissible notice closes without accepting', (tester) async {
    var accepted = false;
    await _openPreview(
      tester,
      _notice(behavior: NoticeBehavior.dismissible),
      onAccepted: () => accepted = true,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Fechar'));
    await tester.pumpAndSettle();

    expect(accepted, isFalse);
    expect(find.byKey(const Key('notice-preview-dialog')), findsNothing);
  });

  testWidgets('confirmation notice accepts when confirmed', (tester) async {
    var accepted = false;
    await _openPreview(
      tester,
      _notice(behavior: NoticeBehavior.confirmation),
      onAccepted: () => accepted = true,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
  });

  testWidgets('checkbox confirmation exposes device semantics and enables confirmation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _openPreview(
      tester,
      _notice(behavior: NoticeBehavior.checkboxConfirmation, targetDevice: NoticeTargetDevice.web),
    );

    expect(find.bySemanticsLabel('Pr\u00e9via do aviso em Web'), findsOneWidget);
    final confirmButton = find.widgetWithText(FilledButton, 'Confirmar');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.tap(find.byKey(const Key('notice-acknowledgement')));
    await tester.pump();

    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    expect(find.byTooltip('Sair da simula\u00e7\u00e3o'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('notice-acknowledgement'))).height,
      greaterThanOrEqualTo(CoeloSize.touchMin),
    );
    semantics.dispose();
  });
  testWidgets('acknowledgement uses the canonical administrative toggle', (tester) async {
    await _openPreview(tester, _notice(behavior: NoticeBehavior.checkboxConfirmation));
    final acknowledgement = find.byKey(const Key('notice-acknowledgement'));

    expect(tester.widget(acknowledgement), isA<CoeloAdminToggleField>());
    expect(tester.widget<CoeloAdminToggleField>(acknowledgement).value, isFalse);
  });

  testWidgets('acknowledgement expands without overflow at 200 percent text scale', (tester) async {
    await _openPreview(
      tester,
      _notice(behavior: NoticeBehavior.checkboxConfirmation),
      textScale: 2,
    );

    expect(
      tester.getSize(find.byKey(const Key('notice-acknowledgement'))).height,
      greaterThan(CoeloSize.touchMin),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps actions fixed while a 5000 character body scrolls at 200 percent', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(375, 600);
    addTearDown(tester.view.reset);
    await _openPreview(
      tester,
      _notice(message: List.filled(500, 'conteúdo').join(' ')),
      textScale: 2,
    );

    expect(find.byKey(const Key('notice-popup-body-scroll')), findsOneWidget);
    expect(find.byKey(const Key('notice-popup-primary-action')), findsOneWidget);
    await tester.drag(find.byKey(const Key('notice-popup-body-scroll')), const Offset(0, -300));
    await tester.pump();

    expect(find.byKey(const Key('notice-popup-primary-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkbox notice requires acknowledgement before confirming', (tester) async {
    var accepted = false;
    final notice = PlatformNotice(
      id: 'notice',
      title: 'Aviso obrigatório',
      message: 'Leia antes de continuar.',
      priority: NoticePriority.important,
      status: NoticeStatus.active,
      startsAt: DateTime.utc(2026, 8, 3),
      endsAt: null,
      audience: NoticeAudience.coeloTeam,
      audienceLabel: 'Equipe Coelo',
      behavior: NoticeBehavior.checkboxConfirmation,
      targetDevice: NoticeTargetDevice.all,
      mandatory: true,
      reach: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showNoticePreview(context, notice, onAccepted: () => accepted = true),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmar')).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('notice-acknowledgement')));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });
}

Future<void> _openPreview(
  WidgetTester tester,
  PlatformNotice notice, {
  VoidCallback? onAccepted,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showNoticePreview(context, notice, onAccepted: onAccepted),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

PlatformNotice _notice({
  CommunicationType type = CommunicationType.notice,
  NoticeBehavior behavior = NoticeBehavior.confirmation,
  NoticeContentFormat contentFormat = NoticeContentFormat.textBackground,
  NoticeImageOrientation imageOrientation = NoticeImageOrientation.vertical,
  NoticeTargetDevice targetDevice = NoticeTargetDevice.all,
  NoticeVisualTone backgroundTone = NoticeVisualTone.dark,
  NoticeVisualTone textTone = NoticeVisualTone.light,
  String? linkLabel,
  String message = 'Read before continuing.',
}) => PlatformNotice(
  type: type,
  id: 'notice',
  title: 'Notice preview',
  message: message,
  priority: NoticePriority.important,
  status: NoticeStatus.active,
  startsAt: DateTime.utc(2026, 8, 3),
  endsAt: null,
  audience: NoticeAudience.coeloTeam,
  audienceLabel: 'Coelo team',
  behavior: behavior,
  targetDevice: targetDevice,
  reach: 1,
  contentFormat: contentFormat,
  imageOrientation: imageOrientation,
  backgroundTone: backgroundTone,
  textTone: textTone,
  linkLabel: linkLabel,
);

Color _surfaceColor(WidgetTester tester) =>
    tester.widget<Material>(find.byKey(const Key('notice-popup-surface'))).color!;
