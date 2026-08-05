import 'dart:async';

import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_presentation_support.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a masked read-only detail with semantic status and timeline', (tester) async {
    await _pumpDetail(tester, inviteId: 'invite-1', size: const Size(375, 900));

    final pageSurface = tester.widget<ColoredBox>(
      find.byKey(const Key('invite-detail-page-surface')),
    );
    expect(pageSurface.color, CoeloTheme.light.colorScheme.surface);
    expect(find.text('o***@aurora.test'), findsOneWidget);
    expect(find.text('owner@aurora.test'), findsNothing);
    expect(find.textContaining('https://preview.coelo.test'), findsNothing);
    expect(find.byType(InviteStatusChip), findsOneWidget);
    await tester.drag(find.byKey(const Key('invite-detail-scroll')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Linha do tempo'), findsOneWidget);
    expect(find.text('Convite criado'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copies safely and revokes a pending invitation after confirmation', (tester) async {
    final repository = FakeInviteRepository(now: () => DateTime(2026, 8, 4, 12));
    await _pumpDetail(tester, repository: repository, inviteId: 'invite-1');

    expect(find.text('Copiar link'), findsOneWidget);
    expect(find.text('Reenviar convite'), findsOneWidget);
    expect(find.text('Revogar convite'), findsOneWidget);

    final divider = find.descendant(
      of: find.byKey(const Key('invite-detail-actions')),
      matching: find.byType(Divider),
    );
    expect(divider, findsOneWidget);
    expect(
      tester.getTopLeft(divider).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(const Key('invite-detail-resend'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('invite-detail-revoke'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(divider).dy),
    );
    final revoke = tester.widget<TextButton>(find.byKey(const Key('invite-detail-revoke')));
    expect(
      revoke.style?.foregroundColor?.resolve(<WidgetState>{}),
      CoeloTheme.light.colorScheme.error,
    );
    expect(
      revoke.style?.backgroundColor?.resolve(<WidgetState>{WidgetState.hovered}),
      CoeloTheme.light.colorScheme.errorContainer,
    );

    await tester.tap(find.text('Copiar link'));
    await tester.pumpAndSettle();
    expect(find.text('Link do convite copiado.'), findsOneWidget);
    expect(find.textContaining('https://preview.coelo.test'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revogar convite'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-revoke-dialog')), findsOneWidget);
    expect(repository.find('invite-1')!.status, InviteStatus.pending);

    await tester.tap(find.byKey(const Key('invite-revoke-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.find('invite-1')!.status, InviteStatus.revoked);
    expect(find.text('Convite revogado com sucesso.'), findsOneWidget);
    expect(find.text('Reenviar convite'), findsNothing);
    expect(find.text('Revogar convite'), findsNothing);
  });

  testWidgets('shows processing and error feedback for a failed safe copy', (tester) async {
    await _pumpDetail(tester, inviteId: 'invite-1');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final pendingCopy = Completer<void>();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) => pendingCopy.future);

    await tester.tap(find.byKey(const Key('invite-detail-copy')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('invite-detail-copy')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('invite-detail-resend'))).onPressed,
      isNull,
    );

    pendingCopy.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Link do convite copiado.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard-failed');
      }
      return null;
    });
    await tester.tap(find.byKey(const Key('invite-detail-copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Não foi possível concluir a ação.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('groups each timeline event semantically and hides its decorative icon', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpDetail(tester, inviteId: 'invite-1', size: const Size(375, 900));

    await tester.drag(find.byKey(const Key('invite-detail-scroll')), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Convite criado, ${formatInviteDate(DateTime(2026, 8, 4, 8))}'),
      findsOneWidget,
    );
    final eventSemantics = tester.widget<Semantics>(
      find.byKey(const Key('invite-timeline-event-0')),
    );
    expect(eventSemantics.excludeSemantics, isTrue);
    semantics.dispose();
  });

  testWidgets('hides invalid actions for an accepted invitation', (tester) async {
    await _pumpDetail(tester, inviteId: 'invite-2');

    expect(find.text('Copiar link'), findsOneWidget);
    expect(find.text('Reenviar convite'), findsNothing);
    expect(find.text('Revogar convite'), findsNothing);
  });

  testWidgets('uses the canonical missing invitation state', (tester) async {
    await _pumpDetail(tester, inviteId: 'missing');

    expect(find.byType(CoeloStatePanel), findsOneWidget);
    expect(find.text('Convite não encontrado'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  FakeInviteRepository? repository,
  required String inviteId,
  Size size = const Size(1024, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: InviteDetailPage(
          repository: repository ?? FakeInviteRepository(now: () => DateTime(2026, 8, 4, 12)),
          inviteId: inviteId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
