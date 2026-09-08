import 'dart:async';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_widgets.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_sections.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

const _failure = 'Não foi possível copiar o link. Tente novamente.';
final _link = Uri.parse('https://app.coelo.me/convites/synthetic-copy');

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: child),
);

Widget _result({Uri? link}) => InviteDeliveryResult(
  result: InviteCommandResult(invite: testInvite(), replayed: false, link: link ?? _link),
);

void main() {
  testWidgets('delivery result keeps the link after clipboard failure and permits retry', (
    tester,
  ) async {
    final copies = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        copies.add((call.arguments as Map)['text'] as String);
        if (copies.length == 1) throw PlatformException(code: 'denied', message: 'private-token');
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_app(_result()));
    await tester.tap(find.byKey(const Key('invite-result-copy-link')));
    await tester.pumpAndSettle();
    expect(find.text(_failure), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    expect(find.byKey(const Key('invite-result-link')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-result-copy-link')));
    await tester.pumpAndSettle();
    expect(copies, [_link.toString(), _link.toString()]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend dialog stays open on copy failure and closes after successful retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData' && ++copies == 1) {
        throw PlatformException(code: 'denied');
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      _app(
        InviteDirectoryPage(
          repository: TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]),
          allowCommands: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminFlyout<InviteRowAction>>(
          find.byType(CoeloAdminFlyout<InviteRowAction>).first,
        )
        .onSelected(InviteRowAction.resend);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('invite-resend-copy-link')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_failure), findsOneWidget);
    expect(find.byKey(const Key('invite-resend-link')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-resend-copy-link')));
    await tester.pumpAndSettle();
    expect(copies, 2);
    expect(find.byKey(const Key('invite-resend-link')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final replace in [false, true]) {
    testWidgets(
      'late copy failure stays silent after result ${replace ? 'replacement' : 'removal'}',
      (tester) async {
        final pending = Completer<void>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') await pending.future;
          return null;
        });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(_app(_result()));
        await tester.tap(find.byKey(const Key('invite-result-copy-link')));
        await tester.pump();
        await tester.pumpWidget(
          _app(
            replace
                ? _result(link: Uri.parse('https://app.coelo.me/convites/other'))
                : const Text('Outro contexto'),
          ),
        );
        pending.completeError(PlatformException(code: 'denied'));
        await tester.pumpAndSettle();
        expect(find.text(_failure), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
