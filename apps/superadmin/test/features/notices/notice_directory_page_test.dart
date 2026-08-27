import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  testWidgets('uses the shell title without repeating a local heading', (tester) async {
    final repository = _repository()
      ..create(_draft(1, type: CommunicationType.notice))
      ..create(_draft(2, type: CommunicationType.content))
      ..create(_draft(3, type: CommunicationType.highlight))
      ..create(_draft(4, type: CommunicationType.forYou));

    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Comunicações do app'), findsNothing);
    for (final label in ['Todos', 'Avisos', 'Conteúdos', 'Destaques', 'Para você']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('Conteúdos').first);
    await tester.pump();
    expect(find.text('Aviso 2'), findsWidgets);
    expect(find.text('Aviso 1'), findsNothing);
  });

  testWidgets('uses the canonical large directory inset', (tester) async {
    await _pumpDirectory(tester, repository: _repository(), size: const Size(1440, 900));

    final inset = tester.widget<Padding>(find.byKey(const Key('notice-directory-content-inset')));
    expect(inset.padding, const EdgeInsets.all(CoeloSpacing.space10));
  });

  testWidgets('uses cards on compact width and the canonical table on medium width', (
    tester,
  ) async {
    final repository = _repository()..create(_draft(1));
    await _pumpDirectory(tester, repository: repository, size: const Size(375, 800));
    expect(find.byKey(const Key('notice-card-list')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<PlatformNotice>), findsNothing);

    await _pumpDirectory(tester, repository: repository, size: const Size(1024, 800));
    expect(find.byType(CoeloAdminResizableTable<PlatformNotice>), findsOneWidget);
  });

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

    await tester.tap(find.text('Nova comunicação').first);
    await tester.pump();
    expect(created, isTrue);
    expect(find.byType(NoticeFormPage), findsNothing);

    await tester.ensureVisible(find.text('Aviso 24').first);
    await tester.tap(find.text('Aviso 24').first);
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

    await tester.tap(find.byTooltip('Ações da comunicação').first);
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
    final enabledConfirm = tester.widget<FilledButton>(
      find.byKey(const Key('notice-inactivate-confirm')),
    );
    expect(enabledConfirm.onPressed, isNotNull);
    final colors = Theme.of(
      tester.element(find.byKey(const Key('notice-inactivate-confirm'))),
    ).colorScheme;
    expect(enabledConfirm.style?.backgroundColor?.resolve({}), colors.error);
    expect(enabledConfirm.style?.foregroundColor?.resolve({}), colors.onError);
    expect(
      enabledConfirm.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.errorContainer,
    );
    expect(enabledConfirm.style?.foregroundColor?.resolve({WidgetState.hovered}), colors.error);
    expect(enabledConfirm.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
  });

  testWidgets('keeps Nova comunicação visible in empty and no-results states', (tester) async {
    final repository = _repository();
    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Nenhuma comunicação'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);
  });

  testWidgets('keeps creation and retry actions when loading fails', (tester) async {
    final repository = _repository()..nextError = const NoticeUnexpectedException();
    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(find.text('Nenhuma comunicação'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);
  });

  testWidgets('renders only the forbidden state when directory access is denied', (tester) async {
    final repository = _repository()..nextError = const NoticeUnauthorizedException();
    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.byType(CoeloAdminListingToolbar), findsNothing);
    expect(find.byKey(const Key('notice-directory-content-inset')), findsOneWidget);
    expect(find.text('Todos'), findsNothing);
    expect(find.text('Nova comunicação'), findsNothing);
  });
}

Future<void> _pumpDirectory(
  WidgetTester tester, {
  required FakeNoticeRepository repository,
  VoidCallback? onCreate,
  ValueChanged<String>? onEdit,
  Size size = const Size(1440, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
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

NoticeDraft _draft(int index, {CommunicationType type = CommunicationType.notice}) => NoticeDraft(
  type: type,
  title: 'Aviso $index',
  message: 'Mensagem $index',
  priority: NoticePriority.routine,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.dismissible,
);
