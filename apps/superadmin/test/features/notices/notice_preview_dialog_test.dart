import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_preview_dialog.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('checkbox notice requires acknowledgement before confirming', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _app(
        _notice(behavior: NoticeBehavior.checkboxConfirmation, mandatory: true),
        onAccepted: () => accepted = true,
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final acknowledgement = find.byKey(const Key('notice-acknowledgement'));
    expect(acknowledgement, findsOneWidget);
    expect(tester.widget<CoeloAdminToggleField>(acknowledgement).value, isFalse);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmar')).onPressed,
      isNull,
    );

    await tester.tap(acknowledgement);
    await tester.pump();
    expect(tester.widget<CoeloAdminToggleField>(acknowledgement).value, isTrue);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('confirmation notice accepts without acknowledgement', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _app(
        _notice(behavior: NoticeBehavior.confirmation, mandatory: true),
        onAccepted: () => accepted = true,
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notice-acknowledgement')), findsNothing);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('dismissible notice closes without accepting', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _app(_notice(behavior: NoticeBehavior.dismissible), onAccepted: () => accepted = true),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    expect(accepted, isFalse);
    expect(find.byKey(const Key('notice-preview-dialog')), findsNothing);
  });
}

PlatformNotice _notice({required NoticeBehavior behavior, bool mandatory = false}) =>
    PlatformNotice(
      id: 'notice',
      title: 'Aviso obrigatório',
      message: 'Leia antes de continuar.',
      priority: NoticePriority.important,
      status: NoticeStatus.active,
      startsAt: DateTime.utc(2026, 8, 3),
      endsAt: null,
      audience: NoticeAudience.coeloTeam,
      audienceLabel: 'Equipe Coelo',
      behavior: behavior,
      mandatory: mandatory,
      targetDevice: NoticeTargetDevice.all,
      reach: 1,
    );

Widget _app(PlatformNotice notice, {VoidCallback? onAccepted}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => FilledButton(
        onPressed: () => showNoticePreview(context, notice, onAccepted: onAccepted),
        child: const Text('Abrir'),
      ),
    ),
  ),
);
