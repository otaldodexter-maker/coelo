import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('Aviso obrigatório'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmar')).onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });
}
