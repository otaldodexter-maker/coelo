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

  testWidgets('matches create and edit wizard baselines', (tester) async {
    await _pumpEditor(tester, width: 375, brightness: Brightness.light);
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_form_create_light_375.png'),
    );

    await _pumpEditor(tester, width: 1440, brightness: Brightness.dark, modelId: 'unit-model');
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_form_edit_dark_1440.png'),
    );
  });

  testWidgets('matches scope and fields steps', (tester) async {
    for (final scenario in const [
      (label: 'Alcance', width: 1024.0, file: 'daily_routine_scope_light_1024.png'),
      (label: 'Seções e campos', width: 1024.0, file: 'daily_routine_fields_light_1024.png'),
    ]) {
      await _pumpEditor(tester, width: 1024, brightness: Brightness.light);
      await tester.tap(find.text(scenario.label).first);
      await tester.pumpAndSettle();
      if (scenario.width != 1024) {
        tester.view.physicalSize = Size(scenario.width, 1000);
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byKey(const Key('daily-routine-golden-root')),
        matchesGoldenFile('goldens/${scenario.file}'),
      );
    }
  });

  testWidgets('matches directory cards and table', (tester) async {
    await _pumpDirectory(tester);
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_directory_cards_light_1440.png'),
    );
    await tester.tap(find.byKey(const Key('daily-routine-view-table')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_directory_table_light_1440.png'),
    );
  });

  testWidgets('matches review dirty-exit and read-only states', (tester) async {
    await _pumpEditor(
      tester,
      width: 1440,
      brightness: Brightness.dark,
      modelId: 'institution-model',
    );
    await tester.tap(find.text('Revisão e ativação').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_review_dark_1440.png'),
    );

    await _pumpEditor(tester, width: 375, brightness: Brightness.light);
    await tester.enterText(find.byKey(const Key('daily-routine-name')), 'Rotina em edição');
    await tester.tap(find.byKey(const Key('daily-routine-cancel')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_dirty_exit_light_375.png'),
    );

    await _pumpEditor(
      tester,
      width: 1440,
      brightness: Brightness.light,
      modelId: 'institution-model',
      permissions: DailyRoutinePermissions.readOnly,
    );
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_read_only_light_1440.png'),
    );
  });

  testWidgets('matches directory filter and hover interaction states', (tester) async {
    await _pumpDirectory(tester);
    final filter = find.byKey(const Key('daily-routine-origin-filter'));
    await tester.tap(find.descendant(of: filter, matching: find.text('Todas')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_directory_filter_open_light_1440.png'),
    );
    await tester.tap(find.text('Unidade').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_directory_filter_selected_light_1440.png'),
    );

    await _pumpDirectory(tester);
    final card = find.byKey(const Key('daily-routine-card-institution-model'));
    await tester.sendEventToBinding(PointerHoverEvent(position: tester.getCenter(card)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_directory_card_hover_light_1440.png'),
    );
  });

  testWidgets('matches validation and progressive interaction states', (tester) async {
    await _pumpEditor(tester, width: 375, brightness: Brightness.light);
    await tester.tap(find.byKey(const Key('daily-routine-continue')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_identity_error_light_375.png'),
    );

    await _pumpEditor(tester, width: 1024, brightness: Brightness.light, modelId: 'unit-model');
    await tester.tap(find.text('Seções e campos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-add-section')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('daily-routine-golden-root')),
      matchesGoldenFile('goldens/daily_routine_section_dialog_light_1024.png'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required double width,
  required Brightness brightness,
  String? modelId,
  DailyRoutinePermissions permissions = DailyRoutinePermissions.owner,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _app(
      brightness,
      DailyRoutineEditorPage(
        key: UniqueKey(),
        repository: InMemoryDailyRoutineRepository.seeded(),
        permissions: permissions,
        logout: unavailableSuperadminLogout,
        modelId: modelId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDirectory(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _app(
      Brightness.light,
      DailyRoutineDirectoryPage(
        key: UniqueKey(),
        repository: InMemoryDailyRoutineRepository.seeded(),
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _app(Brightness brightness, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('daily-routine-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
      child: child!,
    ),
  ),
  home: home,
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
