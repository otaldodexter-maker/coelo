import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart'
    as domain;
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Institution mutations are closed in production and every other structure
/// family has a test saying so. Instituições did not: the only test touching the
/// flag turns it on, which describes a configuration production never runs.
///
/// That mattered more than a missing assertion. Someone reading the green suite
/// for institutions - a full create wizard, an edit form, save lifecycle tests -
/// would reasonably conclude the screens ship. They do not: the routes render
/// the blocked page and the directory is handed no create or edit callback.
final class _TrackingInstitutionRepository implements InstitutionDirectoryRepository {
  _TrackingInstitutionRepository() : _inner = FakeInstitutionDirectoryRepository();

  final FakeInstitutionDirectoryRepository _inner;
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    calls.add('fetchPage');
    return _inner.fetchPage(query);
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    calls.add('fetchFilterOptions');
    return _inner.fetchFilterOptions(states: states, cities: cities);
  }
}

void main() {
  testWidgets('the production list works while creating and editing fail closed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final repository = _TrackingInstitutionRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.institutions);
    await tester.pumpAndSettle();
    expect(find.byType(InstitutionDirectoryPage), findsOneWidget);
    expect(repository.calls, contains('fetchPage'));

    repository.calls.clear();
    router.go(SuperadminRoutes.institutionCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byType(InstitutionFormPage), findsNothing);
    // A blocked route must not read either: refusing after fetching would still
    // have spent a query on a screen nobody is allowed to see.
    expect(repository.calls, isEmpty);

    repository.calls.clear();
    router.go('/institutions/demo-institution-aurora/edit');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byType(InstitutionFormPage), findsNothing);
    expect(repository.calls, isEmpty);
  });

  testWidgets('the production directory offers no way into a blocked screen', (tester) async {
    // The gate is the last line, not the only one. Leaving a visible control
    // that always lands on a refusal would teach the operator that the product
    // is broken rather than that the capability is not theirs yet.
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    router.go(SuperadminRoutes.institutions);
    await tester.pumpAndSettle();

    final page = tester.widget<InstitutionDirectoryPage>(find.byType(InstitutionDirectoryPage));
    expect(page.onCreate, isNull);
    expect(page.onEdit, isNull);
    expect(find.byKey(const Key('create-institution-card')), findsNothing);
  });
}
