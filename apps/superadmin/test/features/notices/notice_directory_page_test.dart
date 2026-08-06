import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/data/fake_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps creation and edition outside the paginated directory', (tester) async {
    var created = false;
    String? editedId;
    final repository = _repository(extraNotices: 9);

    await _pumpDirectory(
      tester,
      repository: repository,
      onCreate: () => created = true,
      onEdit: (id) => editedId = id,
    );

    expect(find.byType(NoticeFormPage), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    await tester.tap(find.text('Novo aviso').first);
    await tester.pump();
    expect(created, isTrue);
    expect(find.byType(NoticeFormPage), findsNothing);

    await tester.tap(find.text('Aviso 8'));
    await tester.pump();
    expect(editedId, isNotNull);

    var pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.currentPage, 1);
    expect(pagination.pageSize, 8);
    expect(pagination.pageSizeOptions, const [8, 16, 24]);

    pagination.onNext?.call();
    await tester.pump();
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.currentPage, 2);
    expect(find.text('Aviso 0'), findsOneWidget);
  });
}

Future<void> _pumpDirectory(
  WidgetTester tester, {
  required FakeNoticeRepository repository,
  VoidCallback? onCreate,
  ValueChanged<String>? onEdit,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NoticeDirectoryPage(repository: repository, onCreate: onCreate, onEdit: onEdit),
      ),
    ),
  );
  await tester.pump();
}

FakeNoticeRepository _repository({int extraNotices = 0}) {
  final now = DateTime.utc(2026, 8, 3, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  final repository = FakeNoticeRepository(store: store, now: () => now);
  for (var index = 0; index < extraNotices; index++) {
    repository.create(_draft(index));
  }
  return repository;
}

NoticeDraft _draft(int index) => NoticeDraft(
  title: 'Aviso $index',
  message: 'Mensagem $index',
  priority: NoticePriority.routine,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.dismissible,
);
