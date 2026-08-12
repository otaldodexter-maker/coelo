import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_popup_preview.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_preview_dialog.dart';

void main() {
  testWidgets('preview renders configured CTA, size and outer inset', (tester) async {
    final notice = _notice(
      popupSize: NoticePopupSize.compact,
      hasOuterInset: true,
      buttonColorValue: const Color(0xFF146C43).toARGB32(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoticePopupPreview(
            notice: notice,
            device: NoticeTargetDevice.web,
            checkboxChecked: false,
            onCheckboxChanged: null,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('notice-popup-size-compact')), findsOneWidget);
    expect(find.byKey(const Key('notice-popup-outer-inset')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entendi'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Entendi'));
    expect(button.style?.backgroundColor?.resolve({}), const Color(0xFF146C43));
  });

  testWidgets('fullscreen dialog removes outer inset and closes through CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNoticePreview(
              context,
              _notice(popupSize: NoticePopupSize.fullscreen, hasOuterInset: true),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notice-preview-dialog-fullscreen')), findsOneWidget);
    expect(find.byKey(const Key('notice-popup-outer-inset')), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Entendi'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Entendi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notice-preview-dialog-fullscreen')), findsNothing);
  });
}

PlatformNotice _notice({
  required NoticePopupSize popupSize,
  required bool hasOuterInset,
  int? buttonColorValue,
}) => PlatformNotice(
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
  buttonColorValue: buttonColorValue,
  popupSize: popupSize,
  hasOuterInset: hasOuterInset,
);
