import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_schedule_section.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _requestId = '40000000-0000-4000-8000-000000000001';
const _secondRequestId = '40000000-0000-4000-8000-000000000002';

typedef _PublishCall = ({String id, List<LocationScheduleWindow> windows, int version, String rid});

LocationScheduleWindow window(int weekday, int starts, int ends) =>
    LocationScheduleWindow(weekday: weekday, startsMinute: starts, endsMinute: ends);

final class _SchedulingWriter implements LocationCatalogWriter {
  final reads = <String>[];
  final publishes = <_PublishCall>[];
  final readResults = <Completer<LocationSchedule>>[];
  final publishResults = <Completer<LocationSchedule>>[];

  @override
  Future<LocationSchedule> readSchedule({required String locationId}) {
    reads.add(locationId);
    final result = Completer<LocationSchedule>();
    readResults.add(result);
    return result.future;
  }

  @override
  Future<LocationSchedule> setSchedule({
    required String locationId,
    required List<LocationScheduleWindow> windows,
    required int expectedVersion,
    required String requestId,
  }) {
    publishes.add((id: locationId, windows: windows, version: expectedVersion, rid: requestId));
    final result = Completer<LocationSchedule>();
    publishResults.add(result);
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
  Future<LocationCatalogEntry> copy({
    required String sourceId,
    required String sourceInstitutionId,
    required LocationScope targetScope,
    required String name,
    required String requestId,
  }) async => throw UnimplementedError('this test does not copy');
}

void main() {
  late _SchedulingWriter writer;
  late List<String> issuedIds;
  late int published;

  setUp(() {
    writer = _SchedulingWriter();
    issuedIds = [_requestId, _secondRequestId];
    published = 0;
  });

  Widget section({int version = 3, bool enabled = true}) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationScheduleSection(
          entry: locationFixture(managementVersion: version),
          writer: writer,
          enabled: enabled,
          requestIdFactory: () => issuedIds.removeAt(0),
          onPublished: () => published++,
        ),
      ),
    ),
  );

  Future<void> loadWith(WidgetTester tester, List<LocationScheduleWindow> windows) async {
    await tester.tap(find.byKey(const Key('location-schedule-load')));
    await tester.pump();
    writer.readResults.single.complete(
      LocationSchedule(locationId: locationA, managementVersion: 3, windows: windows),
    );
    await tester.pumpAndSettle();
  }

  group('clock formatting', () {
    test('midnight at the end of the day reads as 24:00, never as 00:00', () {
      // The two are the same instant but not the same statement: a window that
      // ended at 00:00 would read as ending before it started.
      expect(locationScheduleTime(1440), '24:00');
      expect(locationScheduleTime(0), '00:00');
      expect(locationScheduleTime(485), '08:05');
    });

    test('parsing accepts a clock and refuses everything else', () {
      expect(parseLocationScheduleTime('08:00'), 480);
      expect(parseLocationScheduleTime('8:00'), 480);
      expect(parseLocationScheduleTime('24:00'), 1440);
      expect(parseLocationScheduleTime(' 09:30 '), 570);
      for (final invalid in ['24:01', '25:00', '08:60', '0800', 'oito', '', '08:5']) {
        expect(parseLocationScheduleTime(invalid), isNull, reason: invalid);
      }
    });
  });

  group('reading', () {
    testWidgets('nothing is read until the actor asks', (tester) async {
      await tester.pumpWidget(section());
      expect(writer.reads, isEmpty);
      expect(find.byKey(const Key('location-schedule-load')), findsOneWidget);
    });

    testWidgets('an empty week says nothing was declared, not that it is always open', (
      tester,
    ) async {
      await tester.pumpWidget(section());
      await loadWith(tester, const []);
      expect(find.byKey(const Key('location-schedule-empty')), findsOneWidget);
      expect(find.textContaining('não quer dizer aberto sempre'), findsOneWidget);
    });

    testWidgets('a published week is shown by day and clock', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720), window(3, 480, 1440)]);
      expect(find.textContaining('Segunda · 08:00 às 12:00'), findsOneWidget);
      expect(find.textContaining('Quarta · 08:00 às 24:00'), findsOneWidget);
    });

    testWidgets('a denial says permission and reads nothing further', (tester) async {
      await tester.pumpWidget(section());
      await tester.tap(find.byKey(const Key('location-schedule-load')));
      await tester.pump();
      writer.readResults.single.completeError(const LocationWriteDeniedException());
      await tester.pumpAndSettle();
      expect(find.textContaining('permissão para ver a agenda'), findsOneWidget);
    });

    testWidgets('without a session nothing can be read', (tester) async {
      await tester.pumpWidget(section(enabled: false));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('location-schedule-load')))
            .onPressed,
        isNull,
      );
    });
  });

  group('editing the draft', () {
    testWidgets('publishing is offered only once something changed', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('location-schedule-publish'))).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('location-schedule-remove-1-480')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('location-schedule-publish'))).onPressed,
        isNotNull,
      );
    });

    testWidgets('a window is added on the chosen day and kept in order', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(3, 480, 720)]);
      await tester.enterText(find.byKey(const Key('location-schedule-start')), '14:00');
      await tester.enterText(find.byKey(const Key('location-schedule-end')), '16:00');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-schedule-add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      expect(writer.publishes.single.windows.map((w) => w.weekday).toList(), [1, 3]);
      expect(writer.publishes.single.windows.first.startsMinute, 840);
    });

    testWidgets('a time that is not a time is refused before anything is added', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, const []);
      await tester.enterText(find.byKey(const Key('location-schedule-start')), '25:00');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-schedule-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-schedule-window-error')), findsOneWidget);
      expect(find.byKey(const Key('location-schedule-empty')), findsOneWidget);
    });

    testWidgets('an end before its start is refused', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, const []);
      await tester.enterText(find.byKey(const Key('location-schedule-start')), '16:00');
      await tester.enterText(find.byKey(const Key('location-schedule-end')), '14:00');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-schedule-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-schedule-window-error')), findsOneWidget);
    });

    testWidgets('an overlap is caught here, while the offending window is on screen', (
      tester,
    ) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.enterText(find.byKey(const Key('location-schedule-start')), '10:00');
      await tester.enterText(find.byKey(const Key('location-schedule-end')), '14:00');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-schedule-add')));
      await tester.pumpAndSettle();
      expect(find.textContaining('se sobrepõe'), findsOneWidget);
      expect(writer.publishes, isEmpty);
    });

    testWidgets('a window that merely touches another is accepted', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.enterText(find.byKey(const Key('location-schedule-start')), '12:00');
      await tester.enterText(find.byKey(const Key('location-schedule-end')), '14:00');
      await tester.pump();
      await tester.tap(find.byKey(const Key('location-schedule-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('location-schedule-window-error')), findsNothing);
      expect(find.byKey(const Key('location-schedule-window-1-720')), findsOneWidget);
    });
  });

  group('publishing', () {
    testWidgets('sends the whole week with the version the actor was looking at', (tester) async {
      await tester.pumpWidget(section(version: 9));
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.tap(find.byKey(const Key('location-schedule-remove-1-480')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      expect(writer.publishes.single.id, locationA);
      expect(writer.publishes.single.version, 9);
      expect(writer.publishes.single.rid, _requestId);
      expect(writer.publishes.single.windows, isEmpty);
    });

    testWidgets('a published week becomes the new baseline and tells the detail', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.tap(find.byKey(const Key('location-schedule-remove-1-480')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      writer.publishResults.single.complete(
        LocationSchedule(locationId: locationA, managementVersion: 4, windows: const []),
      );
      await tester.pumpAndSettle();
      expect(published, 1);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('location-schedule-publish'))).onPressed,
        isNull,
      );
    });

    testWidgets('a conflict says the screen went stale', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.tap(find.byKey(const Key('location-schedule-remove-1-480')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      writer.publishResults.single.completeError(const LocationWriteConflictException());
      await tester.pumpAndSettle();
      expect(find.textContaining('Alguém mudou este local'), findsOneWidget);
      expect(published, 0);
    });

    testWidgets('a retry after a transport failure is the same request', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.tap(find.byKey(const Key('location-schedule-remove-1-480')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      writer.publishResults.single.completeError(
        const LocationCatalogWriteUnavailableException(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      expect(writer.publishes.map((call) => call.rid).toSet(), {_requestId});
    });

    testWidgets('a rejected week starts a new request on the next attempt', (tester) async {
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await tester.tap(find.byKey(const Key('location-schedule-remove-1-480')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      writer.publishResults.single.completeError(const LocationWriteRejectedException());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-schedule-publish')));
      await tester.pump();
      expect(writer.publishes.map((call) => call.rid).toList(), [_requestId, _secondRequestId]);
    });
  });

  group('accessibility', () {
    testWidgets('the loaded section meets tap size, labelling and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(1440, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(section());
      await loadWith(tester, [window(1, 480, 720)]);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
