import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/locations/presentation/locations_map_section.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('institution form exposes the catalog from creation and scopes edit', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(_app(_institutionForm(institutions)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Localização e contato').first);
    await tester.pumpAndSettle();

    var section = tester.widget<LocationsMapSection>(find.byType(LocationsMapSection));
    expect(section.ownerKind, LocationOwnerKind.institution);
    expect(section.scope, isNull);
    expect(find.byKey(const Key('locations-map-section-before-owner')), findsOneWidget);

    final institution = institutions.records.first;
    await tester.pumpWidget(_app(_institutionForm(institutions, institutionId: institution.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Localização e contato').first);
    await tester.pumpAndSettle();

    section = tester.widget<LocationsMapSection>(find.byType(LocationsMapSection));
    expect(section.scope, isA<InstitutionLocationScope>());
    expect(section.scope!.institutionId, institution.id);
  });

  testWidgets('unit form exposes an independent catalog and scopes edit', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();
    final units = FakeUnitDirectoryRepository(institutions);

    await tester.pumpWidget(_app(_unitForm(units)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Localização').first);
    await tester.pumpAndSettle();

    var section = tester.widget<LocationsMapSection>(find.byType(LocationsMapSection));
    expect(section.ownerKind, LocationOwnerKind.unit);
    expect(section.scope, isNull);
    expect(find.byKey(const Key('locations-map-section-before-owner')), findsOneWidget);

    final unit = units.records.first;
    await tester.pumpWidget(_app(_unitForm(units, unitId: unit.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Localização').first);
    await tester.pumpAndSettle();

    section = tester.widget<LocationsMapSection>(find.byType(LocationsMapSection));
    expect(section.scope, isA<UnitLocationScope>());
    expect(section.scope!.institutionId, unit.institutionId);
    expect((section.scope! as UnitLocationScope).unitId, unit.id);
  });
}

Widget _institutionForm(FakeInstitutionDirectoryRepository repository, {String? institutionId}) =>
    InstitutionFormPage(
      key: ValueKey(institutionId),
      repository: repository,
      institutionId: institutionId,
      logout: _logout,
      onCancel: () {},
      onSaved: (_) {},
    );

Widget _unitForm(FakeUnitDirectoryRepository repository, {String? unitId}) => UnitFormPage(
  key: ValueKey(unitId),
  repository: repository,
  unitId: unitId,
  logout: _logout,
  onCancel: () {},
  onSaved: (_) {},
);

Widget _app(Widget home) => MaterialApp(theme: CoeloTheme.light, home: home);

Future<LogoutResult> _logout() async => const LogoutResult.success();
