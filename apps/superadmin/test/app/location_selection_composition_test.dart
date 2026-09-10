import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/locations/data/supabase_location_consumer_selection_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../features/locations/location_read_fixtures.dart';

const groupId = '40000000-0000-4000-8000-000000000001';

class _Groups implements GroupDetailRepository {
  @override
  Future<GroupDetail> fetchById(String id) async => GroupDetail(
    id: id,
    institutionId: institutionA,
    institutionName: 'Instituição autorizada',
    unitId: unitA,
    unitName: 'Unidade autorizada',
    name: 'Turma autorizada',
    groupType: 'class',
    groupTypeOtherText: null,
    status: 'active',
    inheritAppearance: true,
    inheritAccess: true,
    inheritActivities: true,
    managementVersion: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  for (final enabled in [false, true]) {
    testWidgets('App forwards selection reader with qualified gate $enabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = SuperadminSession()
        ..authorize(
          const SuperadminAuthContext(
            platformRoleCode: 'test',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {'groups.read', 'locations.read'},
            aal: 'aal1',
          ),
          sessionId: 'selection-app-session',
        );
      addTearDown(session.dispose);
      final calls = <String>[];
      Future<Object?> rpc(String name, Map<String, dynamic> params) async {
        calls.add(name);
        expect(params, {'p_group_id': groupId});
        return {
          'ok': true,
          'error': null,
          'data': {'group_id': groupId, 'location': null},
        };
      }

      final reader = enabled
          ? SupabaseLocationConsumerSelectionReader.withRpc(rpc, available: true)
          : SupabaseLocationConsumerSelectionReader.withRpc(rpc);
      await tester.pumpWidget(
        SuperadminApp(
          session: session,
          userPreferencesRepository: InMemoryUserPreferencesRepository(),
          groupDetailRepository: _Groups(),
          locationConsumerSelectionReader: reader,
        ),
      );
      await tester.pumpAndSettle();
      final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      router.go('/groups/$groupId');
      await tester.pumpAndSettle();
      expect(calls, enabled ? ['superadmin_group_location_selection_v2'] : isEmpty);
      expect(
        find.byKey(Key(enabled ? 'consumer-selection-empty' : 'consumer-selection-unavailable')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
