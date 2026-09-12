import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coelo_superadmin/core/config/superadmin_media_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/forms/data/form_export_download_resolver.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/forms_media_reader.dart';
import 'package:coelo_superadmin/features/forms/data/forms_anonymous_edit_secret_store.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_media_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = '11111111-1111-4111-8111-111111111111';
const _authContext = SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'forms.read'},
  aal: 'aal1',
);

void main() {
  testWidgets('SuperadminApp forwards live Forms media composition to its stable router', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = SuperadminSession()..signInForTesting();
    final media = SuperadminMediaScope(session: session, downloadGateway: _Downloads());
    final backend = _Backend();
    final reader = FormsMediaReader(gateway: backend);
    await tester.pumpWidget(
      SuperadminApp(session: session, formsMediaScope: media, formsMediaReader: reader),
    );
    await tester.pumpAndSettle();
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    router.go('/forms/media/$_asset');
    await tester.pumpAndSettle();
    expect(backend.envelopes, hasLength(1));
    expect(tester.widget<FormsMediaPage>(find.byType(FormsMediaPage)).session, same(media.current));
    backend.pending.single.complete({'asset_id': _asset, 'state': 'unavailable'});
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    media.dispose();
    session.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal response detail forwards form and response to the contextual reader', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final api = _Api();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      formsApi: api,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go('/forms/form-a/responses/response-a');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(api.contexts, [('form-a', 'response-a')]);
    expect(api.legacyDetailCalls, 0);
    expect(tester.widget<FormsOperationsPage>(find.byType(FormsOperationsPage)).formId, 'form-a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('same router renews file context and resolver on authorization revision', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final downloads = _Downloads();
    final media = SuperadminMediaScope(session: session, downloadGateway: downloads);
    final api = _Api();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      formsApi: api,
      formsMediaScope: media,
    );
    addTearDown(router.dispose);
    addTearDown(media.dispose);
    addTearDown(session.dispose);
    router.go('/forms/form-a/files');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final before = tester.widget<FormsOperationsPage>(find.byType(FormsOperationsPage));
    final oldState = tester.state(find.byType(FormsOperationsPage));
    final lifetime = media.current!;
    expect(before.downloadResolver, same(media.downloadResolver));
    expect(before.openDownloadUrl, isNotNull);
    expect(downloads.calls, 0);
    session.authorize(_authContext, sessionId: '22222222-2222-4222-8222-222222222223');
    await tester.pumpAndSettle();
    final after = tester.widget<FormsOperationsPage>(find.byType(FormsOperationsPage));
    expect(after.key, isNot(before.key));
    expect(tester.state(find.byType(FormsOperationsPage)), isNot(same(oldState)));
    expect(after.downloadResolver, same(media.downloadResolver));
    expect(after.downloadResolver, isNot(same(before.downloadResolver)));
    expect(lifetime.isInvalidated, isTrue);
    expect(api.fileReads, 2);
    expect(downloads.calls, 0, reason: 'reading jobs never downloads implicitly');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forms route dispatches domain asset and survives logout and second login', (
    tester,
  ) async {
    final session = SuperadminSession()..signInForTesting();
    final backend = _Backend();
    final reader = FormsMediaReader(gateway: backend);
    final media = SuperadminMediaScope(session: session, downloadGateway: _Downloads());
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      formsMediaReader: reader,
      formsMediaScope: media,
    );
    addTearDown(router.dispose);
    addTearDown(media.dispose);
    addTearDown(session.dispose);
    router.go('/forms/media/$_asset');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final old = media.current!;
    expect(backend.envelopes, [
      {
        'action': 'read',
        'payload': {'asset_id': _asset, 'rendition': 'preview'},
      },
    ]);
    final page = tester.widget<FormsMediaPage>(find.byType(FormsMediaPage));
    expect(page.reader, same(reader));
    expect(page.session, same(old));
    session.signOut();
    await tester.pumpAndSettle();
    expect(old.isInvalidated, isTrue);
    expect(media.current, isNull);
    backend.pending.first.complete({'asset_id': _asset, 'state': 'unavailable'});
    await tester.pumpAndSettle();
    expect(await media.prepareAuthorization(), isTrue);
    session.authorize(_authContext, sessionId: '22222222-2222-4222-8222-222222222222');
    media.authorizationCommitted();
    await tester.pumpAndSettle();
    router.go('/forms/media/$_asset');
    await tester.pumpAndSettle();
    expect(media.current, isNot(same(old)));
    expect(backend.envelopes, hasLength(2));
    backend.pending.last.complete({'asset_id': _asset, 'state': 'unavailable'});
    await tester.pumpAndSettle();
    expect(tester.widget<FormsMediaPage>(find.byType(FormsMediaPage)).session, same(media.current));
    expect(tester.takeException(), isNull);
  });

  testWidgets('response route receives the current stable anonymous store context', (tester) async {
    final session = SuperadminSession()..signInForTesting();
    final api = _PendingResponseApi();
    final first = _AnonymousStore();
    final second = _AnonymousStore();
    var current = first;
    var providerCalls = 0;
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      formsApi: api,
      formsAnonymousEditSecrets: () {
        providerCalls++;
        return current;
      },
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    router.go('/forms/form-1/occurrences/occurrence-1/respond');
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pump();
    expect(
      tester.widget<FormResponsePage>(find.byType(FormResponsePage)).anonymousEditSecrets,
      same(first),
    );
    expect(providerCalls, greaterThan(0));
    final firstContextCalls = providerCalls;

    current = second;
    session.authorize(_authContext, sessionId: '22222222-2222-4222-8222-222222222222');
    await tester.pump();
    expect(
      tester.widget<FormResponsePage>(find.byType(FormResponsePage)).anonymousEditSecrets,
      same(second),
    );
    expect(providerCalls, greaterThan(firstContextCalls));
    final authorizedCalls = providerCalls;

    session.signOut();
    router.go('/forms/form-1/occurrences/occurrence-1/respond');
    await tester.pumpAndSettle();
    expect(find.byType(FormResponsePage), findsNothing);
    expect(
      providerCalls,
      authorizedCalls,
      reason: 'unauthorized routes must not resolve an account store',
    );
  });
}

final class _AnonymousStore implements FormsAnonymousEditSecretStore {
  @override
  Future<String> loadOrCreate(String occurrenceId) async => 's' * 43;
}

final class _PendingResponseApi implements FormsApi {
  final pending = Completer<FormOccurrenceForResponse>();

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) => pending.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Api implements FormsApi, FormsResponseContextReader {
  final contexts = <(String, String)>[];
  int legacyDetailCalls = 0;
  int fileReads = 0;
  @override
  Future<FormResponseDetail> getResponseDetailInForm(String formId, String responseId) async {
    contexts.add((formId, responseId));
    throw StateError('synthetic unavailable detail');
  }

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) async {
    legacyDetailCalls++;
    throw StateError('legacy reader must remain unused');
  }

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    fileReads++;
    return FormCursorPage(items: const [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Downloads implements FormExportDownloadGateway {
  int calls = 0;
  @override
  Future<Object?> resolve(String jobId) async {
    calls++;
    throw StateError('no implicit download');
  }
}

final class _Backend implements FormsBackendGateway {
  final envelopes = <Map<String, Object?>>[];
  final pending = <Completer<Object?>>[];
  @override
  Future<Object?> media(Map<String, Object?> envelope) {
    envelopes.add(envelope);
    final next = Completer<Object?>();
    pending.add(next);
    return next.future;
  }

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) =>
      throw StateError('media must not call RPC directly');
}
