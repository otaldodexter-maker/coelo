import 'dart:io';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('directory mobile light', (tester) async {
    await _golden(
      tester,
      size: const Size(375, 900),
      theme: CoeloTheme.light,
      child: InviteDirectoryPage(repository: TestInviteRepository()),
      file: 'goldens/invite_directory_light_375.png',
    );
  });

  testWidgets('directory desktop dark', (tester) async {
    await _golden(
      tester,
      size: const Size(1440, 900),
      theme: CoeloTheme.dark,
      child: InviteDirectoryPage(repository: TestInviteRepository()),
      file: 'goldens/invite_directory_dark_1440.png',
    );
  });

  testWidgets('canonical form mobile light', (tester) async {
    await _golden(
      tester,
      size: const Size(375, 900),
      theme: CoeloTheme.light,
      child: InviteFormPage(repository: TestInviteRepository(), onCancel: () {}),
      file: 'goldens/invite_form_light_375.png',
    );
  });

  testWidgets('canonical form desktop dark', (tester) async {
    await _golden(
      tester,
      size: const Size(1440, 900),
      theme: CoeloTheme.dark,
      child: InviteFormPage(repository: TestInviteRepository(), onCancel: () {}),
      file: 'goldens/invite_form_dark_1440.png',
    );
  });

  testWidgets('canonical form mobile light at 200 percent text', (tester) async {
    await _golden(
      tester,
      size: const Size(375, 900),
      theme: CoeloTheme.light,
      textScaler: const TextScaler.linear(2),
      child: InviteFormPage(repository: TestInviteRepository(), onCancel: () {}),
      file: 'goldens/invite_form_text_200_light_375.png',
    );
  });

  testWidgets('expired detail makes resend dominant', (tester) async {
    final repository = TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]);
    await _golden(
      tester,
      size: const Size(1440, 900),
      theme: CoeloTheme.light,
      child: InviteDetailPage(repository: repository, inviteId: repository.invites.single.id),
      file: 'goldens/invite_detail_expired_resend_light_1440.png',
    );
  });

  testWidgets('directory flyout open follows the canonical invitation actions', (tester) async {
    const inviteId = '11111111-1111-4111-8111-111111111111';
    await _pumpGolden(
      tester,
      size: const Size(1440, 900),
      theme: CoeloTheme.light,
      child: InviteDirectoryPage(
        repository: TestInviteRepository(invites: [testInvite(status: InviteStatus.expired)]),
        onOpen: (_) {},
      ),
    );

    final trigger = find.byKey(const Key('invite-actions-$inviteId'));
    await tester.ensureVisible(trigger);
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/invite_directory_flyout_open_light_1440.png'),
    );
  });

  testWidgets('directory row hover follows the canonical continuous table row', (tester) async {
    const inviteId = '11111111-1111-4111-8111-111111111111';
    await _pumpGolden(
      tester,
      size: const Size(1440, 900),
      theme: CoeloTheme.light,
      child: InviteDirectoryPage(repository: TestInviteRepository()),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('invite-row-$inviteId'))));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/invite_directory_table_row_hover_light_1440.png'),
    );
  });

  testWidgets('revoke confirmation follows the canonical negative dialog', (tester) async {
    final repository = TestInviteRepository();
    await _pumpGolden(
      tester,
      size: const Size(1440, 900),
      theme: CoeloTheme.light,
      child: InviteDetailPage(repository: repository, inviteId: repository.invites.single.id),
    );

    await tester.tap(find.byKey(const Key('invite-detail-revoke')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/invite_revoke_confirmation_light_1440.png'),
    );
  });
}

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}

Future<void> _golden(
  WidgetTester tester, {
  required Size size,
  required ThemeData theme,
  required Widget child,
  required String file,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await _pumpGolden(tester, size: size, theme: theme, textScaler: textScaler, child: child);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
}

Future<void> _pumpGolden(
  WidgetTester tester, {
  required Size size,
  required ThemeData theme,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Widget app() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
      child: content!,
    ),
    home: Scaffold(body: child),
  );
  await tester.pumpWidget(app());
  await tester.pumpAndSettle();
  // Warm image assets so a cold logo decode cannot make the golden order-dependent.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(app());
  await tester.pumpAndSettle();
}
