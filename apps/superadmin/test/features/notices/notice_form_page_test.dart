import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  testWidgets('validates and advances through the five notice wizard steps on mobile', (
    tester,
  ) async {
    await _pumpForm(tester, const Size(375, 812));

    expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.text('Informe o título do aviso para continuar.'), findsOneWidget);
    expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);

    await tester.enterText(_fieldIn(const Key('notice-title')), 'Manutenção programada');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-content')), findsOneWidget);

    await tester.enterText(_fieldIn(const Key('notice-message')), 'O serviço ficará indisponível.');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-audience')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-schedule')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    expect(find.byKey(const Key('notice-step-review')), findsOneWidget);
    expect(find.text('Manutenção programada'), findsWidgets);
    expect(find.byType(Card), findsNothing);
    expect(find.byKey(const Key('notice-metrics-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('has no layout exception at mobile and desktop widths', (tester) async {
    for (final size in [const Size(375, 812), const Size(1440, 900)]) {
      await _pumpForm(tester, size);

      expect(find.byKey(const Key('notice-step-identity')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'layout at ${size.width}px');
    }
  });
}

Finder _fieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

Future<void> _pumpForm(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final now = DateTime.utc(2026, 8, 6, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  final repository = FakeNoticeRepository(store: store, now: () => now);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NoticeFormPage(repository: repository)),
    ),
  );
  await tester.pump();
}
