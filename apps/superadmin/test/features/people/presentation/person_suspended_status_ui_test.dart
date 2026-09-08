import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart'
    show PersonDirectoryItem, PersonStatus;
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('suspended indicator and filter preserve meaning in ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakePersonDirectoryRepository(
        seed: [
          _person('suspended-person', 'Suspended synthetic', 'suspended'),
          _person('inactive-person', 'Inactive synthetic', 'inactive'),
        ],
      );
      final theme = dark ? CoeloTheme.dark : CoeloTheme.light;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PersonDirectoryPage(
              repository: repository,
              logout: () async => const LogoutResult.success(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(theme: theme, routerConfig: router));
      await tester.pumpAndSettle();
      final indicator = find.byKey(const Key('person-status-suspended-person'));
      final container = tester.widget<Container>(
        find.descendant(of: indicator, matching: find.byType(Container)).first,
      );
      final colors =
          theme.extension<CoeloStatusColors>() ??
          (dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
      expect((container.decoration! as BoxDecoration).color, colors.warningContainer);
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      expect(find.text('Suspensa'), findsOneWidget);
      expect(find.text('Suspender'), findsNothing);
      final filter = tester.widget<CoeloAdminMultiSelectFilter<PersonStatus>>(
        find.descendant(
          of: find.byKey(const Key('people-status-filter')),
          matching: find.byType(CoeloAdminMultiSelectFilter<PersonStatus>),
        ),
      );
      expect(filter.options, contains(PersonStatus.suspended));
      filter.onChanged({PersonStatus.suspended});
      await tester.pumpAndSettle();
      expect(find.text('Suspended synthetic'), findsOneWidget);
      expect(find.text('Inactive synthetic'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

PersonDirectoryItem _person(String id, String name, String status) => PersonDirectoryItem.fromJson({
  'id': id,
  'first_name': 'Synthetic',
  'last_name': 'Person',
  'display_name': name,
  'type': 'adult',
  'status': status,
  'updated_at': '2026-09-07T12:00:00Z',
});
