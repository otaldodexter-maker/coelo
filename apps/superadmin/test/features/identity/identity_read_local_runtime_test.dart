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
      final isUsers = config.profile == 'Users49';
      if (config.isMembershipRevoked) {
        expect(authContext, isNull);
        await tester.runAsync(() => _verifyMembershipRevoked(client, users, models, isUsers));
        return;
      }
      expect(authContext, isNotNull);
      expect(
        authContext!.scopeKind,
        config.isUsersScoped
            ? SuperadminAuthScopeKind.institution
            : SuperadminAuthScopeKind.platform,
      );
      if (config.isUsersScoped) {
        expect(authContext.scopeInstitutionId, '97000000-0000-4000-8000-000000000001');
      }
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
      final path = isUsers ? SuperadminRoutes.internalUsers : SuperadminRoutes.profileModels;
      final label = isUsers
          ? config.isUsersScoped
                ? 'Caio Almeida'
                : 'Owner Sintético'
          : 'Read nominal platform';
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
        if (config.isUsersScoped) expect(find.text('Bruna Barros'), findsNothing);
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
          if (config.isUsersScoped) {
            expect(page.items.map((item) => item.id).toSet(), {
              '93000000-0000-4000-8000-000000000003',
              '93000000-0000-4000-8000-000000000004',
            });
            expect(page.totalCount, 2);
            expect(await users.fetchById('93000000-0000-4000-8000-000000000004'), isNotNull);
            for (final suffix in ['005', '099']) {
              final id = '93000000-0000-4000-8000-000000000$suffix';
              await _expectBackendCode(client, 'superadmin_internal_user_detail', {
                'p_internal_identity_id': id,
              }, 'SAI_PERMISSION_DENIED');
              await expectLater(
                users.fetchById(id),
                throwsA(
                  isA<PlatformUserRuleException>().having(
                    (error) => error.code,
                    'code',
                    'unauthorized',
                  ),
                ),
              );
            }
          } else {
            expect(page.items.map((item) => item.id).toList(), [
              'e3000000-0000-4000-8000-000000000001',
            ]);
            expect(page.totalCount, 1);
            expect(await users.fetchById('e3000000-0000-4000-8000-000000000001'), isNotNull);
          }
        } else {
          for (final domain in AccessProfileDomain.values) {
            if (config.isDomainDenied && domain == AccessProfileDomain.institution) {
              await _expectBackendCode(client, 'superadmin_access_profile_models_cursor', {
                'p_query': null,
                'p_domain': 'institution',
                'p_status': null,
                'p_scope': null,
                'p_limit': 25,
                'p_after_name': null,
                'p_after_id': null,
              }, 'SAI_PERMISSION_DENIED');
              await _expectBackendCode(client, 'superadmin_access_profile_model_detail', {
                'p_model_id': 'f7000000-0000-4000-8000-000000000002',
              }, 'SAI_PERMISSION_DENIED');
              await expectLater(
                models.fetchModels(AccessProfileModelQuery(domain: domain)),
                throwsA(isA<AccessProfileUnauthorizedException>()),
              );
              continue;
            }
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

Future<void> _expectBackendCode(
  SupabaseClient client,
  String rpc,
  Map<String, dynamic> params,
  String code,
) async {
  final response = await client.rpc<Map<String, dynamic>>(rpc, params: params);
  expect(response['error'], isA<Map<dynamic, dynamic>>());
  expect((response['error'] as Map<dynamic, dynamic>)['code'], code);
  expect(response['items'], isNull);
  expect(response['data'], isNull);
}

Future<void> _verifyMembershipRevoked(
  SupabaseClient client,
  SupabasePlatformUserRepository users,
  SupabaseAccessProfileRepository models,
  bool isUsers,
) async {
  const code = 'SAI_MEMBERSHIP_REVOKED';
  if (isUsers) {
    await _expectBackendCode(client, 'superadmin_internal_users_list', {
      'p_search': null,
      'p_profile_ids': null,
      'p_statuses': null,
      'p_scopes': null,
      'p_page': 1,
      'p_page_size': 11,
    }, code);
    await _expectBackendCode(client, 'superadmin_internal_user_profiles', {}, code);
    for (final suffix in ['004', '099']) {
      await _expectBackendCode(client, 'superadmin_internal_user_detail', {
        'p_internal_identity_id': '93000000-0000-4000-8000-000000000$suffix',
      }, code);
    }
    await expectLater(
      users.fetchPage(PlatformUserQuery()),
      throwsA(
        isA<PlatformUserRuleException>().having((error) => error.code, 'code', 'unauthorized'),
      ),
    );
  } else {
    await _expectBackendCode(client, 'superadmin_access_profile_models_cursor', {
      'p_query': null,
      'p_domain': 'platform',
      'p_status': null,
      'p_scope': null,
      'p_limit': 25,
      'p_after_name': null,
      'p_after_id': null,
    }, code);
    await _expectBackendCode(client, 'superadmin_access_permission_catalog', {}, code);
    for (final suffix in ['001', '099']) {
      await _expectBackendCode(client, 'superadmin_access_profile_model_detail', {
        'p_model_id': 'f7000000-0000-4000-8000-000000000$suffix',
      }, code);
    }
    await expectLater(
      models.fetchModels(const AccessProfileModelQuery(domain: AccessProfileDomain.platform)),
      throwsA(isA<AccessProfileUnauthorizedException>()),
    );
  }
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
