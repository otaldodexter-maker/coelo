import '../domain/access_profile.dart';
import '../domain/access_profile_model.dart';

/// Reuses the canonical profile screens for profile-model CRUD.
final class AccessProfileModelRepositoryAdapter implements AccessProfileRepository {
  AccessProfileModelRepositoryAdapter(this._models);

  final AccessProfileModelRepository _models;
  final Map<String, AccessProfileModel> _details = {};

  @override
  bool get isDemo => false;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async {
    if (query.domain == AccessProfileDomain.principal) {
      return const AccessProfilePage.empty();
    }
    var afterName = null as String?;
    var afterId = null as String?;
    var currentPage = const AccessProfileModelPage(items: []);
    for (var page = 0; page <= query.page; page++) {
      currentPage = await _models.fetchModels(
        AccessProfileModelQuery(
          domain: query.domain,
          search: query.search,
          status: query.statuses.length == 1 ? query.statuses.single : null,
          scope: query.scopes.length == 1 ? query.scopes.single.databaseValue : null,
          limit: query.pageSize,
          afterName: afterName,
          afterId: afterId,
        ),
      );
      if (page < query.page && currentPage.nextId == null) {
        return AccessProfilePage(
          items: const [],
          totalCount: page * query.pageSize + currentPage.items.length,
          page: query.page,
          pageSize: query.pageSize,
        );
      }
      afterName = currentPage.nextName;
      afterId = currentPage.nextId;
    }
    return AccessProfilePage(
      items: currentPage.items.map(_toProfile).toList(growable: false),
      totalCount:
          query.page * query.pageSize +
          currentPage.items.length +
          (currentPage.nextId == null ? 0 : 1),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async {
    final model = await _models.fetchModel(profileId);
    _details[model.id] = model;
    final catalog = await _models.fetchPermissionCatalog();
    return _toProfile(model, catalog: catalog);
  }

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async {
    final catalog = await _models.fetchPermissionCatalog();
    return AccessProfile(
      id: '',
      domain: domain,
      code: '',
      name: '',
      description: '',
      status: AccessProfileStatus.active,
      maxScope: _defaultScope(domain),
      version: 0,
      membershipCount: 0,
      permissions: _permissions(catalog, domain, const []),
    );
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => const [];

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async {
    final existing = draft.id.isEmpty ? null : _details[draft.id];
    final selectedCodes = draft.permissions
        .where((permission) => permission.selected)
        .map((permission) => permission.code)
        .toSet();
    final denied =
        existing?.capabilities.where(
          (capability) =>
              capability.effect == AccessProfileModelEffect.deny &&
              !selectedCodes.contains(capability.code),
        ) ??
        const Iterable<AccessProfileModelCapability>.empty();
    final modelDraft = AccessProfileModelDraft(
      id: draft.id.isEmpty ? null : draft.id,
      domain: draft.domain,
      name: draft.name,
      description: draft.description,
      maxScopeKind: draft.maxScope.databaseValue,
      status: draft.status,
      capabilities: [
        for (final code in selectedCodes)
          AccessProfileModelCapability(code: code, effect: AccessProfileModelEffect.allow),
        ...denied,
      ],
      expectedVersion: draft.id.isEmpty ? null : expectedVersion,
      reason: reason,
    );
    final saved = draft.id.isEmpty
        ? await _models.createModel(requestId, modelDraft)
        : await _models.updateModel(requestId, modelDraft);
    _details[saved.id] = saved;
    return _toProfile(saved);
  }

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) => _models.deleteModel(
    requestId: requestId,
    modelId: profileId,
    expectedVersion: expectedVersion,
    reason: reason,
  );

  Future<AccessProfile> duplicate({
    required String requestId,
    required String sourceModelId,
    required AccessProfileDomain domain,
    required String name,
    required String reason,
  }) async {
    final duplicated = await _models.duplicateModel(
      requestId,
      AccessProfileModelDraft(
        sourceModelId: sourceModelId,
        domain: domain,
        name: name,
        description: '',
        maxScopeKind: _defaultScope(domain).databaseValue,
        status: AccessProfileStatus.inactive,
        capabilities: const [],
        reason: reason,
      ),
    );
    _details[duplicated.id] = duplicated;
    return _toProfile(duplicated);
  }
}

AccessProfile _toProfile(
  AccessProfileModel model, {
  List<AccessPermissionCatalogItem> catalog = const [],
}) => AccessProfile(
  id: model.id,
  domain: model.domain,
  code: model.code,
  name: model.name,
  description: model.description,
  status: model.status,
  maxScope: _scope(model.maxScopeKind),
  version: model.version,
  membershipCount: model.capabilities.length,
  isSystem: model.isSystem,
  permissions: _permissions(catalog, model.domain, model.capabilities),
);

List<AccessPermission> _permissions(
  List<AccessPermissionCatalogItem> catalog,
  AccessProfileDomain domain,
  List<AccessProfileModelCapability> capabilities,
) {
  final effects = {for (final item in capabilities) item.code: item.effect};
  final application = switch (domain) {
    AccessProfileDomain.platform => 'superadmin',
    AccessProfileDomain.institution => 'admin',
    AccessProfileDomain.principal => 'principal',
  };
  return catalog
      .where((item) => item.applicationCode == application)
      .map(
        (item) => AccessPermission(
          code: item.code,
          module: item.moduleLabel,
          screenCode: item.screenCode,
          actionCode: item.actionCode,
          name: item.actionLabel,
          description: item.description,
          risk: item.riskLevel,
          requiresMfa: item.requiresMfa,
          selected: effects[item.code] == AccessProfileModelEffect.allow,
        ),
      )
      .toList(growable: false);
}

AccessProfileScope _scope(String value) => switch (value) {
  'platform' => AccessProfileScope.platform,
  'institution' => AccessProfileScope.institution,
  'unit' => AccessProfileScope.unit,
  'group' => AccessProfileScope.group,
  'child_context' => AccessProfileScope.group,
  _ => throw AccessProfileException('Escopo de modelo de perfil inválido.'),
};

AccessProfileScope _defaultScope(AccessProfileDomain domain) => switch (domain) {
  AccessProfileDomain.platform => AccessProfileScope.platform,
  AccessProfileDomain.institution => AccessProfileScope.institution,
  AccessProfileDomain.principal => AccessProfileScope.group,
};
