import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Four of the eleven people filters reach no server at all.
///
/// Atividade, UF, Municipio and Bairro exist in the query object, in the view
/// model and on the screen. They exist nowhere else: `superadmin_people_list`
/// declares no parameter for them and `superadmin_people_filter_options`
/// returns no options for them.
///
/// Today that is merely useless - the dropdowns come back empty, so nothing can
/// be picked. The trap is what happens if someone fills the options and stops
/// there: a selection would be dropped on the way out and the directory would
/// answer with an unfiltered list. Not an error, not an empty result. Everyone,
/// under a heading that says the list was narrowed to one neighbourhood.
///
/// So the fence stands on both sides at once. Wiring the options without wiring
/// the parameter turns these tests red, and wiring the parameter without the
/// migration turns every listing red at runtime instead - PostgREST refuses a
/// call whose argument names it does not know.
const _migration =
    '../../packages/coelo_database/migrations/'
    '20260729141839_superadmin_people_directory.sql';

/// The declared parameter names of one `create or replace function`.
Set<String> _parameters(String sql, String name) {
  final start = sql.indexOf('create or replace function $name(');
  if (start == -1) {
    throw StateError('the migration no longer declares $name');
  }
  final open = sql.indexOf('(', start);
  // The migration is CRLF, so match the break instead of assuming one.
  final close = RegExp(r'\)\s*returns').firstMatch(sql.substring(open));
  if (close == null) {
    throw StateError('could not find the end of the signature of $name');
  }
  return RegExp(r'\b(p_[a-z_]+)\b')
      .allMatches(sql.substring(open, open + close.start))
      .map((match) => match.group(1)!)
      .toSet();
}

/// Every filter the query object can carry, including the four that go nowhere.
PersonDirectoryQuery _everything() => PersonDirectoryQuery(
  search: 'ana',
  types: const {PersonType.adult},
  statuses: const {PersonStatus.active},
  institutionIds: const {'11111111-1111-4111-8111-111111111111'},
  unitIds: const {'22222222-2222-4222-8222-222222222222'},
  groupIds: const {'33333333-3333-4333-8333-333333333333'},
  activityIds: const {'activity-1'},
  stateCodes: const {'SP'},
  municipalityIds: const {'municipality-1'},
  neighborhoodIds: const {'neighborhood-1'},
  contextualRoles: const {'guardian'},
  authLinks: const {AuthLinkStatus.linked},
);

void main() {
  final sql = File(_migration).readAsStringSync();
  final declared = _parameters(sql, 'public.superadmin_people_list');

  const unreachable = {'activity', 'state', 'municipality', 'neighborhood'};

  Future<Map<String, dynamic>> onTheWire(
    Future<void> Function(SupabasePersonDirectoryRepository repository) call,
    Object response,
  ) async {
    Request? captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        captured = request;
        return Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    try {
      await call(SupabasePersonDirectoryRepository(client));
    } on Object {
      // The response is not what this test is about; the request is.
    }
    // A call with no arguments carries no object; only the listing test reads
    // these keys back.
    final decoded = captured!.body.isEmpty ? null : jsonDecode(captured!.body);
    return decoded is Map ? decoded.cast<String, dynamic>() : <String, dynamic>{};
  }

  test('the listing function was never given these four filters', () {
    for (final missing in unreachable) {
      expect(
        declared.where((parameter) => parameter.contains(missing)),
        isEmpty,
        reason: 'superadmin_people_list now declares a $missing parameter; wire it',
      );
    }
    // The eight it does take, so a rename on either side is caught here too.
    expect(declared, contains('p_institution_ids'));
    expect(declared, contains('p_unit_ids'));
    expect(declared, contains('p_group_ids'));
    expect(declared, contains('p_contextual_roles'));
  });

  test('a query carrying all four sends none of them, and sends nothing extra', () async {
    final params = await onTheWire(
      (repository) => repository.fetchPage(_everything()),
      {'items': <dynamic>[], 'total_count': 0},
    );
    // Exactly the declared signature: no silent extra argument, which
    // PostgREST would reject outright, and no filter left behind by accident.
    expect(params.keys.toSet(), equals(declared));
    for (final missing in unreachable) {
      expect(params.keys.where((key) => key.contains(missing)), isEmpty);
    }
  });

  test('the options for the four come back empty from the real adapter', () async {
    // A generous response: everything the function does return, and nothing it
    // does not. The four lists stay empty because there is no key to read.
    PersonDirectoryFilterOptions? options;
    await onTheWire((repository) async {
      options = await repository.fetchFilterOptions();
    }, {
      'institutions': [
        {'id': '11111111-1111-4111-8111-111111111111', 'label': 'Casa Nuvem'},
      ],
      'units': [
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'label': 'Unidade Centro',
          'institution_id': '11111111-1111-4111-8111-111111111111',
        },
      ],
      'groups': <dynamic>[],
      'roles': [
        {'code': 'guardian', 'label': 'Responsavel'},
      ],
    });

    expect(options, isNotNull);
    expect(options!.institutions, hasLength(1));
    expect(options!.roles, hasLength(1));
    expect(options!.activities, isEmpty);
    expect(options!.states, isEmpty);
    expect(options!.municipalities, isEmpty);
    expect(options!.neighborhoods, isEmpty);
  });

  test('picking only the four still reads as an active filter', () {
    // Recorded, not endorsed. The screen would light up its "filters applied"
    // state and offer to clear them while the list underneath was never
    // narrowed. It cannot happen today because the options are empty; it is the
    // exact shape of the failure if someone fills them.
    final onlyUnreachable = PersonDirectoryQuery(
      activityIds: const {'activity-1'},
      stateCodes: {'SP'},
      municipalityIds: {'municipality-1'},
      neighborhoodIds: {'neighborhood-1'},
    );
    expect(onlyUnreachable.hasActiveFilters, isTrue);
  });
}
