import 'dart:io';

import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches cards and responsive table at supported widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_directoryApp(brightness));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('access-profile-golden-root')),
          matchesGoldenFile('goldens/access_profile_cards_${brightness.name}_${width.toInt()}.png'),
        );

        await tester.tap(find.byIcon(Icons.table_rows_rounded));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('access-profile-golden-root')),
          matchesGoldenFile('goldens/access_profile_table_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  testWidgets('matches create mobile and permission editor desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = FakeAccessProfileRepository();

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(
      _formApp(
        AccessProfileFormPage(
          repository: repository,
          logout: _logout,
          domain: AccessProfileDomain.institution,
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('access-profile-form-golden-root')),
      matchesGoldenFile('goldens/access_profile_form_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _formApp(
        AccessProfileFormPage(
          repository: repository,
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: 'demo-owner',
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('access-profile-form-golden-root')),
      matchesGoldenFile('goldens/access_profile_editor_dark_1440.png'),
    );

    await tester.drag(find.byKey(const Key('access-profile-form-scroll')), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-access-profile')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('access-profile-form-golden-root')),
      matchesGoldenFile('goldens/access_profile_review_dark_1440.png'),
    );
  });
}

Widget _directoryApp(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('access-profile-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: AccessProfileDirectoryPage(repository: FakeAccessProfileRepository(), logout: _logout),
);

Widget _formApp(Widget child, Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('access-profile-form-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: child,
);

Future<LogoutResult> _logout() async => const LogoutResult.success();

Future<void> _loadGoldenFonts() async {
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
