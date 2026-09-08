import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'location_read_fixtures.dart';

void main() {
  testWidgets('directory revision clears data and invalidates captured open callback', (
    tester,
  ) async {
    final reader = ControlledLocationReader();
    var opens = 0;
    Widget app(int revision) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: LocationDirectoryPanel(
          scope: scopeA,
          reader: reader,
          sessionAvailable: true,
          contextRevision: revision,
          onOpen: (_) => opens++,
        ),
      ),
    );
    await tester.pumpWidget(app(0));
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();
    final oldOpen = tester
        .widget<CoeloAdminInteractiveCard>(find.byType(CoeloAdminInteractiveCard))
        .onPressed!;
    await tester.pumpWidget(app(1));
    expect(find.text('Sala de leitura'), findsNothing);
    oldOpen();
    expect(opens, 0);
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();
    oldOpen();
    expect(opens, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    oldOpen();
    expect(opens, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('detail reader and id replacement discard old completion', (tester) async {
    final old = ControlledLocationReader();
    final next = ControlledLocationReader();
    Widget app(ControlledLocationReader reader, String id) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: LocationDetailPanel(
          scope: scopeA,
          reader: reader,
          id: id,
          sessionAvailable: true,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpWidget(app(old, locationA));
    await tester.pumpWidget(app(next, locationB));
    old.details.single.result.complete(locationFixture());
    await tester.pump();
    expect(find.text('Sala de leitura'), findsNothing);
    next.details.single.result.complete(locationFixture(id: locationB, name: 'Local novo'));
    await tester.pumpAndSettle();
    expect(find.text('Local novo'), findsOneWidget);
    expect(find.text('Sala de leitura'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('detail preserves canonical district in own address', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: LocationDetailPanel(
            id: locationA,
            scope: scopeA,
            reader: reader,
            sessionAvailable: true,
            onBack: () {},
          ),
        ),
      ),
    );
    reader.details.single.result.complete(
      locationFixture(
        kind: LocationKind.external,
        address: {
          'country': 'Brasil',
          'postal_code': '12345678',
          'state': 'SP',
          'city': 'Cidade exemplo',
          'district': 'Bairro de teste',
          'street': 'Rua de teste',
          'number': '12',
          'complement': 'Bloco A',
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('location-detail-content')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Bairro de teste'), findsOneWidget);
    expect(find.text('Rua de teste'), findsOneWidget);
    expect(find.text('Bloco A'), findsOneWidget);
  });
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('directory $width dark=$dark text200 cards/table and session', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reader = ControlledLocationReader();
        String? opened;
        Widget app(bool session) => MaterialApp(
          theme: dark ? CoeloTheme.dark : CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: LocationDirectoryPanel(
              reader: reader,
              scope: scopeA,
              sessionAvailable: session,
              onOpen: (item) => opened = item.id,
            ),
          ),
        );
        await tester.pumpWidget(app(true));
        reader.directories.single.result.complete(locationPage());
        await tester.pumpAndSettle();
        expect(find.text('Sala de leitura'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Sala de leitura'));
        expect(opened, locationA);
        await tester.tap(find.byKey(const Key('location-view-table')));
        reader.directories.last.result.complete(locationPage());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('location-table')), findsOneWidget);
        final row = tester.getRect(
          find.byKey(const Key('coelo-admin-table-row-background-$locationA')),
        );
        final name = tester.getRect(find.text('Sala de leitura').first);
        expect((row.center.dy - name.center.dy).abs(), lessThan(2));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text('Sala de leitura').first, matching: find.byType(RichText)),
        );
        final glyphs = paragraph
            .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 15))
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b));
        expect((row.center.dy - paragraph.localToGlobal(glyphs.center).dy).abs(), lessThan(4));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(false));
        await tester.pumpAndSettle();
        expect(find.text('Sala de leitura'), findsNothing);
        expect(find.byKey(const Key('location-directory-denied')), findsOneWidget);
        expect(find.byKey(const Key('location-files')), findsNothing);
      });
    }
  }
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('detail $width dark=$dark text200 safe and read only', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reader = ControlledLocationReader();
        var back = 0;
        Widget app(bool session) => MaterialApp(
          theme: dark ? CoeloTheme.dark : CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: LocationDetailPanel(
              reader: reader,
              id: locationA,
              scope: scopeA,
              sessionAvailable: session,
              onBack: () => back++,
            ),
          ),
        );
        await tester.pumpWidget(app(true));
        expect(find.byKey(const Key('location-detail-loading')), findsOneWidget);
        reader.details.single.result.complete(locationFixture());
        await tester.pumpAndSettle();
        expect(find.text('Sala de leitura'), findsOneWidget);
        expect(find.text('Salvar'), findsNothing);
        expect(find.text('Reservas'), findsNothing);
        expect(tester.takeException(), isNull);
        for (final key in ['location-detail-back', 'location-detail-reload']) {
          expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(48));
        }
        await tester.tap(find.byKey(const Key('location-detail-back')));
        expect(back, 1);
        await tester.pumpWidget(app(false));
        await tester.pumpAndSettle();
        expect(find.text('Sala de leitura'), findsNothing);
        expect(find.byKey(const Key('location-detail-denied')), findsOneWidget);
        expect(reader.details, hasLength(1));
      });
    }
  }
}
