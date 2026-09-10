import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_reservation_gateway.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_reservation_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const locationId = 'a1000000-0000-4000-8000-000000000001';
const consumer = LocationReservationConsumer(
  kind: LocationReservationConsumerKind.activity,
  id: 'a1000000-0000-4000-8000-000000000002',
);
const scope = LocationScope.institution(institutionId: 'a1000000-0000-4000-8000-000000000003');

LocationReservation reservation({
  String id = 'a1000000-0000-4000-8000-000000000004',
  LocationReservationState state = LocationReservationState.active,
  int version = 1,
}) => LocationReservation(
  id: id,
  locationId: locationId,
  consumer: consumer,
  state: state,
  recurrence: const LocationReservationRecurrence.once(),
  occurrences: [
    LocationReservationOccurrence(
      startsAt: DateTime.utc(2026, 9, 9, 12),
      endsAt: DateTime.utc(2026, 9, 9, 13),
    ),
  ],
  managementVersion: version,
);

class _Gateway implements LocationReservationGateway {
  bool isAvailable = true;
  Object? readError;
  LocationSchedulingPolicyState policy = const LocationSchedulingPolicyState(
    scope: scope,
    policy: LocationSchedulingPolicy.block,
    managementVersion: 2,
  );
  LocationReservationAssessment assessment = LocationReservationAssessment(
    policy: LocationSchedulingPolicy.block,
    conflict: LocationReservationConflict.none,
    conflicting: const [],
  );
  List<LocationReservation> listed = [];
  String? nextId;
  final assessed = <LocationReservationDraft>[];
  final creates = <({LocationReservationDraft draft, String requestId})>[];
  final cancellations = <({String reservationId, int version, String requestId})>[];
  final policyWrites = <({LocationSchedulingPolicy policy, int version, String requestId})>[];
  Object? createError;
  Object? cancelError;
  Object? policyError;

  @override
  bool get available => isAvailable;

  @override
  Future<LocationReservationAssessment> assess(LocationReservationDraft draft) async {
    assessed.add(draft);
    return assessment;
  }

  @override
  Future<LocationReservation> create({
    required LocationReservationDraft draft,
    required String requestId,
  }) async {
    creates.add((draft: draft, requestId: requestId));
    if (createError case final error?) throw error;
    return reservation();
  }

  @override
  Future<LocationReservation> cancel({
    required String locationId,
    required LocationReservationConsumer consumer,
    required String reservationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    cancellations.add((
      reservationId: reservationId,
      version: expectedVersion,
      requestId: requestId,
    ));
    if (cancelError case final error?) throw error;
    return reservation(id: reservationId, state: LocationReservationState.cancelled, version: 2);
  }

  @override
  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  }) async {
    if (readError case final error?) throw error;
    return policy;
  }

  @override
  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  }) async => LocationReservationPage(
    locationId: locationId,
    consumer: consumer,
    items: listed,
    nextId: nextId,
  );

  @override
  Future<LocationSchedulingPolicyState> setPolicy({
    required String locationId,
    required LocationScope scope,
    required LocationSchedulingPolicy policy,
    required int expectedVersion,
    required String requestId,
  }) async {
    policyWrites.add((policy: policy, version: expectedVersion, requestId: requestId));
    if (policyError case final error?) throw error;
    return this.policy = LocationSchedulingPolicyState(
      scope: scope,
      policy: policy,
      managementVersion: expectedVersion + 1,
    );
  }
}

final class _DelayedReadGateway extends _Gateway {
  final policyResult = Completer<LocationSchedulingPolicyState>();
  final pageResult = Completer<LocationReservationPage>();

  @override
  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  }) => policyResult.future;

  @override
  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  }) => pageResult.future;
}

final class _DelayedAssessmentGateway extends _Gateway {
  final result = Completer<LocationReservationAssessment>();
  @override
  Future<LocationReservationAssessment> assess(LocationReservationDraft draft) {
    assessed.add(draft);
    return result.future;
  }
}

final class _DelayedCreateGateway extends _Gateway {
  final createResult = Completer<LocationReservation>();

  @override
  Future<LocationReservation> create({
    required LocationReservationDraft draft,
    required String requestId,
  }) {
    creates.add((draft: draft, requestId: requestId));
    return createResult.future;
  }
}

