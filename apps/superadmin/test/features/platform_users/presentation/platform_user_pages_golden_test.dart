import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_detail_page.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches create, view, and edit references', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = FakePlatformUserRepository();
    final id = repository.records.first.id;

    for (final scenario in [
      (
        name: 'create_light_375',
        size: const Size(375, 900),
        brightness: Brightness.light,
        page: PlatformUserFormPage(
          repository: repository,
          capability: PlatformUserCapability.owner,
          logout: _logout,
        ),
      ),
      (
        name: 'view_light_375',
        size: const Size(375, 900),
        brightness: Brightness.light,
        page: PlatformUserDetailPage(
          repository: repository,
          internalUserId: id,
          capability: PlatformUserCapability.owner,
          logout: _logout,
        ),
      ),
      (
        name: 'view_dark_1440',
        size: const Size(1440, 900),
        brightness: Brightness.dark,
        page: PlatformUserDetailPage(
          repository: repository,
          internalUserId: id,
          capability: PlatformUserCapability.owner,
          logout: _logout,
        ),
      ),
      (
        name: 'edit_dark_1440',
        size: const Size(1440, 900),
        brightness: Brightness.dark,
        page: PlatformUserFormPage(
          repository: repository,
          internalUserId: id,
          capability: PlatformUserCapability.owner,
          logout: _logout,
        ),
      ),
    ]) {
      tester.view.physicalSize = scenario.size;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_goldenApp(scenario.brightness, scenario.page));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('platform-user-pages-golden-root')),
        matchesGoldenFile('goldens/platform_user_${scenario.name}.png'),
      );
    }
  });

  testWidgets('matches protected Owner actions flyout', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = FakePlatformUserRepository();
    await tester.pumpWidget(
      _goldenApp(
        Brightness.dark,
        PlatformUserDetailPage(
          repository: repository,
          internalUserId: repository.records.first.id,
          capability: PlatformUserCapability.owner,
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-user-actions')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('platform-user-pages-golden-root')),
      matchesGoldenFile('goldens/platform_user_detail_actions_open_dark_1440.png'),
    );
  });
}

Widget _goldenApp(Brightness brightness, Widget page) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('platform-user-pages-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: page,
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
