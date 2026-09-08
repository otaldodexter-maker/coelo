import 'dart:async';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_sections.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  testWidgets('disposing detail removes only its confirmation beneath another route', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final repository = TestInviteRepository();
    Widget host(bool showDetail) => MaterialApp(
      navigatorKey: navigator,
      theme: CoeloTheme.light,
      home: showDetail
          ? InviteDetailPage(
              repository: repository,
              inviteId: repository.invites.single.id,
              allowCommands: true,
            )
          : const Scaffold(body: Text('Origem')),
    );
    await tester.pumpWidget(host(true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-detail-revoke')));
    await tester.pumpAndSettle();
    unawaited(
      navigator.currentState!.push(
        DialogRoute<void>(
          context: navigator.currentContext!,
          builder: (_) => const Dialog(child: Text('Outra rota')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(false));
    await tester.pumpAndSettle();
    expect(find.text('Outra rota'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Origem'), findsOneWidget);
    expect(find.byKey(const Key('invite-revoke-dialog')), findsNothing);
    expect(repository.lastRevoke, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final revoke in [false, true]) {
    testWidgets('captured ${revoke ? 'revoke' : 'resend'} callback cannot run after denial', (
      tester,
    ) async {
      final repository = TestInviteRepository();
      await tester.pumpWidget(
        _app(
          InviteDetailPage(
            repository: repository,
            inviteId: repository.invites.single.id,
            allowCommands: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final resend = tester
          .widget<OutlinedButton>(find.byKey(const Key('invite-detail-resend')))
          .onPressed!;
      final captured = revoke
          ? tester.widget<TextButton>(find.byKey(const Key('invite-detail-revoke'))).onPressed!
          : resend;
      repository.failure = const InviteUnauthorizedException();
      resend();
      await tester.pumpAndSettle();
      expect(find.text('Acesso não autorizado'), findsOneWidget);
      repository.failure = null;
      captured();
      await tester.pumpAndSettle();
      expect(repository.lastResend, isNull);
      expect(repository.lastRevoke, isNull);
      expect(find.byKey(const Key('invite-revoke-dialog')), findsNothing);
      expect(find.byKey(const Key('invite-result-link')), findsNothing);
    });
  }

  testWidgets('late unauthorized resend cannot purge replacement repository detail', (
    tester,
  ) async {
    final invite = testInvite(status: InviteStatus.expired);
    final first = _DeferredResendRepository([invite]);
    final second = TestInviteRepository(invites: [testInvite(recipient: 'b***@aurora.test')]);
    Widget page(InviteRepository repository) =>
        _app(InviteDetailPage(repository: repository, inviteId: invite.id, allowCommands: true));
    await tester.pumpWidget(page(first));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pump();
    await tester.pumpWidget(page(second));
    await tester.pumpAndSettle();
    first._pending.single.completeError(const InviteUnauthorizedException());
    await tester.pumpAndSettle();
    expect(find.text('b***@aurora.test'), findsOneWidget);
    expect(find.text('Acesso não autorizado'), findsNothing);
  });

  testWidgets('transient resend error keeps the authorized context for explicit retry', (
    tester,
  ) async {
    final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          repository: repository,
          inviteId: repository.invites.single.id,
          allowCommands: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.failure = const InviteUnavailableException();
    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pumpAndSettle();
    expect(find.text('a***@aurora.test'), findsOneWidget);
    expect(find.text('Acesso não autorizado'), findsNothing);
    repository.failure = null;
    await tester.tap(find.byKey(const Key('invite-detail-resend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-result-link')), findsOneWidget);
  });

  for (final change in ['repository', 'round-trip', 'commands-disabled']) {
    testWidgets('old revoke confirmation is invalidated by $change', (tester) async {
      final first = TestInviteRepository();
      final second = TestInviteRepository();
      Widget page(TestInviteRepository repository, {bool allow = true}) => _app(
        InviteDetailPage(
          repository: repository,
          inviteId: first.invites.single.id,
          allowCommands: allow,
        ),
      );
      await tester.pumpWidget(page(first));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-detail-revoke')));
      await tester.pumpAndSettle();
      if (change == 'commands-disabled') {
        await tester.pumpWidget(page(first, allow: false));
      } else {
        await tester.pumpWidget(page(second));
        if (change == 'round-trip') await tester.pumpWidget(page(first));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-revoke-dialog')), findsNothing);
      expect(first.lastRevoke, isNull);
      expect(second.lastRevoke, isNull);
    });
  }

  for (final revoke in [false, true]) {
    testWidgets('${revoke ? 'revoke' : 'resend'} denial removes retained link and detail', (
      tester,
    ) async {
      final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
      await tester.pumpWidget(
        _app(
          InviteDetailPage(
            repository: repository,
            inviteId: repository.invites.single.id,
            allowCommands: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-detail-resend')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-result-link')), findsOneWidget);
      repository.failure = const InviteUnauthorizedException();
      await tester.tap(find.byKey(Key(revoke ? 'invite-detail-revoke' : 'invite-detail-resend')));
      await tester.pumpAndSettle();
      if (revoke) {
        await tester.tap(find.byKey(const Key('invite-revoke-confirm')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Acesso não autorizado'), findsOneWidget);
      expect(find.byKey(const Key('invite-result-link')), findsNothing);
      expect(find.text('a***@aurora.test'), findsNothing);
      expect(find.byKey(const Key('invite-detail-resend')), findsNothing);
      expect(find.byKey(const Key('invite-detail-revoke')), findsNothing);
    });
  }

  testWidgets('groups identity, actions and detail sections with responsive hierarchy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = TestInviteRepository();
    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          repository: repository,
          inviteId: repository.invites.single.id,
          allowCommands: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite-detail-header')), findsOneWidget);
    expect(find.byKey(const Key('invite-detail-data-section')), findsOneWidget);
    expect(find.byKey(const Key('invite-detail-timeline-section')), findsOneWidget);
    final header = tester.widget<Flex>(find.byKey(const Key('invite-detail-header')));
    expect(header.direction, Axis.horizontal);
  });

  testWidgets('expired invitation presents resend as the primary action and shows new link', (
    tester,
  ) async {
    final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
    await tester.pumpWidget(
      _app(
        InviteDetailPage(
          repository: repository,
          inviteId: repository.invites.single.id,
          allowCommands: true,
        ),
      ),
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
      _app(
        InviteDetailPage(
          repository: repository,
          inviteId: repository.invites.single.id,
          allowCommands: true,
        ),
      ),
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
      _app(
        InviteDetailPage(
          repository: repository,
          inviteId: repository.invites.single.id,
          allowCommands: true,
        ),
      ),
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
          allowCommands: true,
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
          allowCommands: true,
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
          allowCommands: true,
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
          allowCommands: true,
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
