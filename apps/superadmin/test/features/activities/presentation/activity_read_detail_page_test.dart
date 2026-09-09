import 'dart:async';

import 'package:coelo_superadmin/features/activities/domain/activity_read_detail.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_read_detail_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const activityId = '10000000-0000-4000-8000-000000000001';
const nextActivityId = '10000000-0000-4000-8000-000000000002';
const institutionId = '20000000-0000-4000-8000-000000000001';
const unitId = '30000000-0000-4000-8000-000000000001';
ActivityReadDetail readDetail({String id = activityId}) => ActivityReadDetail.fromJson({
  'activity': {
    'activity_id': id,
    'institution_id': institutionId,
    'name': 'Oficina autorizada',
    'description': 'Descrição autorizada',
    'taxonomy_id': null,
    'taxonomy_name': null,
    'status': 'draft',
    'management_version': 1,
    'icon_key': null,
    'initials': 'OA',
    'created_at': '2026-09-01T12:00:00Z',
    'updated_at': '2026-09-01T12:00:00Z',
  },
  'units': [
    {'unit_id': unitId, 'name': 'Unidade autorizada', 'status': 'active'},
  ],
  'groups': <Object?>[],
  'counts': {'units': 1, 'groups': 0, 'participants': 2, 'instructors': 1, 'activity_admins': 1},
});

class _Reader implements ActivityReadDetailRepository {
  final calls = <({String id, Completer<ActivityReadDetail> result})>[];
  @override
  Future<ActivityReadDetail> fetchById(String id) {
    final result = Completer<ActivityReadDetail>();
    calls.add((id: id, result: result));
    return result.future;
  }
}

void main() {
  Widget app(
    _Reader reader, {
    String id = activityId,
    bool canRead = true,
    int revision = 1,
    List<String>? consumers,
    List<String>? edits,
    bool dark = false,
    double scale = 1,
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: ActivityReadDetailPage(
      activityId: id,
      repository: reader,
      sessionAvailable: true,
      canRead: canRead,
      contextRevision: revision,
      logout: unavailableSuperadminLogout,
      onBack: () {},
      onEdit: (detail) => edits?.add(detail.id),
      onAssessmentSettings: (detail) {},
      reservationBuilder: (context, detail) {
        consumers?.add(detail.id);
        return Text('Reservas de ${detail.id}');
      },
    ),
  );

  testWidgets('authorized projection renders actual fields and passes persisted consumer', (
    tester,
  ) async {
    final reader = _Reader();
    final consumers = <String>[];
    await tester.pumpWidget(app(reader, consumers: consumers));
    expect(find.byKey(const Key('activity-read-loading')), findsOneWidget);
    reader.calls.single.result.complete(readDetail());
    await tester.pumpAndSettle();
    expect(find.text('Oficina autorizada'), findsOneWidget);
    expect(find.text('Governança'), findsNothing);
    expect(find.text('Sem término'), findsNothing);
    expect(find.text(institutionId), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Reservas de $activityId'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('activity-read-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(consumers.toSet(), {activityId});
    expect(tester.takeException(), isNull);
  });

  testWidgets('route A completion cannot replace pending route B', (tester) async {
    final reader = _Reader();
    final consumers = <String>[];
    await tester.pumpWidget(app(reader, consumers: consumers));
    await tester.pumpWidget(app(reader, id: nextActivityId, consumers: consumers));
    reader.calls.first.result.complete(readDetail());
    await tester.pump();
    expect(find.text('Oficina autorizada'), findsNothing);
    expect(consumers, isEmpty);
    reader.calls.last.result.complete(readDetail(id: nextActivityId));
    await tester.pumpAndSettle();
    expect(consumers.toSet(), {nextActivityId});
  });

  testWidgets('revision clears detail; denial and stale edit callback disclose nothing', (
    tester,
  ) async {
    final reader = _Reader();
    final edits = <String>[];
    await tester.pumpWidget(app(reader, edits: edits));
    reader.calls.single.result.complete(readDetail());
    await tester.pumpAndSettle();
    final oldEdit = tester
        .widget<OutlinedButton>(find.byKey(const Key('activity-read-edit')))
        .onPressed!;
    await tester.pumpWidget(app(reader, revision: 2, edits: edits));
    expect(find.text('Oficina autorizada'), findsNothing);
    oldEdit();
    expect(edits, isEmpty);
    reader.calls.last.result.completeError(
      const ActivityReadDetailException(ActivityReadDetailFailure.denied),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-read-denied')), findsOneWidget);
    expect(find.text('Oficina autorizada'), findsNothing);
  });

  testWidgets('invalid route or capability loss never reaches reader', (tester) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader, id: 'draft'));
    await tester.pumpAndSettle();
    expect(reader.calls, isEmpty);
    await tester.pumpWidget(app(reader, canRead: false));
    await tester.pumpAndSettle();
    expect(reader.calls, isEmpty);
  });

  testWidgets('wrong resource and transport errors have no payload or raw diagnostics', (
    tester,
  ) async {
    final reader = _Reader();
    await tester.pumpWidget(app(reader));
    reader.calls.single.result.complete(readDetail(id: nextActivityId));
    await tester.pumpAndSettle();
    expect(find.text('Oficina autorizada'), findsNothing);
    expect(find.byKey(const Key('activity-read-unavailable')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-read-reload')));
    reader.calls.last.result.completeError(StateError('private SQL detail'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private SQL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('read detail width=$width dark=$dark text200', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reader = _Reader();
        await tester.pumpWidget(app(reader, dark: dark, scale: 2));
        reader.calls.single.result.complete(readDetail());
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Reservas de $activityId'),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('activity-read-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('activity-read-assessment')),
          -100,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('activity-read-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('activity-read-assessment')).hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('activity-read-reload')),
          -200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('activity-read-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('activity-read-reload')).hitTestable(), findsOneWidget);
        for (final key in ['back', 'edit']) {
          expect(find.byKey(Key('activity-read-$key')).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
