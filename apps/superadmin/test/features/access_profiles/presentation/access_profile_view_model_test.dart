import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discarda resposta antiga quando uma consulta mais nova termina primeiro', () async {
    final repository = _DelayedRepository();
    final viewModel = AccessProfileViewModel(repository);
    addTearDown(viewModel.dispose);

    final firstLoad = viewModel.load();
    await Future<void>.delayed(Duration.zero);
    final secondLoad = viewModel.setDomain(AccessProfileDomain.institution);
    await Future<void>.delayed(Duration.zero);

    repository.second.complete(
      const AccessProfilePage(items: [_institutionProfile], totalCount: 1, page: 0, pageSize: 11),
    );
    await secondLoad;
    repository.first.complete(
      const AccessProfilePage(items: [_platformProfile], totalCount: 1, page: 0, pageSize: 11),
    );
    await firstLoad;

    expect(viewModel.query.domain, AccessProfileDomain.institution);
    expect(viewModel.page.items.single.domain, AccessProfileDomain.institution);
  });

  test('filtra capacidades do Principal localmente', () async {
    final repository = _DelayedRepository()
      ..capabilities = const [
        PrincipalCapability(
          id: 'messages',
          code: 'messages.read',
          name: 'Ver comunicados',
          description: 'Consulta comunicados no contexto autorizado.',
          contextCount: 2,
        ),
      ];
    final viewModel = AccessProfileViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.setDomain(AccessProfileDomain.principal);
    await viewModel.setSearch('comunicados');

    expect(viewModel.visibleCapabilities, hasLength(1));
    expect(viewModel.state, AccessProfileLoadState.success);
  });

  test('limpa a busca ao trocar o domínio', () async {
    final repository = _DelayedRepository();
    final viewModel = AccessProfileViewModel(repository);
    addTearDown(viewModel.dispose);

    await viewModel.setDomain(AccessProfileDomain.principal);
    await viewModel.setSearch('comunicados');
    repository.first.complete(const AccessProfilePage.empty());

    await viewModel.setDomain(AccessProfileDomain.institution);

    expect(viewModel.query.search, isEmpty);
  });

  test('clears the inactive collection when switching to Principal', () async {
    final repository = _ImmediateRepository();
    final viewModel = AccessProfileViewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    expect(viewModel.page.items, isNotEmpty);

    await viewModel.setDomain(AccessProfileDomain.principal);

    expect(viewModel.page.items, isEmpty);
    expect(viewModel.capabilities, isNotEmpty);
  });

  test('unauthorized and dispose clear every sensitive snapshot without notifying', () async {
    final repository = _ImmediateRepository();
    final viewModel = AccessProfileViewModel(repository);
    var notifications = 0;
    viewModel.addListener(() => notifications += 1);
    await viewModel.load();
    await viewModel.setSearch('perfil sensível');
    repository.unauthorized = true;

    await viewModel.load();

    expect(viewModel.state, AccessProfileLoadState.unauthorized);
    expect(viewModel.page.items, isEmpty);
    expect(viewModel.capabilities, isEmpty);
    expect(viewModel.query, const AccessProfileQuery());
    final beforeDispose = notifications;
    viewModel.dispose();
    expect(viewModel.page.items, isEmpty);
    expect(viewModel.capabilities, isEmpty);
    expect(viewModel.query, const AccessProfileQuery());
    expect(notifications, beforeDispose);
  });
}

final class _ImmediateRepository implements AccessProfileRepository {
  bool unauthorized = false;

  @override
  bool get isDemo => false;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async {
    if (unauthorized) throw const AccessProfileUnauthorizedException();
    return const AccessProfilePage(items: [_platformProfile], totalCount: 1, page: 1, pageSize: 11);
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => const [
    PrincipalCapability(
      id: 'messages',
      code: 'messages.read',
      name: 'Ver comunicados',
      description: 'Consulta autorizada.',
      contextCount: 1,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedRepository implements AccessProfileRepository {
  final first = Completer<AccessProfilePage>();
  final second = Completer<AccessProfilePage>();
  var calls = 0;
  List<PrincipalCapability> capabilities = const [];

  @override
  bool get isDemo => false;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) {
    calls++;
    return calls == 1 ? first.future : second.future;
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => capabilities;

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) => throw UnimplementedError();

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) =>
      throw UnimplementedError();

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) => throw UnimplementedError();

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) => throw UnimplementedError();
}

const _platformProfile = AccessProfile(
  id: 'platform',
  domain: AccessProfileDomain.platform,
  code: 'platform',
  name: 'Plataforma',
  description: '',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
);

const _institutionProfile = AccessProfile(
  id: 'institution',
  domain: AccessProfileDomain.institution,
  code: 'institution',
  name: 'Instituição',
  description: '',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.institution,
  version: 1,
  membershipCount: 0,
);
