import 'dart:convert';

import 'package:coelo_superadmin/features/notices/data/supabase_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// B9 principal.for-you: o hub lê pelo leitor do ator (`list_my_principal_for_you`),
// declarando o destino e o vínculo ativo; a audiência é decidida no servidor.
void main() {
  Map<String, Object?> item(String id, String title) => {
    'id': id,
    'type': 'for_you',
    'title': title,
    'body': 'corpo',
    'priority': 'important',
    'status': 'active',
    'starts_at': '2026-09-17T00:00:00Z',
    'ends_at': null,
    'audience': {
      'rules': [
        {
          'dimension': 'institution',
          'select_all': false,
          'target_ids': ['d0c40000-0000-4000-8000-000000000001'],
        },
      ],
    },
    'audience_label': 'QA',
    'behavior': 'dismissible',
    'target_device': 'all',
    'content_format': 'text_background',
    'popup_size': 'standard',
    'has_outer_inset': true,
    'recurrence': 'one_time',
    'image_orientation': 'vertical',
    'management_version': 1,
  };

  test('readForYou calls list_my_principal_for_you with device and membership', () async {
    late Map<String, dynamic> sent;
    late String path;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        path = request.url.path;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return Response(
          jsonEncode({
            'ok': true,
            'data': {
              'items': [item('n-1', 'Primeiro'), item('n-2', 'Segundo')],
            },
            'error': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final reader = SupabaseNoticeRepository(client, targetDevice: 'web') as PrincipalForYouReader;
    final items = await reader.readForYou(membershipId: 'membership-1');
    expect(path, '/rest/v1/rpc/list_my_principal_for_you');
    expect(sent, {'p_target_device': 'web', 'p_membership_id': 'membership-1', 'p_limit': 100});
    expect(items.map((notice) => notice.title), ['Primeiro', 'Segundo']);
    expect(items.first.type, CommunicationType.forYou);
    expect(items.first.status, NoticeStatus.active);
  });

  test('a refused actor surfaces as unauthorized, never as an empty hub', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode({'code': '42501', 'message': 'principal_context_denied'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseNoticeRepository(client, targetDevice: 'web').readForYou(),
      throwsA(isA<NoticeUnauthorizedException>()),
    );
  });
}
