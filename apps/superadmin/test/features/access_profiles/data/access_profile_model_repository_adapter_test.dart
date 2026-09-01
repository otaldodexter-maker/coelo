import 'package:coelo_superadmin/features/access_profiles/data/access_profile_model_repository_adapter.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps cursor models to the canonical paged profile contract', () async {
    final source = _ModelRepository();
    final adapter = AccessProfileModelRepositoryAdapter(source);

    final page = await adapter.fetchProfiles(
      const AccessProfileQuery(
        domain: AccessProfileDomain.institution,
        search: 'gestão',
        statuses: {AccessProfileStatus.active},
        scopes: {AccessProfileScope.unit},
        pageSize: 1,
      ),
    );

    expect(page.items.single.name, 'Gestão escolar');
    expect(page.items.single.maxScope, AccessProfileScope.unit);
    expect(page.totalCount, 2);
    expect(source.lastQuery?.status, AccessProfileStatus.active);
    expect(source.lastQuery?.scope, 'unit');
  });

  test('detail combines model effects with the permission catalog', () async {
    final adapter = AccessProfileModelRepositoryAdapter(_ModelRepository());

    final detail = await adapter.fetchDetail(AccessProfileDomain.institution, 'model-1');

    expect(detail.permissions, hasLength(2));
    expect(detail.permissions.singleWhere((item) => item.code.endsWith('.read')).selected, isTrue);
    expect(
      detail.permissions.singleWhere((item) => item.code.endsWith('.delete')).selected,
      isFalse,
    );
  });

  test('save maps canonical selection and preserves an existing deny effect', () async {
    final source = _ModelRepository();
    final adapter = AccessProfileModelRepositoryAdapter(source);
    final detail = await adapter.fetchDetail(AccessProfileDomain.institution, 'model-1');

    await adapter.save(
      requestId: 'request-update',
      expectedVersion: detail.version,
      reason: 'Revisão',
      draft: detail,
    );

    expect(source.updatedDraft?.expectedVersion, 3);
    expect(
      source.updatedDraft?.capabilities.map((item) => '${item.code}:${item.effect.databaseValue}'),
      containsAll(['admin.institutions.read:allow', 'admin.institutions.delete:deny']),
    );
  });

  test('delete and duplicate delegate guarded model commands', () async {
    final source = _ModelRepository();
    final adapter = AccessProfileModelRepositoryAdapter(source);

    await adapter.deleteAndReassign(
      requestId: 'request-delete',
      domain: AccessProfileDomain.institution,
      profileId: 'model-1',
      expectedVersion: 3,
      replacementProfileId: null,
      reason: 'Desativação',
    );
    final duplicated = await adapter.duplicate(
      requestId: 'request-copy',
      sourceModelId: 'model-1',
      domain: AccessProfileDomain.institution,
      name: 'Gestão escolar regional',
      reason: 'Nova região',
    );

    expect(source.deletedId, 'model-1');
    expect(source.duplicatedDraft?.sourceModelId, 'model-1');
    expect(duplicated.status, AccessProfileStatus.inactive);
  });
}

final class _ModelRepository implements AccessProfileModelRepository {
  AccessProfileModelQuery? lastQuery;
  AccessProfileModelDraft? updatedDraft;
  AccessProfileModelDraft? duplicatedDraft;
  String? deletedId;

  @override
  Future<AccessProfileModelPage> fetchModels(AccessProfileModelQuery query) async {
    lastQuery = query;
    return AccessProfileModelPage(
      items: const [_model],
      nextName: 'Gestão escolar',
      nextId: 'model-1',
    );
  }

  @override
  Future<AccessProfileModel> fetchModel(String modelId) async => _model;

  @override
  Future<List<AccessPermissionCatalogItem>> fetchPermissionCatalog() async => const [
    _readCatalog,
    _deleteCatalog,
  ];

  @override
  Future<AccessProfileModel> createModel(String requestId, AccessProfileModelDraft draft) async =>
      _model;

  @override
  Future<AccessProfileModel> updateModel(String requestId, AccessProfileModelDraft draft) async {
    updatedDraft = draft;
    return _model;
  }

  @override
  Future<void> deleteModel({
    required String requestId,
    required String modelId,
    required int expectedVersion,
    required String reason,
  }) async => deletedId = modelId;

  @override
  Future<AccessProfileModel> duplicateModel(String requestId, AccessProfileModelDraft draft) async {
    duplicatedDraft = draft;
    return _model.copyWith(status: AccessProfileStatus.inactive);
  }

  @override
  Future<AccessProfileModelExport> exportModels(AccessProfileDomain domain) =>
      throw UnimplementedError();

  @override
  Future<AccessProfileModelImportPreview> previewModelImport(
    AccessProfileDomain domain,
    List<Map<String, dynamic>> rows,
  ) => throw UnimplementedError();

  @override
  Future<List<AccessProfileModel>> confirmModelImport({
    required String requestId,
    required AccessProfileDomain domain,
    required List<Map<String, dynamic>> rows,
    required String reason,
  }) => throw UnimplementedError();
}

extension on AccessProfileModel {
  AccessProfileModel copyWith({AccessProfileStatus? status}) => AccessProfileModel(
    id: id,
    domain: domain,
    code: code,
    name: name,
    description: description,
    status: status ?? this.status,
    maxScopeKind: maxScopeKind,
    version: version,
    isSystem: isSystem,
    capabilities: capabilities,
    applicationCode: applicationCode,
  );
}

const _model = AccessProfileModel(
  id: 'model-1',
  domain: AccessProfileDomain.institution,
  code: 'gestao-escolar',
  name: 'Gestão escolar',
  description: 'Operação da unidade.',
  status: AccessProfileStatus.active,
  maxScopeKind: 'unit',
  version: 3,
  isSystem: false,
  capabilities: [
    AccessProfileModelCapability(
      code: 'admin.institutions.read',
      effect: AccessProfileModelEffect.allow,
    ),
    AccessProfileModelCapability(
      code: 'admin.institutions.delete',
      effect: AccessProfileModelEffect.deny,
    ),
  ],
);

const _readCatalog = AccessPermissionCatalogItem(
  applicationCode: 'admin',
  moduleCode: 'structure',
  moduleLabel: 'Estrutura',
  screenCode: 'institutions',
  screenLabel: 'Instituições',
  actionCode: 'read',
  actionLabel: 'Visualizar',
  code: 'admin.institutions.read',
  description: 'Visualizar instituições.',
  riskLevel: 'normal',
  requiresMfa: false,
);

const _deleteCatalog = AccessPermissionCatalogItem(
  applicationCode: 'admin',
  moduleCode: 'structure',
  moduleLabel: 'Estrutura',
  screenCode: 'institutions',
  screenLabel: 'Instituições',
  actionCode: 'delete',
  actionLabel: 'Excluir',
  code: 'admin.institutions.delete',
  description: 'Excluir instituições.',
  riskLevel: 'high',
  requiresMfa: true,
);
