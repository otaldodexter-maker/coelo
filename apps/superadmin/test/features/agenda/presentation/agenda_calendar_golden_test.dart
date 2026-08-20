import 'dart:io';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  for (final scenario in const [
    (width: 1440.0, brightness: Brightness.dark, name: 'timeline_1440_dark'),
    (width: 1024.0, brightness: Brightness.dark, name: 'timeline_1024_dark'),
    (width: 768.0, brightness: Brightness.light, name: 'timeline_768_light'),
    (width: 375.0, brightness: Brightness.light, name: 'timeline_375_light'),
  ]) {
    testWidgets('agenda ${scenario.name}', (tester) async {
      await _setSize(tester, Size(scenario.width, 1000));
      await tester.pumpWidget(_goldenApp(scenario.brightness));
      await _precacheAgendaImages(tester);

      await expectLater(
        find.byKey(const Key('agenda-calendar-golden-root')),
        matchesGoldenFile('goldens/agenda_${scenario.name}.png'),
      );
    });
  }

  testWidgets('card da timeline em hover', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_goldenApp(Brightness.light));
    await _precacheAgendaImages(tester);
    final card = find.byKey(const Key('agenda-event-card-routine-school'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('agenda-calendar-golden-root')),
      matchesGoldenFile('goldens/agenda_timeline_card_hover_light_1440.png'),
    );
  });

  testWidgets('calendário desktop dark com detalhe', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_goldenApp(Brightness.dark));
    await _precacheAgendaImages(tester);
    await tester.ensureVisible(find.byKey(const Key('agenda-open-full-calendar')));
    await tester.tap(find.byKey(const Key('agenda-open-full-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-more-2026-8-5')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('agenda-calendar-golden-root')),
      matchesGoldenFile('goldens/agenda_calendar_complete_desktop_dark.png'),
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

Future<void> _precacheAgendaImages(WidgetTester tester) async {
  final context = tester.element(find.byType(AgendaCalendarPage));
  await tester.runAsync(() async {
    for (final asset in const [
      'assets/principal_profile/institution-cover.png',
      'assets/principal_profile/institution-crest.png',
      'assets/agenda/event-thumbnails.png',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
  });
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
