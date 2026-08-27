import 'dart:io';
import 'dart:ui';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import '../support/health_care_fixture_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_directory_page.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileChildren = [
  HealthCareProfileChildOption(id: 'child-demo-a', label: 'Criança Demo A'),
];

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches both sibling directories on mobile light and desktop dark', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (
        name: 'profile_directory_mobile_light',
        size: const Size(375, 900),
        dark: false,
        medication: false,
      ),
      (
        name: 'profile_directory_desktop_dark',
        size: const Size(1440, 900),
        dark: true,
        medication: false,
      ),
      (
        name: 'medication_directory_mobile_light',
        size: const Size(375, 900),
        dark: false,
        medication: true,
      ),
      (
        name: 'medication_directory_desktop_dark',
        size: const Size(1440, 900),
        dark: true,
        medication: true,
      ),
    ]) {
      tester.view.physicalSize = configuration.size;
      final controller = HealthCareController(FixtureHealthCareRepository());
      addTearDown(controller.dispose);

      final page = configuration.medication
          ? HealthMedicationPlanDirectoryPage(
              controller: controller,
              logout: unavailableSuperadminLogout,
              onCreate: () {},
              onPlanSelected: (_) {},
            )
          : HealthCareProfileDirectoryPage(
              controller: controller,
              logout: unavailableSuperadminLogout,
              onCreate: () {},
              onChildSelected: (_) {},
            );
      await _pumpFrame(tester, page, dark: configuration.dark);
      await expectLater(
        find.byKey(const Key('health-care-golden-frame')),
        matchesGoldenFile('../../../goldens/health_care/${configuration.name}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('matches profile files flyout open', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await _pumpOverlayFrame(
      tester,
      HealthCareProfileDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
        onChildSelected: (_) {},
      ),
      dark: false,
    );
    await tester.tap(find.text('Arquivos'));
    await tester.pumpAndSettle();

    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('health-care-files-golden-frame')),
      matchesGoldenFile('../../../goldens/health_care/profile_directory_files_open_light_1440.png'),
    );
  });
  testWidgets('matches both forms on mobile light and desktop dark', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (
        name: 'profile_form_mobile_light',
        size: const Size(375, 900),
        dark: false,
        medication: false,
      ),
      (
        name: 'profile_form_desktop_dark',
        size: const Size(1440, 900),
        dark: true,
        medication: false,
      ),
      (
        name: 'medication_form_mobile_light',
        size: const Size(375, 900),
        dark: false,
        medication: true,
      ),
      (
        name: 'medication_form_desktop_dark',
        size: const Size(1440, 900),
        dark: true,
        medication: true,
      ),
    ]) {
      tester.view.physicalSize = configuration.size;
      final page = configuration.medication
          ? HealthMedicationPlanFormPage(
              logout: unavailableSuperadminLogout,
              onCancel: () {},
              onSaved: () async {},
              medicationId: configuration.dark ? 'medication-demo-a' : null,
            )
          : HealthCareProfileFormPage(
              logout: unavailableSuperadminLogout,
              childOptions: _profileChildren,
              onCancel: () {},
              onSaved: (_) async {},
              loadDraft: configuration.dark
                  ? (childId) async => HealthCareProfileDraft(childId: childId)
                  : null,
              childId: configuration.dark ? 'child-demo-a' : null,
            );
      await _pumpFrame(tester, page, dark: configuration.dark);
      await expectLater(
        find.byKey(const Key('health-care-golden-frame')),
        matchesGoldenFile('../../../goldens/health_care/${configuration.name}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('matches profile directory tabs hover and table evidence', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await _pumpFrame(
      tester,
      HealthCareProfileDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
        onChildSelected: (_) {},
      ),
      dark: false,
    );

    await tester.tap(find.text('Inativos'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('health-care-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/health_care/profile_directory_tabs_selected_light_1440.png',
      ),
    );

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(CoeloAdminInteractiveCard).first),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('health-care-golden-frame')),
      matchesGoldenFile('../../../goldens/health_care/profile_directory_card_hover_light_1440.png'),
    );

    await mouse.moveTo(const Offset(2, 2));
    await tester.tap(find.byKey(const Key('health-care-profiles-view-table')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('health-care-golden-frame')),
      matchesGoldenFile('../../../goldens/health_care/profile_directory_table_light_1440.png'),
    );
  });
}

Future<void> _pumpFrame(WidgetTester tester, Widget page, {required bool dark}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? CoeloTheme.dark : CoeloTheme.light,
      home: RepaintBoundary(key: const Key('health-care-golden-frame'), child: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpOverlayFrame(WidgetTester tester, Widget page, {required bool dark}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('health-care-files-golden-frame'),
      child: MaterialApp(theme: dark ? CoeloTheme.dark : CoeloTheme.light, home: page),
    ),
  );
  await tester.pumpAndSettle();
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
