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
/// A clean run is a negative with value: it means the Importações overflow is
/// an isolated case rather than a pattern.
///
/// WARNING FOR WHOEVER EXTENDS THIS TO DETAIL ROUTES. The error-screen guard
/// below is not enough there. A parameterised route reached with an id that
/// belongs to no record renders the legitimate EMPTY detail: no error path is
/// taken, no exception is thrown, and the probe reports success while having
/// exercised nothing. Widget density does not discriminate either, since the
/// shell alone contributes around 1400. The guard that is missing in that case
/// is about the INPUT, not the output: assert that the identifier came from a
/// row actually present in the listing. Another front hit exactly this and
/// found that sixteen of twenty passing detail probes were empty pages.
void main() {
  const probes = <({String name, String path})>[
    (name: 'Pessoas', path: SuperadminRoutes.devPeople),
    (name: 'Unidades', path: SuperadminRoutes.devUnits),
    (name: 'Turmas', path: SuperadminRoutes.devGroups),
    (name: 'Alunos', path: SuperadminRoutes.devStudents),
    (name: 'Rotina', path: SuperadminRoutes.devDailyRoutine),
    (name: 'Planos de medicação', path: SuperadminRoutes.devHealthMedicationPlans),
    (name: 'Perfis de cuidado', path: SuperadminRoutes.devHealthCareProfiles),
    // Pinned defect, not a passing case: this one DOES overflow with data, by
    // 1069 pixels, at both viewports. It is expected to fail here so the suite
    // stays honest and green. WHEN IT IS FIXED, invert this entry instead of
    // deleting it: move it up with the others and the guard starts protecting
    // the fix.
    (name: 'Importações', path: SuperadminRoutes.devImports),
  ];

  const overflowsWithData = {'Importações'};

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
