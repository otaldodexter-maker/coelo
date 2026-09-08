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
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final creating in [false, true]) {
    for (final transition in ['unchanged', 'route', 'context']) {
      final commands = <Map<String, dynamic>>[];
      var name = 'Contexto A';
      late Completer<void> completion;
      final client = SupabaseClient(
        'https://model-routes.invalid',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final rpc = request.url.path.split('/').last;
          Map<String, Object?> data;
          if (rpc == 'superadmin_access_profile_model_${creating ? "create" : "update"}') {
            commands.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
            // The old successful response is captured before the context changes.
            data = {
              'model': _model('model-a', 'Resposta antiga'),
              'model_id': 'model-a',
              'version': 4,
              'replayed': false,
            };
            await completion.future;
          } else if (rpc == 'superadmin_access_profile_model_detail') {
            final payload = jsonDecode(request.body) as Map;
            data = _model(payload['p_model_id'] as String, name);
          } else if (rpc == 'superadmin_access_permission_catalog' ||
              rpc == 'superadmin_access_profile_models_cursor') {
            data = {'items': <Object>[], 'next_cursor': null};
          } else {
            throw StateError('Unexpected RPC $rpc');
          }
          return Response(
            jsonEncode({'ok': true, 'data': data, 'error': null}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      tearDownAll(client.dispose);

      testWidgets('model ${creating ? "create" : "update"} completion with $transition', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        completion = Completer<void>();
        addTearDown(() {
          if (!completion.isCompleted) completion.complete();
        });
        final session = SuperadminSession()..authorize(_context, sessionId: 'session-a');
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
        final initialPath = creating
            ? '/profile-models/new/platform'
            : '/profile-models/platform/model-a/edit';
        router.go(initialPath);
        await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
          'Rascunho A',
        );
        if (creating) {
          await tester.enterText(find.widgetWithText(CoeloFormTextField, 'Código'), 'modelo.a');
          await tester.enterText(
            find.widgetWithText(CoeloFormTextField, 'Descrição'),
            'Descrição nominal',
          );
        }
        for (var step = 0; step < (creating ? 2 : 3); step++) {
          await tester.tap(find.byKey(const Key('access-profile-continue')));
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.widgetWithText(CoeloFormTextField, 'Motivo da alteração'),
          'Motivo nominal',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('access-profile-save')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(commands, hasLength(1));
        expect(router.routeInformationProvider.value.uri.path, initialPath);
        name = 'Contexto B';
        String expectedPath;
        if (transition == 'route') {
          expectedPath = '/profile-models/platform/model-b/edit';
          router.go(expectedPath);
          await tester.pumpAndSettle();
          expect(find.text('Contexto B'), findsWidgets);
        } else if (transition == 'context') {
          expectedPath = initialPath;
          session.authorize(_context, sessionId: 'session-b');
          await tester.pumpAndSettle();
          if (creating) {
            await tester.enterText(
              find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
              'Rascunho B',
            );
          } else {
            expect(find.text('Contexto B'), findsWidgets);
          }
        } else {
          expectedPath = '/profile-models';
        }
        completion.complete();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, expectedPath);
        expect(commands, hasLength(1));
        expect(find.text('Resposta antiga'), findsNothing);
        if (transition != 'unchanged') {
          expect(find.text('Rascunho A'), findsNothing);
          expect(
            find.text(creating && transition == 'context' ? 'Rascunho B' : 'Contexto B'),
            findsWidgets,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

const _context = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'platform.roles.manage', 'platform.role_models.read'},
  aal: 'aal1',
);
Map<String, Object?> _model(String id, String name) => {
  'id': id,
  'domain': 'platform',
  'application_code': 'superadmin',
  'code': 'modelo.a',
  'name': name,
  'description': 'Descrição nominal',
  'status': 'inactive',
  'max_scope_kind': 'platform',
  'version': 4,
  'is_system': false,
  'capabilities': <Object>[],
};
