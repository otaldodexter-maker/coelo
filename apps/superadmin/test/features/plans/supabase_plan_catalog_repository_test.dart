import 'dart:convert';

import 'package:coelo_superadmin/features/plans/data/supabase_plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps list and detail RPC payloads with entitlements and linked institutions', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.pathSegments.last == 'superadmin_plans_list') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'p_search': 'cuidado',
            'p_status': 'active',
            'p_feature': 'agenda',
            'p_page': 2,
            'p_page_size': 8,
          });
          return _response({
            'items': [_plan()],
            'total_items': 9,
            'page': 2,
            'page_size': 8,
          }, request);
        }
        return _response({
          ..._plan(),
          'linked_institutions': [_linkedInstitution()],
        }, request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePlanCatalogRepository(client);

    final page = await repository.list(
      const PlanQuery(
        search: 'cuidado',
        status: PlanStatus.active,
        feature: PlanFeature.agenda,
        page: 2,
        pageSize: 8,
      ),
    );
    final detail = await repository.get('00000000-0000-4000-8000-000000000001');

    expect(page.totalItems, 9);
    expect(page.items.single.features, containsAll({PlanFeature.agenda, PlanFeature.routine}));
    expect(page.items.single.limits.mediaGb, 20);
    expect(detail.linkedInstitutions.single.name, 'Escola Horizonte');
    expect(detail.linkedInstitutions.single.startsAt, DateTime.parse('2026-08-01T00:00:00Z'));
  });

  test('saves with request id, revision, reason and canonical entitlement payload', () async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return _response({..._plan(), 'linked_institutions': const <Object?>[]}, request);
      }),
    );
    addTearDown(client.dispose);

    await SupabasePlanCatalogRepository(client).save(
      PlanSaveCommand(
        requestId: '00000000-0000-4000-8000-000000000123',
        expectedRevision: 7,
        reason: 'Ajuste acordado para ampliar o cuidado da escola.',
        draft: PlanDraft(
          id: '00000000-0000-4000-8000-000000000001',
          name: 'Coelo Cuidado',
          code: 'coelo-cuidado',
          description: 'Apoia escola e terapia ocupacional.',
          status: PlanStatus.active,
          features: {PlanFeature.agenda, PlanFeature.routine},
          limits: const PlanLimits(units: 4, memberships: 800, storageGb: 50, mediaGb: 20),
        ),
      ),
    );

    expect(captured!.url.pathSegments, contains('superadmin_plan_save'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], '00000000-0000-4000-8000-000000000123');
    expect(body['p_plan_id'], '00000000-0000-4000-8000-000000000001');
    expect(body['p_expected_revision'], 7);
    expect(body['p_reason'], contains('cuidado da escola'));
    final entitlements = body['p_payload']['entitlements'] as Map<String, dynamic>;
    expect(entitlements['feature.agenda'], {'enabled': true});
    expect(entitlements['feature.chat'], {'enabled': false});
    expect(entitlements['limit.memberships'], {'value': 800});
  });
}

Map<String, Object?> _plan() => {
  'id': '00000000-0000-4000-8000-000000000001',
  'name': 'Coelo Cuidado',
  'code': 'coelo-cuidado',
  'description': 'Cuidado compartilhado.',
  'status': 'active',
  'revision': 7,
  'used_by_institution_count': 1,
  'entitlements': {
    for (final feature in PlanFeature.values)
      'feature.${feature.name}': {
        'enabled': feature == PlanFeature.agenda || feature == PlanFeature.routine,
      },
    'limit.units': {'value': 4},
    'limit.memberships': {'value': 800},
    'limit.storage_gb': {'value': 50},
    'limit.media_gb': {'value': 20},
  },
};

Map<String, Object?> _linkedInstitution() => {
  'id': '00000000-0000-4000-8000-000000000002',
  'name': 'Escola Horizonte',
  'subscription_status': 'active',
  'starts_at': '2026-08-01T00:00:00Z',
  'units_with_override': 1,
};

Response _response(Object payload, Request request) => Response(
  jsonEncode(payload),
  200,
  headers: const {'content-type': 'application/json'},
  request: request,
);
