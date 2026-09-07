import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/groups/data/supabase_group_detail_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/units/data/supabase_unit_detail_repository.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('unconfigured composition cannot read either structure detail', () async {
    final scope = await createSuperadminAuthScope(supabaseUrl: '', supabasePublishableKey: '');
    addTearDown(scope.session.dispose);
    expect(scope.groupDetailRepository, isA<UnavailableGroupDetailRepository>());
    expect(scope.unitDetailRepository, isA<UnavailableUnitDetailRepository>());
    await expectLater(
      scope.groupDetailRepository.fetchById('id'),
      throwsA(isA<GroupDetailException>()),
    );
    await expectLater(
      scope.unitDetailRepository.fetchById('id'),
      throwsA(isA<UnitDetailException>()),
    );
  });
  test(
    'configured composition adds internal detail without enabling legacy lists or mutations',
    () async {
      late SupabaseClient client;
      final scope = await createSuperadminAuthScope(
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: 'sb_publishable_test',
        initializeSupabase: ({required localStorage, required publishableKey, required url}) async {
          client = SupabaseClient(url, publishableKey);
          return client;
        },
      );
      addTearDown(client.dispose);
      addTearDown(scope.session.dispose);
      expect(scope.groupDetailRepository, isA<SupabaseGroupDetailRepository>());
      expect(scope.unitDetailRepository, isA<SupabaseUnitDetailRepository>());
      expect(scope.groupDirectoryRepository, isA<UnavailableGroupDirectoryRepository>());
      expect(scope.unitDirectoryRepository, isA<UnavailableUnitDirectoryRepository>());
      expect(scope.structureMutationsEnabled, isFalse);
      expect(scope.session.isAuthenticated, isFalse);
    },
  );
}
