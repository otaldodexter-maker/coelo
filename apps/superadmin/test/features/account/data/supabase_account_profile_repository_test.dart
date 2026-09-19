import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/data/supabase_account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> response(int version) => {
  'avatar_contract_version': version,
  'first_name': 'Conta',
  'last_name': 'QA',
  'email': 'qa@invalid.test',
  'mobile_phone': '11999990000',
  'avatar': {'mode': 'initials', 'initials': 'CQ', 'background_color': '#336699'},
  'access': {
    'role': 'Operador',
    'mfa_enabled': false,
    'capabilities': ['Editar turma'],
    'capability_details': [
      {
        'code': 'groups.manage',
        'label': 'Editar turma',
        'module_code': 'structure',
        'module_label': 'Estrutura',
        'scope_kind': 'institution',
        'scope_id': 'qa-school',
        'scope_label': 'Escola QA',
      },
    ],
  },
};

Map<String, Object?> photoResponse(int version) => {
  ...response(version),
  'avatar': {
    'mode': 'photo',
    'asset_id': '8d200000-0000-4000-8000-000000000901',
    'initials': 'CQ',
    'background_color': '#336699',
  },
};

void main() {
  test('negotiates persisted color and resets contract on older account load', () async {
    var version = 2;
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://coelo.test',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode(response(version)),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAccountProfileRepository(client);
    final profile = await repository.load();
    await repository.save(profile);
    expect(requests.last.url.path, endsWith('/superadmin_account_profile_save_v2'));
    expect(jsonDecode(requests.last.body)['p_avatar_background_color'], '#336699');
    version = 1;
    await repository.load();
    await repository.save(profile);
    expect(requests.last.url.path, endsWith('/superadmin_account_profile_save'));
    expect(jsonDecode(requests.last.body), isNot(contains('p_avatar_background_color')));
  });

  Response bytesResponse(Request request) => Response.bytes(
    const [137, 80, 78, 71, 13, 10, 26, 10, 1],
    200,
    request: request,
    headers: {'content-type': 'application/octet-stream'},
  );

  test('projects a finalized private avatar asset as a photo after reload', () async {
    late final MockClient mediaClient;
    mediaClient = MockClient((request) async {
      if (request.url.path.endsWith('/functions/v1/account-media')) {
        expect((jsonDecode(request.body) as Map)['inline'], isTrue);
        return bytesResponse(request);
      }
      return Response(
        jsonEncode(photoResponse(2)),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://coelo.test',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: mediaClient,
    );
    addTearDown(client.dispose);

    final profile = await SupabaseAccountProfileRepository(client).load();

    expect(profile.avatar.mode, AccountAvatarMode.photo);
    expect(profile.avatar.photoAssetId, '8d200000-0000-4000-8000-000000000901');
    expect(profile.avatar.photoBytes, hasLength(9));
  });

  test('uploads a new avatar through the private media gateway before saving', () async {
    final requests = <Request>[];
    late final MockClient mediaClient;
    mediaClient = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/functions/v1/account-media')) {
        if (request.headers['content-type'] == 'application/octet-stream') {
          expect(request.headers['x-coelo-asset-id'], '8d200000-0000-4000-8000-000000000902');
          expect(request.bodyBytes, [1, 2, 3]);
          return Response(
            jsonEncode({'asset_id': '8d200000-0000-4000-8000-000000000902', 'status': 'active'}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['action'] == 'read') return bytesResponse(request);
        return Response(
          jsonEncode(switch (body['action']) {
            'prepare' => {
              'asset_id': '8d200000-0000-4000-8000-000000000902',
              'object_key': 'people/owner/avatar/902/original/object.png',
              'upload_status': 'draft',
            },
            _ => <String, Object?>{},
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/superadmin_account_profile_save_v2')) {
        return Response(
          jsonEncode(photoResponse(2)),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      return Response(jsonEncode(response(2)), 200, request: request);
    });
    final client = SupabaseClient(
      'https://coelo.test',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: mediaClient,
    );
    addTearDown(client.dispose);
    final repository = SupabaseAccountProfileRepository(client);
    await repository.load();
    final profile = AccountProfile.prototype().copyWith(
      avatar: AccountAvatar(
        mode: AccountAvatarMode.photo,
        initials: 'OC',
        backgroundColor: AccountAvatar.defaultBackgroundColor,
        photoBytes: Uint8List.fromList(const [1, 2, 3]),
      ),
    );

    final saved = await repository.save(profile);

    expect(
      requests
          .where((request) => request.url.path.endsWith('/functions/v1/account-media'))
          .map(
            (request) => request.headers['content-type'] == 'application/octet-stream'
                ? 'upload'
                : (jsonDecode(request.body) as Map)['action'],
          ),
      containsAllInOrder(['prepare', 'upload', 'read']),
    );
    expect(saved.avatar.mode, AccountAvatarMode.photo);
    expect(saved.avatar.photoAssetId, '8d200000-0000-4000-8000-000000000901');
  });

  test('removes the previously loaded private avatar before saving initials', () async {
    final actions = <String>[];
    late final MockClient mediaClient;
    mediaClient = MockClient((request) async {
      if (request.url.path.endsWith('/functions/v1/account-media')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        actions.add(body['action'] as String);
        if (body['action'] == 'read') return bytesResponse(request);
        return Response(
          jsonEncode(switch (body['action']) {
            'read' => {
              'asset_id': '8d200000-0000-4000-8000-000000000901',
              'signed_url': 'https://r2.coelo.test/read',
              'expires_in': 120,
            },
            'remove' => {
              'asset_id': '8d200000-0000-4000-8000-000000000901',
              'status': 'revoked',
              'object_key': 'people/owner/avatar/901/original/object.png',
            },
            _ => <String, Object?>{},
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      return Response(
        jsonEncode(
          request.url.path.endsWith('/superadmin_account_profile_get')
              ? photoResponse(2)
              : response(2),
        ),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://coelo.test',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: mediaClient,
    );
    addTearDown(client.dispose);
    final repository = SupabaseAccountProfileRepository(client);
    await repository.load();

    final saved = await repository.save(
      AccountProfile.prototype().copyWith(
        avatar: AccountAvatar(
          mode: AccountAvatarMode.initials,
          initials: 'OC',
          backgroundColor: AccountAvatar.defaultBackgroundColor,
        ),
      ),
    );

    expect(actions, containsAllInOrder(['read', 'remove']));
    expect(saved.avatar.mode, AccountAvatarMode.initials);
    expect(saved.avatar.photoAssetId, isNull);
  });

  testWidgets('access groups and search use returned module and institution', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final profile = await tester.runAsync(() async {
      final client = SupabaseClient(
        'https://coelo.test',
        'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode(response(2)),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      try {
        return await SupabaseAccountProfileRepository(client).load();
      } finally {
        await client.dispose();
      }
    });
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(initial: profile!),
      activities: activities,
    );
    addTearDown(() async {
      controller.dispose();
      activities.dispose();
    });
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estrutura · Escola QA'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('account-access-search')), 'Escola QA');
    await tester.pumpAndSettle();
    expect(find.text('Editar turma'), findsOneWidget);
    expect(find.text('Nenhuma permissão encontrada.'), findsNothing);
  });
}
