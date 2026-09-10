import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_map_section.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

void main() {
  Widget section({
    required ControlledLocationReader reader,
    LocationScope? scope = scopeA,
    LocationOwnerKind ownerKind = LocationOwnerKind.institution,
    bool sessionAvailable = true,
    VoidCallback? onOpenCatalog,
    bool dark = false,
    double textScale = 1,
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationsMapSection(
          ownerKind: ownerKind,
          scope: scope,
          reader: reader,
          sessionAvailable: sessionAvailable,
          onOpenCatalog: onOpenCatalog,
        ),
      ),
    ),
  );

  testWidgets('before the owner exists the section explains instead of reading', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader, scope: null));
    await tester.pumpAndSettle();
    expect(reader.directories, isEmpty);
    expect(find.byKey(const Key('locations-map-section-before-owner')), findsOneWidget);
    expect(find.byKey(const Key('locations-map-section-count')), findsNothing);
    expect(find.byKey(const Key('locations-map-section-open')), findsNothing);
  });

  testWidgets('a unit says its catalog is independent from the institution', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      section(reader: reader, scope: null, ownerKind: LocationOwnerKind.unit),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('independente do catálogo da instituição'), findsOneWidget);
  });

  testWidgets('an existing owner summarizes its catalog', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader, onOpenCatalog: () {}));
    await tester.pump();
    expect(reader.directories.single.request.scope.institutionId, institutionA);
    reader.directories.single.result.complete(locationPage(total: 4));
    await tester.pumpAndSettle();
    expect(find.text('4 locais cadastrados'), findsOneWidget);
    expect(find.byKey(const Key('locations-map-section-item-$locationA')), findsOneWidget);
  });

  testWidgets('a single location is counted in the singular', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader));
    await tester.pump();
    reader.directories.single.result.complete(locationPage());
    await tester.pumpAndSettle();
    expect(find.text('1 local cadastrado'), findsOneWidget);
  });

  testWidgets('the section never promises media it cannot store', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader));
    await tester.pump();
    reader.directories.single.result.complete(locationPage());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locations-map-section-media-limit')), findsOneWidget);
    for (final label in const ['Enviar planta', 'Adicionar foto', 'Enviar imagem']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('without a composed route the section offers no catalog link', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader));
    await tester.pump();
    reader.directories.single.result.complete(locationPage());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locations-map-section-open')), findsNothing);
  });

  testWidgets('with a composed route the catalog link opens it', (tester) async {
    final reader = ControlledLocationReader();
    var opened = 0;
    await tester.pumpWidget(section(reader: reader, onOpenCatalog: () => opened++));
    await tester.pump();
    reader.directories.single.result.complete(locationPage());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('locations-map-section-open')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('without a session the section is denied and reads nothing', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader, sessionAvailable: false, onOpenCatalog: () {}));
    await tester.pumpAndSettle();
    expect(reader.directories, isEmpty);
    expect(find.byKey(const Key('locations-map-section-denied')), findsOneWidget);
    expect(find.byKey(const Key('locations-map-section-open')), findsNothing);
  });

  testWidgets('a failed read says unavailable instead of showing zero locations', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(section(reader: reader));
    await tester.pump();
    reader.directories.single.result.completeError(StateError('raw server detail'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locations-map-section-unavailable')), findsOneWidget);
    expect(find.textContaining('0 locais'), findsNothing);
  });

  for (final size in const [Size(375, 812), Size(1440, 900)]) {
    for (final scale in const [1.0, 2.0]) {
      for (final dark in const [false, true]) {
        final label = '${size.width.toInt()} ${dark ? 'dark' : 'light'} ${scale}x';
        testWidgets('the section lays out without overflow at $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final reader = ControlledLocationReader();
          await tester.pumpWidget(
            section(reader: reader, dark: dark, textScale: scale, onOpenCatalog: () {}),
          );
          await tester.pump();
          reader.directories.single.result.complete(locationPage(total: 3));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('locations-map-section')), findsOneWidget);
        });
      }
    }
  }
}
