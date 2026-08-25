import 'dart:io';

import 'package:coelo_superadmin/app/dev_menu/dev_menu_overlay.dart';
import 'package:coelo_superadmin/app/navigation/superadmin_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  final parentDestinations = <(String, String)>[];
  void collect(CoeloNavigationNode node) {
    if (node.id != 'home' &&
        node.routeName != null &&
        node.isAvailable(CoeloNavigationEnvironment.development)) {
      parentDestinations.add((node.label, node.id));
    }
    for (final child in node.children) {
      collect(child);
    }
  }

  for (final node in coeloSuperadminNavigation) {
    collect(node);
  }

  testWidgets('lists every parent preview route in the approved order', (tester) async {
    final navigations = <String>[];
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_previewApp(navigations.add));

    await tester.tap(find.byTooltip('Abrir menu de desenvolvimento'));
    await tester.pumpAndSettle();

    final menuItems = tester
        .widgetList<MenuItemButton>(find.byType(MenuItemButton))
        .map((item) => (item.child! as Text).data)
        .toList();
    expect(menuItems, parentDestinations.map((item) => item.$1).toList());

    final settings = find.widgetWithText(MenuItemButton, 'Publicar no Agora');
    await tester.scrollUntilVisible(settings, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(settings.hitTestable(), findsOneWidget);
    await tester.tap(settings.hitTestable());
    await tester.pumpAndSettle();
    expect(navigations, ['principal-now-publish']);
  });

  testWidgets('keeps the complete preview menu usable at supported widths', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(_previewApp((_) {}));
      await tester.ensureVisible(find.byTooltip('Abrir menu de desenvolvimento'));
      await tester.tap(find.byTooltip('Abrir menu de desenvolvimento').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsWidgets, reason: 'open menu at width $width');

      await tester.scrollUntilVisible(
        find.widgetWithText(MenuItemButton, 'Publicar no Agora'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'viewport width $width');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing, reason: 'close menu at width $width');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('matches the approved open preview menu', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_previewApp((_) {}));

    await tester.tap(find.byTooltip('Abrir menu de desenvolvimento'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Overlay),
      matchesGoldenFile('goldens/dev_menu_all_parent_routes_light_375.png'),
    );
  });
}

Widget _previewApp(ValueChanged<String> onNavigate) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  home: DevMenuOverlay(
    onNavigate: onNavigate,
    child: const Scaffold(body: SizedBox.expand()),
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
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
