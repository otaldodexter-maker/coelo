import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_map_section.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingReader implements LocationCatalogReader {
  final directories = <LocationDirectoryRequest>[];

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async {
    directories.add(request);
    return LocationDirectoryResult(items: const [], totalCount: 0);
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) =>
      Future.error(const LocationCatalogAccessDeniedException());
}

void main() {
  Widget app({LocationCatalogReader? reader, String? unitId}) => MaterialApp(
    theme: CoeloTheme.light,
    home: UnitFormPage(
      repository: FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
      unitId: unitId,
      logout: () async => const LogoutResult.success(),
      onCancel: () {},
      onSaved: (_) {},
      locationCatalogReader: reader,
      sessionAvailable: reader != null,
    ),
  );

  /// Jumps straight to Localização through the step rail.
  ///
  /// Advancing with Continuar validates the profile step first, which is a
  /// different behaviour and is covered by the form's own tests.
  Future<void> goToLocationStep(WidgetTester tester) async {
    final step = find.byKey(const Key('step-localiza-o'));
    expect(step, findsOneWidget);
    await tester.ensureVisible(step);
    await tester.pumpAndSettle();
    await tester.tap(step);
    await tester.pumpAndSettle();
  }

  testWidgets('without a composed catalog the location step is unchanged', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await goToLocationStep(tester);
    expect(find.byType(LocationsMapSection), findsNothing);
  });

  testWidgets('creating a unit says the catalog is independent and opens later', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _RecordingReader();
    await tester.pumpWidget(app(reader: reader));
    await tester.pumpAndSettle();
    await goToLocationStep(tester);

    final section = find.byType(LocationsMapSection);
    expect(section, findsOneWidget);
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    expect(reader.directories, isEmpty);
    expect(find.byKey(const Key('locations-map-section-before-owner')), findsOneWidget);
    expect(find.textContaining('independente do catálogo da instituição'), findsOneWidget);
  });
}
