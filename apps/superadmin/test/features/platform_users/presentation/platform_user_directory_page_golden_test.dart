import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches Institutions geometry for cards and table', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_goldenApp(brightness));
        await tester.pumpAndSettle();
        final suffix = '${brightness.name}_${width.toInt()}';

        await expectLater(
          find.byKey(const Key('platform-user-directory-golden-root')),
          matchesGoldenFile('goldens/platform_user_directory_cards_$suffix.png'),
        );

        await tester.ensureVisible(find.byKey(const Key('platform-user-view-table')));
        await tester.tap(find.byKey(const Key('platform-user-view-table')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('platform-user-directory-golden-root')),
          matchesGoldenFile('goldens/platform_user_directory_table_$suffix.png'),
        );
      }
    }
  });

  testWidgets('matches approved hover and filter flyout references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = FakePlatformUserRepository();
    await tester.pumpWidget(_goldenApp(Brightness.light, repository: repository));
    await tester.pumpAndSettle();

    final card = find.byKey(Key('platform-user-card-${repository.records.first.id}'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('platform-user-directory-golden-root')),
      matchesGoldenFile('goldens/platform_user_directory_card_hover_light_1440.png'),
    );

    await mouse.moveTo(Offset.zero);
    await tester.tap(find.byKey(const Key('platform-user-role-filter')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('platform-user-directory-golden-root')),
      matchesGoldenFile('goldens/platform_user_directory_filter_open_light_1440.png'),
    );
  });

  testWidgets('matches the approved files flyout and import popup references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_goldenApp(Brightness.light));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('platform-user-directory-golden-root')),
      matchesGoldenFile('goldens/platform_user_directory_files_open_light_1440.png'),
    );

    await tester.tap(find.byKey(const Key('platform-user-files-import')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('platform-user-directory-golden-root')),
      matchesGoldenFile('goldens/platform_user_import_dialog_light_1440.png'),
    );
  });
}

Widget _goldenApp(Brightness brightness, {PlatformUserRepository? repository}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('platform-user-directory-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: PlatformUserDirectoryPage(
      repository: repository ?? FakePlatformUserRepository(),
      capability: PlatformUserCapability.owner,
      logout: _logout,
    ),
  );
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

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
