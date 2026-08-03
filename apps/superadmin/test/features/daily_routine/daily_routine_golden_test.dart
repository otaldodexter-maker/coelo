import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches optional feeling editor on mobile light and desktop dark', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final scenario in const [
      (width: 375.0, brightness: Brightness.light, suffix: 'light_375'),
      (width: 1440.0, brightness: Brightness.dark, suffix: 'dark_1440'),
    ]) {
      tester.view.physicalSize = Size(scenario.width, 900);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(scenario.brightness));
      await tester.pumpAndSettle();

      final participant = find.byKey(const Key('daily-routine-participant-participant-1-feeling'));
      final editorScroll = find
          .descendant(
            of: find.byKey(const Key('daily-routine-editor-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(participant, 300, scrollable: editorScroll);
      await tester.ensureVisible(participant);
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('daily-routine-editor-golden-root')),
        matchesGoldenFile('goldens/daily_routine_editor_${scenario.suffix}.png'),
      );
    }
  });
}

Widget _app(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('daily-routine-editor-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
      child: child!,
    ),
  ),
  home: DailyRoutineEditorPage(
    repository: InMemoryDailyRoutineRepository.seeded(),
    permissions: DailyRoutinePermissions.owner,
    logout: unavailableSuperadminLogout,
  ),
);

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();

  final windowsDirectory = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final emojiFont = File('$windowsDirectory\\Fonts\\seguiemj.ttf');
  if (emojiFont.existsSync()) {
    final emojiLoader = FontLoader('Segoe UI Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiFont.readAsBytesSync())));
    await emojiLoader.load();
  }

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
