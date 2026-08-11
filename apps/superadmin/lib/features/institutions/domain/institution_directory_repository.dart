import 'institution_directory_page.dart';
import 'institution_directory_query.dart';
import 'institution_record.dart';

final class InstitutionDirectoryFilterOption {
  const InstitutionDirectoryFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

final class InstitutionDirectoryFilterOptions {
  const InstitutionDirectoryFilterOptions({
    required this.plans,
    required this.types,
    this.states = const [],
    this.cities = const [],
    this.districts = const [],
  });

  static const empty = InstitutionDirectoryFilterOptions(
    plans: [],
    types: [],
    states: [],
    cities: [],
    districts: [],
  );

  final List<InstitutionDirectoryFilterOption> plans;
  final List<InstitutionDirectoryFilterOption> types;
  final List<InstitutionDirectoryFilterOption> states;
  final List<InstitutionDirectoryFilterOption> cities;
  final List<InstitutionDirectoryFilterOption> districts;
}

abstract interface class InstitutionDirectoryRepository {
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query);
  Future<InstitutionRecord> fetchById(String institutionId);
  Future<InstitutionRecord> create(InstitutionRecord draft);
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion});

  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  });
}

final class InstitutionDirectoryUnauthorizedException implements Exception {
  const InstitutionDirectoryUnauthorizedException();
}

final class InstitutionDirectoryNotFoundException implements Exception {
  const InstitutionDirectoryNotFoundException();
}

final class InstitutionDirectoryConflictException implements Exception {
  const InstitutionDirectoryConflictException();
}

final class InstitutionDirectoryValidationException implements Exception {
  const InstitutionDirectoryValidationException(this.message);
  final String message;
}

final class InstitutionDirectoryUnexpectedException implements Exception {
  const InstitutionDirectoryUnexpectedException(this.message);
  final String message;
}

final class InstitutionDirectoryUnsupportedRelationException implements Exception {
  const InstitutionDirectoryUnsupportedRelationException(this.message);
  final String message;
}

final class InstitutionDirectoryUnavailableException implements Exception {
  const InstitutionDirectoryUnavailableException();
}
