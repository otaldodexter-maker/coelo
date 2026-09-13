import 'dart:convert';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/data/supabase_account_profile_repository.dart';
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
