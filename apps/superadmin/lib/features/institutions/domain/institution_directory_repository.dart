import 'institution_directory_page.dart';
import 'institution_directory_query.dart';

final class InstitutionDirectoryFilterOption {
  const InstitutionDirectoryFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

final class InstitutionDirectoryFilterOptions {
  const InstitutionDirectoryFilterOptions({
    required this.plans,
    required this.types,
    this.cities = const [],
    this.districts = const [],
  });

  static const empty = InstitutionDirectoryFilterOptions(
    plans: [],
    types: [],
    cities: [],
    districts: [],
  );

  final List<InstitutionDirectoryFilterOption> plans;
  final List<InstitutionDirectoryFilterOption> types;
  final List<InstitutionDirectoryFilterOption> cities;
  final List<InstitutionDirectoryFilterOption> districts;
}

abstract interface class InstitutionDirectoryRepository {
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query);

  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({String? state, String? city});
}

final class InstitutionDirectoryUnauthorizedException implements Exception {
  const InstitutionDirectoryUnauthorizedException();
}

final class InstitutionDirectoryUnavailableException implements Exception {
  const InstitutionDirectoryUnavailableException();
}
