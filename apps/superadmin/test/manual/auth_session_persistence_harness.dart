// Local browser proof only. Never deploy this entrypoint.
// Run on http://127.0.0.1:8921 so the production scope's fixed storage key
// cannot share an origin with the deployed app or another local harness.
// Synthetic HTTP exercises SDK + production scope/storage + normal app routes;
// it does not prove Supabase authentication or server-side revocation.
import 'dart:convert';

import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _email = 'session-proof@example.invalid';
const _password = 'SyntheticProof123!';
const _userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _sessionId = '11111111-1111-4111-8111-111111111111';
const _user = <String, Object?>{
  'id': _userId,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': _email,
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-09-09T00:00:00Z',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb || kReleaseMode || Uri.base.origin != 'http://127.0.0.1:8921') {
    throw StateError('D01 proof requires debug browser origin http://127.0.0.1:8921.');
  }

  final scope = await createSuperadminAuthScope(
    supabaseUrl: 'https://d01-auth.invalid',
    supabasePublishableKey: 'd01-synthetic-publishable-not-a-credential',
    initializeSupabase: ({required url, required publishableKey, required localStorage}) async {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        debug: false,
        httpClient: MockClient(_respond),
        authOptions: FlutterAuthClientOptions(
          localStorage: localStorage,
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );
      return Supabase.instance.client;
    },
  );

  runApp(
    Banner(
      message: 'D01 LOCAL SYNTHETIC',
      location: BannerLocation.topEnd,
      textDirection: TextDirection.ltr,
      layoutDirection: TextDirection.ltr,
      child: SuperadminApp(
        session: scope.session,
        login: scope.login,
        logout: scope.logout,
        requestPasswordRecovery: scope.requestPasswordRecovery,
        resetPassword: scope.resetPassword,
      ),
    ),
  );
}

Future<Response> _respond(Request request) async {
  if (request.url.host != 'd01-auth.invalid') {
    throw StateError('D01 synthetic transport refuses any other host.');
  }
  if (request.method == 'POST' &&
      request.url.path == '/auth/v1/token' &&
      request.url.queryParameters['grant_type'] == 'password') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (body['email'] != _email || body['password'] != _password) {
      return _json(request, {'code': 'invalid_credentials', 'msg': 'Invalid credentials'}, 400);
    }
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${encode({'sub': _userId, 'session_id': _sessionId, 'role': 'authenticated', 'aal': 'aal1', 'exp': expiry})}.'
        'd01-synthetic-signature';
    return _json(request, {
      'access_token': token,
      'refresh_token': 'd01-synthetic-refresh-not-a-credential',
      'expires_in': 3600,
      'expires_at': expiry,
      'token_type': 'bearer',
      'user': _user,
    });
  }

  final authorization = request.headers['Authorization'] ?? request.headers['authorization'];
  if (authorization == null || !authorization.endsWith('.d01-synthetic-signature')) {
    return _json(request, {'code': 'bad_jwt', 'msg': 'Synthetic session required'}, 401);
  }
  if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
    return _json(request, _user);
  }
  if (request.method == 'POST' && request.url.path == '/auth/v1/logout') {
    return _json(request, <String, Object?>{});
  }
  if (request.method == 'POST' &&
      request.url.path == '/rest/v1/rpc/superadmin_auth_bootstrap_context') {
    return _json(request, {
      'ok': true,
      'data': {
        'platform_role_code': 'operations',
        'scope_kind': 'platform',
        'scope_institution_id': null,
        'permission_codes': ['platform.read'],
        'aal': 'aal1',
      },
      'error': null,
    });
  }
  // Includes recovery email, refresh and password changes: no provider fallback.
  throw StateError('D01 synthetic endpoint is not allowed: ${request.method} ${request.url.path}');
}

Response _json(Request request, Object body, [int statusCode = 200]) => Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
  request: request,
);
