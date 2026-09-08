import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_location_map_preview.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

void main() {
  Widget panel(ControlledLocationReader reader) => MaterialApp(
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
  );

  testWidgets('an external location shows its address on the map preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(panel(reader));
    await tester.pump();
    reader.details.last.result.complete(
      locationFixture(
        kind: LocationKind.external,
        address: const {
          'country': 'Brasil',
          'street': 'Rua Sintética',
          'number': '100',
          'district': 'Centro',
          'city': 'Cidade exemplo',
          'state': 'SP',
        },
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToMap(tester);

    final preview = find.byType(SuperadminLocationMapPreview);
    expect(preview, findsOneWidget);
    // The composed address is what the preview is asked to show; asserting the
    // property keeps the check on my composition, not on the shared widget.
    expect(
      tester.widget<SuperadminLocationMapPreview>(preview).address,
      'Rua Sintética, 100, Centro, Cidade exemplo, SP',
    );
  });

  testWidgets('an internal location has no address and therefore no map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(panel(reader));
    await tester.pump();
    reader.details.last.result.complete(locationFixture());
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminLocationMapPreview), findsNothing);
  });

  testWidgets('an external location with empty address parts still renders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = ControlledLocationReader();
    await tester.pumpWidget(panel(reader));
    await tester.pump();
    reader.details.last.result.complete(
      locationFixture(kind: LocationKind.external, address: const {'country': 'Brasil'}),
    );
    await tester.pumpAndSettle();
    await _scrollToMap(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SuperadminLocationMapPreview), findsOneWidget);
    // With nothing to compose, the preview says what is missing instead of
    // showing an empty label.
    expect(find.textContaining('Preencha o endereço'), findsOneWidget);
  });
}

/// The detail scrolls; the map sits after the address block.
Future<void> _scrollToMap(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(SuperadminLocationMapPreview),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('location-detail-content')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}
