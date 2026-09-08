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

final class _RecordingWriter implements LocationCatalogWriter {
  final drafts = <LocationWriteDraft>[];
  final requestIds = <String>[];
  final results = <Completer<LocationCatalogEntry>>[];

  @override
  Future<LocationCatalogEntry> create({
    required LocationWriteDraft draft,
    required String requestId,
  }) {
    drafts.add(draft);
    requestIds.add(requestId);
    final result = Completer<LocationCatalogEntry>();
    results.add(result);
    return result.future;
  }
}

void main() {
  Widget panel({
    required _RecordingWriter writer,
    bool sessionAvailable = true,
    void Function(LocationCatalogEntry)? onCreated,
    VoidCallback? onCancel,
    double textScale = 1,
    bool dark = false,
    Size size = const Size(1440, 900),
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: LocationFormPanel(
        scope: scopeA,
        writer: writer,
        sessionAvailable: sessionAvailable,
        requestIdFactory: () => _requestId,
        onCancel: onCancel ?? () {},
        onCreated: onCreated ?? (_) {},
      ),
    ),
  );

  testWidgets('an internal location is sent with the owner of the screen', (tester) async {
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-form-name')), '  Sala de leitura  ');
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();

    expect(writer.drafts.single.scope, scopeA);
    expect(writer.drafts.single.name, '  Sala de leitura  ');
    expect(writer.drafts.single.kind, LocationKind.internal);
    expect(writer.drafts.single.address, isNull);
    expect(writer.requestIds.single, _requestId);
  });

  testWidgets('an empty name is refused on screen without any write', (tester) async {
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pumpAndSettle();
    expect(writer.drafts, isEmpty);
    expect(find.text('Informe o nome do local.'), findsOneWidget);
  });

  testWidgets('a second tap while saving does not create a second location', (tester) async {
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala');
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('location-form-save')), warnIfMissed: false);
    await tester.pump();
    expect(writer.drafts, hasLength(1));
  });

  testWidgets('the created location is handed back to the caller', (tester) async {
    final writer = _RecordingWriter();
    LocationCatalogEntry? created;
    await tester.pumpWidget(panel(writer: writer, onCreated: (entry) => created = entry));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala');
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();
    writer.results.single.complete(locationFixture());
    // The saving spinner keeps animating on purpose until the caller navigates,
    // so settle by a bounded pump instead of waiting for a quiet frame.
    await tester.pump(const Duration(milliseconds: 80));
    expect(created?.id, locationA);
  });

  testWidgets('denial, refusal and conflict say different things', (tester) async {
    Future<void> expectMessage(Object error, String message, {required String reason}) async {
      final writer = _RecordingWriter();
      await tester.pumpWidget(panel(writer: writer));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala');
      await tester.tap(find.byKey(const Key('location-form-save')));
      await tester.pump();
      writer.results.last.completeError(error);
      await tester.pumpAndSettle();
      expect(find.textContaining(message), findsOneWidget, reason: reason);
    }

    await expectMessage(
      const LocationWriteDeniedException(),
      'não tem permissão',
      reason: 'denied',
    );
    await expectMessage(const LocationWriteConflictException(), 'já foi usado', reason: 'conflict');
    await expectMessage(
      const LocationWriteRejectedException(),
      'Revise os dados',
      reason: 'rejected',
    );
    await expectMessage(
      const LocationCatalogWriteUnavailableException(),
      'Não foi possível salvar',
      reason: 'unavailable',
    );
  });

  testWidgets('retrying after a transport failure reuses the same request id', (tester) async {
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala');
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();
    writer.results.last.completeError(const LocationCatalogWriteUnavailableException());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();
    // The same id is what makes the retry idempotent instead of duplicating.
    expect(writer.requestIds, [_requestId, _requestId]);
  });

  testWidgets('a rejected payload starts a new request instead of reusing the id', (tester) async {
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala');
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();
    writer.results.last.completeError(const LocationWriteRejectedException());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-form-name')), 'Sala corrigida');
    await tester.tap(find.byKey(const Key('location-form-save')));
    await tester.pump();
    expect(writer.drafts.last.name, 'Sala corrigida');
    expect(writer.requestIds, hasLength(2));
  });

  testWidgets('without a session the form is denied and cannot save', (tester) async {
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer, sessionAvailable: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-form-denied')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('location-form-save'))).enabled,
      isFalse,
    );
    expect(writer.drafts, isEmpty);
  });

  testWidgets('an external location asks for an address, an internal one does not', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final writer = _RecordingWriter();
    await tester.pumpWidget(panel(writer: writer));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-form-postal-code')), findsNothing);

    // The name is typed first: the address block pushes it out of the viewport.
    await tester.enterText(find.byKey(const Key('location-form-name')), 'Praça');
    final kind = find.byKey(const Key('location-form-kind'));
    await tester.ensureVisible(kind);
    await tester.pumpAndSettle();
    await tester.tap(kind);
    await tester.pumpAndSettle();
    final option = find.text('Externo').hitTestable();
    expect(option, findsWidgets, reason: 'the kind menu must offer Externo');
    await tester.tap(option.last);
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byKey(const Key('location-form-content')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('location-form-postal-code')),
      160,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-form-postal-code')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('location-form-postal-code')), '01001000');
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('location-form-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(writer.drafts.single.kind, LocationKind.external);
    expect(writer.drafts.single.address?['country'], 'Brasil');
    expect(writer.drafts.single.address?['postal_code'], '01001000');
  });

  testWidgets('the catalog page offers creating only to an actor allowed to create', (
    tester,
  ) async {
    final reader = ControlledLocationReader();
    Widget page({required bool canCreate}) => MaterialApp(
      theme: CoeloTheme.light,
      home: LocationsPage(
        scope: scopeA,
        logout: unavailableSuperadminLogout,
        reader: reader,
        sessionAvailable: true,
        canCreate: canCreate,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(page(canCreate: false));
    reader.directories.last.result.complete(locationPage());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locations-create')), findsNothing);

    await tester.pumpWidget(page(canCreate: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locations-create')), findsOneWidget);
    await tester.tap(find.byKey(const Key('locations-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locations-form')), findsOneWidget);
  });

  for (final size in const [Size(375, 812), Size(1440, 900)]) {
    for (final scale in const [1.0, 2.0]) {
      final label = '${size.width.toInt()} ${scale}x';
      testWidgets('the form lays out without overflow at $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final writer = _RecordingWriter();
        await tester.pumpWidget(panel(writer: writer, textScale: scale, size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('location-form-content')), findsOneWidget);
      });
    }
  }
}
