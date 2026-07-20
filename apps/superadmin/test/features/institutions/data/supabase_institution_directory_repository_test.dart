import 'dart:convert';

import 'package:coelo_superadmin/features/institutions/data/supabase_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sends multiselect filters as PostgREST IN clauses', () async {
    Uri? capturedUri;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedUri = request.url;
        return Response(
          jsonEncode([
            {
              'id': 'institution-1',
              'public_name': 'Instituição Aurora',
              'status': 'active',
              'units_count': 1,
              'groups_count': 2,
            },
          ]),
          200,
          headers: {'content-range': '0-0/1', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await repository.fetchPage(
      InstitutionDirectoryQuery(
        statuses: {InstitutionStatus.active, InstitutionStatus.onboarding},
        typeIds: {'school', 'therapy'},
        states: {'SP', 'PR'},
        cities: {'Campinas', 'Curitiba'},
        districts: {'Cambuí', 'Batel'},
      ),
    );

    final parameters = capturedUri!.queryParameters;
    expect(
      parameters['status'],
      allOf(startsWith('in.('), contains('active'), contains('onboarding')),
    );
    expect(
      parameters['institution_type_id'],
      allOf(startsWith('in.('), contains('school'), contains('therapy')),
    );
    expect(parameters['state'], allOf(startsWith('in.('), contains('SP'), contains('PR')));
    expect(
      parameters['city'],
      allOf(startsWith('in.('), contains('Campinas'), contains('Curitiba')),
    );
    expect(
      parameters['district'],
      allOf(startsWith('in.('), contains('Cambuí'), contains('Batel')),
    );
  });
}
