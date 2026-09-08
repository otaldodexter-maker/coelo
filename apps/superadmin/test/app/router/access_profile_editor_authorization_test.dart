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
    for (final editing in [false, true]) {
      for (final loaded in [true, false]) {
        var permitted = true;
        var calls = 0;
        Completer<void>? nextGate;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            calls++;
            final gate = nextGate;
            nextGate = null;
            final status = permitted || models ? 200 : 403;
            final catalog = request.url.path.contains('catalog');
            final data = catalog ? {'items': <Object>[]} : _record;
            final Object response = permitted
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
        testWidgets(
          '${models ? "Models" : "Profiles"} ${editing ? "edit" : "detail"} rejects old data with loaded=$loaded',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1440, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            permitted = true;
            calls = 0;
            final oldResponse = loaded ? null : Completer<void>();
            nextGate = oldResponse;
            final session = SuperadminSession()..authorize(_full, sessionId: 'nominal');
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
            router.go(
              '/${models ? "profile-models" : "profiles"}/platform/model${editing ? "/edit" : ""}',
            );
            await tester.pumpWidget(
              MaterialApp.router(theme: CoeloTheme.light, routerConfig: router),
            );
            if (loaded) {
              await tester.pumpAndSettle();
              expect(find.text('Snapshot anterior'), findsWidgets);
            } else {
              await tester.pump();
              expect(calls, 1);
            }
            final previousCalls = calls;
            session.authorize(_full, sessionId: 'nominal');
            if (loaded) {
              await tester.pumpAndSettle();
            } else {
              await tester.pump();
            }
            expect(calls, previousCalls);
            permitted = false;
            final denial = Completer<void>();
            nextGate = denial;
            session.authorize(_reduced, sessionId: 'nominal');
            await tester.pump();
            await tester.pump();
            final oldVisible = find.text('Snapshot anterior').evaluate().isNotEmpty;
            denial.complete();
            oldResponse?.complete();
            nextGate = null;
            await tester.pumpAndSettle();
            expect(session.isAuthenticated, isTrue);
            expect(oldVisible, isFalse);
            expect(find.text('Snapshot anterior'), findsNothing);
            expect(calls, previousCalls + 1);
            expect(
              find.text(
                editing ? 'Não foi possível abrir o perfil' : 'Não foi possível carregar o perfil',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

const _full = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'platform.roles.manage', 'platform.role_models.read'},
  aal: 'aal1',
);
const _reduced = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read'},
  aal: 'aal1',
);
const _record = <String, Object?>{
  'id': 'model',
  'domain': 'platform',
  'code': 'model',
  'name': 'Snapshot anterior',
  'description': 'Dados sintéticos.',
  'status': 'active',
  'max_scope_kind': 'platform',
  'version': 1,
  'is_system': false,
  'capabilities': <Object>[],
  'permissions': <Object>[],
};
