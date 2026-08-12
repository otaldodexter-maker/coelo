import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  testWidgets('uses canonical frame with footer after rail', (tester) async {
    await _pumpForm(tester, const Size(1024, 900));
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    final navigation = tester.getRect(find.byType(SuperadminFormStepNavigation));
    final footer = tester.getRect(find.byType(SuperadminFormActionFooter));
    expect(navigation.width, 248);
    expect(footer.left, greaterThanOrEqualTo(navigation.right + CoeloSpacing.space6));
  });

  testWidgets('supports 200 percent text on compact wizard', (tester) async {
    await _pumpForm(tester, const Size(375, 900), textScale: 2);
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpForm(WidgetTester tester, Size size, {double textScale = 1}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final now = DateTime.utc(2026, 8, 6, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: NoticeFormPage(
          repository: FakeNoticeRepository(store: store, now: () => now),
        ),
      ),
    ),
  );
  await tester.pump();
}
