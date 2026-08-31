import 'dart:io';

import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the approved responsive editor contract', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_goldenApp(brightness));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('extra-point')));
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('forms-editor-golden-root')),
          matchesGoldenFile('goldens/forms_editor_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  testWidgets('matches catalog, date range and explicit preview states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forms-editor-add-question')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-add-question')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-editor-golden-root')),
      matchesGoldenFile('goldens/forms_editor_catalog_light_1440.png'),
    );

    await tester.drag(
      find.byKey(const Key('forms-editor-question-catalog-scroll')),
      const Offset(0, -620),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-editor-golden-root')),
      matchesGoldenFile('goldens/forms_editor_catalog_groups_light_1440.png'),
    );

    await tester.ensureVisible(find.byKey(const Key('forms-editor-catalog-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-catalog-date')));
    await tester.pumpAndSettle();
    final dynamic dateRuleField = tester.widget(find.byKey(const Key('forms-editor-date-rule')));
    dateRuleField.onChanged(dateRuleField.options.last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forms-editor-question-date')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-editor-golden-root')),
      matchesGoldenFile('goldens/forms_editor_date_range_light_1440.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forms-editor-toggle-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-toggle-preview')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-editor-golden-root')),
      matchesGoldenFile('goldens/forms_editor_preview_light_1440.png'),
    );
  });

  testWidgets('matches the approved editor at 200 percent text', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final entry in [
      (width: 375.0, brightness: Brightness.light),
      (width: 1440.0, brightness: Brightness.dark),
    ]) {
      tester.view.physicalSize = Size(entry.width, 1000);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_goldenApp(entry.brightness, textScale: 2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('extra-point')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('forms-editor-golden-root')),
        matchesGoldenFile(
          'goldens/forms_editor_${entry.brightness.name}_${entry.width.toInt()}_text_200.png',
        ),
      );
    }
  });

  testWidgets('keeps the compact editor title and subtitle readable at 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_goldenApp(Brightness.light, textScale: 2));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Editar formulário'));
    final subtitle = tester.widget<Text>(
      find.text('Organize seções e perguntas para a rotina das equipes.'),
    );
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(subtitle.maxLines, isNull);
    expect(subtitle.overflow, isNull);
    expect(tester.takeException(), isNull);
  });
}

Widget _goldenApp(Brightness brightness, {double textScale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('forms-editor-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
  home: SuperadminShell(
    logout: _logout,
    title: 'Editar formulário',
    subtitle: 'Organize seções e perguntas para a rotina das equipes.',
    currentDestination: 'forms',
    canAccessCapability: (_) => true,
    child: const FormsEditorPage.development(),
  ),
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
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
