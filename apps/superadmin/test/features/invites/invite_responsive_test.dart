import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_widgets.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'invite directory follows cards-table at ${width.toInt()} and ${scale.toInt()}00%',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final repository = TestInviteRepository();

          await tester.pumpWidget(
            _scaledApp(
              InviteDirectoryPage(repository: repository, onOpen: (_) {}),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.byType(SuperadminDirectoryViewToggle<InviteDirectoryTableView>),
            findsOneWidget,
          );
          expect(find.byType(InviteDirectoryCards), findsOneWidget);
          expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
          final gridWidth = tester.getSize(find.byKey(const Key('invite-card-grid'))).width;
          final cardWidth = tester
              .getSize(find.byKey(const Key('invite-card-11111111-1111-4111-8111-111111111111')))
              .width;
          if (width == 375) {
            expect(cardWidth, closeTo(gridWidth, 1));
          } else {
            expect(cardWidth, lessThanOrEqualTo(360));
          }

          await tester.tap(find.byKey(const Key('invite-view-table')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(InviteDirectoryTable), findsOneWidget);
          expect(find.byType(CoeloAdminResizableTable<PlatformInvite>), findsOneWidget);
        },
      );
    }
  }

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
    ('directory', (repository) => InviteDirectoryPage(repository: repository, onCreate: () {})),
    (
      'detail',
      (repository) => InviteDetailPage(
        repository: repository,
        inviteId: repository.invites.single.id,
        allowCommands: true,
      ),
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
          ? find.byKey(const Key('invite-create-card'))
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

Widget _scaledApp(Widget child, {double scale = 2}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, content) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: content!,
  ),
  home: Scaffold(body: child),
);
