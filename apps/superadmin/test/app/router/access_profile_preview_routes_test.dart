import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares complete development access profile route families', () {
    expect(SuperadminRoutes.devProfiles, '/dev/profiles');
    expect(SuperadminRoutes.devProfileCreate, '/dev/profiles/new/:domain');
    expect(SuperadminRoutes.devProfileDetail, '/dev/profiles/:domain/:profileId');
    expect(SuperadminRoutes.devProfileEdit, '/dev/profiles/:domain/:profileId/edit');
    expect(SuperadminRoutes.devProfileModels, '/dev/profile-models');
    expect(SuperadminRoutes.devProfileModelCreate, '/dev/profile-models/new/:domain');
    expect(SuperadminRoutes.devProfileModelDetail, '/dev/profile-models/:domain/:modelId');
    expect(SuperadminRoutes.devProfileModelEdit, '/dev/profile-models/:domain/:modelId/edit');
  });

  testWidgets('development profiles and models expose list, create, detail and edit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      allowDevelopmentPreview: true,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final route in <String, String>{
      '/dev/profiles': 'Perfis e permissões',
      '/dev/profiles/new/platform': 'Criar perfil',
      '/dev/profiles/platform/demo-owner': 'Owner',
      '/dev/profiles/platform/demo-owner/edit': 'Editar perfil',
      '/dev/profile-models': 'Perfis e permissões',
      '/dev/profile-models/new/platform': 'Criar modelo de perfil',
      '/dev/profile-models/platform/demo-owner': 'Owner',
      '/dev/profile-models/platform/demo-owner/edit': 'Editar modelo de perfil',
    }.entries) {
      router.go(route.key);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, route.key);
      expect(find.text(route.value), findsWidgets, reason: route.key);
      expect(find.text('503'), findsNothing, reason: route.key);
      expect(find.text('404'), findsNothing, reason: route.key);
    }

    router.go(SuperadminRoutes.devProfiles);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-access-profile-card')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/profiles/new/platform');

    router.go(SuperadminRoutes.devProfiles);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-card-demo-owner')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/dev/profiles/platform/demo-owner/edit',
    );

    router.go(SuperadminRoutes.devProfileModels);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-access-profile-card')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dev/profile-models/new/platform');
  });
}
