import 'dart:io';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('calendário compacto light', (tester) async {
    await _setSize(tester, const Size(375, 900));
    await tester.pumpWidget(_goldenApp(Brightness.light));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('agenda-calendar-golden-root')),
      matchesGoldenFile('goldens/agenda_calendar_mobile_light.png'),
    );
  });

  testWidgets('calendário desktop dark com detalhe', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_goldenApp(Brightness.dark));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-more-2026-8-5')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('agenda-calendar-golden-root')),
      matchesGoldenFile('goldens/agenda_calendar_desktop_dark.png'),
    );
  });
}

Widget _goldenApp(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
  home: RepaintBoundary(
    key: const Key('agenda-calendar-golden-root'),
    child: AgendaCalendarPage(
      store: AgendaPrototypeStore.seeded(),
      logout: () async => const LogoutResult.success(),
      onAreaSelected: (_) {},
      onCreateItem: () {},
    ),
  ),
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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
