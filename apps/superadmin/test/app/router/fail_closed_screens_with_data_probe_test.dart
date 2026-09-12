import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Probe: are the fail-closed screens green because they work, or because they
/// were never mounted with data?
///
/// Several production compositions wire `Unavailable*` repositories on purpose,
/// in the AUTHORIZED branch of `superadmin_auth_scope`: person identity, group
/// directory, unit directory, imports, student tracking, routine and medication
/// plans. Their screens render an unavailability panel, which lays out in any
/// viewport, so every existing test passes. That green says nothing about how
/// the same page behaves once a repository returns rows.
///
/// The `/dev` routes mount the SAME page classes with development repositories
/// that DO return data, so they are the cheapest faithful way to ask the
/// question. This file walks them at a desktop viewport and reports any layout
/// exception, which is what Flutter raises on a RenderFlex overflow.
///
/// A clean run is a negative with value: none of these pages breaks its layout
/// once it has rows.
///
/// WARNING FOR WHOEVER EXTENDS THIS TO DETAIL ROUTES. The error-screen guard
/// below is not enough there. A parameterised route reached with an id that
/// belongs to no record renders the legitimate EMPTY detail: no error path is
/// taken, no exception is thrown, and the probe reports success while having
/// exercised nothing. Widget density does not discriminate either, since the
/// shell alone contributes around 1400. The guard that is missing in that case
/// is about the INPUT, not the output: assert that the identifier came from a
/// row actually present in the listing.
///
/// An earlier version of this comment attributed a count of empty detail probes
/// to another front. That number could not be substantiated when checked, and
/// the measurement that does exist points the other way: twenty-two
/// parameterised routes walked with ids harvested from the listings themselves,
/// at two viewports, all of them reaching real content. The mechanism above is
/// real and worth guarding against; the count was not, so it is gone. Harvest
/// the ids from the listing and the question does not arise.
void main() {
  const probes = <({String name, String path})>[
    (name: 'Pessoas', path: SuperadminRoutes.devPeople),
    (name: 'Unidades', path: SuperadminRoutes.devUnits),
    (name: 'Turmas', path: SuperadminRoutes.devGroups),
    (name: 'Alunos', path: SuperadminRoutes.devStudents),
    (name: 'Rotina', path: SuperadminRoutes.devDailyRoutine),
    (name: 'Planos de medicação', path: SuperadminRoutes.devHealthMedicationPlans),
    (name: 'Perfis de cuidado', path: SuperadminRoutes.devHealthCareProfiles),
    // Importações overflowed by 1069 pixels with data until the R05 migration
    // to the CoeloAdminDirectory composite (3471321a5); now the guard protects
    // that fix. Pin a new defect here by adding its name to overflowsWithData.
    (name: 'Importações', path: SuperadminRoutes.devImports),
  ];

  const overflowsWithData = <String>{};

  const viewports = <({String label, Size size})>[
    (label: '1440x900', size: Size(1440, 900)),
    (label: '375x812', size: Size(375, 812)),
  ];

  for (final probe in probes) {
    for (final viewport in viewports) {
      testWidgets('${probe.name} lays out with data at ${viewport.label}', (tester) async {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final session = SuperadminSession()..signInForTesting();
        final router = createSuperadminRouter(
          session: session,
          login: unavailableSuperadminLogin,
          logout: unavailableSuperadminLogout,
          requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
          allowDevelopmentPreview: true,
          mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
          onThemeModeChanged: (_) {},
        );
        addTearDown(router.dispose);
        addTearDown(session.dispose);

        router.go(probe.path);
        await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
        await tester.pumpAndSettle();

        // Guard against a vacuous green: if the dev route fell back to the error
        // screen, no content was laid out and "no exception" would prove nothing.
        // This is the same trap the probe exists to expose, one level up.
        expect(
          find.byType(SuperadminErrorScreen),
          findsNothing,
          reason:
              '${probe.name} (${probe.path}) rendered the error screen, so this '
              'probe never exercised the populated layout',
        );

        final exception = tester.takeException();
        if (overflowsWithData.contains(probe.name)) {
          expect(
            exception,
            isNotNull,
            reason:
                '${probe.name} (${probe.path}) is pinned as overflowing with '
                'data. If it no longer does, the defect was fixed: move it out '
                'of overflowsWithData instead of relaxing this expectation.',
          );
          expect('$exception', contains('overflowed'));
        } else {
          expect(
            exception,
            isNull,
            reason:
                '${probe.name} (${probe.path}) reported a layout error once '
                'mounted with data. Its production composition is fail-closed, so '
                'no other test exercises this path and the green elsewhere proves '
                'nothing about it: $exception',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
