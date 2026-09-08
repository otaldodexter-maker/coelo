import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

/// Regression guard for the compact communication card after the shared status
/// indicator started reserving the project's 48 px touch target.
///
/// Before the fix the indicator sat in the title row, so the title lost 24 px,
/// wrapped onto a second line and pushed the card rhythm down. The touch target
/// is not negotiable, so the card moved the indicator to the descriptor row.
void main() {
  setUpAll(_loadFonts);

  const title = 'Para você de exemplo';

  Future<void> pumpDirectory(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.reset);
    final now = DateTime.utc(2026, 8, 20, 12);
    final store = SuperadminPrototypeStore(
      activityController: SuperadminActivityController(now: () => now),
      now: () => now,
    );
    final repository = FakeNoticeRepository(store: store, now: () => now)
      ..create(
        const NoticeDraft(
          type: CommunicationType.notice,
          title: title,
          message: 'Mensagem de exemplo',
          priority: NoticePriority.routine,
          audience: NoticeAudience.everyone,
          audienceLabel: 'Todos',
          behavior: NoticeBehavior.dismissible,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: NoticeDirectoryPage(
            repository: repository,
            onEdit: (_) {},
            canManageLifecycle: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the compact card title on a single line', (tester) async {
    await pumpDirectory(tester);

    final titleFinder = find.text(title);
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: Theme.of(tester.element(titleFinder)).textTheme.titleMedium,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final size = tester.getSize(titleFinder);
    expect(
      size.width,
      greaterThan(painter.width),
      reason: 'the title must keep more width than a single rendered line needs',
    );
    expect(
      size.height,
      lessThan(painter.height * 2),
      reason: 'the title must not wrap onto a second line at 375',
    );
  });

  testWidgets('keeps the 48 px status target without overlapping its neighbours', (tester) async {
    await pumpDirectory(tester);

    final status = find.byType(CoeloAdminExpandableStatusIndicator);
    expect(tester.getSize(status), const Size(CoeloSize.touchMin, CoeloSize.touchMin));

    final statusRect = tester.getRect(status);
    final titleRect = tester.getRect(find.text(title));
    final menuRect = tester.getRect(find.byTooltip('Ações da comunicação').first);
    expect(statusRect.overlaps(titleRect), isFalse);
    expect(statusRect.overlaps(menuRect), isFalse);

    // The enlarged target must receive the pointer at its own centre and must
    // not steal a tap that belongs to the type badge beside it.
    expect(find.text('Rascunho'), findsNothing);
    await tester.tapAt(statusRect.center);
    await tester.pumpAndSettle();
    expect(find.text('Rascunho'), findsOneWidget);

    await tester.tapAt(statusRect.center);
    await tester.pumpAndSettle();
    expect(find.text('Rascunho'), findsNothing);

    await tester.tapAt(Offset(statusRect.left - 4, statusRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Rascunho'), findsNothing);
  });

  testWidgets('keeps the status indicator focusable and announced', (tester) async {
    await pumpDirectory(tester);

    final handle = tester.ensureSemantics();
    final labelled = find.bySemanticsLabel(RegExp('^Status '));
    expect(labelled, findsOneWidget);
    expect(tester.getSemantics(labelled).flagsCollection.isButton, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}

Future<void> _loadFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await loader.load();
}
