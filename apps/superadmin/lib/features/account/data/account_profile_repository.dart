import '../domain/account_profile.dart';

abstract interface class AccountProfileRepository {
  Future<AccountProfile> load();
  Future<AccountProfile> save(AccountProfile profile);
}

abstract interface class AccountEmailChangeCancellation {
  Future<void> cancelEmailChange();
}

final class AccountProfileRepositoryException implements Exception {
  const AccountProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class UnavailableAccountProfileRepository implements AccountProfileRepository {
  const UnavailableAccountProfileRepository();

  @override
  Future<AccountProfile> load() => Future<AccountProfile>.error(
    const AccountProfileRepositoryException('Perfil indisponível nesta versão.'),
  );

  @override
  Future<AccountProfile> save(AccountProfile profile) => Future<AccountProfile>.error(
    const AccountProfileRepositoryException('Perfil indisponível nesta versão.'),
  );
}

final class InMemoryAccountProfileRepository implements AccountProfileRepository {
  InMemoryAccountProfileRepository({AccountProfile? initial})
    : _profile = initial ?? AccountProfile.prototype();

  AccountProfile _profile;

  @override
  Future<AccountProfile> load() async => _profile;

  @override
  Future<AccountProfile> save(AccountProfile profile) async => _profile = profile;
}
