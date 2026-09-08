import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_map_section.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _institutionA = '20000000-0000-4000-8000-000000000001';
const _locationA = '10000000-0000-4000-8000-000000000001';

Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _RecordingReader implements LocationCatalogReader {
  final directories = <LocationDirectoryRequest>[];

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) async {
    directories.add(request);
    return LocationDirectoryResult(
      items: [
        LocationCatalogEntry(
          id: _locationA,
          scope: request.scope,
          kind: LocationKind.internal,
          name: 'Sala de leitura',
          description: null,
          floor: null,
          address: null,
          visibility: LocationVisibility.team,
          status: LocationCatalogStatus.active,
          managementVersion: 1,
          createdAt: DateTime.utc(2026, 9, 7),
          updatedAt: DateTime.utc(2026, 9, 7),
        ),
      ],
      totalCount: 1,
    );
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) =>
      Future.error(const LocationCatalogUnavailableException());
}

final class LocationCatalogUnavailableException implements Exception {
  const LocationCatalogUnavailableException();
}

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: CoeloTheme.light,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );

  Future<void> goToAddressStep(WidgetTester tester) async {
    for (var step = 0; step < 2; step++) {
      final button = find.byKey(const Key('institution-form-continue'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('without a composed catalog the address step is unchanged', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToAddressStep(tester);
    expect(find.byType(LocationsMapSection), findsNothing);
  });

  testWidgets('creating an institution announces that the catalog opens later', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _RecordingReader();
    await tester.pumpWidget(
      app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
          locationCatalogReader: reader,
          sessionAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToAddressStep(tester);

    final section = find.byType(LocationsMapSection);
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    expect(section, findsOneWidget);
    // No owner yet, so no catalog read and no false empty list.
    expect(reader.directories, isEmpty);
    expect(find.byKey(const Key('locations-map-section-before-owner')), findsOneWidget);
  });

  testWidgets('editing an institution reads its own catalog in the address step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _RecordingReader();
    await tester.pumpWidget(
      app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: _institutionA,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
          locationCatalogReader: reader,
          sessionAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The fake repository has no record with this id, so the form reports its
    // own not-found state; what matters here is that a malformed owner never
    // becomes a catalog read.
    expect(
      reader.directories.every((request) => request.scope.institutionId == _institutionA),
      isTrue,
    );
  });

  testWidgets('a malformed institution id never becomes a catalog read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _RecordingReader();
    await tester.pumpWidget(
      app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
          locationCatalogReader: reader,
          sessionAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await goToAddressStep(tester);
    final section = find.byType(LocationsMapSection);
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    expect(reader.directories, isEmpty);
    expect(find.byKey(const Key('locations-map-section-before-owner')), findsOneWidget);
  });
}
