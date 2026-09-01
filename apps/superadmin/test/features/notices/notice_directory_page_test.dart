import 'dart:async';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_popup_preview.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_preview_dialog.dart';
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

  testWidgets('repository swap clears tenant A before a late response', (tester) async {
    final stalePage = Completer<NoticePage>();
    final noticeA = _repository().create(_draft(91));
    var loadsA = 0;
    final repositoryA = _DeferredNoticeRepository((query) {
      if (loadsA++ == 0) return Future.value(NoticePage(items: [noticeA]));
      return stalePage.future;
    });
    final repositoryB = _DeferredNoticeRepository(
      (_) => Future<NoticePage>.error(const NoticeUnauthorizedException()),
    );

    Widget app(NoticeRepository repository) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: NoticeDirectoryPage(
          repository: repository,
          canManageLifecycle: true,
          onCreate: () {},
          onEdit: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(app(repositoryA));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 91'), findsWidgets);

    await tester.enterText(find.byType(EditableText).first, 'Aviso');
    await tester.pump(const Duration(milliseconds: 310));
    expect(loadsA, 2);

    await tester.pumpWidget(app(repositoryB));
    await tester.pumpAndSettle();
    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.text('Aviso 91'), findsNothing);
    expect(find.byType(CoeloAdminListingToolbar), findsNothing);
    expect(find.text('Nova comunicação'), findsNothing);

    stalePage.complete(NoticePage(items: [noticeA.copyWith(title: 'Resposta tardia A')]));
    await tester.pumpAndSettle();
    expect(find.text('Resposta tardia A'), findsNothing);
    expect(find.text('Sem permissão'), findsOneWidget);
  });

  testWidgets('late lifecycle command from tenant A cannot refresh tenant B', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.reset);
    final pendingPublish = Completer<PlatformNotice>();
    final noticeA = _repository().create(_draft(93));
    final noticeB = _repository().create(_draft(94));
    var loadsB = 0;
    final repositoryA = _DeferredNoticeRepository(
      (_) => Future.value(NoticePage(items: [noticeA])),
      publishHandler: (_, {required requestId, required expectedVersion}) => pendingPublish.future,
    );
    final repositoryB = _DeferredNoticeRepository((_) async {
      loadsB++;
      return NoticePage(items: [noticeB]);
    });

    Widget app(NoticeRepository repository) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: NoticeDirectoryPage(repository: repository, canManageLifecycle: true)),
    );

    await tester.pumpWidget(app(repositoryA));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações da comunicação').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar').last);
    await tester.pump();

    await tester.pumpWidget(app(repositoryB));
    await tester.pumpAndSettle();
    expect(find.text('Aviso 94'), findsWidgets);
    expect(loadsB, 1);

    pendingPublish.complete(noticeA.copyWith(status: NoticeStatus.active, managementVersion: 1));
    await tester.pumpAndSettle();

    expect(find.text('Aviso 94'), findsWidgets);
    expect(find.textContaining('Publicação agendada'), findsNothing);
    expect(loadsB, 1);
  });

  testWidgets('repository swap dismisses tenant A preview overlay', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.reset);
    final noticeA = _repository().create(_draft(95));
    final repositoryA = _DeferredNoticeRepository(
      (_) => Future.value(NoticePage(items: [noticeA])),
    );
    final repositoryB = _DeferredNoticeRepository(
      (_) => Future<NoticePage>.error(const NoticeUnauthorizedException()),
    );

    Widget app(NoticeRepository repository) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: NoticeDirectoryPage(repository: repository, canManageLifecycle: true)),
    );

    await tester.pumpWidget(app(repositoryA));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações da comunicação').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pré-visualizar popup').last);
    await tester.pumpAndSettle();
    expect(find.byType(NoticePreviewDialog), findsOneWidget);
    expect(find.text('Aviso 95'), findsWidgets);

    await tester.pumpWidget(app(repositoryB));
    await tester.pumpAndSettle();
    expect(find.byType(NoticePreviewDialog), findsNothing);
    expect(find.text('Aviso 95'), findsNothing);
    expect(find.text('Sem permissão'), findsOneWidget);

    await tester.pumpWidget(app(repositoryA));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações da comunicação').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inativar').last);
    await tester.pumpAndSettle();
    expect(find.text('Inativar aviso'), findsWidgets);

    await tester.pumpWidget(app(repositoryB));
    await tester.pumpAndSettle();
    expect(find.text('Inativar aviso'), findsNothing);
    expect(find.text('Sem permissão'), findsOneWidget);
  });

  testWidgets('cancellation request ids follow the normalized command payload', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.reset);
    final notice = _repository().create(_draft(96));
    final requestIds = <String>[];
    final repository = _DeferredNoticeRepository(
      (_) => Future.value(NoticePage(items: [notice])),
      changeStatusHandler:
          (_, {required requestId, required status, required expectedVersion, reason}) async {
            requestIds.add(requestId);
            throw const NoticeUnavailableException();
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: NoticeDirectoryPage(repository: repository, canManageLifecycle: true)),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> cancelWith(String reason) async {
      await tester.tap(find.byTooltip('Ações da comunicação').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inativar').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('notice-inactivate-reason')), reason);
      await tester.pump();
      await tester.tap(find.byKey(const Key('notice-inactivate-confirm')));
      await tester.pumpAndSettle();
    }

    await cancelWith('Motivo original');
    await cancelWith('Motivo alterado');
    await cancelWith('  Motivo alterado  ');

    expect(requestIds, hasLength(3));
    expect(requestIds[1], isNot(requestIds[0]));
    expect(requestIds[2], requestIds[1]);
  });

  testWidgets('uses the canonical large directory inset', (tester) async {
    await _pumpDirectory(tester, repository: _repository(), size: const Size(1440, 900));

    final inset = tester.widget<Padding>(find.byKey(const Key('notice-directory-content-inset')));
    expect(inset.padding, const EdgeInsets.all(CoeloSpacing.space10));
  });

  testWidgets('exposes honest unavailable import and export actions', (tester) async {
    await _pumpDirectory(tester, repository: _repository(), size: const Size(1440, 900));

    final fileActions = tester.widget<CoeloAdminFileActions>(find.byType(CoeloAdminFileActions));
    fileActions.actions.first.onPressed!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('A importação de comunicações ainda não está disponível.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
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

  testWidgets('matches the approved responsive creation contract without a view toggle', (
    tester,
  ) async {
    final repository = _repository()..create(_draft(1));

    await _pumpDirectory(
      tester,
      repository: repository,
      onCreate: () {},
      size: const Size(375, 800),
    );
    expect(find.byKey(const Key('create-notice-card')), findsOneWidget);
    expect(find.byKey(const Key('create-notice-banner')), findsNothing);
    expect(find.text('Cards'), findsNothing);
    expect(find.text('Tabela'), findsNothing);

    await _pumpDirectory(
      tester,
      repository: repository,
      onCreate: () {},
      size: const Size(768, 800),
    );
    expect(find.byKey(const Key('create-notice-card')), findsNothing);
    expect(find.byKey(const Key('create-notice-banner')), findsOneWidget);
    expect(find.text('Cards'), findsNothing);
    expect(find.text('Tabela'), findsNothing);
  });

  testWidgets('uses the exact Institution table rhythm and uniform type badges', (tester) async {
    final repository = _repository()
      ..create(_draft(1, type: CommunicationType.notice))
      ..create(_draft(2, type: CommunicationType.content))
      ..create(_draft(3, type: CommunicationType.highlight))
      ..create(_draft(4, type: CommunicationType.forYou));

    await _pumpDirectory(tester, repository: repository, size: const Size(1440, 900));

    final table = tester.widget<CoeloAdminResizableTable<PlatformNotice>>(
      find.byType(CoeloAdminResizableTable<PlatformNotice>),
    );
    expect(table.headerHeight, 56);
    expect(table.rowHeight, 64);

    final badgeWidths = <double>[];
    for (final type in CommunicationType.values) {
      final box = tester.renderObject<RenderBox>(
        find.byKey(Key('communication-type-badge-${type.storageValue}')),
      );
      badgeWidths.add(box.size.width);
    }
    expect(badgeWidths.toSet(), hasLength(1));
  });

  testWidgets('shows a selectable right preview only when explicitly enabled', (tester) async {
    final repository = _repository()
      ..create(_draft(1, type: CommunicationType.content))
      ..create(_draft(2, type: CommunicationType.content));

    await _pumpDirectory(
      tester,
      repository: repository,
      inlinePreview: true,
      size: const Size(1440, 900),
    );
    await tester.tap(find.text('Conteúdos').first);
    await tester.pump();

    expect(find.byKey(const Key('notice-directory-inline-preview')), findsOneWidget);
    expect(find.byType(CommunicationPreviewCard), findsOneWidget);
    expect(find.byType(NoticePopupPreview), findsNothing);
    expect(find.text('Prévia administrativa'), findsWidgets);
    expect(find.text('Aviso 2'), findsWidgets);

    await tester.tap(find.text('Aviso 1').first);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('notice-directory-inline-preview')),
        matching: find.text('Aviso 1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the canonical table without a side preview below large width', (tester) async {
    final repository = _repository()..create(_draft(1, type: CommunicationType.content));

    await _pumpDirectory(
      tester,
      repository: repository,
      inlinePreview: true,
      size: const Size(1024, 900),
    );
    await tester.tap(find.text('Conteúdos').first);
    await tester.pump();

    expect(find.byType(CoeloAdminResizableTable<PlatformNotice>), findsOneWidget);
    expect(find.byKey(const Key('notice-directory-inline-preview')), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(pagination.pageSize, 8);
    expect(pagination.pageSizeOptions, const [8, 20, 50, 100]);

    pagination.onNext?.call();
    await tester.pump();
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.currentPage, 2);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
  });

  testWidgets('uses the literal Institutions page sizes for cards and table', (tester) async {
    final compactRepository = _repository(extraNotices: 25);
    await _pumpDirectory(tester, repository: compactRepository, size: const Size(375, 900));
    final compactFooter = tester.widget<SuperadminListingPaginationFooter>(
      find.byType(SuperadminListingPaginationFooter),
    );
    var pagination = compactFooter.child as CoeloAdminPagination;
    expect(pagination.pageSize, 11);
    expect(pagination.pageSizeOptions, const [11, 20, 50, 100]);
    expect(compactFooter.compactCurrentPage, 1);
    expect(compactFooter.compactTotalPages, greaterThan(1));
    expect(compactFooter.compactOnPrevious, isNull);
    expect(compactFooter.compactOnNext, isNotNull);

    final tableRepository = _repository(extraNotices: 25);
    await _pumpDirectory(tester, repository: tableRepository, size: const Size(768, 900));
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.pageSize, 8);
    expect(pagination.pageSizeOptions, const [8, 20, 50, 100]);
  });

  testWidgets('uses the constrained content width for compact pagination', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    final repository = _repository(extraNotices: 25);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 560,
              height: 900,
              child: NoticeDirectoryPage(repository: repository, canManageLifecycle: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final footer = tester.widget<SuperadminListingPaginationFooter>(
      find.byType(SuperadminListingPaginationFooter),
    );
    final pagination = footer.child as CoeloAdminPagination;
    expect(pagination.pageSize, 11);
    expect(pagination.pageSizeOptions, const [11, 20, 50, 100]);
  });

  testWidgets('keeps tabular cells on one line at 200 percent text', (tester) async {
    final repository = _repository()..create(_draft(1));
    await _pumpDirectory(
      tester,
      repository: repository,
      size: const Size(1440, 1000),
      textScaler: const TextScaler.linear(2),
    );

    final validity = tester.widget<Text>(find.textContaining('Desde ').first);
    expect(validity.maxLines, 1);
    expect(validity.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
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
    await _pumpDirectory(tester, repository: repository, onCreate: () {});

    expect(find.text('Nenhuma comunicação'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);
    expect(find.byKey(const Key('create-notice-banner')), findsOneWidget);
    expect(find.byKey(const Key('create-notice-card')), findsNothing);

    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);
    expect(find.byKey(const Key('create-notice-banner')), findsOneWidget);
  });

  testWidgets('uses the canonical creation tile in compact empty state', (tester) async {
    await _pumpDirectory(
      tester,
      repository: _repository(),
      onCreate: () {},
      size: const Size(375, 812),
    );

    expect(find.byKey(const Key('create-notice-card')), findsOneWidget);
    expect(find.byKey(const Key('create-notice-banner')), findsNothing);
  });

  testWidgets('keeps creation and retry actions when loading fails', (tester) async {
    final repository = _repository()..nextError = const NoticeUnexpectedException();
    await _pumpDirectory(tester, repository: repository, onCreate: () {});

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byKey(const Key('create-notice-banner')), findsOneWidget);

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

  testWidgets('omits creation in empty and content states without a real callback', (tester) async {
    final repository = _repository();
    await _pumpDirectory(tester, repository: repository);

    expect(find.text('Nenhuma comunicação'), findsOneWidget);
    expect(find.text('Nova comunicação'), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);

    final repositoryWithContent = _repository()..create(_draft(92));
    await _pumpDirectory(tester, repository: repositoryWithContent);
    expect(find.text('Aviso 92'), findsWidgets);
    expect(find.text('Nova comunicação'), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });
}

Future<void> _pumpDirectory(
  WidgetTester tester, {
  required FakeNoticeRepository repository,
  VoidCallback? onCreate,
  ValueChanged<String>? onEdit,
  bool inlinePreview = false,
  Size size = const Size(1440, 900),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: NoticeDirectoryPage(
          repository: repository,
          canManageLifecycle: true,
          onCreate: onCreate,
          onEdit: onEdit,
          enableInlinePreview: inlinePreview,
        ),
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

final class _DeferredNoticeRepository implements NoticeRepository {
  const _DeferredNoticeRepository(this._fetchPage, {this.publishHandler, this.changeStatusHandler});

  final Future<NoticePage> Function(NoticeDirectoryQuery query) _fetchPage;
  final Future<PlatformNotice> Function(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  })?
  publishHandler;
  final Future<PlatformNotice> Function(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  })?
  changeStatusHandler;

  @override
  Future<NoticePage> fetchPage(NoticeDirectoryQuery query) => _fetchPage(query);

  @override
  Future<PlatformNotice> publish(
    PlatformNotice notice, {
    required String requestId,
    required int expectedVersion,
  }) => publishHandler!(notice, requestId: requestId, expectedVersion: expectedVersion);

  @override
  Future<PlatformNotice> changeStatus(
    String noticeId, {
    required String requestId,
    required NoticeStatus status,
    required int expectedVersion,
    String? reason,
  }) => changeStatusHandler!(
    noticeId,
    requestId: requestId,
    status: status,
    expectedVersion: expectedVersion,
    reason: reason,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
