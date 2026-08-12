import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  testWidgets('keeps creation and edition outside the paginated directory', (tester) async {
    var created = false;
    String? editedId;
    final repository = _repository(extraNotices: 25);

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

    await tester.tap(find.text('Aviso 24'));
    await tester.pump();
    expect(editedId, isNotNull);

    var pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.currentPage, 1);
    expect(pagination.pageSize, 24);
    expect(pagination.pageSizeOptions, const [12, 24, 48]);

    pagination.onNext?.call();
    await tester.pump();
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.currentPage, 2);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
  });

  testWidgets('requires an audit reason before inactivating a notice', (tester) async {
    final repository = _repository();
    repository.create(_draft(1));
    await _pumpDirectory(tester, repository: repository);

    await tester.tap(find.byTooltip('Ações do aviso').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inativar').last);
    await tester.pumpAndSettle();

    expect(find.text('Inativar aviso'), findsWidgets);
    final confirm = tester.widget<FilledButton>(find.byKey(const Key('notice-inactivate-confirm')));
    expect(confirm.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('notice-inactivate-reason')),
      'Conteúdo substituído por comunicado vigente.',
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('notice-inactivate-confirm'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('keeps Novo aviso visible in empty and no-results states', (tester) async {
    final repository = _repository();
    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Nenhum aviso'), findsOneWidget);
    expect(find.text('Novo aviso'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.text('Novo aviso'), findsOneWidget);
  });

  testWidgets('keeps creation and retry actions when loading fails', (tester) async {
    final repository = _repository()..nextError = const NoticeUnexpectedException();
    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Novo aviso'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(find.text('Nenhum aviso'), findsOneWidget);
    expect(find.text('Novo aviso'), findsOneWidget);
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
