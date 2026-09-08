import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/auth/data/supabase_superadmin_auth_context_gateway.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/platform_users/data/supabase_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/identity/identity_read_local_config.dart';

// PREPARATION ONLY: requires a separately reserved seed and local PostgREST.
// Signed synthetic bearer != real user login. Invalid session != revocation.
void main() {
  testWidgets(
    'nominal identity READ runtime candidate',
    (tester) async {
      final config = IdentityReadLocalConfig(Platform.environment);
      final transport = (await tester.runAsync(() async => _ReadTransport(config)))!;
      var token = config.readerToken;
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          config.origin.toString(),
          config.publicKey,
          accessToken: () async => token,
          httpClient: transport,
        ),
      ))!;
      addTearDown(
        () => tester.runAsync(() async {
          await client.dispose();
          transport.close();
        }),
      );
      final users = SupabasePlatformUserRepository(client);
      final models = SupabaseAccessProfileRepository(client);
      final gateway = SupabaseSuperadminAuthContextGateway(client);
      final authContext = await tester.runAsync(gateway.bootstrap);
      expect(authContext, isNotNull);
      expect(authContext!.scopeKind, SuperadminAuthScopeKind.platform);
      expect(authContext.aal, 'aal1');
      expect(authContext.permissionCodes, contains('platform.read'));
      final session = SuperadminSession()
        ..authorize(authContext, sessionId: config.readerSessionId);
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        platformUserRepository: users,
        accessProfileRepository: models,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final isUsers = config.profile == 'Users49';
      final path = isUsers ? SuperadminRoutes.internalUsers : SuperadminRoutes.profileModels;
      final label = isUsers ? 'Owner Sintético' : 'Read nominal platform';
      final listRpc = isUsers
          ? 'superadmin_internal_users_list'
          : 'superadmin_access_profile_models_cursor';
      router.go(path);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await _waitFor(tester, () => find.text(label).evaluate().isNotEmpty);
      expect(router.routeInformationProvider.value.uri.path, path);
      if (isUsers) {
        final page = tester.widget<PlatformUserDirectoryPage>(
          find.byType(PlatformUserDirectoryPage),
        );
        expect(page.repository, same(users));
        expect(page.onCreate, isNull);
        expect(find.text('Parcial Sintético'), findsNothing);
      } else {
        expect(find.byType(AccessProfileDirectoryPage), findsOneWidget);
      }

      Future<void> reenter() async {
        router.go(SuperadminRoutes.home);
        await _waitFor(
          tester,
          () =>
              find.byType(PlatformUserDirectoryPage).evaluate().isEmpty &&
              find.byType(AccessProfileDirectoryPage).evaluate().isEmpty,
        );
        router.go(path);
      }

      final beforeReload = transport.calls.where((name) => name == listRpc).length;
      await reenter();
      await _waitFor(
        tester,
        () =>
            find.text(label).evaluate().isNotEmpty &&
            transport.calls.where((name) => name == listRpc).length > beforeReload,
      );

      await tester.runAsync(() async {
        if (isUsers) {
          final page = await users.fetchPage(PlatformUserQuery());
          expect(page.items.map((item) => item.id).toList(), [
            'e3000000-0000-4000-8000-000000000001',
          ]);
          expect(page.totalCount, 1);
          expect(await users.fetchById('e3000000-0000-4000-8000-000000000001'), isNotNull);
        } else {
          for (final domain in AccessProfileDomain.values) {
            final page = await models.fetchModels(
              AccessProfileModelQuery(domain: domain, search: 'Read nominal'),
            );
            expect(page.items, hasLength(1));
            expect((await models.fetchModel(page.items.single.id)).id, page.items.single.id);
          }
          expect(await models.fetchPermissionCatalog(), isNotEmpty);
        }
        token = config.invalidSessionToken;
        expect(await gateway.bootstrap(), isNull);
        if (isUsers) {
          await expectLater(
            users.fetchPage(PlatformUserQuery()),
            throwsA(
              isA<PlatformUserRuleException>().having(
                (error) => error.code,
                'code',
                'unauthorized',
              ),
            ),
          );
        } else {
          await expectLater(
            models.fetchModels(const AccessProfileModelQuery(domain: AccessProfileDomain.platform)),
            throwsA(isA<AccessProfileUnauthorizedException>()),
          );
        }
      });
      await reenter();
      await _waitFor(tester, () => find.text('Acesso não autorizado').evaluate().isNotEmpty);
      expect(find.text(label), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    skip: Platform.environment['COELO_IDENTITY_LOCAL_RUNTIME'] != '1',
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('Identity local runtime did not reach the expected state.');
}

final class _ReadTransport extends http.BaseClient {
  _ReadTransport(this.config)
    : _inner = IOClient(HttpOverrides.runWithHttpOverrides(HttpClient.new, _LocalOverrides()));
  final IdentityReadLocalConfig config;
  final http.Client _inner;
  final calls = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    config.validateRequest(request.method, request.url);
    request.followRedirects = false;
    final response = await _inner.send(request).timeout(const Duration(seconds: 10));
    final bytes = await response.stream.toBytes().timeout(const Duration(seconds: 10));
    calls.add(request.url.pathSegments.last);
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => _inner.close();
}

final class _LocalOverrides extends HttpOverrides {}
