import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_selection_source.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_selection_field.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

LocationReferenceSnapshot snapshot({
  String id = locationA,
  String label = 'Sala de leitura',
  LocationScope scope = scopeA,
  LocationKind kind = LocationKind.internal,
}) => LocationReferenceSnapshot(id: id, scope: scope, kind: kind, label: label);

final class ControlledSelectionSource implements LocationSelectionSource {
  final optionRequests = <LocationSelectionRequest>[];
  final optionResults = <Completer<LocationSelectionOptions>>[];
  final resolveRequests = <({String id, LocationScope scope})>[];
  final resolveResults = <Completer<LocationResolvedSnapshot>>[];

  @override
  Future<LocationSelectionOptions> fetchOptions(LocationSelectionRequest request) {
    optionRequests.add(request);
    final result = Completer<LocationSelectionOptions>();
    optionResults.add(result);
    return result.future;
  }

  @override
  Future<LocationResolvedSnapshot> resolveSnapshot({
    required String id,
    required LocationScope scope,
  }) {
    resolveRequests.add((id: id, scope: scope));
    final result = Completer<LocationResolvedSnapshot>();
    resolveResults.add(result);
    return result.future;
  }
}

void main() {
  Widget field({
    required ControlledSelectionSource source,
    LocationScope scope = scopeA,
    bool sessionAvailable = true,
    bool catalogOnly = false,
    LocationSelection? initial,
    required void Function(LocationSelection?) onChanged,
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
        child: LocationSelectionField(
          scope: scope,
          source: source,
          sessionAvailable: sessionAvailable,
          catalogOnly: catalogOnly,
          initialSelection: initial,
          onChanged: onChanged,
        ),
      ),
    ),
  );

  testWidgets('catalogued options are read for the owner scope and can be chosen', (tester) async {
    final source = ControlledSelectionSource();
    final changes = <LocationSelection?>[];
    await tester.pumpWidget(field(source: source, onChanged: changes.add));
    await tester.pump();
    expect(source.optionRequests.single.scope.institutionId, institutionA);
    source.optionResults.last.complete(
      LocationSelectionOptions(
        options: [
          snapshot(),
          snapshot(id: locationB, label: 'Pátio'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-selection-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pátio').last);
    await tester.pumpAndSettle();
    expect(changes.last, isA<CataloguedLocationSelection>());
    expect((changes.last! as CataloguedLocationSelection).snapshot.id, locationB);
  });

  testWidgets('reservation context only offers catalogued locations', (tester) async {
    final source = ControlledSelectionSource();
    final changes = <LocationSelection?>[];
    await tester.pumpWidget(field(source: source, catalogOnly: true, onChanged: changes.add));
    source.optionResults.last.complete(LocationSelectionOptions(options: [snapshot()]));
    await tester.pumpAndSettle();
    expect(find.text('Pontual'), findsNothing);
    expect(find.byKey(const Key('location-selection-one-off')), findsNothing);
    await tester.tap(find.byKey(const Key('location-selection-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala de leitura').last);
    await tester.pumpAndSettle();
    expect((changes.last! as CataloguedLocationSelection).snapshot.id, locationA);
  });

  testWidgets('a one-off keeps its text and never becomes a catalogued id', (tester) async {
    final source = ControlledSelectionSource();
    final changes = <LocationSelection?>[];
    await tester.pumpWidget(field(source: source, onChanged: changes.add));
    await tester.pump();
    source.optionResults.last.complete(LocationSelectionOptions(options: [snapshot()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pontual'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-selection-one-off')), '  Praça  ');
    await tester.pumpAndSettle();
    expect(changes.last, isA<OneOffLocationSelection>());
    expect((changes.last! as OneOffLocationSelection).text, 'Praça');
    expect(find.byKey(const Key('location-selection-one-off-limit')), findsOneWidget);
  });

  testWidgets('the one-off mode offers no promotion to the catalog', (tester) async {
    final source = ControlledSelectionSource();
    await tester.pumpWidget(field(source: source, onChanged: (_) {}));
    await tester.pump();
    source.optionResults.last.complete(LocationSelectionOptions(options: [snapshot()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pontual'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Salvar no catálogo'), findsNothing);
    expect(find.textContaining('não entra no catálogo', findRichText: true), findsOneWidget);
  });

  testWidgets('switching mode drops the previous choice instead of converting it', (tester) async {
    final source = ControlledSelectionSource();
    final changes = <LocationSelection?>[];
    await tester.pumpWidget(field(source: source, onChanged: changes.add));
    await tester.pump();
    source.optionResults.last.complete(LocationSelectionOptions(options: [snapshot()]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-selection-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala de leitura').last);
    await tester.pumpAndSettle();
    expect(changes.last, isA<CataloguedLocationSelection>());

    await tester.tap(find.text('Pontual'));
    await tester.pumpAndSettle();
    expect(changes.last, isNull);
  });

  testWidgets('search narrows the read on the server, not only on screen', (tester) async {
    final source = ControlledSelectionSource();
    await tester.pumpWidget(field(source: source, onChanged: (_) {}));
    await tester.pump();
    source.optionResults.last.complete(LocationSelectionOptions(options: [snapshot()]));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-selection-search')), '  pátio  ');
    // The loading panel spins, so settle only after the read answers.
    await tester.pump();
    expect(source.optionRequests.last.search, 'pátio');
    source.optionResults.last.complete(LocationSelectionOptions(options: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selection-noResults')), findsOneWidget);
  });

  testWidgets('truncation asks for a narrower search instead of implying completeness', (
    tester,
  ) async {
    final source = ControlledSelectionSource();
    await tester.pumpWidget(field(source: source, onChanged: (_) {}));
    await tester.pump();
    source.optionResults.last.complete(
      LocationSelectionOptions(options: [snapshot()], truncated: true),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selection-truncated')), findsOneWidget);
  });

  testWidgets('an empty catalog says empty and a denied read says denied', (tester) async {
    final source = ControlledSelectionSource();
    await tester.pumpWidget(field(source: source, onChanged: (_) {}));
    await tester.pump();
    source.optionResults.last.complete(LocationSelectionOptions(options: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selection-empty')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('location-selection-search')), 'x');
    await tester.pump();
    source.optionResults.last.completeError(const LocationCatalogAccessDeniedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selection-denied')), findsOneWidget);
  });

  testWidgets('without a session nothing is read and the field stays denied', (tester) async {
    final source = ControlledSelectionSource();
    await tester.pumpWidget(field(source: source, sessionAvailable: false, onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(source.optionRequests, isEmpty);
    expect(find.byKey(const Key('location-selection-denied')), findsOneWidget);
  });

  testWidgets('the default source is unavailable rather than an empty catalog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: LocationSelectionField(scope: scopeA, sessionAvailable: true, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selection-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('location-selection-empty')), findsNothing);
  });

  testWidgets('a stored choice is re-resolved and a stale one is announced', (tester) async {
    final source = ControlledSelectionSource();
    await tester.pumpWidget(
      field(source: source, initial: LocationSelection.catalogued(snapshot()), onChanged: (_) {}),
    );
    await tester.pump();
    source.optionResults.last.complete(
      LocationSelectionOptions(
        options: [snapshot(id: locationB, label: 'Pátio')],
      ),
    );
    // A stored choice is re-read before the field publishes anything, so the
    // panel is still loading here.
    await tester.pump();
    expect(source.resolveRequests.single.id, locationA);
    source.resolveResults.last.complete(
      LocationResolvedSnapshot(
        resolution: LocationSnapshotResolution.notSelectable,
        snapshot: snapshot(label: 'Sala de leitura (desativada)'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selection-stale')), findsOneWidget);
  });

  testWidgets('changing owner drops a choice made in the previous catalog', (tester) async {
    final source = ControlledSelectionSource();
    final changes = <LocationSelection?>[];
    await tester.pumpWidget(field(source: source, onChanged: changes.add));
    await tester.pump();
    source.optionResults.last.complete(LocationSelectionOptions(options: [snapshot()]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-selection-option')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala de leitura').last);
    await tester.pumpAndSettle();
    expect(changes.last, isA<CataloguedLocationSelection>());

    await tester.pumpWidget(field(source: source, scope: scopeB, onChanged: changes.add));
    await tester.pump();
    expect(source.optionRequests.last.scope.institutionId, institutionB);
    expect(changes.last, isNull);
  });

  for (final size in const [Size(375, 812), Size(1440, 900)]) {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 2.0]) {
        final label = '${size.width.toInt()} ${dark ? 'dark' : 'light'} ${scale}x';
        testWidgets('the field lays out without overflow at $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final source = ControlledSelectionSource();
          await tester.pumpWidget(
            field(source: source, dark: dark, textScale: scale, onChanged: (_) {}),
          );
          await tester.pump();
          source.optionResults.last.complete(
            LocationSelectionOptions(
              options: [
                snapshot(),
                snapshot(id: locationB, label: 'Pátio coberto principal'),
              ],
              truncated: true,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('location-selection-mode')), findsOneWidget);
        });
      }
    }
  }
}
