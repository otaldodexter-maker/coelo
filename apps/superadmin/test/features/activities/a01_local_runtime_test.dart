import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/activities/data/supabase_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_page.dart';
import 'package:coelo_superadmin/features/auth/data/supabase_superadmin_auth_context_gateway.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/activities/a01_local_runtime_config.dart';

// Candidate only. Requires an independently reserved, seeded A01 base55.
// No SQL, Docker, remote URL, service role, login or personal session here.
void main() {
  testWidgets(
    'A01 real local PostgREST and normal Activities route',
    (tester) async {
      final config = A01LocalRuntimeConfig.fromEnvironment(Platform.environment);
      final transport = (await tester.runAsync(() async => _A01LocalTransport(config.origin)))!;
      var actor = 'reader';
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          config.origin.toString(),
          config.publicKey,
          accessToken: () async => config.tokens[actor],
          httpClient: transport,
        ),
      ))!;
      addTearDown(
        () => tester.runAsync(() async {
          await client.dispose();
          transport.close();
        }),
      );
      final repository = SupabaseActivityDirectoryRepository(client);
      final gateway = SupabaseSuperadminAuthContextGateway(client);
      final context = await tester.runAsync(gateway.bootstrap);
      expect(context, isNotNull, reason: 'Real bootstrap must authorize synthetic reader102.');
      expect(context!.scopeKind, SuperadminAuthScopeKind.institution);
      expect(context.scopeInstitutionId, A01LocalRuntimeConfig.id(10));
      expect(context.permissionCodes, containsAll(['platform.read', 'activities.read']));

      final session = SuperadminSession()
        ..authorize(context, sessionId: A01LocalRuntimeConfig.id(202));
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        activityDirectoryRepository: repository,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      router.go(SuperadminRoutes.activities);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await _waitFor(tester, () => find.text('Robótica Local A').evaluate().isNotEmpty);
      expect(router.routeInformationProvider.value.uri.path, '/activities');
      expect(find.text('Robótica A'), findsWidgets);
      expect(find.text('Robótica B'), findsNothing);
      expect(find.text('Criar atividade'), findsNothing);

      final beforeReload = transport.records.length;
      router.go(SuperadminRoutes.login);
      await _waitFor(
        tester,
        () =>
            router.routeInformationProvider.value.uri.path == SuperadminRoutes.home &&
            find.byType(ActivityDirectoryPage).evaluate().isEmpty,
      );
      router.go(SuperadminRoutes.activities);
      await _waitFor(
        tester,
        () =>
            transport.records
                .skip(beforeReload)
                .any(
                  (record) =>
                      record['rpc'] == 'superadmin_activity_directory_v2' && record['ok'] == true,
                ) &&
            transport.records
                .skip(beforeReload)
                .any(
                  (record) =>
                      record['rpc'] == 'superadmin_activity_filter_options_v2' &&
                      record['ok'] == true,
                ) &&
            find.text('Robótica Local A').evaluate().isNotEmpty,
      );
      expect(find.text('Robótica B'), findsNothing);

      await tester.runAsync(() async {
        final page = await repository.fetchPage(ActivityDirectoryQuery());
        expect(page.items.map((item) => item.id).toSet(), {
          A01LocalRuntimeConfig.id(701),
          A01LocalRuntimeConfig.id(703),
        });
        final options = await repository.fetchFilterOptions();
        expect(options.institutions.map((item) => item.id).toList(), [
          A01LocalRuntimeConfig.id(10),
        ]);
        expect(options.units, hasLength(2));
        expect(options.groups, hasLength(5));
        final crossScope = await repository.fetchPage(
          ActivityDirectoryQuery(institutionIds: {A01LocalRuntimeConfig.id(20)}),
        );
        expect(crossScope.items, isEmpty);
        expect(crossScope.totalCount, 0);
        actor = 'revoked';
        expect(await gateway.bootstrap(), isNull);
        await expectLater(
          repository.fetchPage(ActivityDirectoryQuery()),
          throwsA(isA<ActivityDirectoryUnauthorizedException>()),
        );
        actor = 'denied';
        expect(
          await gateway.bootstrap(),
          isNotNull,
          reason: 'Actor106 must bootstrap but be denied activities.read by backend.',
        );
        await expectLater(
          repository.fetchFilterOptions(),
          throwsA(isA<ActivityDirectoryUnauthorizedException>()),
        );
        actor = 'reader';
      });

      // Keep the authorized shell and change only the real backend token: the
      // directory must deny access on its next read, not trust cached UI context.
      actor = 'revoked';
      router.go(SuperadminRoutes.login);
      await _waitFor(
        tester,
        () =>
            router.routeInformationProvider.value.uri.path == SuperadminRoutes.home &&
            find.byType(ActivityDirectoryPage).evaluate().isEmpty,
      );
      router.go(SuperadminRoutes.activities);
      await _waitFor(tester, () => find.text('Acesso não autorizado').evaluate().isNotEmpty);
      expect(find.text('Robótica A'), findsNothing);
      expect(find.text('Robótica Local A'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        transport.records
            .where((record) => record['rpc'] != 'superadmin_auth_bootstrap_context')
            .every((record) => record['correlation_id'] != null),
        isTrue,
        reason: 'Every Activities response must be correlatable with the independent audit check.',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // Only correlation/action/status metadata. Eng1 verifies audit rows out of
      // band; emitting this report is not itself proof of backend audit.
      // ignore: avoid_print
      print('A01_LOCAL_HTTP_CORRELATIONS ${jsonEncode(transport.records)}');
    },
    skip: Platform.environment['COELO_A01_LOCAL_RUNTIME'] != '1',
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('A01 local UI did not reach the required state within ten seconds.');
}

final class _A01LocalTransport extends http.BaseClient {
  _A01LocalTransport(this.origin)
    : _inner = IOClient(HttpOverrides.runWithHttpOverrides(HttpClient.new, _A01HttpOverrides()));
  final Uri origin;
  final http.Client _inner;
  final records = <Map<String, Object?>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    A01LocalRuntimeConfig.validateReadRequest(origin, uri, request.method);
    request.followRedirects = false;
    final response = await _inner.send(request).timeout(const Duration(seconds: 10));
    final bytes = await response.stream.toBytes().timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map) {
      final data = decoded['data'];
      final error = decoded['error'];
      final correlation =
          decoded['correlation_id'] ??
          (data is Map ? data['correlation_id'] : null) ??
          (error is Map ? error['correlation_id'] : null);
      records.add({
        'rpc': uri.pathSegments.last,
        'http_status': response.statusCode,
        'ok': decoded['ok'] == true,
        'correlation_id': correlation is String && RegExp(r'^[0-9a-f-]{36}$').hasMatch(correlation)
            ? correlation
            : null,
      });
    }
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

final class _A01HttpOverrides extends HttpOverrides {}
