import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final authenticated in [false, true]) {
    for (final domain in ['units', 'groups']) {
      for (final width in [800.0, 1440.0]) {
        testWidgets('$domain detail deep-link authenticated=$authenticated width=$width', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final session = SuperadminSession();
          if (authenticated) {
            // This fixture exercises backend denial after the read preflight.
            session.authorize(
              const SuperadminAuthContext(
                platformRoleCode: 'test',
                scopeKind: SuperadminAuthScopeKind.platform,
                permissionCodes: {'platform.read', 'groups.read'},
                aal: 'aal1',
              ),
              sessionId: 'detail-route-test',
            );
          }
          final units = _Units();
          final groups = _Groups();
          final router = createSuperadminRouter(
            session: session,
            login: unavailableSuperadminLogin,
            logout: unavailableSuperadminLogout,
            requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
            onThemeModeChanged: (_) {},
            unitDetailRepository: units,
            groupDetailRepository: groups,
          );
          addTearDown(router.dispose);
          addTearDown(session.dispose);
          router.go('/$domain/11111111-1111-4111-8111-111111111111');
          await tester.pumpWidget(
            MaterialApp.router(theme: CoeloTheme.light, routerConfig: router),
          );
          await tester.pumpAndSettle();
          if (!authenticated) {
            expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
            expect(units.ids, isEmpty);
            expect(groups.ids, isEmpty);
          } else {
            final ids = domain == 'units' ? units.ids : groups.ids;
            expect(ids, ['11111111-1111-4111-8111-111111111111']);
            final entity = domain == 'units' ? 'unit' : 'group';
            expect(find.byKey(Key('$entity-detail-denied')), findsOneWidget);
            expect(find.text('Salvar alterações'), findsNothing);
            session.signOut();
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
            expect(find.byKey(Key('$entity-detail-denied')), findsNothing);
            expect(ids, hasLength(1));
          }
        });
      }
    }
  }
}

class _Units implements UnitDetailRepository {
  final ids = <String>[];
  @override
  Future<UnitDetail> fetchById(String id) async {
    ids.add(id);
    throw const UnitDetailException(UnitDetailFailure.denied);
  }
}

class _Groups implements GroupDetailRepository {
  final ids = <String>[];
  @override
  Future<GroupDetail> fetchById(String id) async {
    ids.add(id);
    throw const GroupDetailException(GroupDetailFailure.denied);
  }
}
