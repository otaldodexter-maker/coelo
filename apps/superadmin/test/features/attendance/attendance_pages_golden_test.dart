import 'dart:io';

import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_attendance_repository.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the new attendance call references', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final contextRepository = FakeAttendanceRepository.seeded();
    addTearDown(contextRepository.dispose);
    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(
      _goldenApp(
        AttendanceNewCallPage(
          repository: contextRepository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
          today: FakeAttendanceRepository.today,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('attendance-golden-root')),
      matchesGoldenFile('goldens/attendance_new_call_context_light_375.png'),
    );

    final callRepository = FakeAttendanceRepository.seeded();
    addTearDown(callRepository.dispose);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      _goldenApp(
        AttendanceCallPage(
          repository: callRepository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
          today: FakeAttendanceRepository.today,
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('attendance-golden-root')),
      matchesGoldenFile('goldens/attendance_new_call_marking_dark_1440.png'),
    );
  });
}

Widget _goldenApp(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('attendance-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: child,
);

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

  final emojiFont = File(r'C:\Windows\Fonts\seguiemj.ttf');
  if (Platform.isWindows && emojiFont.existsSync()) {
    final emojiFontLoader = FontLoader('Segoe UI Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiFont.readAsBytesSync())));
    await emojiFontLoader.load();
  }
}
