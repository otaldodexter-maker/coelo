import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the unit directory at the supported widths and themes', (tester) async {
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
          find.byKey(const Key('unit-directory-golden-root')),
          matchesGoldenFile('goldens/unit_directory_${brightness.name}_${width.toInt()}.png'),
        );

        await tester.ensureVisible(find.byKey(const Key('unit-view-table')));
        await tester.tap(find.byKey(const Key('unit-view-table')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('unit-directory-golden-root')),
          matchesGoldenFile('goldens/unit_directory_table_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  testWidgets('matches critical create mobile and edit desktop forms', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final institutions = FakeInstitutionDirectoryRepository();
    final units = FakeUnitDirectoryRepository(institutions);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(
      _formApp(
        UnitFormPage(
          key: const ValueKey('unit-form-create-golden'),
          repository: units,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('unit-form-golden-root')),
      matchesGoldenFile('goldens/unit_form_create_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      _formApp(
        UnitFormPage(
          key: const ValueKey('unit-form-edit-golden'),
          repository: units,
          unitId: units.records.first.id,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('unit-form-golden-root')),
      matchesGoldenFile('goldens/unit_form_edit_dark_1440.png'),
    );
  });
}

Widget _directoryApp(Brightness brightness) {
  final institutions = FakeInstitutionDirectoryRepository();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('unit-directory-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: UnitDirectoryPage(repository: FakeUnitDirectoryRepository(institutions), logout: _logout),
  );
}

Widget _formApp(Widget child, Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('unit-form-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: child,
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
