import 'dart:convert';

import 'package:coelo_superadmin/features/notices/data/supabase_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lists notices through the authorized cursor RPC', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(request, {
        'items': [_noticeJson()],
        'next_cursor_occurred_at': '2026-08-11T12:00:00Z',
        'next_cursor_id': '20000000-0000-4000-8000-000000000001',
      });
    });
    addTearDown(client.dispose);

    final page = await SupabaseNoticeRepository(client).fetchPage(
      const NoticeDirectoryQuery(
        search: 'Rotina',
        types: {CommunicationType.notice, CommunicationType.forYou},
        pageSize: 24,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/list_notices_for_superadmin'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_search'], 'Rotina');
    expect(body['p_limit'], 24);
    expect(body['p_types'], ['popup', 'for_you']);
    expect(page.items.single.title, 'Rotina');
    expect(page.nextCursorId, '20000000-0000-4000-8000-000000000001');
    expect(captured!.body, isNot(contains('service_role')));
  });

  test('save sends request id, expected version and structured appearance', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(request, _noticeJson());
    });
    addTearDown(client.dispose);

    await SupabaseNoticeRepository(client).saveDraft(
      NoticeDraft(
        type: CommunicationType.highlight,
        title: 'Rotina',
        message: 'Mensagem',
        priority: NoticePriority.important,
        audience: NoticeAudience.institution,
        audienceLabel: 'Instituições filtradas',
        behavior: NoticeBehavior.confirmation,
        mandatory: true,
        targetDevice: NoticeTargetDevice.all,
        contentFormat: NoticeContentFormat.textBackground,
        buttonColorValue: 0xFFD63C00,
        popupSize: NoticePopupSize.large,
        hasOuterInset: true,
        audienceSelection: const NoticeAudienceSelection(
          rules: [
            NoticeAudienceRule(
              dimension: NoticeAudienceDimension.institution,
              selectAll: true,
              excludedIds: ['30000000-0000-4000-8000-000000000001'],
              filters: {
                'search': ['Centro'],
              },
            ),
          ],
        ),
        buttonLabel: 'Confirmar',
        startsAt: DateTime.utc(2026, 8, 11, 12),
      ),
      requestId: '10000000-0000-4000-8000-000000000001',
      expectedVersion: 7,
    );

    expect(captured!.url.path, endsWith('/rpc/save_notice_draft_for_superadmin'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], '10000000-0000-4000-8000-000000000001');
    expect(body['p_expected_version'], 7);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['type'], 'highlight');
    expect(payload['button_color'], '#D63C00');
    expect(payload['popup_size'], 'standard');
    expect(payload['behavior'], 'dismissible');
    expect(
      ((payload['audience'] as Map<String, dynamic>)['rules'] as List).single,
      containsPair('filters', {
        'search': ['Centro'],
      }),
    );
  });

  test('maps legacy and current communication types from the RPC', () async {
    for (final entry in {
      'popup': CommunicationType.notice,
      'notice': CommunicationType.notice,
      'critical_notice': CommunicationType.notice,
      'content_card': CommunicationType.content,
      'highlight': CommunicationType.highlight,
      'for_you': CommunicationType.forYou,
    }.entries) {
      final client = _client(
        (request) async => _json(request, {..._noticeJson(), 'type': entry.key}),
      );
      final item = await SupabaseNoticeRepository(client).getById('id');
      expect(item.type, entry.value, reason: entry.key);
      client.dispose();
    }
  });

  test('maps forbidden responses without exposing server details', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({'code': '42501', 'message': 'sensitive internal detail'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseNoticeRepository(client).getById('20000000-0000-4000-8000-000000000001'),
      throwsA(isA<NoticeUnauthorizedException>()),
    );
  });
}

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _json(Request request, Object value) => Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _noticeJson() => {
  'id': '20000000-0000-4000-8000-000000000001',
  'title': 'Rotina',
  'body': 'Mensagem',
  'priority': 'important',
  'status': 'draft',
  'starts_at': '2026-08-11T12:00:00Z',
  'audience': {
    'rules': [
      {'dimension': 'platform', 'select_all': true},
    ],
    'role_codes': <String>[],
    'plan_ids': <String>[],
  },
  'audience_label': 'Todos',
  'behavior': 'confirmation',
  'target_device': 'all',
  'content_format': 'text_background',
  'button_color': '#D63C00',
  'popup_size': 'standard',
  'has_outer_inset': true,
  'button_label': 'Confirmar',
  'recurrence': 'one_time',
  'weekly_days': <int>[],
  'management_version': 7,
};
