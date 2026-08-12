import 'dart:async';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_widgets.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  testWidgets('loads the authorised server page and renders the aligned canonical table', (
    tester,
  ) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository)));
    await tester.pumpAndSettle();

    expect(repository.lastQuery?.page, 1);
    expect(repository.lastQuery?.pageSize, 20);
    expect(find.byType(InviteDirectoryToolbar), findsOneWidget);
    expect(find.byType(InviteDirectoryTable), findsOneWidget);
    expect(find.text('a***@aurora.test'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Total de'), findsNothing);
    expect(find.textContaining('fict'), findsNothing);

    final recipient = find.text('a***@aurora.test').first;
    final align = tester.widget<Align>(
      find.ancestor(of: recipient, matching: find.byType(Align)).first,
    );
    expect(align.alignment, Alignment.centerLeft);
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
  });

  testWidgets('expired row offers resend and exposes the one-time link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository, onOpen: (_) {})));
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

  testWidgets('retries an ambiguous resend with the same request id', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _AmbiguousResendRepository();
    await tester.pumpWidget(_app(InviteDirectoryPage(repository: repository, onOpen: (_) {})));
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
