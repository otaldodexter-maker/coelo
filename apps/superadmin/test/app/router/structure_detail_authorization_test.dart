import 'dart:async';
import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
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

const _id = '11111111-1111-4111-8111-111111111111';
// These contexts pass the local Group read preflight so existing cases continue
// exercising backend denial and invalidation between authorized contexts.
const _contextA = SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.institution,
  scopeInstitutionId: 'institution-a',
  permissionCodes: {'institution.read', 'groups.read'},
  aal: 'aal2',
);
const _contextB = SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.institution,
  scopeInstitutionId: 'institution-b',
  permissionCodes: {'institution.read', 'groups.read'},
  aal: 'aal2',
);

void main() {
  for (final phase in ['initial-denied', 'loaded-revoked', 'pending-revoked']) {
    testWidgets('group detail read preflight $phase', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const denied = SuperadminAuthContext(
        platformRoleCode: 'operations',
        scopeKind: SuperadminAuthScopeKind.institution,
        scopeInstitutionId: 'institution-a',
        permissionCodes: {'institution.read'},
        aal: 'aal2',
      );
      final session = SuperadminSession()
        ..authorize(phase == 'initial-denied' ? denied : _contextA, sessionId: 'read-preflight');
      final groups = _Groups();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        onThemeModeChanged: (_) {},
        groupDetailRepository: groups,
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go('/groups/$_id');
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pump();
      final originalCalls = phase == 'initial-denied' ? 0 : 1;
      expect(groups.calls, hasLength(originalCalls));
      if (phase == 'loaded-revoked') {
        groups.calls.single.complete(_groupA);
        await tester.pumpAndSettle();
        expect(find.text('Dados do contexto A'), findsOneWidget);
      }
      if (phase != 'initial-denied') {
        session.authorize(denied, sessionId: 'read-preflight');
      }
      await tester.pump();
      expect(groups.calls, hasLength(originalCalls));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('group-detail-denied')), findsOneWidget);
      expect(find.text('Dados do contexto A'), findsNothing);
      await tester.tap(find.byKey(const Key('group-detail-reload')));
      await tester.pumpAndSettle();
      expect(groups.calls, hasLength(originalCalls));
      if (phase == 'pending-revoked') {
        groups.calls.first.complete(_groupA);
        await tester.pumpAndSettle();
        expect(find.text('Dados do contexto A'), findsNothing);
      }
      session.authorize(_contextA, sessionId: 'read-preflight');
      await tester.pump();
      expect(groups.calls, hasLength(originalCalls + 1));
      groups.calls.last.complete(_groupA);
      await tester.pumpAndSettle();
      expect(find.text('Dados do contexto A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final entity in ['unit', 'group']) {
    for (final pendingA in [false, true]) {
      for (final newSession in [false, true]) {
        testWidgets(
          '$entity invalidates A on authorization change pending=$pendingA newSession=$newSession',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(800, 900);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final session = SuperadminSession()..authorize(_contextA, sessionId: 'session-a');
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
            router.go('/${entity}s/$_id');
            await tester.pumpWidget(
              MaterialApp.router(theme: CoeloTheme.light, routerConfig: router),
            );
            await tester.pump();
            int calls() => entity == 'unit' ? units.calls.length : groups.calls.length;
            void completeA() {
              if (entity == 'unit') {
                units.calls.first.complete(_unitA);
              } else {
                groups.calls.first.complete(_groupA);
              }
            }

            expect(calls(), 1);
            if (!pendingA) {
              completeA();
              await tester.pumpAndSettle();
              expect(find.text('Dados do contexto A'), findsOneWidget);
            }
            final revision = session.authorizationInvalidationRevision;
            session.authorize(
              newSession ? _contextA : _contextB,
              sessionId: newSession ? 'session-b' : 'session-a',
            );
            expect(session.isAuthenticated, isTrue);
            expect(session.authorizationInvalidationRevision, greaterThan(revision));
            await tester.pump();
            expect(find.text('Dados do contexto A'), findsNothing);
            expect(calls(), 2);
            expect(find.byKey(Key('$entity-detail-loading')), findsOneWidget);
            if (entity == 'unit') {
              units.calls.last.completeError(const UnitDetailException(UnitDetailFailure.denied));
            } else {
              groups.calls.last.completeError(
                const GroupDetailException(GroupDetailFailure.denied),
              );
            }
            await tester.pumpAndSettle();
            if (pendingA) {
              completeA();
              await tester.pumpAndSettle();
            }
            expect(find.byKey(Key('$entity-detail-denied')), findsOneWidget);
            expect(find.text('Dados do contexto A'), findsNothing);
            expect(router.routeInformationProvider.value.uri.path, '/${entity}s/$_id');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  for (final entity in ['unit', 'group']) {
    for (final pending in [false, true]) {
      for (final recovery in [false, true]) {
        testWidgets('$entity stops reads on logout/recovery pending=$pending recovery=$recovery', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1440, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final authStates = StreamController<CoeloAuthSessionState>(sync: true);
          addTearDown(authStates.close);
          final session = SuperadminSession(authSessionStateChanges: authStates.stream)
            ..authorize(_contextA, sessionId: 'session-a');
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
          router.go('/${entity}s/$_id');
          await tester.pumpWidget(
            MaterialApp.router(theme: CoeloTheme.light, routerConfig: router),
          );
          await tester.pump();
          int calls() => entity == 'unit' ? units.calls.length : groups.calls.length;
          void complete() {
            if (entity == 'unit') {
              units.calls.first.complete(_unitA);
            } else {
              groups.calls.first.complete(_groupA);
            }
          }

          expect(calls(), 1);
          if (!pending) {
            complete();
            await tester.pumpAndSettle();
            expect(find.text('Dados do contexto A'), findsOneWidget);
          }
          if (recovery) {
            authStates.add(const CoeloAuthSessionState.passwordRecovery());
          } else {
            session.signOut();
          }
          await tester.pump();
          expect(find.text('Dados do contexto A'), findsNothing);
          expect(calls(), 1);
          await tester.pumpAndSettle();
          if (pending) {
            complete();
            await tester.pumpAndSettle();
          }
          expect(find.text('Dados do contexto A'), findsNothing);
          expect(calls(), 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

class _Units implements UnitDetailRepository {
  final calls = <Completer<UnitDetail>>[];
  @override
  Future<UnitDetail> fetchById(String id) {
    final value = Completer<UnitDetail>();
    calls.add(value);
    return value.future;
  }
}

class _Groups implements GroupDetailRepository {
  final calls = <Completer<GroupDetail>>[];
  @override
  Future<GroupDetail> fetchById(String id) {
    final value = Completer<GroupDetail>();
    calls.add(value);
    return value.future;
  }
}

final _unitA = UnitDetail(
  id: _id,
  name: 'Dados do contexto A',
  slug: 'unit',
  status: 'active',
  institutionId: 'institution-a',
  institutionName: 'Instituição A',
  institutionType: null,
  unitType: const UnitDetailType(id: 'type', name: 'Escola'),
  address: null,
  contact: null,
  effectivePlan: null,
);
final _groupA = GroupDetail(
  id: _id,
  institutionId: 'institution-a',
  institutionName: 'Instituição A',
  unitId: 'unit',
  unitName: 'Unidade A',
  name: 'Dados do contexto A',
  groupType: 'class',
  groupTypeOtherText: null,
  status: 'active',
  inheritAppearance: false,
  inheritAccess: false,
  inheritActivities: false,
  managementVersion: 1,
  createdAt: DateTime.utc(2026, 9, 7),
  updatedAt: DateTime.utc(2026, 9, 7),
);
