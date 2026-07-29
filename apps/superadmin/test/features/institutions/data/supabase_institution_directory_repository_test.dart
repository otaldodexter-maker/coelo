import 'dart:convert';

import 'package:coelo_superadmin/features/institutions/data/supabase_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final pageSize in InstitutionDirectoryQuery.allowedPageSizes) {
    test('requests the exact PostgREST range for page size $pageSize', () async {
      Request? capturedRequest;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return Response(
            jsonEncode(<Map<String, Object?>>[]),
            200,
            headers: {
              'content-range': '${pageSize * 2}-${pageSize * 3 - 1}/0',
              'content-type': 'application/json',
            },
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseInstitutionDirectoryRepository(client);

      final page = await repository.fetchPage(
        InstitutionDirectoryQuery(page: 2, pageSize: pageSize),
      );

      expect(capturedRequest?.url.queryParameters['offset'], '${pageSize * 2}');
      expect(capturedRequest?.url.queryParameters['limit'], '$pageSize');
      expect(page.pageSize, pageSize);
    });
  }

  test('keeps state options unfiltered and cascades distinct location options', () async {
    final capturedUris = <Uri>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedUris.add(request.url);
        final table = request.url.pathSegments.last;
        final locations = [
          {'state': 'SP', 'city': 'Campinas', 'district': 'Centro'},
          {'state': 'SP', 'city': 'Campinas', 'district': 'Centro'},
          {'state': 'PR', 'city': 'Curitiba', 'district': 'Batel'},
        ];
        final body = switch (table) {
          'plans' || 'institution_types' => <Map<String, String>>[],
          'institution_directory_locations' =>
            request.url.queryParameters['select'] == 'state'
                ? locations
                : locations
                      .where(
                        (location) => location['state'] == 'SP' && location['city'] == 'Campinas',
                      )
                      .toList(growable: false),
          _ => <Map<String, String>>[],
        };
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-range': '0-0/1', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    final options = await repository.fetchFilterOptions(states: {'SP'}, cities: {'Campinas'});

    final stateRequest = capturedUris.singleWhere(
      (uri) =>
          uri.pathSegments.last == 'institution_directory_locations' &&
          uri.queryParameters['select'] == 'state',
    );
    final dependentRequest = capturedUris.singleWhere(
      (uri) =>
          uri.pathSegments.last == 'institution_directory_locations' &&
          uri.queryParameters['select'] == 'state,city,district',
    );
    expect(stateRequest.queryParameters['state'], isNull);
    expect(stateRequest.queryParameters['city'], isNull);
    expect(dependentRequest.queryParameters['state'], contains('SP'));
    expect(dependentRequest.queryParameters['city'], contains('Campinas'));
    expect(options.states.map((option) => option.label), ['PR', 'SP']);
    expect(options.cities.map((option) => option.label), ['Campinas']);
    expect(options.districts.map((option) => option.label), ['Centro']);
  });

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

  test('uses allowlisted sort and query page size in PostgREST', () async {
    Request? capturedRequest;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return Response(
          '[]',
          200,
          headers: {'content-range': '*/0', 'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseInstitutionDirectoryRepository(client);

    await repository.fetchPage(
      InstitutionDirectoryQuery(
        page: 1,
        pageSize: 9,
        sortColumn: InstitutionDirectorySortColumn.unitsCount,
        sortAscending: false,
      ),
    );

    final order = capturedRequest!.url.queryParameters['order'];
    expect(order, startsWith('units_count.desc'));
    expect(order, contains('id.asc'));
    expect(capturedRequest!.url.queryParameters['offset'], '9');
    expect(capturedRequest!.url.queryParameters['limit'], '9');
  });
}
