import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/people/data/supabase_person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('unconfigured detail reader is unavailable without fabricated data', () async {
    final scope = await createSuperadminAuthScope(supabaseUrl: '', supabasePublishableKey: '');
    addTearDown(scope.session.dispose);
    expect(scope.personDetailReader, isA<UnavailablePersonDetailReader>());
    await expectLater(
      scope.personDetailReader.fetchDetail('id'),
      throwsA(isA<PersonDirectoryUnavailableException>()),
    );
  });
  test('configured scope exposes read only wrapper without authenticating session', () async {
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
    expect(scope.personDetailReader, isA<SupabasePersonDetailReader>());
    expect(scope.personDetailReader, isNot(isA<PersonDirectoryRepository>()));
    expect(scope.session.isAuthenticated, isFalse);
    expect(scope.structureMutationsEnabled, isFalse);
  });
}
