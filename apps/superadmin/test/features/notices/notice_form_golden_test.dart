import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the initial notice wizard on mobile and desktop', (tester) async {
    await _pumpGolden(tester, size: const Size(375, 900));
    await expectLater(
      find.byKey(const Key('notice-form-golden-root')),
      matchesGoldenFile('goldens/notice_form_initial_mobile_light_375.png'),
    );

    await _pumpGolden(tester, size: const Size(1440, 900), brightness: Brightness.dark);
    await expectLater(
      find.byKey(const Key('notice-form-golden-root')),
      matchesGoldenFile('goldens/notice_form_initial_desktop_dark_1440.png'),
    );
  });
}

Future<void> _pumpGolden(
  WidgetTester tester, {
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
        key: const Key('notice-form-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
          child: child!,
        ),
      ),
      home: Scaffold(body: NoticeFormPage(repository: _repository())),
    ),
  );
  await tester.pumpAndSettle();
}

FakeNoticeRepository _repository() {
  final now = DateTime.utc(2026, 8, 6, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  return FakeNoticeRepository(store: store, now: () => now);
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
