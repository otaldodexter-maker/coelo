import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/locations/domain/location_capabilities.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

/// A grant taken away has to take its surface with it.
///
/// The page reset an open form when the context changed, when the session was
/// lost, when the scope changed and when the route pointed elsewhere. It did not
/// reset when the capability itself was withdrawn, so a composition that
/// narrowed the grants mid-session left the form standing - still holding a
/// writer, still showing a save button, with only the server between it and a
/// write it was no longer allowed to attempt.
///
/// The server is the right last line and the wrong first one.
///
/// This is the third time this file has had the same shape of defect: state
/// outliving the thing that justified it. The other two were an edit surviving a
/// route change and a selection surviving a failed reload.
///
/// Each grant closes only what it held open. The selected detail is a read and
/// survives all of it, and losing the right to copy is no reason to shut an
/// edit someone is in the middle of.
const _create = Key('locations-create');
const _bring = Key('locations-bring-from-institution');
const _form = Key('locations-form');
const _edit = Key('location-detail-edit');
const _copy = Key('location-detail-copy');

final class _CopyProbeWriter implements LocationCatalogWriter {
  int copyCalls = 0;

  @override
  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  }) async {
    copyCalls++;
    return locationFixture(id: locationB);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ControlledLocationReader reader;

  /// Completes whatever the panels asked for, so nothing is left spinning and
  /// `pumpAndSettle` has something to settle on.
  Future<void> answer(WidgetTester tester) async {
    await tester.pump();
    for (final pending in reader.details) {
      if (!pending.result.isCompleted) {
        pending.result.complete(locationFixture(id: pending.id, scope: scopeUnitA));
      }
    }
    for (final pending in reader.directories) {
      if (!pending.result.isCompleted) {
        pending.result.complete(locationPage(scope: scopeUnitA));
      }
    }
    await tester.pumpAndSettle();
  }

  Future<void> show(
    WidgetTester tester,
    LocationCapabilities capabilities, {
    String? selected,
    int contextRevision = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: LocationsPage(
          scope: scopeUnitA,
          logout: unavailableSuperadminLogout,
          reader: reader,
          writer: const UnavailableLocationCatalogWriter(),
          sessionAvailable: true,
          contextRevision: contextRevision,
          capabilities: capabilities,
          selectedLocationId: selected,
        ),
      ),
    );
    await answer(tester);
  }

  Future<void> pump(
    WidgetTester tester,
    LocationCapabilities capabilities, {
    String? selected,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    reader = ControlledLocationReader();
    await show(tester, capabilities, selected: selected);
  }

  /// Rebuilds the same page with different grants, which is what a composition
  /// does when the actor's context narrows. The reader is the same one, so the
  /// page keeps its state and `didUpdateWidget` is what has to react.
  Future<void> regrant(
    WidgetTester tester,
    LocationCapabilities capabilities, {
    String? selected,
    int contextRevision = 0,
  }) => show(tester, capabilities, selected: selected, contextRevision: contextRevision);

  testWidgets('losing create closes the create form that was open', (tester) async {
    await pump(tester, const LocationCapabilities(create: true));
    await tester.tap(find.byKey(_create));
    await tester.pumpAndSettle();
    expect(find.byKey(_form), findsOneWidget);

    await regrant(tester, LocationCapabilities.none);
    expect(find.byKey(_form), findsNothing);
    expect(find.byKey(_create), findsNothing);
  });

  testWidgets('losing copy closes the panel that brings one down', (tester) async {
    await pump(tester, const LocationCapabilities(copy: true));
    await tester.tap(find.byKey(_bring));
    // The panel starts its own read of the institution catalog, so it needs an
    // answer before anything settles.
    await answer(tester);
    expect(find.byKey(const Key('locations-bring-panel')), findsOneWidget);

    await regrant(tester, LocationCapabilities.none);
    expect(find.byKey(const Key('locations-bring-panel')), findsNothing);
  });

  testWidgets('losing update closes the edit form of a location', (tester) async {
    await pump(tester, const LocationCapabilities(update: true), selected: locationA);
    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('locations-form-$locationA')), findsOneWidget);

    await regrant(tester, LocationCapabilities.none, selected: locationA);
    expect(find.byKey(Key('locations-form-$locationA')), findsNothing);
  });

  testWidgets('losing copy closes a duplication dialog that is already open', (tester) async {
    await pump(tester, const LocationCapabilities(copy: true), selected: locationA);
    await tester.tap(find.byKey(_copy));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-copy-dialog')), findsOneWidget);

    await regrant(tester, LocationCapabilities.none, selected: locationA);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-copy-dialog')), findsNothing);
    expect(find.byKey(Key('locations-detail-$locationA')), findsOneWidget);
  });

  testWidgets('changing authorization context closes a duplication dialog', (tester) async {
    const copy = LocationCapabilities(copy: true);
    await pump(tester, copy, selected: locationA);
    await tester.tap(find.byKey(_copy));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-copy-dialog')), findsOneWidget);

    await regrant(tester, copy, selected: locationA, contextRevision: 1);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-copy-dialog')), findsNothing);
    expect(find.byKey(Key('locations-detail-$locationA')), findsNothing);
  });

  testWidgets('revocation before the first dialog frame leaves no old writer action', (
    tester,
  ) async {
    final writer = _CopyProbeWriter();
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, value, _) => LocationDetailPanel(
            id: value == 0 ? locationA : locationB,
            scope: scopeUnitA,
            onBack: () {},
            reader: reader,
            writer: writer,
            sessionAvailable: true,
            contextRevision: value,
            capabilities: value == 0
                ? const LocationCapabilities(copy: true)
                : LocationCapabilities.none,
            onCopied: (_) {},
          ),
        ),
      ),
    );
    await answer(tester);

    await tester.tap(find.byKey(_copy));
    // Keep the Navigator alive and invalidate the panel synchronously, before
    // the dialog route receives its first frame.
    revision.value = 1;
    await answer(tester);

    expect(find.byKey(const Key('location-copy-dialog')), findsNothing);
    expect(find.byKey(const Key('location-copy-confirm')), findsNothing);
    expect(writer.copyCalls, 0);
  });

  testWidgets('losing copy does not shut an edit someone is in the middle of', (tester) async {
    // The precision matters: a blanket reset would throw away work for a grant
    // that had nothing to do with it.
    await pump(tester, const LocationCapabilities(update: true, copy: true), selected: locationA);
    await tester.tap(find.byKey(_edit));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('locations-form-$locationA')), findsOneWidget);

    await regrant(tester, const LocationCapabilities(update: true), selected: locationA);
    expect(find.byKey(Key('locations-form-$locationA')), findsOneWidget);
  });

  testWidgets('the grants that stay keep drawing what they always drew', (tester) async {
    // A guard that closed too much would pass every test above.
    await pump(tester, LocationCapabilities.all);
    expect(find.byKey(_create), findsOneWidget);
    expect(find.byKey(_bring), findsOneWidget);

    await regrant(tester, LocationCapabilities.all);
    expect(find.byKey(_create), findsOneWidget);
    expect(find.byKey(_bring), findsOneWidget);
  });
}
