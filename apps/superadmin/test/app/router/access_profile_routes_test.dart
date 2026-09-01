import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares only production access profile routes', () {
    expect(SuperadminRoutes.profiles, '/profiles');
    expect(SuperadminRoutes.profileCreate, '/profiles/new/:domain');
    expect(SuperadminRoutes.profileDetail, '/profiles/:domain/:profileId');
    expect(SuperadminRoutes.profileModels, '/profile-models');
    expect(SuperadminRoutes.profiles, isNot(startsWith('/dev/')));
  });

  testWidgets('exposes Profiles as an active navigation destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'profiles',
          onDestinationSelected: (value) => selected = value,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final destination = find.byKey(const Key('superadmin-navigation-profiles'));
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    expect(selected, 'profiles');
  });

  for (final viewport in <({String label, Size size, ThemeData theme})>[
    (label: '375 light', size: const Size(375, 900), theme: CoeloTheme.light),
    (label: '1440 dark', size: const Size(1440, 900), theme: CoeloTheme.dark),
  ]) {
    testWidgets('production profile routes use the injected repository at ${viewport.label}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = SuperadminSession()..signInForTesting();
      final repository = _TrackingAccessProfileRepository();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        accessProfileRepository: repository,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: viewport.theme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );

      for (final path in const [
        '/profiles',
        '/profiles/new/platform',
        '/profiles/platform/profile-id',
        '/profiles/platform/profile-id/edit',
      ]) {
        final callsBefore = repository.calls;
        router.go(path);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, path, reason: path);
        expect(find.text('503'), findsNothing, reason: path);
        expect(tester.takeException(), isNull, reason: path);
        expect(repository.calls, greaterThan(callsBefore), reason: path);
      }
    });
  }

  testWidgets('production model directory composes the injected Supabase-capable contract', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final repository = _TrackingAccessProfileRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      accessProfileRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.profileModels);
    await tester.pumpAndSettle();

    expect(find.text('Modelo Owner'), findsOneWidget);
    expect(find.text('503'), findsNothing);
    expect(repository.modelCalls, 1);
  });
}

final class _TrackingAccessProfileRepository
    implements AccessProfileRepository, AccessProfileModelRepository {
  var calls = 0;
  var modelCalls = 0;

  @override
  bool get isDemo => false;

  Never _unexpectedCall() {
    calls += 1;
    throw StateError('AccessProfileRepository must stay unused while fail-closed.');
  }

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) async => _unexpectedCall();

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async =>
      _unexpectedCall();

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => _unexpectedCall();

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async => _unexpectedCall();

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async => _unexpectedCall();

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async => _unexpectedCall();

  @override
  Future<AccessProfileModelPage> fetchModels(AccessProfileModelQuery query) async {
    modelCalls += 1;
    return const AccessProfileModelPage(items: [_platformModel]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _platformModel = AccessProfileModel(
  id: 'model-owner',
  domain: AccessProfileDomain.platform,
  code: 'model-owner',
  name: 'Modelo Owner',
  description: 'Modelo de acesso total à plataforma.',
  status: AccessProfileStatus.active,
  maxScopeKind: 'platform',
  version: 1,
  isSystem: true,
  capabilities: [],
);
