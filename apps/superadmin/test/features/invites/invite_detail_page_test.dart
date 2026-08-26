import 'dart:async';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_sections.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  testWidgets('expired invitation presents resend as the primary action and shows new link', (
    tester,
  ) async {
    final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
    await tester.pumpWidget(
      _app(InviteDetailPage(repository: repository, inviteId: repository.invites.single.id)),
    );
    await tester.pumpAndSettle();

    final resend = tester.widget<FilledButton>(find.byKey(const Key('invite-detail-resend')));
    expect(resend.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pumpAndSettle();

    expect(repository.lastResend?.expectedVersion, 1);
    expect(find.byKey(const Key('invite-result-link')), findsOneWidget);
  });

  testWidgets('revocation remains negative, confirmed and versioned', (tester) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(
      _app(InviteDetailPage(repository: repository, inviteId: repository.invites.single.id)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invite-detail-revoke')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-revoke-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-revoke-confirm')));
    await tester.pumpAndSettle();

    expect(repository.lastRevoke?.expectedVersion, 1);
    expect(repository.lastRevoke?.reason, isNotEmpty);
    expect(find.text('Revogado'), findsOneWidget);
  });

  testWidgets('does not enumerate an unavailable invitation', (tester) async {
    final repository = TestInviteRepository(invites: const []);
    await tester.pumpWidget(_app(InviteDetailPage(repository: repository, inviteId: 'other')));
    await tester.pumpAndSettle();

    expect(find.text('Convite não encontrado'), findsOneWidget);
    expect(find.textContaining('tenant'), findsNothing);
  });

  testWidgets('does not resend a fresh pending invitation before expiry', (tester) async {
    final repository = TestInviteRepository(
      invites: [testInvite(status: InviteStatus.pending, expiresAt: DateTime.utc(2099, 1, 1))],
    );
    await tester.pumpWidget(
      _app(InviteDetailPage(repository: repository, inviteId: repository.invites.single.id)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-detail-resend')), findsNothing);
    expect(find.byKey(const Key('invite-detail-revoke')), findsOneWidget);
  });

  testWidgets('shows email delivery state only when email is selected', (tester) async {
    final emailInvite = testInvite(channels: const {InviteChannel.email});
    await tester.pumpWidget(
      _app(
        InviteDeliveryResult(
          result: InviteCommandResult(invite: emailInvite, replayed: false),
          onDone: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('invite-result-email-state')), findsOneWidget);
    expect(
      find.text('E-mail na fila. A entrega ainda depende da confirmação do provedor.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('invite-result-link')), findsNothing);

    final linkInvite = testInvite(channels: const {InviteChannel.link});
    const dangerousText = 'javascript:alert(1)';
    await tester.pumpWidget(
      _app(
        InviteDeliveryResult(
          result: InviteCommandResult(
            invite: linkInvite,
            replayed: false,
            link: Uri.parse(dangerousText),
          ),
          onDone: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('invite-result-email-state')), findsNothing);
    expect(find.byKey(const Key('invite-result-link')), findsOneWidget);
    expect(find.text(dangerousText), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('invite-result-link')),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });

  testWidgets('clears a one-time link when the routed invitation id changes', (tester) async {
    final first = testInvite(status: InviteStatus.expired);
    final second = testInvite(
      id: '77777777-7777-4777-8777-777777777777',
      recipient: 'b***@aurora.test',
    );
    final repository = TestInviteRepository(invites: [first, second]);

    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          key: const Key('routed-invite-detail'),
          repository: repository,
          inviteId: first.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-result-link')), findsOneWidget);

    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          key: const Key('routed-invite-detail'),
          repository: repository,
          inviteId: second.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('b***@aurora.test'), findsOneWidget);
    expect(find.byKey(const Key('invite-result-link')), findsNothing);
  });

  testWidgets('route change isolates a late resend and starts with a new request id', (
    tester,
  ) async {
    final first = testInvite(status: InviteStatus.expired);
    final second = testInvite(
      id: '77777777-7777-4777-8777-777777777777',
      recipient: 'b***@aurora.test',
      status: InviteStatus.expired,
    );
    final repository = _DeferredResendRepository([first, second]);

    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          key: const Key('routed-invite-detail'),
          repository: repository,
          inviteId: first.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pump();
    expect(repository.commands, hasLength(1));

    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          key: const Key('routed-invite-detail'),
          repository: repository,
          inviteId: second.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.completeNext(first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-result-link')), findsNothing);
    expect(find.text('Não foi possível reenviar o convite.'), findsNothing);

    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pump();
    expect(repository.commands, hasLength(2));
    expect(repository.commands[1].requestId, isNot(repository.commands[0].requestId));

    repository.completeNext(second);
    await tester.pumpAndSettle();
  });
}

final class _DeferredResendRepository implements InviteRepository {
  _DeferredResendRepository(this.invites);

  final List<PlatformInvite> invites;
  final List<InviteResendCommand> commands = [];
  final List<Completer<InviteCommandResult>> _pending = [];

  @override
  Future<PlatformInvite?> fetchById(String inviteId) async =>
      invites.where((invite) => invite.id == inviteId).firstOrNull;

  @override
  Future<InviteCommandResult> resend(InviteResendCommand command) {
    commands.add(command);
    final completer = Completer<InviteCommandResult>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(PlatformInvite invite) {
    _pending
        .removeAt(0)
        .complete(
          InviteCommandResult(
            invite: invite,
            replayed: false,
            link: Uri.parse('https://app.coelo.me/convites/once'),
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: child),
);
