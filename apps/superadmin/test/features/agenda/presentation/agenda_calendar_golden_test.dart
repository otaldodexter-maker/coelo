import 'dart:io';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_event_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

enum _AgendaGoldenSurface { calendar, list, create }

void main() {
  setUpAll(_loadGoldenFonts);

  for (final surface in _AgendaGoldenSurface.values) {
    for (final brightness in Brightness.values) {
      for (final width in const [375.0, 768.0, 1440.0]) {
        final themeName = brightness == Brightness.light ? 'light' : 'dark';
        final widthName = width.toInt();
        testWidgets('agenda ${surface.name} $themeName $widthName', (tester) async {
          await _setSize(tester, Size(width, 1200));
          await tester.pumpWidget(_goldenApp(brightness, surface));
          await tester.pumpAndSettle();

          if (surface == _AgendaGoldenSurface.list) {
            await tester.tap(find.byKey(const Key('agenda-view-list')));
            await tester.pumpAndSettle();
          }

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('agenda-golden-root')),
            matchesGoldenFile('goldens/agenda_${surface.name}_${themeName}_$widthName.png'),
          );
        });
      }
    }
  }
}

Widget _goldenApp(Brightness brightness, _AgendaGoldenSurface surface) {
  final store = AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 3, 12));
  final child = switch (surface) {
    _AgendaGoldenSurface.calendar || _AgendaGoldenSurface.list => AgendaCalendarPage(
      store: store,
      logout: () async => const LogoutResult.success(),
      onAreaSelected: (_) {},
      onCreateItem: () {},
    ),
    _AgendaGoldenSurface.create => Scaffold(
      body: AgendaEventFormPage(store: store, onCancel: () {}, onSaved: (_) {}),
    ),
  };
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
    home: RepaintBoundary(key: const Key('agenda-golden-root'), child: child),
  );
}

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
