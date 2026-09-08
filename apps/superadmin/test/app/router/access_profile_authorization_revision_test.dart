import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final models in [false, true]) {
    var authorized = true;
    var calls = 0;
    Completer<void>? nextResponseGate;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls++;
        final gate = nextResponseGate;
        nextResponseGate = null;
        final status = authorized || models ? 200 : 403;
        final data = {
          'items': [_record],
          if (!models) ...{'total': 1, 'page': 1, 'page_size': 11},
          if (models) 'next_cursor': null,
        };
        final response = authorized
            ? models
                  ? {'ok': true, 'data': data, 'error': null}
                  : data
            : models
            ? {
                'ok': false,
                'data': null,
                'error': {'code': 'SAI_PERMISSION_DENIED'},
              }
            : {'code': '42501', 'message': 'permission denied'};
        if (gate != null) await gate.future;
        return Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    tearDownAll(client.dispose);

    testWidgets('${models ? "Models" : "Profiles"} discards visible data after context reduction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      authorized = true;
      calls = 0;
      final session = SuperadminSession()..authorize(_fullContext, sessionId: 'nominal-session');
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        accessProfileRepository: SupabaseAccessProfileRepository(client),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go(models ? '/profile-models' : '/profiles');
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Snapshot autorizado anterior'), findsOneWidget);
      expect(calls, 1);
      final previousRevision = session.authorizationInvalidationRevision;
      session.authorize(_fullContext, sessionId: 'nominal-session');
      await tester.pumpAndSettle();
      expect(session.authorizationInvalidationRevision, previousRevision);
      expect(calls, 1);
      expect(find.text('Snapshot autorizado anterior'), findsOneWidget);

      authorized = false;
      final denialGate = Completer<void>();
      nextResponseGate = denialGate;
      session.authorize(_reducedContext, sessionId: 'nominal-session');
      await tester.pump();
      await tester.pump();
      final visibleWhilePending = find.text('Snapshot autorizado anterior').evaluate().isNotEmpty;
      denialGate.complete();
      nextResponseGate = null;
      await tester.pumpAndSettle();

      expect(session.isAuthenticated, isTrue);
      expect(session.authorizationInvalidationRevision, greaterThan(previousRevision));
      expect(
        visibleWhilePending,
        isFalse,
        reason: 'old snapshot must disappear before denial completes',
      );
      expect(calls, 2);
      expect(find.text('Snapshot autorizado anterior'), findsNothing);
      expect(find.byKey(const Key('access-profile-unauthorized')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${models ? "Models" : "Profiles"} rejects a late response from the old context', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      authorized = true;
      calls = 0;
      final oldResponse = Completer<void>();
      nextResponseGate = oldResponse;
      final session = SuperadminSession()..authorize(_fullContext, sessionId: 'nominal-session');
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        accessProfileRepository: SupabaseAccessProfileRepository(client),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go(models ? '/profile-models' : '/profiles');
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pump();
      final initialCalls = calls;

      authorized = false;
      session.authorize(_reducedContext, sessionId: 'nominal-session');
      await tester.pump();
      await tester.pump();
      oldResponse.complete();
      nextResponseGate = null;
      await tester.pumpAndSettle();

      expect(initialCalls, 1);
      expect(find.text('Snapshot autorizado anterior'), findsNothing);
      expect(calls, 2);
      expect(find.byKey(const Key('access-profile-unauthorized')), findsOneWidget);
      expect(session.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

const _fullContext = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'platform.roles.manage', 'platform.role_models.read'},
  aal: 'aal1',
);
const _reducedContext = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.institution,
  scopeInstitutionId: '00000000-0000-4000-8000-000000000001',
  permissionCodes: {'platform.read'},
  aal: 'aal1',
);
const _record = <String, Object?>{
  'id': 'nominal-profile',
  'domain': 'platform',
  'code': 'nominal-profile',
  'name': 'Snapshot autorizado anterior',
  'description': 'Dados sintéticos do contexto anterior.',
  'status': 'active',
  'max_scope_kind': 'platform',
  'version': 1,
  'is_system': false,
  'capabilities': <Object>[],
  'permissions': <Object>[],
};
