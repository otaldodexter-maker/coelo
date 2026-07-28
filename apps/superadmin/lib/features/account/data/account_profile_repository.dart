import '../domain/account_profile.dart';

abstract interface class AccountProfileRepository {
  Future<AccountProfile> load();
  Future<void> save(AccountProfile profile);
}

final class InMemoryAccountProfileRepository implements AccountProfileRepository {
  InMemoryAccountProfileRepository({AccountProfile? initial})
    : _profile = initial ?? AccountProfile.prototype();

  AccountProfile _profile;

  @override
  Future<AccountProfile> load() async => _profile;

  @override
  Future<void> save(AccountProfile profile) async => _profile = profile;
}
