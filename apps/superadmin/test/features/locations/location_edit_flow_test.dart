import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_writer.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_form_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

const _requestId = '40000000-0000-4000-8000-000000000001';
const _secondRequestId = '40000000-0000-4000-8000-000000000002';

typedef _UpdateCall = ({String id, LocationWriteDraft draft, int version, String requestId});

final class _EditingWriter implements LocationCatalogWriter {
  final creates = <LocationWriteDraft>[];
  final updates = <_UpdateCall>[];
  final results = <Completer<LocationCatalogEntry>>[];

  @override
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  }) {
    creates.add(draft);
    final result = Completer<LocationCatalogEntry>();
    results.add(result);
    return result.future;
  }

  @override
  Future<LocationCatalogEntry> update({
    required String locationId,
    required LocationWriteDraft draft,
    required int expectedVersion,
    required String requestId,
  }) {
    updates.add((id: locationId, draft: draft, version: expectedVersion, requestId: requestId));
    final result = Completer<LocationCatalogEntry>();
    results.add(result);
    return result.future;
  }

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
  late _EditingWriter writer;
  late List<String> issuedIds;

  setUp(() {
    writer = _EditingWriter();
    issuedIds = [_requestId, _secondRequestId];
  });

  Widget form({LocationCatalogEntry? initial, void Function(LocationCatalogEntry)? onSaved}) =>
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: LocationFormPanel(
            scope: scopeA,
            initial: initial,
            writer: writer,
            sessionAvailable: true,
            requestIdFactory: () => issuedIds.removeAt(0),
            onCancel: () {},
            onCreated: onSaved ?? (_) {},
          ),
        ),
      );

  group('the form in edit mode', () {
    testWidgets('opens holding what the location already says', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        form(
          initial: locationFixture(
            kind: LocationKind.external,
            address: const {
              'country': 'Brasil',
              'city': 'Cidade exemplo',
              'street': 'Rua Sintética',
              'number': '100',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('location-form-name')))
            .controller
            ?.text,
        'Sala de leitura',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('location-form-street')))
            .controller
            ?.text,
        'Rua Sintética',
      );
      expect(find.text('Editar local'), findsOneWidget);
      expect(find.text('Salvar local'), findsOneWidget);
      expect(find.text('Novo local'), findsNothing);
    });

    testWidgets('creating still says creating', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(form());
      await tester.pumpAndSettle();
      expect(find.text('Novo local'), findsOneWidget);
      expect(find.text('Criar local'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('location-form-name')))
            .controller
            ?.text,
        isEmpty,
      );
    });

    testWidgets('saving edits instead of creating, carrying id and version', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(form(initial: locationFixture(managementVersion: 6)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala renomeada');
      await tester.pump();
      final submit = find.byKey(const Key('location-form-save'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();

      expect(writer.creates, isEmpty);
      expect(writer.updates.single.id, locationA);
      expect(writer.updates.single.version, 6);
      expect(writer.updates.single.requestId, _requestId);
      expect(writer.updates.single.draft.name, 'Sala renomeada');
    });

    testWidgets('the owner comes from the stored location, never from the screen', (tester) async {
      // The page and the entry agree today. If they ever stop agreeing, the
      // catalog must refuse rather than silently move the place, so what travels
      // is what is stored.
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: LocationFormPanel(
              scope: scopeB,
              initial: locationFixture(scope: scopeUnitA),
              writer: writer,
              sessionAvailable: true,
              requestIdFactory: () => issuedIds.removeAt(0),
              onCancel: () {},
              onCreated: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('location-form-save'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(writer.updates.single.draft.scope, isA<UnitLocationScope>());
      expect(writer.updates.single.draft.scope.institutionId, institutionA);
    });

    testWidgets('a conflict tells the actor the screen went stale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(form(initial: locationFixture()));
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('location-form-save'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      writer.results.single.completeError(const LocationWriteConflictException());
      await tester.pumpAndSettle();
      expect(find.textContaining('Alguém mudou este local'), findsOneWidget);
    });

    testWidgets('a denial names editing, not creating', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(form(initial: locationFixture()));
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('location-form-save'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      writer.results.single.completeError(const LocationWriteDeniedException());
      await tester.pumpAndSettle();
      expect(find.textContaining('permissão para editar'), findsOneWidget);
    });
  });

  group('the page', () {
    late ControlledLocationReader reader;
    setUp(() => reader = ControlledLocationReader());

    Widget page({bool canCreate = true, bool? canManage}) => MaterialApp(
      theme: CoeloTheme.light,
      home: LocationsPage(
        scope: scopeA,
        logout: unavailableSuperadminLogout,
        reader: reader,
        writer: writer,
        sessionAvailable: true,
        canCreate: canCreate,
        canManage: canManage,
        selectedLocationId: locationA,
      ),
    );

    Future<void> openDetail(WidgetTester tester, {bool canCreate = true, bool? canManage}) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(page(canCreate: canCreate, canManage: canManage));
      await tester.pump();
      reader.details.last.result.complete(locationFixture(managementVersion: 3));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('an actor who may manage is offered the edit control', (tester) async {
      await openDetail(tester);
      expect(find.byKey(const Key('location-detail-edit')), findsOneWidget);
      expect(find.byKey(const Key('location-status-actions')), findsOneWidget);
    });

    testWidgets('an actor who may not manage is offered neither', (tester) async {
      await openDetail(tester, canCreate: false);
      expect(find.byKey(const Key('location-detail-edit')), findsNothing);
      expect(find.byKey(const Key('location-status-actions')), findsNothing);
    });

    testWidgets('managing can be denied on its own, even to someone who may create', (
      tester,
    ) async {
      await openDetail(tester, canManage: false);
      expect(find.byKey(const Key('location-detail-edit')), findsNothing);
      expect(find.byKey(const Key('location-status-actions')), findsNothing);
    });

    testWidgets('editing opens the form on that location and going back returns', (tester) async {
      await openDetail(tester);
      final edit = find.byKey(const Key('location-detail-edit'));
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(Key('locations-form-$locationA')), findsOneWidget);
      expect(find.text('Editar local'), findsOneWidget);
      // The create form keeps the key it always had, so nothing that looks for
      // it starts finding an edit instead.
      expect(find.byKey(const Key('locations-form')), findsNothing);

      final cancel = find.byKey(const Key('location-form-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(Key('locations-form-$locationA')), findsNothing);
    });

    testWidgets('creating is not offered while a location is open', (tester) async {
      await openDetail(tester);
      expect(find.byKey(const Key('locations-create')), findsNothing);
    });
  });
}
