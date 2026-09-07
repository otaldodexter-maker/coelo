import 'dart:convert';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/data/supabase_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final canRead in [true, false]) {
    final paths = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return Response(
          jsonEncode({'items': <Object?>[], 'total': 0, 'page': 1, 'page_size': 8}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    tearDownAll(client.dispose);
    testWidgets('normal directory enforces member.read=$canRead before loading', (tester) async {
      final session = _session(canRead: canRead);
      final repository = SupabasePlatformUserRepository(client);
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        platformUserRepository: repository,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go(SuperadminRoutes.internalUsers);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      final page = tester.widget<PlatformUserDirectoryPage>(find.byType(PlatformUserDirectoryPage));
      expect(page.repository, same(repository));
      expect(
        page.capability,
        canRead ? PlatformUserCapability.auditor : PlatformUserCapability.unauthorized,
      );
      expect(page.onCreate, isNull);
      expect(
        paths,
        canRead
            ? [
                '/rest/v1/rpc/superadmin_internal_user_profiles',
                '/rest/v1/rpc/superadmin_internal_users_list',
              ]
            : isEmpty,
      );

      if (canRead) {
        session.authorize(session.authContext!, sessionId: 'replacement-session');
        await tester.pumpAndSettle();
        final replacementPage = tester.widget<PlatformUserDirectoryPage>(
          find.byType(PlatformUserDirectoryPage),
        );
        expect(replacementPage.key, isNot(page.key));
        expect(paths, hasLength(4));
        session.authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'owner',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {'platform.read'},
            aal: 'aal1',
          ),
          sessionId: 'replacement-session',
        );
        await tester.pumpAndSettle();
        expect(find.text('Acesso não autorizado'), findsOneWidget);
        expect(paths, hasLength(4));
      }
      session.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(PlatformUserDirectoryPage), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
    });
  }

  for (final useDemo in [false, true]) {
    testWidgets('normal directory rejects ${useDemo ? "demo" : "missing"} composition', (
      tester,
    ) async {
      final session = _session(canRead: true);
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        platformUserRepository: useDemo ? FakePlatformUserRepository() : null,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go(SuperadminRoutes.internalUsers);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('503'), findsOneWidget);
      expect(find.byType(PlatformUserDirectoryPage), findsNothing);
    });
  }
}

SuperadminSession _session({required bool canRead}) => SuperadminSession()
  ..authorize(
    SuperadminAuthContext(
      platformRoleCode: 'owner',
      scopeKind: SuperadminAuthScopeKind.platform,
      permissionCodes: {'platform.read', if (canRead) 'platform.member.read'},
      aal: 'aal1',
    ),
    sessionId: '00000000-0000-4000-8000-000000000001',
  );
