import 'dart:convert';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
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
  for (final scenario in ['allowed', 'missing-create', 'institution-scope', 'invalid-domain']) {
    final calls = <String>[];
    final commands = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://d04-model.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final rpc = request.url.path.split('/').last;
        calls.add(rpc);
        final Object data;
        if (rpc == 'superadmin_access_profile_model_detail') {
          data = _model(_source);
        } else if (rpc == 'superadmin_access_profile_model_duplicate') {
          commands.add(jsonDecode(request.body) as Map<String, dynamic>);
          data = {'model': _model(_copy), 'model_id': _copy, 'version': 1, 'replayed': false};
        } else if (rpc == 'superadmin_access_permission_catalog') {
          data = {'items': <Object>[]};
        } else if (rpc == 'superadmin_access_profile_models_cursor') {
          data = {
            'items': [_model(_source)],
            'next_cursor': null,
          };
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
    testWidgets('normal model duplicate route $scenario', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = SuperadminSession()
        ..authorize(
          SuperadminAuthContext(
            platformRoleCode: 'owner',
            scopeKind: scenario == 'institution-scope'
                ? SuperadminAuthScopeKind.institution
                : SuperadminAuthScopeKind.platform,
            permissionCodes: {
              'platform.read',
              'platform.role_models.read',
              if (scenario != 'missing-create') 'platform.role_models.create',
            },
            aal: 'aal1',
          ),
          sessionId: 'd04-session',
        );
      addTearDown(session.dispose);
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        accessProfileRepository: SupabaseAccessProfileRepository(client),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      final allowed = scenario == 'allowed';
      router.go(
        allowed
            ? '/profile-models'
            : '/profile-models/${scenario == 'invalid-domain' ? 'unknown' : 'platform'}/$_source/duplicate',
      );
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      if (!allowed) {
        expect(find.byKey(const Key('access-model-duplicate-forbidden')), findsOneWidget);
        expect(calls, isEmpty);
        return;
      }
      final directory = tester.widget<AccessProfileDirectoryPage>(
        find.byType(AccessProfileDirectoryPage),
      );
      expect(directory.onDuplicate, isNotNull);
      directory.onDuplicate!(AccessProfileDomain.platform, _source);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/profile-models/platform/$_source/duplicate',
      );
      await tester.enterText(
        find.widgetWithText(CoeloFormTextField, 'Motivo da duplicação'),
        'Revisão nominal D04',
      );
      await tester.tap(find.byKey(const Key('access-profile-duplicate-submit')));
      await tester.pumpAndSettle();
      expect(
        calls.where((rpc) => rpc == 'superadmin_access_profile_model_duplicate'),
        hasLength(1),
      );
      expect(router.routeInformationProvider.value.uri.path, '/profile-models');
      expect(commands.single['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      final draft = commands.single['p_draft'] as Map<String, dynamic>;
      expect(draft['source_model_id'], _source);
      expect(draft['reason'], 'Revisão nominal D04');
      expect(draft['status'], 'inactive');
      expect(
        calls.where((rpc) => rpc == 'superadmin_access_profile_models_cursor').length,
        greaterThanOrEqualTo(2),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

const _source = 'd4040000-0000-4000-8000-000000000001';
const _copy = 'd4040000-0000-4000-8000-000000000002';
Map<String, Object?> _model(String id) => {
  'id': id,
  'domain': 'platform',
  'application_code': 'superadmin',
  'code': 'd04.model',
  'name': 'Modelo sintético',
  'description': 'Descrição nominal',
  'status': 'inactive',
  'max_scope_kind': 'platform',
  'version': 1,
  'is_system': false,
  'capabilities': <Object>[],
};
