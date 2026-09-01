import 'dart:io';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_approvals_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_permissions_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_requests_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Surface { detail, requests, approvals, permissions }

void main() {
  setUpAll(_loadGoldenFonts);

  for (final surface in _Surface.values) {
    for (final brightness in Brightness.values) {
      for (final width in const [375.0, 768.0, 1440.0]) {
        testWidgets('${surface.name} ${brightness.name} ${width.toInt()}', (tester) async {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = Size(width, 1200);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(_app(surface, brightness));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('agenda-additional-golden-root')),
            matchesGoldenFile(
              'goldens/agenda_${surface.name}_${brightness.name}_${width.toInt()}.png',
            ),
          );
        });
      }
    }
  }
}

Widget _app(_Surface surface, Brightness brightness) {
  final store = AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 31, 12));
  final child = switch (surface) {
    _Surface.detail => AgendaEventDetailPage(
      store: store,
      eventId: store.items.first.id,
      onBack: () {},
      onEdit: () {},
    ),
    _Surface.requests => const AgendaRequestsPage.localFixtures(),
    _Surface.approvals => AgendaApprovalsPage.localFixtures(store: store),
    _Surface.permissions => AgendaPermissionsPage(store: store),
  };
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: RepaintBoundary(key: const Key('agenda-additional-golden-root'), child: child),
    ),
    home: Scaffold(body: child),
  );
}

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
