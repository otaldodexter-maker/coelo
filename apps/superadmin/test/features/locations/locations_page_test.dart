import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_read_widgets.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

void main() {
  Widget page({
    required ControlledLocationReader reader,
    LocationScope scope = scopeA,
    bool sessionAvailable = true,
    int contextRevision = 0,
    String? selectedLocationId,
    ValueChanged<String>? onLocationOpened,
    VoidCallback? onLocationClosed,
  }) => MaterialApp(
    theme: CoeloTheme.light,
    home: LocationsPage(
      scope: scope,
      logout: unavailableSuperadminLogout,
      reader: reader,
      sessionAvailable: sessionAvailable,
      contextRevision: contextRevision,
      selectedLocationId: selectedLocationId,
      onLocationOpened: onLocationOpened,
      onLocationClosed: onLocationClosed,
    ),
  );

  testWidgets('the catalog opens on the directory and names its owner', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader));
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();
    expect(find.byType(LocationDirectoryPanel), findsOneWidget);
    expect(find.byType(LocationDetailPanel), findsNothing);
    expect(find.text('Mapa e locais'), findsWidgets);
    expect(find.text(locationScopeLabel(scopeA)), findsWidgets);
  });

  testWidgets('opening a card shows the detail and reports the chosen id', (tester) async {
    final reader = ControlledLocationReader();
    final opened = <String>[];
    await tester.pumpWidget(page(reader: reader, onLocationOpened: opened.add));
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();
    // O primeiro card do grid agora e o Criar do grupo, entao o teste mira o
    // card do local pela chave dele em vez da posicao.
    final card = find.byKey(const Key('location-card-$locationA'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    expect(opened, [locationA]);
    expect(find.byType(LocationDetailPanel), findsOneWidget);
    expect(reader.details.last.id, locationA);
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    expect(find.text('Sala de leitura'), findsWidgets);
  });

  testWidgets('back returns to the directory and reports the close', (tester) async {
    final reader = ControlledLocationReader();
    var closed = 0;
    await tester.pumpWidget(
      page(reader: reader, selectedLocationId: locationA, onLocationClosed: () => closed++),
    );
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-detail-back')));
    await tester.pump();
    expect(closed, 1);
    expect(find.byType(LocationDirectoryPanel), findsOneWidget);
  });

  testWidgets('a direct link opens the detail without passing through the list', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: locationB));
    await tester.pump();
    expect(reader.directories, isEmpty);
    expect(reader.details.single.id, locationB);
  });

  testWidgets('a malformed id in the route never becomes a read', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: 'not-a-uuid'));
    await tester.pump();
    expect(reader.details, isEmpty);
    expect(find.byType(LocationDirectoryPanel), findsOneWidget);
  });

  testWidgets('a new context drops the open detail instead of keeping stale data', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: locationA));
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    expect(find.text('Sala de leitura'), findsWidgets);
    await tester.pumpWidget(
      page(reader: reader, selectedLocationId: locationA, contextRevision: 1),
    );
    await tester.pump();
    expect(find.byType(LocationDetailPanel), findsNothing);
    expect(find.text('Sala de leitura'), findsNothing);
  });

  testWidgets('losing the session drops the open detail', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: locationA));
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      page(reader: reader, selectedLocationId: locationA, sessionAvailable: false),
    );
    await tester.pump();
    expect(find.byType(LocationDetailPanel), findsNothing);
  });

  testWidgets('switching owner drops the detail and reads the new catalog', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: locationA));
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(reader: reader, scope: scopeB, selectedLocationId: locationA));
    await tester.pump();
    expect(find.byType(LocationDetailPanel), findsNothing);
    expect(reader.directories.last.request.scope.institutionId, institutionB);
  });

  testWidgets('the route may close the detail from outside the page', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: locationA));
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    await tester.pumpWidget(page(reader: reader));
    await tester.pump();
    expect(find.byType(LocationDirectoryPanel), findsOneWidget);
    expect(find.byType(LocationDetailPanel), findsNothing);
  });

  testWidgets('without a session the page shows denial and never reads', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, sessionAvailable: false));
    await tester.pumpAndSettle();
    expect(reader.directories, isEmpty);
    expect(reader.details, isEmpty);
    expect(find.byKey(const Key('location-directory-denied')), findsOneWidget);
  });

  for (final size in const [Size(375, 812), Size(768, 1024), Size(1440, 900)]) {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 2.0]) {
        final label = '${size.width.toInt()} ${dark ? 'dark' : 'light'} ${scale}x';
        testWidgets('directory and detail lay out without overflow at $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final reader = ControlledLocationReader();
          Widget app(String? selected) => MaterialApp(
            theme: dark ? CoeloTheme.dark : CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: LocationsPage(
              scope: scopeA,
              logout: unavailableSuperadminLogout,
              reader: reader,
              sessionAvailable: true,
              selectedLocationId: selected,
            ),
          );
          await tester.pumpWidget(app(null));
          reader.directories.last.result.complete(locationPage());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(LocationDirectoryPanel), findsOneWidget);

          await tester.pumpWidget(app(locationA));
          reader.details.last.result.complete(locationFixture(kind: LocationKind.external));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(LocationDetailPanel), findsOneWidget);
        });
      }
    }
  }

  testWidgets('every interactive control of the page is reachable by keyboard', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(page(reader: reader, selectedLocationId: locationA));
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();
    final back = find.byKey(const Key('location-detail-back'));
    final reload = find.byKey(const Key('location-detail-reload'));
    expect(tester.widget<TextButton>(back).enabled, isTrue);
    expect(tester.widget<OutlinedButton>(reload).enabled, isTrue);

    bool focusedIn(Finder control) {
      final focused = primaryFocus?.context?.widget;
      return focused != null &&
          find.descendant(of: control, matching: find.byWidget(focused)).evaluate().isNotEmpty;
    }

    // Tab traversal must reach both footer actions and Enter must activate
    // them, so a pointer is never the only way back to the catalog.
    var reachedReload = false;
    var reachedBack = false;
    for (var step = 0; step < 24 && !(reachedReload && reachedBack); step += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // The shell keeps its own animations running, so settle by a bounded
      // pump instead of waiting for a quiet frame that never arrives.
      await tester.pump(const Duration(milliseconds: 80));
      reachedReload = reachedReload || focusedIn(reload);
      reachedBack = reachedBack || focusedIn(back);
    }
    expect(reachedReload, isTrue);
    expect(reachedBack, isTrue);

    var activated = false;
    for (var step = 0; step < 24 && !activated; step += 1) {
      if (focusedIn(back)) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 80));
        activated = true;
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(activated, isTrue);
    expect(find.byType(LocationDirectoryPanel), findsOneWidget);
  });
}
