import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/institution_directory_item.dart';
import '../domain/institution_directory_page.dart';
import '../domain/institution_directory_query.dart';
import '../domain/institution_directory_repository.dart';

final class SupabaseInstitutionDirectoryRepository implements InstitutionDirectoryRepository {
  const SupabaseInstitutionDirectoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    try {
      var request = _client.from('institution_directory').select();
      final search = query.search.trim();
      if (search.isNotEmpty) {
        request = request.ilike('search_name', '%${_escapeLike(search)}%');
      }
      if (query.statuses.isNotEmpty) {
        request = request.inFilter(
          'status',
          query.statuses.map((status) => status.databaseValue).toList(growable: false),
        );
      }
      if (query.planId != null) {
        request = request.eq('plan_id', query.planId!);
      }
      if (query.states.isNotEmpty) {
        request = request.inFilter('state', query.states.toList(growable: false));
      }
      if (query.cities.isNotEmpty) {
        request = request.inFilter('city', query.cities.toList(growable: false));
      }
      if (query.districts.isNotEmpty) {
        request = request.inFilter('district', query.districts.toList(growable: false));
      }
      if (query.typeIds.isNotEmpty) {
        request = request.inFilter('institution_type_id', query.typeIds.toList(growable: false));
      }

      final response = await request
          .order(query.sortColumn.databaseColumn, ascending: query.sortAscending)
          .order('id', ascending: true)
          .range(query.offset, query.offset + query.pageSize - 1)
          .count(CountOption.exact);
      final rows = response.data;
      final items = rows
          .map((row) => InstitutionDirectoryItem.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      return InstitutionDirectoryPage(
        items: items,
        totalCount: response.count,
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const InstitutionDirectoryUnauthorizedException();
      }
      rethrow;
    }
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    try {
      final statesRequest = _client.from('institution_directory_locations').select('state');
      var locationsRequest = _client
          .from('institution_directory_locations')
          .select('state, city, district');
      if (states.isNotEmpty) {
        locationsRequest = locationsRequest.inFilter('state', states.toList(growable: false));
      }
      if (cities.isNotEmpty) {
        locationsRequest = locationsRequest.inFilter('city', cities.toList(growable: false));
      }
      final results = await Future.wait<List<dynamic>>([
        _client.from('plans').select('id, name').eq('status', 'active').order('name'),
        _client.from('institution_types').select('id, name').eq('status', 'active').order('name'),
        statesRequest.order('state'),
        locationsRequest.order('city').order('district'),
      ]);
      return InstitutionDirectoryFilterOptions(
        plans: _optionsFromRows(results[0]),
        types: _optionsFromRows(results[1]),
        states: _locationOptionsFromRows(results[2], 'state'),
        cities: states.isEmpty ? const [] : _locationOptionsFromRows(results[3], 'city'),
        districts: cities.isEmpty ? const [] : _locationOptionsFromRows(results[3], 'district'),
      );
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        throw const InstitutionDirectoryUnauthorizedException();
      }
      rethrow;
    }
  }
}

final class UnavailableInstitutionDirectoryRepository implements InstitutionDirectoryRepository {
  const UnavailableInstitutionDirectoryRepository();

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    return Future<InstitutionDirectoryPage>.error(const InstitutionDirectoryUnavailableException());
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    return Future<InstitutionDirectoryFilterOptions>.error(
      const InstitutionDirectoryUnavailableException(),
    );
  }
}

List<InstitutionDirectoryFilterOption> _locationOptionsFromRows(List<dynamic> rows, String key) {
  final values = <String>{};
  for (final rawRow in rows) {
    final row = Map<String, dynamic>.from(rawRow as Map);
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      values.add(value);
    }
  }
  final sorted = values.toList()..sort();
  return sorted
      .map((value) => InstitutionDirectoryFilterOption(id: value, label: value))
      .toList(growable: false);
}

List<InstitutionDirectoryFilterOption> _optionsFromRows(List<dynamic> rows) {
  return rows
      .map((row) => Map<String, dynamic>.from(row as Map))
      .map(
        (row) =>
            InstitutionDirectoryFilterOption(id: row['id'] as String, label: row['name'] as String),
      )
      .toList(growable: false);
}

String _escapeLike(String value) {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}
