import 'dart:async';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_widgets.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_presentation_support.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  testWidgets('offers import and export file actions with explicit unavailable feedback', (
    tester,
  ) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminFileActions), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Importação de convites ainda não está disponível.'), findsOneWidget);
  });

  testWidgets('loads cards first and can switch to the aligned canonical table', (tester) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository, onCreate: () {})));
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.page, 1);
    expect(repository.lastQuery?.pageSize, 11);
    expect(
      tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).pageSizeOptions,
      InviteDirectoryQuery.cardPageSizes,
    );
    expect(find.byType(InviteDirectoryToolbar), findsOneWidget);
    expect(find.byType(InviteDirectoryCards), findsOneWidget);
    expect(find.byKey(const Key('invite-create-card')), findsOneWidget);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsOneWidget);
    expect(find.byType(InviteStatusChip), findsNothing);
    final cardStatus = tester.widget<CoeloAdminExpandableStatusIndicator>(
      find.byType(CoeloAdminExpandableStatusIndicator),
    );
    expect(cardStatus.semanticLabel, 'Status: Pendente');
    await tester.tap(find.byType(CoeloAdminExpandableStatusIndicator));
    await tester.pumpAndSettle();
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.byType(InviteDirectoryTable), findsNothing);
    expect(find.byType(SuperadminDirectoryViewToggle<InviteDirectoryTableView>), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(InviteDirectoryCards), findsNothing);
    expect(find.byType(InviteDirectoryTable), findsOneWidget);
    expect(find.byKey(const Key('invite-create-action')), findsOneWidget);
    expect(repository.lastQuery?.pageSize, 8);
    expect(
      tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).pageSizeOptions,
      InviteDirectoryQuery.tablePageSizes,
    );
    expect(find.byType(InviteStatusChip), findsOneWidget);
    final recipient = find.text('a***@aurora.test').first;
    final align = tester.widget<Align>(
      find.ancestor(of: recipient, matching: find.byType(Align)).first,
    );
    expect(align.alignment, Alignment.centerLeft);

    await tester.tap(find.byKey(const Key('invite-view-cards')));
    await tester.pumpAndSettle();
    expect(repository.lastQuery?.pageSize, 11);
    expect(find.text('a***@aurora.test'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Total de'), findsNothing);
    expect(find.textContaining('fict'), findsNothing);
  });

  testWidgets('debounces search and sends it to the repository', (tester) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ana');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.search, 'ana');
    expect(repository.lastQuery?.page, 1);
  });

  testWidgets('fails closed with an unauthorized state', (tester) async {
    final repository = TestInviteRepository(failure: const InviteUnauthorizedException());
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byType(InviteDirectoryTable), findsNothing);
    expect(find.byKey(const Key('invite-create-action')), findsNothing);
  });

  testWidgets('hides create surfaces when no callback is available', (tester) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-create-card')), findsNothing);
    expect(find.byKey(const Key('invite-create-action')), findsNothing);
  });

  testWidgets('keeps the create card beside empty, no-results and failure states', (tester) async {
    final repository = TestInviteRepository(invites: []);
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository, onCreate: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum convite'), findsOneWidget);
    expect(find.byKey(const Key('invite-create-card')), findsOneWidget);

    repository.invites = [testInvite()];
    await tester.enterText(find.byType(TextField).first, 'sem-resultado');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.byKey(const Key('invite-create-card')), findsOneWidget);

    repository.failure = Exception('offline');
    await tester.tap(find.byKey(const Key('invite-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Convites indisponíveis'), findsOneWidget);
    expect(find.byKey(const Key('invite-create-card')), findsOneWidget);
  });

  testWidgets('expired row offers resend and exposes the one-time link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
    await tester.pumpWidget(
      _app(InviteDirectoryPage(repository: repository, onOpen: (_) {}, allowCommands: true)),
    );
    await tester.pumpAndSettle();

    final trigger = find.byKey(const Key('invite-actions-11111111-1111-4111-8111-111111111111'));
    final dynamic flyout = tester.widget(
      find
          .ancestor(
            of: trigger,
            matching: find.byWidgetPredicate(
              (widget) => widget is CoeloAdminFlyout<InviteRowAction>,
            ),
          )
          .first,
    );
    flyout.onSelected(InviteRowAction.resend);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.lastResend?.expectedVersion, 1);
    expect(find.byKey(const Key('invite-resend-link')), findsOneWidget);
    expect(find.byKey(const Key('invite-resend-copy-link')), findsOneWidget);
  });

  testWidgets('ignores an older server response after a newer search completes', (tester) async {
    final repository = _RacingInviteRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository)));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'novo');
    await tester.pump(const Duration(milliseconds: 301));
    expect(repository.requests, hasLength(2));

    repository.requests[1].complete(
      InviteDirectoryResult(
        items: [testInvite(recipient: 'novo@coelo.test')],
        totalCount: 1,
        page: 1,
        pageSize: 20,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('novo@coelo.test'), findsAtLeastNWidgets(1));

    repository.requests[0].complete(
      InviteDirectoryResult(
        items: [testInvite(recipient: 'antigo@coelo.test')],
        totalCount: 1,
        page: 1,
        pageSize: 20,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('novo@coelo.test'), findsAtLeastNWidgets(1));
    expect(find.text('antigo@coelo.test'), findsNothing);
  });

  testWidgets('repository swap clears filters and cancels the previous debounce', (tester) async {
    final repositoryA = _RecordingInviteRepository([testInvite(recipient: 'tenant-a@coelo.test')]);
    final repositoryB = _RecordingInviteRepository([testInvite(recipient: 'tenant-b@coelo.test')]);
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repositoryA)));
    await tester.pumpAndSettle();

    final toolbarA = tester.widget<InviteDirectoryToolbar>(find.byType(InviteDirectoryToolbar));
    toolbarA.onStatusesChanged({InviteStatus.pending});
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tenant-a');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repositoryB)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    final toolbarB = tester.widget<InviteDirectoryToolbar>(find.byType(InviteDirectoryToolbar));
    expect(toolbarB.searchController.text, isEmpty);
    expect(toolbarB.statuses, isEmpty);
    expect(toolbarB.channels, isEmpty);
    expect(repositoryB.queries, hasLength(1));
    expect(repositoryB.queries.single.search, isEmpty);
    expect(repositoryB.queries.single.statuses, isEmpty);
    expect(repositoryA.queries, hasLength(2));
    expect(find.text('tenant-b@coelo.test'), findsAtLeastNWidgets(1));
    expect(find.text('tenant-a@coelo.test'), findsNothing);
  });

  testWidgets('repository swap dismisses an owned revoke dialog without commanding B', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repositoryA = _RecordingInviteRepository([testInvite()]);
    final repositoryB = _RecordingInviteRepository([testInvite(recipient: 'tenant-b@coelo.test')]);
    await tester.pumpWidget(
      _app(InviteDirectoryPage(repository: repositoryA, allowCommands: true)),
    );
    await tester.pumpAndSettle();

    _flyout(tester).onSelected(InviteRowAction.revoke);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-revoke-dialog')), findsOneWidget);

    await tester.pumpWidget(
      _app(InviteDirectoryPage(repository: repositoryB, allowCommands: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-revoke-dialog')), findsNothing);
    expect(find.text('tenant-a@coelo.test'), findsNothing);
    expect(repositoryB.revokes, isEmpty);
  });

  testWidgets('late resend receipt from A cannot open an overlay or refresh B', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repositoryA = _DeferredResendRepository();
    final repositoryB = _RecordingInviteRepository([testInvite(recipient: 'tenant-b@coelo.test')]);
    await tester.pumpWidget(
      _app(InviteDirectoryPage(repository: repositoryA, allowCommands: true)),
    );
    await tester.pumpAndSettle();

    _flyout(tester).onSelected(InviteRowAction.resend);
    await tester.pump();
    expect(repositoryA.commands, hasLength(1));

    await tester.pumpWidget(
      _app(InviteDirectoryPage(repository: repositoryB, allowCommands: true)),
    );
    await tester.pumpAndSettle();
    repositoryA.pending.complete(
      InviteCommandResult(
        invite: repositoryA.invite,
        replayed: false,
        link: Uri.parse('https://stale.example/invite'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-resend-link')), findsNothing);
    expect(find.textContaining('Reenvio solicitado'), findsNothing);
    expect(repositoryB.queries, hasLength(1));
    expect(find.text('tenant-b@coelo.test'), findsAtLeastNWidgets(1));
  });

  testWidgets('retries an ambiguous resend with the same request id', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _AmbiguousResendRepository();
    await tester.pumpWidget(
      _app(InviteDirectoryPage(repository: repository, onOpen: (_) {}, allowCommands: true)),
    );
    await tester.pumpAndSettle();

    final trigger = find.byKey(const Key('invite-actions-11111111-1111-4111-8111-111111111111'));
    dynamic flyout() => tester.widget(
      find
          .ancestor(
            of: trigger,
            matching: find.byWidgetPredicate(
              (widget) => widget is CoeloAdminFlyout<InviteRowAction>,
            ),
          )
          .first,
    );

    flyout().onSelected(InviteRowAction.resend);
    await tester.pumpAndSettle();
    flyout().onSelected(InviteRowAction.resend);
    await tester.pump();

    expect(repository.commands, hasLength(2));
    expect(repository.commands[1].requestId, repository.commands[0].requestId);
  });
}

dynamic _flyout(WidgetTester tester) {
  final trigger = find.byKey(const Key('invite-actions-11111111-1111-4111-8111-111111111111'));
  return tester.widget(
    find
        .ancestor(
          of: trigger,
          matching: find.byWidgetPredicate((widget) => widget is CoeloAdminFlyout<InviteRowAction>),
        )
        .first,
  );
}

final class _RecordingInviteRepository implements InviteRepository {
  _RecordingInviteRepository(this.invites);

  final List<PlatformInvite> invites;
  final List<InviteDirectoryQuery> queries = [];
  final List<InviteRevokeCommand> revokes = [];

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async {
    queries.add(query);
    return InviteDirectoryResult(
      items: invites,
      totalCount: invites.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<InviteCommandResult> revoke(InviteRevokeCommand command) async {
    revokes.add(command);
    return InviteCommandResult(invite: invites.single, replayed: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DeferredResendRepository implements InviteRepository {
  final invite = testInvite(status: InviteStatus.expired);
  final pending = Completer<InviteCommandResult>();
  final List<InviteResendCommand> commands = [];

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async =>
      InviteDirectoryResult(
        items: [invite],
        totalCount: 1,
        page: query.page,
        pageSize: query.pageSize,
      );

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) {
    commands.add(command);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AmbiguousResendRepository implements InviteRepository {
  final invite = testInvite(status: InviteStatus.expired);
  final List<InviteResendCommand> commands = [];

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) async =>
      InviteDirectoryResult(
        items: [invite],
        totalCount: 1,
        page: query.page,
        pageSize: query.pageSize,
      );

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) async {
    commands.add(command);
    if (commands.length == 1) throw Exception('ambiguous transport failure');
    return InviteCommandResult(invite: invite, replayed: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RacingInviteRepository implements InviteRepository {
  final List<Completer<InviteDirectoryResult>> requests = [];

  @override
  Future<InviteDirectoryResult> fetchPage(InviteDirectoryQuery query) {
    final request = Completer<InviteDirectoryResult>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: child),
);
