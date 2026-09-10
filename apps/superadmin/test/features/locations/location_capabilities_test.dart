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

/// One grant draws one affordance, and no others.
///
/// The catalog used to decide with a single flag: whoever could create could
/// also edit, change status, copy and schedule. That is a guess about how the
/// grants move together, and it fails in the direction that matters - it draws
/// a control the actor may not use, and the refusal arrives from the server
/// after the click.
///
/// These tests hold each affordance to its own capability. They also hold the
/// legacy pair, because the router still passes it and its behaviour has to
/// stay identical until it does not.
///
/// Nothing here is authorization. The server checks every command on its own;
/// what is measured is only what gets drawn.
const _create = Key('location-create-internal');
const _bring = Key('locations-bring-from-institution');
const _copy = Key('location-detail-copy');
const _edit = Key('location-detail-edit');
const _status = Key('location-status-actions');
const _schedule = Key('location-schedule-section');

void main() {
  Future<void> pump(
    WidgetTester tester, {
    LocationCapabilities? capabilities,
    bool canCreate = false,
    bool? canManage,
    LocationScope scope = scopeUnitA,
    String? selected,
  }) async {
    // The detail content is a ListView, so a section below the fold is never
    // built and would read as absent. The surface is made tall enough that
    // "not drawn" means not drawn.
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: LocationsPage(
          scope: scope,
          logout: unavailableSuperadminLogout,
          reader: reader,
          // A writer that refuses if anyone calls it: these tests are about what
          // is drawn, and a drawn control must never depend on a live backend.
          writer: const UnavailableLocationCatalogWriter(),
          sessionAvailable: true,
          canCreate: canCreate,
          canManage: canManage,
          capabilities: capabilities,
          selectedLocationId: selected,
        ),
      ),
    );
    await tester.pump();
    for (final pending in reader.details) {
      if (!pending.result.isCompleted) {
        pending.result.complete(locationFixture(id: pending.id, scope: scope));
      }
    }
    for (final pending in reader.directories) {
      if (!pending.result.isCompleted) {
        pending.result.complete(locationPage(scope: scope));
      }
    }
    await tester.pumpAndSettle();
  }

  group('the directory surface', () {
    testWidgets('grants nothing by default, which is a read-only catalog', (tester) async {
      await pump(tester);
      expect(find.byKey(_create), findsNothing);
      expect(find.byKey(_bring), findsNothing);
    });

    testWidgets('create draws creation and nothing else', (tester) async {
      await pump(tester, capabilities: const LocationCapabilities(create: true));
      expect(find.byKey(_create), findsOneWidget);
      expect(
        find.byKey(_bring),
        findsNothing,
        reason: 'bringing one down from the institution is a copy, not a creation',
      );
    });

    testWidgets('copy draws bringing one down and not creation', (tester) async {
      await pump(tester, capabilities: const LocationCapabilities(copy: true));
      expect(find.byKey(_bring), findsOneWidget);
      expect(find.byKey(_create), findsNothing);
    });

    testWidgets('an institution scope never offers to bring one down', (tester) async {
      await pump(tester, scope: scopeA, capabilities: LocationCapabilities.all);
      expect(find.byKey(_bring), findsNothing, reason: 'there is nothing above an institution');
      expect(find.byKey(_create), findsOneWidget);
    });
  });

  group('the detail surface', () {
    testWidgets('a direct compositor cannot bypass the update capability', (tester) async {
      final reader = ControlledLocationReader();
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: LocationDetailPanel(
            id: locationA,
            scope: scopeA,
            reader: reader,
            writer: const UnavailableLocationCatalogWriter(),
            sessionAvailable: true,
            capabilities: LocationCapabilities.none,
            onEdit: (_) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pump();
      reader.details.single.result.complete(locationFixture());
      await tester.pumpAndSettle();

      expect(find.byKey(_edit), findsNothing);
    });

    testWidgets('grants nothing by default', (tester) async {
      await pump(tester, selected: locationA);
      expect(find.byKey(_edit), findsNothing);
      expect(find.byKey(_copy), findsNothing);
      expect(find.byKey(_status), findsNothing);
      expect(find.byKey(_schedule), findsNothing);
    });

    testWidgets('update draws editing alone', (tester) async {
      await pump(
        tester,
        selected: locationA,
        capabilities: const LocationCapabilities(update: true),
      );
      expect(find.byKey(_edit), findsOneWidget);
      expect(find.byKey(_copy), findsNothing);
      expect(find.byKey(_status), findsNothing);
      expect(find.byKey(_schedule), findsNothing);
    });

    testWidgets('status draws the transitions alone', (tester) async {
      await pump(
        tester,
        selected: locationA,
        capabilities: const LocationCapabilities(status: true),
      );
      expect(find.byKey(const Key('location-detail-content')), findsOneWidget);
      expect(find.byKey(_status), findsOneWidget);
      expect(find.byKey(_edit), findsNothing);
      expect(find.byKey(_copy), findsNothing);
      expect(find.byKey(_schedule), findsNothing);
    });

    testWidgets('copy draws duplication alone', (tester) async {
      await pump(tester, selected: locationA, capabilities: const LocationCapabilities(copy: true));
      expect(find.byKey(_copy), findsOneWidget);
      expect(find.byKey(_edit), findsNothing);
      expect(find.byKey(_status), findsNothing);
      expect(find.byKey(_schedule), findsNothing);
    });

    testWidgets('schedule draws availability alone', (tester) async {
      await pump(
        tester,
        selected: locationA,
        capabilities: const LocationCapabilities(schedule: true),
      );
      expect(find.byKey(_schedule), findsOneWidget);
      expect(find.byKey(_edit), findsNothing);
      expect(find.byKey(_copy), findsNothing);
      expect(find.byKey(_status), findsNothing);
    });
  });

  group('the legacy pair still behaves exactly as it did', () {
    testWidgets('canCreate alone grants all five, as before', (tester) async {
      await pump(tester, canCreate: true);
      expect(find.byKey(_create), findsOneWidget);
      expect(find.byKey(_bring), findsOneWidget);

      await pump(tester, canCreate: true, selected: locationA);
      expect(find.byKey(_edit), findsOneWidget);
      expect(find.byKey(_copy), findsOneWidget);
      expect(find.byKey(_status), findsOneWidget);
      expect(find.byKey(_schedule), findsOneWidget);
    });

    testWidgets('canManage false with canCreate true grants creation only', (tester) async {
      await pump(tester, canCreate: true, canManage: false);
      expect(find.byKey(_create), findsOneWidget);
      expect(find.byKey(_bring), findsNothing);

      await pump(tester, canCreate: true, canManage: false, selected: locationA);
      expect(find.byKey(_edit), findsNothing);
      expect(find.byKey(_status), findsNothing);
    });

    testWidgets('capabilities win over the pair when both are passed', (tester) async {
      await pump(
        tester,
        canCreate: true,
        canManage: true,
        capabilities: const LocationCapabilities(status: true),
        selected: locationA,
      );
      expect(find.byKey(_status), findsOneWidget);
      expect(find.byKey(_edit), findsNothing, reason: 'the explicit grant is the whole grant');
    });
  });

  group('the type itself', () {
    test('nothing granted reads as read-only', () {
      expect(LocationCapabilities.none.writesAnything, isFalse);
      expect(LocationCapabilities.none.isReadOnly, isTrue);
      expect(LocationCapabilities.all.writesAnything, isTrue);
    });

    test('the legacy derivation is the one the catalog used', () {
      expect(
        LocationCapabilities.fromLegacyFlags(canCreate: true),
        const LocationCapabilities(
          create: true,
          update: true,
          status: true,
          copy: true,
          schedule: true,
        ),
      );
      expect(
        LocationCapabilities.fromLegacyFlags(canCreate: false, canManage: true),
        const LocationCapabilities(update: true, status: true, copy: true, schedule: true),
      );
      expect(LocationCapabilities.fromLegacyFlags(canCreate: false), LocationCapabilities.none);
    });

    test('one granted write is enough to need a writer', () {
      expect(const LocationCapabilities(schedule: true).writesAnything, isTrue);
    });
  });
}
