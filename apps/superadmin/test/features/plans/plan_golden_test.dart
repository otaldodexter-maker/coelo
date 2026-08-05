import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_directory_page.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches cards and table at approved widths and themes', (tester) async {
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
          find.byKey(const Key('plan-directory-golden-root')),
          matchesGoldenFile('goldens/plan_cards_${brightness.name}_${width.toInt()}.png'),
        );

        await tester.tap(find.byKey(const Key('plan-directory-table-toggle')));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('plan-directory-golden-root')),
          matchesGoldenFile('goldens/plan_table_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  testWidgets('matches create compact and edit capability and review wide', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _repository();

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(_formApp(PlanFormPage(repository: repository), Brightness.light));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('plan-form-golden-root')),
      matchesGoldenFile('goldens/plan_create_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _formApp(
        PlanFormPage(repository: repository, planId: repository.plans.first.id),
        Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('plan-form-golden-root')),
      matchesGoldenFile('goldens/plan_capabilities_dark_1440.png'),
    );

    for (var index = 0; index < 3; index += 1) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(const Key('plan-form-golden-root')),
      matchesGoldenFile('goldens/plan_review_dark_1440.png'),
    );
  });
}

FakePlanCatalogRepository _repository() {
  final activity = SuperadminActivityController();
  return FakePlanCatalogRepository(store: SuperadminPrototypeStore(activityController: activity));
}

Widget _directoryApp(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('plan-directory-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: Scaffold(body: PlanDirectoryPage(repository: _repository())),
);

Widget _formApp(Widget child, Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('plan-form-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: Scaffold(body: child),
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
