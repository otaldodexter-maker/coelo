import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search during catalog load keeps loading and applies to the response', () async {
    final repository = _CatalogRepository();
    final model = AccessProfileViewModel(repository);
    addTearDown(model.dispose);
    final load = model.setDomain(AccessProfileDomain.principal);
    await model.setSearch('sem correspondência');
    expect(model.state, AccessProfileLoadState.loading);
    repository.result.complete(const [_capability]);
    await load;
    expect(model.state, AccessProfileLoadState.noResults);
    expect(model.visibleCapabilities, isEmpty);
    expect(repository.calls, 1);
    await model.setSearch('comunicados');
    expect(model.state, AccessProfileLoadState.success);
    expect(model.visibleCapabilities, const [_capability]);
    expect(repository.calls, 1);
  });

  test('search after catalog failure preserves the error and retry state', () async {
    final repository = _CatalogRepository();
    final model = AccessProfileViewModel(repository);
    addTearDown(model.dispose);
    final load = model.setDomain(AccessProfileDomain.principal);
    repository.result.completeError(const AccessProfileException('Falha no catálogo.'));
    await load;
    await model.setSearch('comunicados');
    expect(model.state, AccessProfileLoadState.failure);
    expect(model.errorMessage, 'Falha no catálogo.');
    expect(model.visibleCapabilities, isEmpty);
    expect(repository.calls, 1);
  });

  test('clearing search on an empty catalog preserves the empty state', () async {
    final repository = _CatalogRepository();
    final model = AccessProfileViewModel(repository);
    addTearDown(model.dispose);
    final load = model.setDomain(AccessProfileDomain.principal);
    repository.result.complete(const []);
    await load;
    await model.setSearch('');
    expect(model.state, AccessProfileLoadState.empty);
    expect(model.resultCount, 0);
  });
}

final class _CatalogRepository implements AccessProfileRepository {
  final result = Completer<List<PrincipalCapability>>();
  int calls = 0;

  @override
  bool get isDemo => false;

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() {
    calls++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _capability = PrincipalCapability(
  id: 'messages',
  code: 'messages.read',
  name: 'Ver comunicados',
  description: 'Consulta comunicados no contexto autorizado.',
  contextCount: 1,
);
