import 'dart:convert';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/invites/data/supabase_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '50000000-0000-4000-8000-000000000001';

void main() {
  final requests = <Request>[];
  var scenario = 'allowed';
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      final command = request.url.path.endsWith('superadmin_invite_resend_v2');
      final denied = scenario == 'read-denied' || (scenario == 'command-denied' && command);
      return Response(
        jsonEncode(
          denied
              ? {
                  'ok': false,
                  'data': null,
                  'error': {'code': 'SAI_PERMISSION_DENIED'},
                }
              : {
                  'ok': true,
                  'data': command ? {'invite': _invite, 'replayed': false, 'link': null} : _invite,
                  'error': null,
                },
        ),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  tearDownAll(client.dispose);

  for (final mode in ['allowed', 'read-denied', 'command-denied', 'unavailable', 'signed-out']) {
    testWidgets('normal invite detail commands: $mode', (tester) async {
      scenario = mode;
      requests.clear();
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = SuperadminSession();
      if (mode != 'signed-out') {
        session.authorize(
          SuperadminAuthContext(
            platformRoleCode: mode == 'read-denied' ? 'auditor' : 'owner',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {
              'platform.read',
              'platform.invites.read',
              if (mode != 'command-denied') 'platform.invites.manage',
            },
            aal: 'aal1',
          ),
          sessionId: '00000000-0000-4000-8000-000000000001',
        );
      }
      final repository = mode == 'unavailable'
          ? const UnavailableInviteRepository()
          : SupabaseInviteRepository(client);
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        inviteRepository: repository,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go('/invites/$_id');
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      if (mode == 'signed-out') {
        expect(find.byType(InviteDetailPage), findsNothing);
        expect(requests, isEmpty);
      } else {
        final page = tester.widget<InviteDetailPage>(find.byType(InviteDetailPage));
        expect(identical(page.repository, repository), isTrue);
        expect(page.allowCommands, mode != 'unavailable');
        expect(router.routeInformationProvider.value.uri.path, '/invites/$_id');
        if (mode == 'read-denied' || mode == 'unavailable') {
          expect(find.byKey(const Key('invite-detail-resend')), findsNothing);
          expect(find.byKey(const Key('invite-detail-revoke')), findsNothing);
          if (mode == 'read-denied') expect(find.text('Acesso não autorizado'), findsOneWidget);
          if (mode == 'unavailable') expect(requests, isEmpty);
        } else {
          expect(find.byKey(const Key('invite-detail-resend')), findsOneWidget);
          expect(find.byKey(const Key('invite-detail-revoke')), findsOneWidget);
          await tester.tap(find.byKey(const Key('invite-detail-resend')));
          await tester.pumpAndSettle();
          final commands = requests.where(
            (r) => r.url.path.endsWith('superadmin_invite_resend_v2'),
          );
          expect(commands, hasLength(1));
          expect(jsonDecode(commands.single.body), containsPair('p_invite_id', _id));
          expect(jsonDecode(commands.single.body), containsPair('p_expected_version', 4));
          if (mode == 'command-denied') {
            expect(find.text('Acesso não autorizado'), findsOneWidget);
            expect(find.byKey(const Key('invite-detail-resend')), findsNothing);
          }
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

const _invite = <String, Object?>{
  'id': _id,
  'scope_kind': 'institution',
  'institution_id': '10000000-0000-4000-8000-000000000001',
  'unit_id': null,
  'group_id': null,
  'scope_label': 'Instituição sintética',
  'profile_id': '30000000-0000-4000-8000-000000000001',
  'profile_label': 'Responsável',
  'recipient_label': null,
  'recipient_masked': 's***@invalid.test',
  'channels': ['email', 'link'],
  'status': 'pending',
  'issuer': {'kind': 'superadmin_internal', 'display': 'Usuário interno'},
  'created_at': '2020-01-01T12:00:00Z',
  'expires_at': '2020-01-03T12:00:00Z',
  'accepted_at': null,
  'revoked_at': null,
  'email_delivery_status': 'not_requested',
  'management_version': 4,
  'timeline': [],
};
