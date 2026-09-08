import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/locations/domain/location_selection_source.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_selection_field.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ControlledSource implements LocationSelectionSource {
  final requests = <LocationSelectionRequest>[];

  @override
  Future<LocationSelectionOptions> fetchOptions(LocationSelectionRequest request) async {
    requests.add(request);
    return LocationSelectionOptions(options: const []);
  }

  @override
  Future<LocationResolvedSnapshot> resolveSnapshot({
    required String id,
    required LocationScope scope,
  }) => Future.error(const LocationSelectionUnavailableException());
}

void main() {
  Widget app({LocationSelectionSource? source}) => MaterialApp(
    theme: CoeloTheme.light,
    home: GroupFormPage(
      repository: FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository()),
      logout: () async => const LogoutResult.success(),
      onCancel: () {},
      onSaved: (_) {},
      locationSelectionSource: source,
      sessionAvailable: source != null,
    ),
  );

  Future<void> goToLinksStep(WidgetTester tester) async {
    final step = find.byKey(const Key('step-v-nculos-e-apar-ncia'));
    expect(step, findsOneWidget);
    await tester.ensureVisible(step);
    await tester.pumpAndSettle();
    await tester.tap(step);
    await tester.pumpAndSettle();
  }

  testWidgets('without a composed source the step renders exactly as before', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await goToLinksStep(tester);
    expect(find.byType(LocationSelectionField), findsNothing);
    expect(find.byKey(const Key('group-location-needs-unit')), findsNothing);
    expect(find.byKey(const Key('group-location-unavailable')), findsNothing);
  });

  testWidgets('a unit without a catalog identifier says so instead of asking for a unit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final source = _ControlledSource();
    await tester.pumpWidget(app(source: source));
    await tester.pumpAndSettle();
    await goToLinksStep(tester);

    final unavailable = find.byKey(const Key('group-location-unavailable'));
    await tester.ensureVisible(unavailable);
    await tester.pumpAndSettle();
    // The local prototype selects a unit whose id is not a catalog identifier.
    // The step must not tell the user to choose a unit that is already chosen,
    // and must not read or show an empty picker.
    expect(unavailable, findsOneWidget);
    expect(find.byKey(const Key('group-location-needs-unit')), findsNothing);
    expect(source.requests, isEmpty);
    expect(find.byType(LocationSelectionField), findsNothing);
  });
}
