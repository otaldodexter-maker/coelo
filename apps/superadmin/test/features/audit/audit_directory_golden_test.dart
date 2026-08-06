import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches mobile light and desktop dark baselines', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(_app(Brightness.light));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('audit-directory-golden-root')),
      matchesGoldenFile('goldens/audit_directory_mobile_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(Brightness.dark));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('audit-directory-golden-root')),
      matchesGoldenFile('goldens/audit_directory_desktop_dark_1440.png'),
    );
  });
}

Widget _app(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('audit-directory-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: AuditDirectoryPage(
    store: SuperadminPrototypeStore(
      activityController: SuperadminActivityController(),
      now: () => DateTime.utc(2026, 8, 3, 16),
    ),
    logout: unavailableSuperadminLogout,
    now: () => DateTime.utc(2026, 8, 3, 16),
  ),
);

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