final class _DelayedReloadGateway extends _Gateway {
  final reloadPolicy = Completer<LocationSchedulingPolicyState>();
  final reloadPage = Completer<LocationReservationPage>();
  var policyReads = 0;
  var pageReads = 0;

  @override
  Future<LocationSchedulingPolicyState> getPolicy({
    required String locationId,
    required LocationScope scope,
  }) {
    if (policyReads++ == 0) return Future.value(policy);
    return reloadPolicy.future;
  }

  @override
  Future<LocationReservationPage> listPaged({
    required String locationId,
    required LocationReservationConsumer consumer,
    String? afterId,
    int limit = 50,
  }) {
    if (pageReads++ == 0) {
      return Future.value(
        LocationReservationPage(
          locationId: locationId,
          consumer: consumer,
          items: listed,
          nextId: nextId,
        ),
      );
    }
    return reloadPage.future;
  }
}

void main() {
  late _Gateway gateway;
  late List<String> requestIds;

  setUp(() {
    gateway = _Gateway();
    requestIds = ['b1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000002'];
  });

  Widget panel({
    bool session = true,
    bool read = true,
    bool manage = true,
    bool override = true,
    LocationCatalogStatus status = LocationCatalogStatus.active,
    String targetLocationId = locationId,
    LocationScope targetScope = scope,
    LocationReservationGateway? source,
  }) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationReservationPanel(
          locationId: targetLocationId,
          scope: targetScope,
          consumer: consumer,
          gateway: source ?? gateway,
          sessionAvailable: session,
          contextRevision: 1,
          canRead: read,
          canManage: manage,
          canOverride: override,
          locationStatus: status,
          requestIdFactory: () => requestIds.removeAt(0),
        ),
      ),
    ),
  );

  Future<void> fillOnce(WidgetTester tester) async {
    tester
        .widget<CoeloDateTimeField>(find.byKey(const Key('location-reservation-start')))
        .onChanged(DateTime(2026, 9, 9, 12));
    tester
        .widget<CoeloDateTimeField>(find.byKey(const Key('location-reservation-end')))
        .onChanged(DateTime(2026, 9, 9, 13));
    await tester.pump();
  }

  testWidgets('inactive catalog keeps cancellation but rejects a held fresh create callback', (
    tester,
  ) async {
    gateway.listed = [reservation()];
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    final old = tester
        .widget<FilledButton>(find.byKey(const Key('location-reservation-assess')))
        .onPressed!;
    await tester.pumpWidget(panel(status: LocationCatalogStatus.inactive));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-reservation-assess')), findsNothing);
    old();
    await tester.pumpAndSettle();
    expect(gateway.assessed, isEmpty);
    final cancel = find.byKey(
      const Key('location-reservation-cancel-a1000000-0000-4000-8000-000000000004'),
    );
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(gateway.cancellations, hasLength(1));
    expect(gateway.creates, isEmpty);
  });
  testWidgets('inactive catalog retains ambiguous receipt retry without opening a new intention', (
    tester,
  ) async {
    gateway.createError = const LocationReservationGatewayUnavailableException();
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    final assess = find.byKey(const Key('location-reservation-assess'));
    await tester.ensureVisible(assess);
    await tester.tap(assess);
    await tester.pumpAndSettle();
    final request = gateway.creates.single.requestId;
    await tester.pumpWidget(panel(status: LocationCatalogStatus.inactive));
    await tester.pumpAndSettle();
    gateway.createError = null;
    final retry = find.byKey(const Key('location-reservation-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(gateway.creates, hasLength(2));
    expect(gateway.creates.last.requestId, request);
    expect(gateway.creates.last.draft, same(gateway.creates.first.draft));
    expect(find.byKey(const Key('location-reservation-assess')), findsNothing);
  });
  testWidgets('inactive catalog stops a pending assessment from starting a fresh write', (
    tester,
  ) async {
    final delayed = _DelayedAssessmentGateway();
    await tester.pumpWidget(panel(source: delayed));
    await tester.pumpAndSettle();
    await fillOnce(tester);
    final assess = find.byKey(const Key('location-reservation-assess'));
    await tester.ensureVisible(assess);
    await tester.tap(assess);
    await tester.pump();
    await tester.pumpWidget(panel(source: delayed, status: LocationCatalogStatus.inactive));
    delayed.result.complete(delayed.assessment);
    await tester.pumpAndSettle();
    expect(delayed.assessed, hasLength(1));
    expect(delayed.creates, isEmpty);
    final policy = tester.widget<OutlinedButton>(
      find.byKey(const Key('location-reservation-policy-save')),
    );
    expect(policy.onPressed, isNotNull);
  });

  testWidgets('fails closed before reading when session or capability is absent', (tester) async {
    await tester.pumpWidget(panel(session: false));
    expect(find.byKey(const Key('location-reservations-denied')), findsOneWidget);
    expect(gateway.assessed, isEmpty);
  });

  testWidgets('an unset policy must be selected explicitly before reserving', (tester) async {
    gateway.policy = const LocationSchedulingPolicyState(
      scope: scope,
      policy: null,
      managementVersion: 0,
    );
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-reservation-policy-unset')), findsOneWidget);
    expect(find.byKey(const Key('location-reservation-assess')), findsNothing);

    await tester.tap(find.byKey(const Key('location-reservation-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alertar e exigir confirmação').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-reservation-policy-save')));
    await tester.pumpAndSettle();

    expect(gateway.policyWrites.single.policy, LocationSchedulingPolicy.warn);
    expect(gateway.policyWrites.single.version, 0);
    expect(gateway.policyWrites.single.requestId, 'b1000000-0000-4000-8000-000000000001');
    expect(find.byKey(const Key('location-reservation-assess')), findsOneWidget);
  });

  testWidgets('a conflict-free once request creates one reservation', (tester) async {
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(gateway.assessed, hasLength(1));
    expect(gateway.creates, hasLength(1));
    expect(gateway.creates.single.draft.recurrence, isA<LocationReservationOnce>());
    expect(gateway.creates.single.requestId, 'b1000000-0000-4000-8000-000000000001');
    expect(
      find.byKey(const Key('location-reservation-a1000000-0000-4000-8000-000000000004')),
      findsOneWidget,
    );
  });

  testWidgets('reload blocks creation until its snapshot has settled', (tester) async {
    final delayed = _DelayedReloadGateway();
    await tester.pumpWidget(panel(source: delayed));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-reservation-reload')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('location-reservation-assess'))).onPressed,
      isNull,
    );
    await fillOnce(tester);

    delayed.reloadPolicy.complete(delayed.policy);
    delayed.reloadPage.complete(
      LocationReservationPage(
        locationId: locationId,
        consumer: consumer,
        items: const [],
        nextId: null,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(delayed.creates, hasLength(1));
    expect(
      find.byKey(const Key('location-reservation-a1000000-0000-4000-8000-000000000004')),
      findsOneWidget,
    );
  });

  testWidgets('confirmable conflict requires capability and a justification', (tester) async {
    gateway.assessment = LocationReservationAssessment(
      policy: LocationSchedulingPolicy.warn,
      conflict: LocationReservationConflict.confirmable,
      conflicting: [reservation().occurrences.single],
    );
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();
    expect(gateway.creates, isEmpty);

    await tester.enterText(
      find.byKey(const Key('location-reservation-justification')),
      'Reunião pedagógica excepcional',
    );
    tester.testTextInput.hide();
    await tester.tap(find.byKey(const Key('location-reservation-confirm-conflict')));
    await tester.pumpAndSettle();
    expect(gateway.creates.single.draft.conflictJustification, 'Reunião pedagógica excepcional');
  });

  testWidgets('editing an assessed conflict requires a fresh assessment', (tester) async {
    gateway.assessment = LocationReservationAssessment(
      policy: LocationSchedulingPolicy.warn,
      conflict: LocationReservationConflict.confirmable,
      conflicting: [reservation().occurrences.single],
    );
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CoeloDateTimeField>(find.byKey(const Key('location-reservation-start')))
          .enabled,
      isTrue,
    );
    tester
        .widget<CoeloDateTimeField>(find.byKey(const Key('location-reservation-start')))
        .onChanged(DateTime(2026, 9, 9, 14));
    tester
        .widget<CoeloDateTimeField>(find.byKey(const Key('location-reservation-end')))
        .onChanged(DateTime(2026, 9, 9, 15));
    await tester.pump();

    expect(find.byKey(const Key('location-reservation-confirm-conflict')), findsNothing);
    gateway.assessment = LocationReservationAssessment(
      policy: LocationSchedulingPolicy.warn,
      conflict: LocationReservationConflict.none,
      conflicting: const [],
    );
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(gateway.assessed, hasLength(2));
    expect(gateway.creates.single.draft.firstOccurrence.startsAt, DateTime(2026, 9, 9, 14).toUtc());
  });

  testWidgets('editing a weekly time zone invalidates its assessed conflict', (tester) async {
    gateway.assessment = LocationReservationAssessment(
      policy: LocationSchedulingPolicy.warn,
      conflict: LocationReservationConflict.confirmable,
      conflicting: [reservation().occurrences.single],
    );
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    tester
        .widget<CoeloAdminSingleSelectField<bool>>(
          find.byKey(const Key('location-reservation-recurrence')),
        )
        .onChanged(true);
    await tester.pump();
    tester
        .widget<CoeloAdminMultiSelectField<int>>(
          find.byKey(const Key('location-reservation-weekdays')),
        )
        .onChanged({1});
    tester
        .widget<CoeloDateRangeField>(find.byKey(const Key('location-reservation-until')))
        .onChanged(DateTimeRange(start: DateTime(2026, 12, 18), end: DateTime(2026, 12, 18)));
    await tester.enterText(
      find.byKey(const Key('location-reservation-time-zone')),
      'America/Sao_Paulo',
    );
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('location-reservation-time-zone'))).enabled,
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('location-reservation-time-zone')), 'UTC');
    await tester.pump();

    expect(find.byKey(const Key('location-reservation-confirm-conflict')), findsNothing);
    gateway.assessment = LocationReservationAssessment(
      policy: LocationSchedulingPolicy.warn,
      conflict: LocationReservationConflict.none,
      conflicting: const [],
    );
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(gateway.assessed, hasLength(2));
    expect((gateway.creates.single.draft.recurrence as LocationReservationWeekly).timeZone, 'UTC');
  });

  testWidgets('transport retry preserves the request id and frozen draft', (tester) async {
    gateway.createError = const LocationReservationGatewayUnavailableException();
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();
    gateway.createError = null;
    await tester.tap(find.byKey(const Key('location-reservation-retry')));
    await tester.pumpAndSettle();

    expect(gateway.creates, hasLength(2));
    expect(gateway.creates.map((call) => call.requestId).toSet(), hasLength(1));
    expect(
      gateway.creates[1].draft.firstOccurrence.startsAt,
      gateway.creates[0].draft.firstOccurrence.startsAt,
    );
  });

  testWidgets('pending retry survives an equivalent rebuilt scope', (tester) async {
    gateway.createError = const LocationReservationGatewayUnavailableException();
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-reservation-retry')), findsOneWidget);
    gateway.createError = null;

    await tester.pumpWidget(
      panel(targetScope: InstitutionLocationScope(institutionId: scope.institutionId)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-reservation-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('location-reservation-retry')));
    await tester.pumpAndSettle();

    expect(gateway.creates, hasLength(2));
    expect(gateway.creates.map((call) => call.requestId).toSet(), hasLength(1));
  });

  testWidgets('an initial read failure can be reloaded', (tester) async {
    gateway.readError = StateError('offline');
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-reservation-error')), findsOneWidget);
    gateway.readError = null;
    await tester.tap(find.byKey(const Key('location-reservation-reload')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-reservation-error')), findsNothing);
    expect(find.byKey(const Key('location-reservation-empty')), findsOneWidget);
  });

  testWidgets('an active reservation can be cancelled with its current version', (tester) async {
    gateway.listed = [reservation(version: 7)];
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('location-reservation-cancel-a1000000-0000-4000-8000-000000000004')),
    );
    await tester.pumpAndSettle();

    expect(gateway.cancellations.single.version, 7);
    expect(find.textContaining('Cancelada'), findsOneWidget);
  });

  testWidgets('policy retry preserves its request id and payload', (tester) async {
    gateway.policyError = StateError('lost response');
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-reservation-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alertar e exigir confirmação').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-reservation-policy-save')));
    await tester.pumpAndSettle();

    gateway.policy = const LocationSchedulingPolicyState(
      scope: scope,
      policy: LocationSchedulingPolicy.block,
      managementVersion: 99,
    );
    await tester.tap(find.byKey(const Key('location-reservation-reload')));
    await tester.pumpAndSettle();
    gateway.policyError = null;
    await tester.tap(find.byKey(const Key('location-reservation-policy-save')));
    await tester.pumpAndSettle();

    expect(gateway.policyWrites, hasLength(2));
    expect(gateway.policyWrites.map((call) => call.requestId).toSet(), hasLength(1));
    expect(gateway.policyWrites.map((call) => call.policy).toSet(), {
      LocationSchedulingPolicy.warn,
    });
    expect(gateway.policyWrites.map((call) => call.version).toSet(), {2});
  });

  testWidgets('cancel retry preserves its request id and target version', (tester) async {
    gateway.listed = [reservation(version: 7)];
    gateway.cancelError = StateError('lost response');
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    final cancel = find.byKey(
      const Key('location-reservation-cancel-a1000000-0000-4000-8000-000000000004'),
    );
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    gateway.listed = [reservation(version: 99)];
    await tester.tap(find.byKey(const Key('location-reservation-reload')));
    await tester.pumpAndSettle();
    gateway.cancelError = null;
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(gateway.cancellations, hasLength(2));
    expect(gateway.cancellations.map((call) => call.requestId).toSet(), hasLength(1));
    expect(gateway.cancellations.map((call) => call.reservationId).toSet(), {reservation().id});
    expect(gateway.cancellations.map((call) => call.version).toSet(), {7});
  });

  testWidgets('a pending read from A cannot replace B when gateway changes at the same revision', (
    tester,
  ) async {
    final delayedA = _DelayedReadGateway();
    final gatewayB = _Gateway();
    await tester.pumpWidget(panel(source: delayedA));
    await tester.pump();

    const locationB = 'a1000000-0000-4000-8000-000000000099';
    await tester.pumpWidget(panel(source: gatewayB, targetLocationId: locationB));
    await tester.pumpAndSettle();
    delayedA.policyResult.completeError(const LocationReservationGatewayUnavailableException());
    delayedA.pageResult.completeError(const LocationReservationGatewayUnavailableException());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-reservation-error')), findsNothing);
    expect(find.byKey(const Key('location-reservation-assess')), findsOneWidget);
  });

  testWidgets('a failed write from A cannot alter B after the context changes', (tester) async {
    final delayedA = _DelayedCreateGateway();
    await tester.pumpWidget(panel(source: delayedA));
    await tester.pumpAndSettle();
    await fillOnce(tester);
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pump();
    expect(delayedA.creates, hasLength(1));

    const locationB = 'a1000000-0000-4000-8000-000000000099';
    await tester.pumpWidget(panel(source: _Gateway(), targetLocationId: locationB));
    await tester.pumpAndSettle();
    delayedA.createResult.completeError(const LocationReservationGatewayUnavailableException());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-reservation-error')), findsNothing);
    expect(find.byKey(const Key('location-reservation-assess')), findsOneWidget);
  });

  testWidgets('weekly recurrence is sent as a rule and never expanded by the client', (
    tester,
  ) async {
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await fillOnce(tester);
    tester
        .widget<CoeloAdminSingleSelectField<bool>>(
          find.byKey(const Key('location-reservation-recurrence')),
        )
        .onChanged(true);
    await tester.pump();
    tester
        .widget<CoeloAdminMultiSelectField<int>>(
          find.byKey(const Key('location-reservation-weekdays')),
        )
        .onChanged({1, 3, 5});
    tester
        .widget<CoeloDateRangeField>(find.byKey(const Key('location-reservation-until')))
        .onChanged(DateTimeRange(start: DateTime(2026, 12, 18), end: DateTime(2026, 12, 18)));
    await tester.enterText(
      find.byKey(const Key('location-reservation-time-zone')),
      'America/Sao_Paulo',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.byKey(const Key('location-reservation-assess')));
    await tester.pumpAndSettle();

    final weekly = gateway.assessed.single.recurrence as LocationReservationWeekly;
    expect(weekly.weekdays, {1, 3, 5});
    expect(weekly.until, DateTime.utc(2026, 12, 18));
    expect(gateway.assessed.single.firstOccurrence.startsAt, DateTime(2026, 9, 9, 12).toUtc());
  });
}
