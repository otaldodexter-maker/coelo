import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_status_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _requestId = '40000000-0000-4000-8000-000000000001';
const _secondRequestId = '40000000-0000-4000-8000-000000000002';

typedef _StatusCall = ({String locationId, LocationCatalogStatus status, int version, String id});

final class _RecordingWriter implements LocationCatalogWriter {
  final calls = <_StatusCall>[];
  final results = <Completer<LocationCatalogEntry>>[];

  @override
  Future<LocationCatalogEntry> setStatus({
    required String locationId,
    required LocationCatalogStatus status,
    required int expectedVersion,
    required String requestId,
  }) {
    calls.add((
      locationId: locationId,
      status: status,
      version: expectedVersion,
      id: requestId,
    ));
    final result = Completer<LocationCatalogEntry>();
    results.add(result);
    return result.future;
  }

  // Only the status command belongs to this surface. Anything else reaching the
  // writer from here is a composition mistake, and it fails loudly.
  @override
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  }) async => throw UnimplementedError('the status actions do not create');

  @override
  Future<LocationCatalogEntry> update({
    required String locationId,
    required LocationWriteDraft draft,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError('the status actions do not edit');

  @override
  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  }) async => throw UnimplementedError('the status actions do not copy');

  @override
  Future<LocationSchedule> readSchedule({required String locationId}) async =>
      throw UnimplementedError('the status actions do not read schedules');

  @override
  Future<LocationSchedule> setSchedule({
    required String locationId,
    required List<LocationScheduleWindow> windows,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError('the status actions do not publish schedules');
}

void main() {
  late _RecordingWriter writer;
  late List<LocationCatalogEntry> changed;
  late List<String> issuedIds;

  setUp(() {
    writer = _RecordingWriter();
    changed = [];
    issuedIds = [_requestId, _secondRequestId];
  });

  Widget actions({
    LocationCatalogStatus status = LocationCatalogStatus.active,
    int version = 4,
    bool enabled = true,
  }) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: LocationStatusActions(
        entry: locationFixture(status: status, managementVersion: version),
        writer: writer,
        enabled: enabled,
        requestIdFactory: () => issuedIds.removeAt(0),
        onChanged: changed.add,
      ),
    ),
  );

  group('what is offered', () {
    testWidgets('an active place can be deactivated or archived, never reactivated', (
      tester,
    ) async {
      await tester.pumpWidget(actions());
      expect(find.byKey(const Key('location-status-inactive')), findsOneWidget);
      expect(find.byKey(const Key('location-status-archived')), findsOneWidget);
      expect(find.byKey(const Key('location-status-active')), findsNothing);
    });

    testWidgets('an inactive place can come back or be archived', (tester) async {
      await tester.pumpWidget(actions(status: LocationCatalogStatus.inactive));
      expect(find.byKey(const Key('location-status-active')), findsOneWidget);
      expect(find.byKey(const Key('location-status-archived')), findsOneWidget);
      expect(find.byKey(const Key('location-status-inactive')), findsNothing);
    });

    testWidgets('an archived place can only come back', (tester) async {
      await tester.pumpWidget(actions(status: LocationCatalogStatus.archived));
      expect(find.byKey(const Key('location-status-active')), findsOneWidget);
      expect(find.byKey(const Key('location-status-inactive')), findsNothing);
      expect(find.byKey(const Key('location-status-archived')), findsNothing);
    });

    testWidgets('a status a location never reaches offers nothing at all', (tester) async {
      await tester.pumpWidget(actions(status: LocationCatalogStatus.suspended));
      expect(find.byKey(const Key('location-status-actions')), findsNothing);
    });

    testWidgets('without a session nothing can be pressed', (tester) async {
      await tester.pumpWidget(actions(enabled: false));
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('location-status-inactive')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('deactivating', () {
    testWidgets('sends the version the actor was looking at', (tester) async {
      await tester.pumpWidget(actions(version: 7));
      await tester.tap(find.byKey(const Key('location-status-inactive')));
      await tester.pump();
      expect(writer.calls.single.status, LocationCatalogStatus.inactive);
      expect(writer.calls.single.version, 7);
      expect(writer.calls.single.id, _requestId);
      expect(writer.calls.single.locationId, locationA);
    });

    testWidgets('reports the new entry once the catalog answers', (tester) async {
      await tester.pumpWidget(actions());
      await tester.tap(find.byKey(const Key('location-status-inactive')));
      await tester.pump();
      writer.results.single.complete(
        locationFixture(status: LocationCatalogStatus.inactive, managementVersion: 5),
      );
      await tester.pump();
      expect(changed.single.status, LocationCatalogStatus.inactive);
      expect(changed.single.managementVersion, 5);
    });

    testWidgets('a second press while the first is in flight sends nothing', (tester) async {
      await tester.pumpWidget(actions());
      await tester.tap(find.byKey(const Key('location-status-inactive')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-status-inactive')), warnIfMissed: false);
      await tester.pump();
      expect(writer.calls.length, 1);
    });
  });

  group('archiving', () {
    testWidgets('asks before taking a place out of every list', (tester) async {
      await tester.pumpWidget(actions());
      await tester.tap(find.byKey(const Key('location-status-archived')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-status-archive-confirm')), findsOneWidget);
      expect(writer.calls, isEmpty);
    });

    testWidgets('keeping it as it is sends nothing', (tester) async {
      await tester.pumpWidget(actions());
      await tester.tap(find.byKey(const Key('location-status-archived')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-status-archive-cancel')));
      await tester.pumpAndSettle();
      expect(writer.calls, isEmpty);
      // The intent was abandoned, so nothing was spent on it.
      expect(issuedIds, [_requestId, _secondRequestId]);
    });

    testWidgets('confirming archives', (tester) async {
      await tester.pumpWidget(actions());
      await tester.tap(find.byKey(const Key('location-status-archived')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-status-archive-accept')));
      await tester.pumpAndSettle();
      expect(writer.calls.single.status, LocationCatalogStatus.archived);
    });
  });

  group('when the catalog refuses', () {
    Future<void> pressAndFail(WidgetTester tester, Object failure) async {
      await tester.pumpWidget(actions());
      await tester.tap(find.byKey(const Key('location-status-inactive')));
      await tester.pump();
      writer.results.single.completeError(failure);
      await tester.pump();
    }

    testWidgets('a conflict says the screen went stale', (tester) async {
      await pressAndFail(tester, const LocationWriteConflictException());
      expect(find.textContaining('Alguém mudou este local'), findsOneWidget);
      expect(changed, isEmpty);
    });

    testWidgets('a denial says permission, never whether it exists', (tester) async {
      await pressAndFail(tester, const LocationWriteDeniedException());
      expect(find.textContaining('não tem permissão'), findsOneWidget);
    });

    testWidgets('an unavailable catalog says so without a server message', (tester) async {
      await pressAndFail(tester, const LocationCatalogWriteUnavailableException());
      expect(find.textContaining('Não foi possível mudar o status'), findsOneWidget);
    });

    testWidgets('a retry of the same intent is the same request', (tester) async {
      await pressAndFail(tester, const LocationCatalogWriteUnavailableException());
      await tester.tap(find.byKey(const Key('location-status-inactive')));
      await tester.pump();
      expect(writer.calls.map((call) => call.id).toSet(), {_requestId});
    });

    testWidgets('a rejected intent starts a new request on the next attempt', (tester) async {
      // The payload itself was wrong, so reusing the id would make the catalog
      // refuse the correction as a conflict instead of judging it.
      await pressAndFail(tester, const LocationWriteRejectedException());
      await tester.tap(find.byKey(const Key('location-status-inactive')));
      await tester.pump();
      expect(writer.calls.map((call) => call.id).toList(), [_requestId, _secondRequestId]);
    });

    testWidgets('the refusal is announced, not just drawn', (tester) async {
      await pressAndFail(tester, const LocationWriteDeniedException());
      final semantics = tester.getSemantics(find.byKey(const Key('location-status-error')));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    });
  });

  group('composition', () {
    testWidgets('the detail panel without a writer offers no status control', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
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
      await tester.pump();
      reader.details.last.result.complete(locationFixture());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-status-actions')), findsNothing);
    });

    testWidgets('the detail panel with a writer reads again after a change', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
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
              writer: writer,
              sessionAvailable: true,
              requestIdFactory: () => issuedIds.removeAt(0),
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      reader.details.last.result.complete(locationFixture(managementVersion: 4));
      await tester.pumpAndSettle();

      final control = find.byKey(const Key('location-status-inactive'));
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pump();
      expect(writer.calls.single.version, 4);

      final readsBefore = reader.details.length;
      writer.results.single.complete(
        locationFixture(status: LocationCatalogStatus.inactive, managementVersion: 5),
      );
      await tester.pump();
      // The panel does not keep the answer it was handed: it asks the catalog
      // again, because the version it is holding is now one behind.
      expect(reader.details.length, readsBefore + 1);
      reader.details.last.result.complete(
        locationFixture(status: LocationCatalogStatus.inactive, managementVersion: 5),
      );
      await tester.pumpAndSettle();
    });
  });

  group('accessibility', () {
    testWidgets('the controls meet tap size, labelling and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(actions());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
