import 'person_directory.dart';

/// Read-only boundary. No legacy list, options or write capability is exposed.
abstract interface class PersonDetailReader {
  Future<PersonDirectoryItem> fetchDetail(String personId);
}

final class UnavailablePersonDetailReader implements PersonDetailReader {
  const UnavailablePersonDetailReader();

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) async =>
      throw const PersonDirectoryUnavailableException();
}

bool isPersonDetailId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);
