import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/data/fake_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches people cards light and table dark at supported widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_directoryApp(Brightness.light));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('person-directory-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/people/person_directory_cards_light_${width.toInt()}.png',
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_directoryApp(Brightness.dark));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('people-view-table')));
      await tester.tap(find.byKey(const Key('people-view-table')));
      await tester.pumpAndSettle();
      await _scrollDirectoryToTop(tester);
      await expectLater(
        find.byKey(const Key('person-directory-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/people/person_directory_table_dark_${width.toInt()}.png',
        ),
      );
    }
  });

  testWidgets('matches critical create mobile and edit desktop forms', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = FakePersonDirectoryRepository();

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(
      _formApp(
        PersonFormPage(repository: repository, logout: _logout, onCancel: () {}, onSaved: (_) {}),
        Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('person-form-golden-frame')),
      matchesGoldenFile('../../../goldens/people/person_form_create_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      _formApp(
        PersonFormPage(
          repository: repository,
          logout: _logout,
          original: repository.people.firstWhere((person) => person.isEditable),
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('person-form-golden-frame')),
      matchesGoldenFile('../../../goldens/people/person_form_edit_dark_1440.png'),
    );
  });

  testWidgets('supports people directory and form at 200% text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _directoryApp(Brightness.light, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('people-view-table')));
    await tester.tap(find.byKey(const Key('people-view-table')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _formApp(
        PersonFormPage(
          repository: FakePersonDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.light,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Etapa 1 de 3'), findsOneWidget);
  });
}

Widget _directoryApp(Brightness brightness, {TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('person-directory-golden-frame'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
        child: child!,
      ),
    ),
    home: PersonDirectoryPage(repository: FakePersonDirectoryRepository(), logout: _logout),
  );
}

Widget _formApp(
  Widget child,
  Brightness brightness, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('person-form-golden-frame'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
        child: child!,
      ),
    ),
    home: child,
  );
}

Future<void> _scrollDirectoryToTop(WidgetTester tester) async {
  await tester.drag(find.byKey(const Key('people-directory-scroll')), const Offset(0, 1000));
  await tester.pumpAndSettle();
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
