import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/chat/presentation/screens/superadmin_chat_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('reconstructing App with a context key installs new media dependencies', (
    tester,
  ) async {
    final auth = SuperadminSession()..signInForTesting();
    addTearDown(auth.dispose);
    final firstReader = _Reader();
    final firstMedia = MediaSession();
    Widget app(String key, MediaReader reader, MediaSession media) => SuperadminApp(
      key: ValueKey(key),
      session: auth,
      mediaReader: reader,
      mediaSession: media,
      userPreferencesRepository: InMemoryUserPreferencesRepository(),
    );
    await tester.pumpWidget(app('context-a', firstReader, firstMedia));
    await tester.pumpAndSettle();
    final firstRouter =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    firstRouter.go(SuperadminRoutes.conversations);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SuperadminChatPage>(find.byType(SuperadminChatPage)).mediaReader,
      same(firstReader),
    );
    await firstMedia.invalidate();
    final secondReader = _Reader();
    final secondMedia = MediaSession();
    await tester.pumpWidget(app('context-b', secondReader, secondMedia));
    await tester.pumpAndSettle();
    final nextRouter =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    expect(nextRouter, isNot(same(firstRouter)));
    nextRouter.go(SuperadminRoutes.conversations);
    await tester.pumpAndSettle();
    expect(nextRouter.routeInformationProvider.value.uri.path, SuperadminRoutes.conversations);
    final page = tester.widget<SuperadminChatPage>(find.byType(SuperadminChatPage));
    expect(page.mediaReader, same(secondReader));
    expect(page.mediaSession, same(secondMedia));
    expect(firstReader.requests, 0);
    expect(secondReader.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final supplied in [false, true]) {
    testWidgets('normal chat media dependencies are explicit (supplied=$supplied)', (tester) async {
      final session = SuperadminSession()..signInForTesting();
      final reader = _Reader();
      final media = MediaSession();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        mediaReader: supplied ? reader : null,
        mediaSession: supplied ? media : null,
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      router.go(SuperadminRoutes.conversations);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.conversations);
      final page = tester.widget<SuperadminChatPage>(find.byType(SuperadminChatPage));
      expect(page.mediaReader, supplied ? same(reader) : isNull);
      expect(page.mediaSession, supplied ? same(media) : isNull);
      expect(reader.requests, 0);
    });
  }
}

final class _Reader implements MediaReader {
  int requests = 0;
  @override
  Future<MediaReadResult> read(MediaReadRequest request) async {
    requests++;
    throw StateError('Unexpected prefetch');
  }
}
