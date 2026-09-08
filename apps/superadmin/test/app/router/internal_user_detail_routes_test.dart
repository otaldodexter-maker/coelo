import 'dart:convert';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/platform_users/data/supabase_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final requests = <Request>[];
  var mode = 'allowed';
  var name = 'Sintético Inicial';
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      final isDetail = path.endsWith('superadmin_internal_user_detail');
      final Object body;
      var status = 200;
      if (isDetail && mode == 'server-denied') {
        body = {
          'ok': false,
          'error': {'code': 'SAI_PERMISSION_DENIED'},
        };
      } else if (isDetail && mode == 'retry') {
        body = {'code': 'XX000', 'message': 'private diagnostic'};
        status = 503;
      } else if (path.endsWith('superadmin_internal_user_profiles')) {
        body = {
          'items': [_profile],
        };
      } else if (path.endsWith('superadmin_internal_users_list')) {
        body = {
          'items': [_record(name)],
          'total': 1,
          'page': 1,
          'page_size': 8,
        };
      } else {
        body = _record(name);
      }
      return Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  // Dispose outside the widget test's fake-async zone (Supabase uses timers).
  tearDownAll(client.dispose);
  for (final scenario in ['allowed', 'capability-denied', 'server-denied', 'retry']) {
    testWidgets('detail route: $scenario', (tester) async {
      mode = scenario;
      name = 'Sintético Inicial';
      requests.clear();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final session = SuperadminSession()
        ..authorize(_context(scenario != 'capability-denied'), sessionId: 'session-a');
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
      router.go('/internal-users/$_id');
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformUserDetailPage), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/internal-users/$_id');
      if (scenario == 'capability-denied') {
        expect(find.text('Acesso não autorizado'), findsOneWidget);
        expect(requests, isEmpty);
      } else if (scenario == 'server-denied') {
        expect(find.text('Acesso não autorizado'), findsOneWidget);
        expect(find.text(name), findsNothing);
      } else {
        if (scenario == 'retry') {
          expect(find.text('Não foi possível carregar o usuário interno'), findsOneWidget);
          expect(find.text('private diagnostic'), findsNothing);
          mode = 'allowed';
          await tester.tap(find.text('Tentar novamente'));
          await tester.pumpAndSettle();
        }
        expect(find.text(name), findsWidgets);
        expect(find.text('Editar'), findsNothing);
        final details = requests.where(
          (r) => r.url.path.endsWith('superadmin_internal_user_detail'),
        );
        expect(jsonDecode(details.last.body)['p_internal_identity_id'], _id);
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.internalUsers);
        await tester.tap(find.text(name).first);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/internal-users/$_id');
        final oldCount = details.length;
        name = 'Sintético Atualizado';
        session.authorize(_context(true), sessionId: 'session-b');
        await tester.pumpAndSettle();
        expect(details.length, oldCount + 1);
        expect(find.text('Sintético Inicial'), findsNothing);
        expect(find.text(name), findsWidgets);
        final requestCount = requests.length;
        session.authorize(_context(false), sessionId: 'session-b');
        await tester.pumpAndSettle();
        expect(find.text('Acesso não autorizado'), findsOneWidget);
        expect(find.text(name), findsNothing);
        expect(requests.length, requestCount);
      }
      session.signOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
      expect(find.byType(PlatformUserDetailPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

SuperadminAuthContext _context(bool canRead) => SuperadminAuthContext(
  platformRoleCode: 'auditor',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', if (canRead) 'platform.member.read'},
  aal: 'aal1',
);

const _id = '30000000-0000-4000-8000-000000000099';
const _profile = {
  'id': 'profile-auditor',
  'code': 'auditor',
  'name': 'Auditor',
  'status': 'active',
  'max_scope_kind': 'platform',
  'permissions': ['platform.member.read'],
};
Map<String, Object?> _record(String name) => {
  'id': _id,
  'version': 1,
  'identity': {
    'id': _id,
    'first_name': name,
    'last_name': '',
    'display_name': name,
    'cpf': '',
    'professional_email': 'synthetic@example.invalid',
    'job_title': 'Teste',
  },
  'credential': {'status': 'active'},
  'memberships': [
    {
      'id': 'membership-test',
      'profile': _profile,
      'status': 'active',
      'scope': 'platform',
      'started_at': '2026-09-01T00:00:00Z',
    },
  ],
  'invitation': {
    'id': 'invitation-test',
    'email': 'synthetic@example.invalid',
    'status': 'accepted',
    'updated_at': '2026-09-01T00:00:00Z',
  },
  'history': [],
};
