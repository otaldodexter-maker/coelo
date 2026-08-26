import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('invitation surfaces render at ${width.toInt()} without overflow', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = TestInviteRepository();

      for (final page in [
        InviteDirectoryPage(repository: repository),
        InviteFormPage(repository: repository, onCancel: () {}),
        InviteDetailPage(repository: repository, inviteId: repository.invites.single.id),
      ]) {
        await tester.pumpWidget(_app(page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final (label, pageBuilder) in <(String, Widget Function(TestInviteRepository))>[
    ('directory', (repository) => InviteDirectoryPage(repository: repository)),
    (
      'detail',
      (repository) =>
          InviteDetailPage(repository: repository, inviteId: repository.invites.single.id),
    ),
  ]) {
    testWidgets('$label remains usable at 375 with 200 percent text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = TestInviteRepository();

      await tester.pumpWidget(_scaledApp(pageBuilder(repository)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
      final inviteControl = label == 'directory'
          ? find.byKey(const Key('invite-create-action'))
          : find.byKey(const Key('invite-detail-revoke'));
      expect(inviteControl, findsOneWidget);
      expect(tester.getSize(inviteControl).height, greaterThanOrEqualTo(48));
    });
  }
}

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: child),
);

Widget _scaledApp(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, content) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
    child: content!,
  ),
  home: Scaffold(body: child),
);
