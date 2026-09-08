import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/domain/location_selection_source.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_institution_copy_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _requestId = '40000000-0000-4000-8000-000000000001';
const _secondRequestId = '40000000-0000-4000-8000-000000000002';

typedef _CopyCall = ({String sourceId, LocationScope target, String name, String requestId});

LocationReferenceSnapshot option(String id, String label) => LocationReferenceSnapshot(
  id: id,
  scope: scopeA,
  kind: LocationKind.internal,
  label: label,
);

final class _StubSelectionSource implements LocationSelectionSource {
  final requests = <LocationSelectionRequest>[];
  final results = <Completer<LocationSelectionOptions>>[];

  @override
  Future<LocationSelectionOptions> fetchOptions(LocationSelectionRequest request) {
    requests.add(request);
    final result = Completer<LocationSelectionOptions>();
    results.add(result);
    return result.future;
  }

  @override
  Future<LocationResolvedSnapshot> resolveSnapshot({
    required String id,
    required LocationScope scope,
  }) async => throw UnimplementedError('this dialog never resolves a stored choice');
}

final class _CopyingWriter implements LocationCatalogWriter {
  final calls = <_CopyCall>[];
  final results = <Completer<LocationCatalogEntry>>[];

  @override
  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  }) {
    calls.add((sourceId: sourceId, target: targetScope, name: name, requestId: requestId));
    final result = Completer<LocationCatalogEntry>();
    results.add(result);
    return result.future;
  }

  @override
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  }) async => throw UnimplementedError('this test does not create');

  @override
  Future<LocationCatalogEntry> update({
    required String locationId,
    required LocationWriteDraft draft,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError('this test does not edit');

  @override
  Future<LocationCatalogEntry> setStatus({
    required String locationId,
    required LocationCatalogStatus status,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError('this test does not change status');

  @override
  Future<LocationSchedule> readSchedule({required String locationId}) async =>
      throw UnimplementedError('this test does not read schedules');

  @override
  Future<LocationSchedule> setSchedule({
    required String locationId,
    required List<LocationScheduleWindow> windows,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError('this test does not publish schedules');
}

void main() {
  late _StubSelectionSource source;
  late _CopyingWriter writer;
  late List<String> issuedIds;
  late List<LocationCatalogEntry> copied;
  late int cancelled;

  setUp(() {
    source = _StubSelectionSource();
    writer = _CopyingWriter();
    issuedIds = [_requestId, _secondRequestId];
    copied = [];
    cancelled = 0;
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: LocationInstitutionCopyPanel(
            target: scopeUnitA as UnitLocationScope,
            source: source,
            writer: writer,
            requestIdFactory: () => issuedIds.removeAt(0),
            onCancel: () => cancelled++,
            onCopied: copied.add,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openWith(
    WidgetTester tester,
    List<LocationReferenceSnapshot> options, {
    bool truncated = false,
  }) async {
    await pumpPanel(tester);
    source.results.last.complete(
      LocationSelectionOptions(options: options, truncated: truncated),
    );
    await tester.pumpAndSettle();
  }

  group('the source list', () {
    testWidgets('is read from the institution of the unit, never from the unit', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      final request = source.requests.single;
      expect(request.scope, isA<InstitutionLocationScope>());
      expect(request.scope.institutionId, institutionA);
      expect(request.limit, locationSelectionMaxLimit);
    });

    testWidgets('an institution with nothing to offer says so', (tester) async {
      await openWith(tester, const []);
      expect(find.byKey(const Key('location-institution-copy-empty')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('location-institution-copy-confirm')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a truncated list says so instead of looking complete', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')], truncated: true);
      expect(find.byKey(const Key('location-institution-copy-truncated')), findsOneWidget);
    });

    testWidgets('a search re-reads with the typed term', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await tester.enterText(
        find.byKey(const Key('location-institution-copy-search')),
        'quadra',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-institution-copy-search-run')));
      await tester.pump();
      expect(source.requests.length, 2);
      expect(source.requests.last.search, 'quadra');
    });

    testWidgets('a failed read leaves an honest message and no options', (tester) async {
      await pumpPanel(tester);
      source.results.single.completeError(const LocationSelectionUnavailableException());
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível listar'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('location-institution-copy-confirm')))
            .onPressed,
        isNull,
      );
    });
  });

  group('bringing one down', () {
    /// The field is a MenuAnchor that opens in a post-frame callback, so the
    /// settle is required. Targeting the MenuItemButton instead of raw text
    /// makes a menu that never opened fail as "found 0 widgets" rather than as
    /// a bare "Bad state: No element" from `.last`.
    Future<void> choose(WidgetTester tester, String label) async {
      final field = find.byKey(const Key('location-institution-copy-option'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      final item = find.widgetWithText(MenuItemButton, label);
      expect(item, findsOneWidget, reason: 'the option menu did not open on $label');
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    testWidgets('choosing a source fills the name it will have in the unit', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      expect(find.byKey(const Key('location-institution-copy-name')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('location-institution-copy-name')))
            .controller
            ?.text,
        'Quadra',
      );
    });

    testWidgets('copies into this unit, from the institution that owns it', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      expect(writer.calls.single.sourceId, locationB);
      expect(writer.calls.single.target, isA<UnitLocationScope>());
      expect((writer.calls.single.target as UnitLocationScope).unitId, unitA);
      expect(writer.calls.single.name, 'Quadra');
      expect(writer.calls.single.requestId, _requestId);
    });

    testWidgets('the name can be changed before it lands', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.enterText(
        find.byKey(const Key('location-institution-copy-name')),
        'Quadra coberta',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      expect(writer.calls.single.name, 'Quadra coberta');
    });

    testWidgets('an emptied name is refused before anything is sent', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.enterText(find.byKey(const Key('location-institution-copy-name')), '  ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      expect(writer.calls, isEmpty);
      expect(find.textContaining('Informe o nome'), findsOneWidget);
    });

    testWidgets('a name already used in the unit is explained as that', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteRejectedException());
      await tester.pumpAndSettle();
      // Scoped to the error node: "nesta unidade" also appears in the field
      // label, and a bare text match would pass on the wrong widget.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('location-institution-copy-error')))
            .data,
        contains('Já existe um local ativo com esse nome nesta unidade'),
      );
    });

    testWidgets('correcting a rejected name starts a new request', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteRejectedException());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('location-institution-copy-name')),
        'Quadra 2',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      expect(writer.calls.map((call) => call.requestId).toList(), [_requestId, _secondRequestId]);
    });

    testWidgets('a retry after a transport failure is the same request', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationCatalogWriteUnavailableException());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      expect(writer.calls.map((call) => call.requestId).toSet(), {_requestId});
    });

    testWidgets('a denial says permission, never whether it exists', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteDeniedException());
      await tester.pumpAndSettle();
      expect(find.textContaining('não tem permissão para trazer'), findsOneWidget);
    });

    testWidgets('the refusal is announced, not just drawn', (tester) async {
      await openWith(tester, [option(locationB, 'Quadra')]);
      await choose(tester, 'Quadra');
      await tester.tap(find.byKey(const Key('location-institution-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteDeniedException());
      await tester.pumpAndSettle();
      final semantics = tester.getSemantics(
        find.byKey(const Key('location-institution-copy-error')),
      );
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });
  });

  group('the page offers it only where it means something', () {
    late ControlledLocationReader reader;
    setUp(() => reader = ControlledLocationReader());

    Future<void> pumpPage(
      WidgetTester tester, {
      required LocationScope scope,
      bool canManage = true,
      String? selectedLocationId,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: LocationsPage(
            scope: scope,
            logout: unavailableSuperadminLogout,
            reader: reader,
            writer: writer,
            sessionAvailable: true,
            canCreate: true,
            canManage: canManage,
            selectedLocationId: selectedLocationId,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a unit catalog offers it', (tester) async {
      await pumpPage(tester, scope: scopeUnitA);
      expect(find.byKey(const Key('locations-bring-from-institution')), findsOneWidget);
    });

    testWidgets('an institution catalog does not: there is nothing above it', (tester) async {
      await pumpPage(tester, scope: scopeA);
      expect(find.byKey(const Key('locations-bring-from-institution')), findsNothing);
    });

    testWidgets('an actor who may not manage is not offered it', (tester) async {
      await pumpPage(tester, scope: scopeUnitA, canManage: false);
      expect(find.byKey(const Key('locations-bring-from-institution')), findsNothing);
    });

    testWidgets('it steps aside while a location is open', (tester) async {
      await pumpPage(tester, scope: scopeUnitA, selectedLocationId: locationA);
      reader.details.last.result.complete(locationFixture(scope: scopeUnitA));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('locations-bring-from-institution')), findsNothing);
    });
  });
}
