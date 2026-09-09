import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/locations/domain/location_capabilities.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_copy_dialog.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _requestId = '40000000-0000-4000-8000-000000000001';
const _secondRequestId = '40000000-0000-4000-8000-000000000002';

typedef _CopyCall = ({String sourceId, LocationScope target, String name, String requestId});

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
  late _CopyingWriter writer;
  late List<String> issuedIds;

  setUp(() {
    writer = _CopyingWriter();
    issuedIds = [_requestId, _secondRequestId];
  });

  Widget dialog({LocationCatalogEntry? source}) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: LocationCopyDialog(
        source: source ?? locationFixture(),
        writer: writer,
        requestIdFactory: () => issuedIds.removeAt(0),
      ),
    ),
  );

  group('the dialog', () {
    testWidgets('suggests a name that will not collide, and keeps it editable', (tester) async {
      await tester.pumpWidget(dialog());
      expect(find.text('Sala de leitura (cópia)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('location-copy-name')), 'Sala nova');
      await tester.pump();
      expect(find.text('Sala nova'), findsOneWidget);
    });

    testWidgets('a suggestion never exceeds what the catalog accepts', (tester) async {
      await tester.pumpWidget(dialog(source: locationFixture(name: 'a' * 120)));
      final suggestion = tester
          .widget<TextFormField>(find.byKey(const Key('location-copy-name')))
          .controller
          ?.text;
      expect(suggestion, isNotNull);
      expect(suggestion!.length, lessThanOrEqualTo(120));
      expect(suggestion.endsWith(' (cópia)'), isTrue);
    });

    testWidgets('copies into the same catalog as the source', (tester) async {
      await tester.pumpWidget(dialog(source: locationFixture(scope: scopeUnitA)));
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      expect(writer.calls.single.sourceId, locationA);
      expect(writer.calls.single.target, isA<UnitLocationScope>());
      expect(writer.calls.single.name, 'Sala de leitura (cópia)');
      expect(writer.calls.single.requestId, _requestId);
    });

    testWidgets('an empty name is refused before anything is sent', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.enterText(find.byKey(const Key('location-copy-name')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      expect(writer.calls, isEmpty);
      expect(find.textContaining('Informe o nome'), findsOneWidget);
    });

    testWidgets('a second tap while the first is in flight sends nothing', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-copy-confirm')), warnIfMissed: false);
      await tester.pump();
      expect(writer.calls.length, 1);
    });

    testWidgets('a taken name is explained as a taken name', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteRejectedException());
      await tester.pump();
      expect(find.textContaining('Já existe um local ativo com esse nome'), findsOneWidget);
    });

    testWidgets('correcting a rejected name starts a new request', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteRejectedException());
      await tester.pump();
      await tester.enterText(find.byKey(const Key('location-copy-name')), 'Outro nome');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      expect(writer.calls.map((call) => call.requestId).toList(), [_requestId, _secondRequestId]);
    });

    testWidgets('a retry after a transport failure is the same request', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationCatalogWriteUnavailableException());
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      expect(writer.calls.map((call) => call.requestId).toSet(), {_requestId});
    });

    testWidgets('a denial says permission, never whether it exists', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteDeniedException());
      await tester.pump();
      expect(find.textContaining('não tem permissão para duplicar'), findsOneWidget);
    });

    testWidgets('the refusal is announced, not just drawn', (tester) async {
      await tester.pumpWidget(dialog());
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      writer.results.single.completeError(const LocationWriteDeniedException());
      await tester.pump();
      final semantics = tester.getSemantics(find.byKey(const Key('location-copy-error')));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('the controls meet tap size, labelling and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(dialog());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('from the detail', () {
    late ControlledLocationReader reader;
    setUp(() => reader = ControlledLocationReader());

    Future<void> openDetail(WidgetTester tester, {bool canManage = true}) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: LocationsPage(
            scope: scopeA,
            logout: unavailableSuperadminLogout,
            reader: reader,
            writer: writer,
            sessionAvailable: true,
            canCreate: true,
            canManage: canManage,
            selectedLocationId: locationA,
          ),
        ),
      );
      await tester.pump();
      reader.details.last.result.complete(locationFixture());
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('an actor who may not manage is offered no duplicate control', (tester) async {
      await openDetail(tester, canManage: false);
      expect(find.byKey(const Key('location-detail-copy')), findsNothing);
    });

    testWidgets('duplicating opens the dialog and lands on the new location', (tester) async {
      await openDetail(tester);
      final copy = find.byKey(const Key('location-detail-copy'));
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-copy-dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();
      final readsBefore = reader.details.length;
      writer.results.single.complete(
        locationFixture(id: locationB, name: 'Sala de leitura (cópia)'),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // The page opens the copy, which means a read of the new location, not of
      // the one that was duplicated.
      expect(reader.details.length, greaterThan(readsBefore));
      expect(reader.details.last.id, locationB);
      reader.details.last.result.complete(
        locationFixture(id: locationB, name: 'Sala de leitura (cópia)'),
      );
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('cancelling the dialog leaves the detail where it was', (tester) async {
      await openDetail(tester);
      final copy = find.byKey(const Key('location-detail-copy'));
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-copy-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-copy-dialog')), findsNothing);
      expect(writer.calls, isEmpty);
    });

    testWidgets('a copy response from context A cannot notify context B', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notified = <String>[];

      Widget panel({required String id, required int revision, required String callbackOwner}) =>
          MaterialApp(
            theme: CoeloTheme.light,
            home: Scaffold(
              body: LocationDetailPanel(
                id: id,
                scope: scopeA,
                reader: reader,
                writer: writer,
                capabilities: const LocationCapabilities(copy: true),
                sessionAvailable: true,
                contextRevision: revision,
                requestIdFactory: () => issuedIds.removeAt(0),
                onBack: () {},
                onCopied: (_) => notified.add(callbackOwner),
              ),
            ),
          );

      await tester.pumpWidget(panel(id: locationA, revision: 0, callbackOwner: 'A'));
      await tester.pump();
      reader.details.last.result.complete(locationFixture());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-detail-copy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        writer.results.single.complete(locationFixture(id: locationB));
      });
      await tester.pumpWidget(panel(id: locationA, revision: 0, callbackOwner: 'B'));
      await tester.pump();

      expect(notified, isEmpty);
    });

    testWidgets('an in-flight copy cannot cross to a new id and revision', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notified = <String>[];

      Widget panel({
        required String id,
        required int revision,
        required String callbackOwner,
        bool completeCopyDuringBuild = false,
      }) => MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              if (completeCopyDuringBuild && !writer.results.single.isCompleted) {
                writer.results.single.complete(locationFixture(id: locationB));
              }
              return LocationDetailPanel(
                id: id,
                scope: scopeA,
                reader: reader,
                writer: writer,
                capabilities: const LocationCapabilities(copy: true),
                sessionAvailable: true,
                contextRevision: revision,
                requestIdFactory: () => issuedIds.removeAt(0),
                onBack: () {},
                onCopied: (_) => notified.add(callbackOwner),
              );
            },
          ),
        ),
      );

      await tester.pumpWidget(panel(id: locationA, revision: 0, callbackOwner: 'A'));
      await tester.pump();
      reader.details.last.result.complete(locationFixture());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-detail-copy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-copy-confirm')));
      await tester.pump();

      await tester.pumpWidget(
        panel(
          id: locationB,
          revision: 1,
          callbackOwner: 'B',
          completeCopyDuringBuild: true,
        ),
      );
      await tester.pump();

      expect(notified, isEmpty);
    });
  });
}
