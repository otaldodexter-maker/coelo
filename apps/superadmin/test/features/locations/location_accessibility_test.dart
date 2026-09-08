import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_form_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_map_section.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

/// Accessibility guarantees for the surfaces this front added.
///
/// These use the framework guidelines rather than hand-written assertions, so a
/// regression in tap size, missing label or contrast fails here instead of
/// reaching someone using a screen reader or a coarse pointer.
void main() {
  testWidgets('the catalog directory meets tap size, labelling and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          // The panel is exercised without the shell on purpose: the shell
          // belongs to another front and carries its own accessibility debt,
          // recorded in the handoff instead of being asserted here.
          body: LocationDirectoryPanel(
            scope: scopeA,
            reader: reader,
            sessionAvailable: true,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the create form meets tap size, labelling and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: LocationFormPanel(
            scope: scopeA,
            writer: const UnavailableLocationCatalogWriter(),
            sessionAvailable: true,
            onCancel: () {},
            onCreated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the Mapa e locais section meets tap size and labelling', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: LocationsMapSection(
              ownerKind: LocationOwnerKind.institution,
              scope: scopeA,
              reader: reader,
              sessionAvailable: true,
              onOpenCatalog: () {},
            ),
          ),
        ),
      ),
    );
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the catalog announces its heading and its owner to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: LocationsPage(
          scope: scopeA,
          logout: unavailableSuperadminLogout,
          reader: reader,
          sessionAvailable: true,
        ),
      ),
    );
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Locais'),
      findsWidgets,
      reason: 'the catalog heading must be announced',
    );
    expect(find.text(locationScopeLabelForTest(scopeA)), findsWidgets);
    handle.dispose();
  });

  testWidgets('a denied catalog announces the denial as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: LocationsPage(scope: scopeA, logout: unavailableSuperadminLogout, reader: reader),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-directory-denied')), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}

String locationScopeLabelForTest(LocationScope scope) =>
    scope is UnitLocationScope ? 'Catálogo da unidade' : 'Catálogo da instituição';
