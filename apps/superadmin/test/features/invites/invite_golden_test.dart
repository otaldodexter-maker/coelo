import 'dart:io';

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

  testWidgets('matches invitation directory references', (tester) async {
    final repository = _repository();

    await _pumpGolden(
      tester,
      InviteDirectoryPage(repository: repository, onOpen: (_) {}),
      size: const Size(375, 900),
    );
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_directory_mobile_light.png'),
    );

    await _pumpGolden(
      tester,
      InviteDirectoryPage(repository: _repository(), onOpen: (_) {}),
      size: const Size(1440, 900),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_directory_desktop_dark.png'),
    );
  });

  testWidgets('matches invitation flyout and revoke confirmation references', (tester) async {
    await _pumpGolden(
      tester,
      InviteDirectoryPage(repository: _repository(), onOpen: (_) {}),
      size: const Size(1440, 900),
    );

    await tester.tap(find.byKey(const Key('invite-actions-invite-1')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_directory_flyout_open_light.png'),
    );

    await tester.tap(find.text('Revogar convite'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_revoke_confirmation_light.png'),
    );
  });

  testWidgets('matches invitation table row hover reference', (tester) async {
    await _pumpGolden(
      tester,
      InviteDirectoryPage(repository: _repository(), onOpen: (_) {}),
      size: const Size(1440, 900),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const Key('coelo-admin-table-row-background-invite-row-invite-1')),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_directory_table_row_hover_light.png'),
    );
  });
  testWidgets('matches invitation form references', (tester) async {
    await _pumpGolden(
      tester,
      InviteFormPage(repository: _repository(), onCancel: () {}),
      size: const Size(375, 900),
    );
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_form_mobile_light.png'),
    );

    await _pumpGolden(
      tester,
      InviteFormPage(repository: _repository(), onCancel: () {}),
      size: const Size(1440, 900),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_form_desktop_dark.png'),
    );
  });

  testWidgets('matches invitation detail references', (tester) async {
    await _pumpGolden(
      tester,
      InviteDetailPage(repository: _repository(), inviteId: 'invite-1'),
      size: const Size(375, 900),
    );
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_detail_mobile_light.png'),
    );

    await _pumpGolden(
      tester,
      InviteDetailPage(repository: _repository(), inviteId: 'invite-1'),
      size: const Size(1440, 900),
      brightness: Brightness.dark,
    );
    await expectLater(
      find.byKey(const Key('invite-golden-root')),
      matchesGoldenFile('goldens/invite_detail_desktop_dark.png'),
    );
  });
}

TestInviteRepository _repository() => TestInviteRepository();

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  required Size size,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => RepaintBoundary(
        key: const Key('invite-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
          child: child!,
        ),
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
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
