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
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _duplicatePath = '/profile-models/platform/model-a/duplicate';

void main() {
  late _Harness harness;
  setUp(() => harness = _Harness());
  tearDown(() => harness.client.dispose());
  testWidgets('normal model directory opens duplication through its action', (tester) async {
    await harness.open(tester, '/profile-models');
    final action = find.byKey(const Key('access-profile-duplicate-model-a'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(harness.path, _duplicatePath);
    expect(find.text('Modelo A (cópia)'), findsOneWidget);
    expect(harness.commands, isEmpty);
  });

  testWidgets('direct duplication link loads the protected source and cancel returns to models', (
    tester,
  ) async {
    await harness.open(tester, _duplicatePath);
    expect(harness.detailIds, ['model-a']);
    expect(find.text('Modelo A (cópia)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('access-profile-duplicate-cancel')));
    await tester.pumpAndSettle();
    expect(harness.path, '/profile-models');
    expect(harness.commands, isEmpty);
  });

  testWidgets('denied source cannot expose fields or send a duplicate', (tester) async {
    harness.denyDetail = true;
    await harness.open(tester, _duplicatePath);
    expect(harness.detailIds, ['model-a']);
    expect(find.text('Não foi possível abrir o modelo'), findsOneWidget);
    expect(find.text('Modelo A (cópia)'), findsNothing);
    expect(find.byKey(const Key('access-profile-duplicate-submit')), findsNothing);
    expect(harness.commands, isEmpty);
    expect(find.textContaining('private-server-detail'), findsNothing);
  });

  testWidgets('denied duplicate stays on its route and exposes only sanitized feedback', (
    tester,
  ) async {
    harness.denyCommand = true;
    await harness.open(tester, _duplicatePath);
    await _submit(tester);
    await tester.pumpAndSettle();
    expect(harness.path, _duplicatePath);
    expect(harness.commands, hasLength(1));
    expect(find.text('Você não tem permissão para gerenciar perfis.'), findsOneWidget);
    expect(find.textContaining('private-server-detail'), findsNothing);
  });

  for (final transition in ['unchanged', 'session', 'route']) {
    testWidgets('duplicate completion respects $transition context and normal callbacks', (
      tester,
    ) async {
      harness.commandGate = Completer<void>();
      await harness.open(tester, _duplicatePath);
      await _submit(tester);
      expect(harness.commands, hasLength(1));
      final command = harness.commands.single;
      expect((command['p_draft'] as Map)['source_model_id'], 'model-a');
      expect(command['p_request_id'], isNotEmpty);
      harness.name = 'Modelo B';
      var expectedPath = '/profile-models';
      if (transition == 'session') {
        expectedPath = _duplicatePath;
        harness.session.authorize(_context, sessionId: 'session-b');
        await tester.pumpAndSettle();
      } else if (transition == 'route') {
        expectedPath = '/profile-models/platform/model-b/duplicate';
        harness.router.go(expectedPath);
        await tester.pumpAndSettle();
      }
      harness.commandGate!.complete();
      await tester.pumpAndSettle();
      expect(harness.path, expectedPath);
      expect(harness.commands, hasLength(1));
      expect(find.text('Resultado antigo'), findsNothing);
      if (transition != 'unchanged') {
        expect(find.text('Modelo B (cópia)'), findsOneWidget);
        expect(find.text('Modelo A (cópia)'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _submit(WidgetTester tester) async {
  expect(
    find.byKey(const Key('access-profile-duplicate-submit')),
    findsOneWidget,
    reason: 'The normal route must compose the duplication form before testing its command.',
  );
  await tester.enterText(
    find.widgetWithText(CoeloFormTextField, 'Motivo da duplicação'),
    'Motivo sintético',
  );
  await tester.tap(find.byKey(const Key('access-profile-duplicate-submit')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

final class _Harness {
  _Harness() {
    client = SupabaseClient(
      'https://model-routes.invalid',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(_respond),
    );
    session = SuperadminSession()..authorize(_context, sessionId: 'session-a');
    router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      accessProfileRepository: SupabaseAccessProfileRepository(client),
      onThemeModeChanged: (_) {},
    );
  }
  late final SupabaseClient client;
  late final SuperadminSession session;
  late final GoRouter router;
  final detailIds = <String>[];
  final commands = <Map<String, dynamic>>[];
  String name = 'Modelo A';
  bool denyDetail = false;
  bool denyCommand = false;
  Completer<void>? commandGate;
  String get path => router.routeInformationProvider.value.uri.path;

  Future<void> open(WidgetTester tester, String path) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() {
      if (commandGate case final gate? when !gate.isCompleted) gate.complete();
      router.dispose();
      session.dispose();
    });
    addTearDown(() => tester.binding.setSurfaceSize(null));
    router.go(path);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<Response> _respond(Request request) async {
    final rpc = request.url.path.split('/').last;
    Object? data;
    var denied = false;
    switch (rpc) {
      case 'superadmin_access_profile_model_detail':
        final id = (jsonDecode(request.body) as Map)['p_model_id'] as String;
        detailIds.add(id);
        denied = denyDetail;
        data = _model(id, name);
      case 'superadmin_access_profile_models_cursor':
        data = {
          'items': [_model('model-a', name)],
          'next_cursor': null,
        };
      case 'superadmin_access_permission_catalog':
        data = {'items': <Object>[]};
      case 'superadmin_access_profile_model_duplicate':
        commands.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
        data = {
          'model': _model('copy-a', 'Resultado antigo'),
          'model_id': 'copy-a',
          'version': 4,
          'replayed': false,
        };
        denied = denyCommand;
        await commandGate?.future;
      default:
        throw StateError('Unexpected RPC $rpc');
    }
    return Response(
      jsonEncode({
        'ok': !denied,
        'data': denied ? null : data,
        'error': denied
            ? {'code': 'SAI_PERMISSION_DENIED', 'message': 'private-server-detail'}
            : null,
      }),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
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
  'description': 'Modelo sintético',
  'status': 'inactive',
  'max_scope_kind': 'platform',
  'version': 4,
  'is_system': false,
  'capabilities': <Object>[],
};
