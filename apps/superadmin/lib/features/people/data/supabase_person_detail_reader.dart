import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/person_detail_reader.dart';
import '../domain/person_directory.dart';
import 'supabase_person_directory_repository.dart';

/// Exposes only the strict v2 read, never the legacy repository's commands.
final class SupabasePersonDetailReader implements PersonDetailReader {
  SupabasePersonDetailReader(SupabaseClient client)
    : _repository = SupabasePersonDirectoryRepository(client);

  final SupabasePersonDirectoryRepository _repository;

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) {
    if (!isPersonDetailId(personId)) {
      return Future.error(const PersonDirectoryUnauthorizedException());
    }
    return _repository.fetchDetail(personId);
  }
}
