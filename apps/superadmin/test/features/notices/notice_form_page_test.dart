import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/data/fake_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses canonical accessible controls and renders UTF-8 labels', (tester) async {
    tester.view.physicalSize = const Size(1024, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final activity = SuperadminActivityController();
    final store = SuperadminPrototypeStore(activityController: activity);
    final repository = FakeNoticeRepository(store: store);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoticeFormPage(repository: repository, embedded: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo'), findsOneWidget);
    expect(find.textContaining('conteúdo'), findsWidgets);

    final startDate = find.byKey(const ValueKey('notice-date-Data de início'));
    expect(startDate, findsWidgets);
    expect(tester.widget(startDate.first), isA<OutlinedButton>());

    expect(find.text('Aviso obrigatório'), findsOneWidget);
  });
}
