import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_read_fixtures.dart';

/// Retry belongs to a failure, not to a refusal.
///
/// The detail offered "Recarregar" in every state but `loading`, which meant it
/// offered it on a denial too. Pressing it put the same question to the same
/// server and got the same refusal back: nothing on screen changed, and the
/// only thing the control communicated was that the actor might be one press
/// away from getting in.
///
/// The directory of this same feature never did that - it draws its retry only
/// for `unavailable`. Two sibling surfaces disagreeing about the same situation
/// is how an operator learns to distrust both, so the detail now follows the
/// directory: on a denial the control is gone.
///
/// Reported by C07 through C06 as a disjunction - absent or disabled - with the
/// remedy deliberately left open. Disabled is the answer, and the reason is a
/// constraint rather than a preference: removing it broke the shared form
/// footer, which asserts at least one continuation action, and on a denial
/// there is no copy and no edit to keep it company. Changing a widget shared
/// with every other form is a larger decision than this defect deserves.
///
/// Every other state keeps it live. `unavailable` is exactly what retry is for.
final class _DenyingReader implements LocationCatalogReader {
  int reads = 0;

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async =>
      throw const LocationCatalogAccessDeniedException();

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async {
    reads += 1;
    throw const LocationCatalogAccessDeniedException();
  }
}

final class _FailingReader implements LocationCatalogReader {
  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async =>
      throw const LocationCatalogUnavailableException();

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async =>
      throw const LocationCatalogUnavailableException();
}

Widget _panel(LocationCatalogReader reader) => MaterialApp(
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

const _reload = Key('location-detail-reload');
const _back = Key('location-detail-back');

void main() {
  testWidgets('a denied detail cannot retry, because retry cannot answer it', (tester) async {
    final reader = _DenyingReader();
    await tester.pumpWidget(_panel(reader));
    await tester.pumpAndSettle();

    // The positive control: the panel rendered and still offers the way out.
    // Without this, the absence below could just mean nothing was built.
    expect(find.byKey(_back), findsOneWidget);
    expect(find.byKey(const Key('location-detail-denied')), findsOneWidget);

    expect(find.byKey(_reload), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(_reload)).onPressed,
      isNull,
      reason: 'a refusal does not change by being asked again',
    );
    expect(reader.reads, 1, reason: 'the denial was read once and never asked again');

    // And it stays that way when pressed: a disabled button must not be a
    // button that merely looks disabled.
    await tester.tap(find.byKey(_reload), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(reader.reads, 1);
  });

  testWidgets('an unavailable detail keeps its retry, which is what retry is for', (tester) async {
    await tester.pumpWidget(_panel(_FailingReader()));
    await tester.pumpAndSettle();

    final reload = find.byKey(_reload);
    expect(reload, findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(_reload)).onPressed,
      isNotNull,
      reason: 'a backend that failed may succeed on the next press; a refusal may not',
    );
  });

  testWidgets('a readable detail keeps its retry too', (tester) async {
    final reader = ControlledLocationReader();
    await tester.pumpWidget(_panel(reader));
    await tester.pump();
    reader.details.single.result.complete(locationFixture());
    await tester.pumpAndSettle();

    expect(find.byKey(_reload), findsOneWidget);
    expect(find.text('Sala de leitura'), findsOneWidget);
  });
}
