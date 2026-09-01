import 'access_profile.dart';

enum AccessProfileModelEffect {
  allow('allow'),
  deny('deny');

  const AccessProfileModelEffect(this.databaseValue);

  final String databaseValue;

  static AccessProfileModelEffect fromDatabase(String value) =>
      values.firstWhere((item) => item.databaseValue == value);
}

final class AccessProfileModelCapability {
  const AccessProfileModelCapability({required this.code, required this.effect});

  factory AccessProfileModelCapability.fromJson(Map<String, dynamic> json) =>
      AccessProfileModelCapability(
        code: json['code'] as String,
        effect: AccessProfileModelEffect.fromDatabase(json['effect'] as String),
      );

  final String code;
  final AccessProfileModelEffect effect;

  Map<String, dynamic> toJson() => {'code': code, 'effect': effect.databaseValue};
}

final class AccessProfileModel {
  const AccessProfileModel({
    required this.id,
    required this.domain,
    required this.code,
    required this.name,
    required this.description,
    required this.status,
    required this.maxScopeKind,
    required this.version,
    required this.isSystem,
    required this.capabilities,
    this.applicationCode,
  });

  factory AccessProfileModel.fromJson(Map<String, dynamic> json) {
    final rows = json['capabilities'] as List<dynamic>? ?? const [];
    return AccessProfileModel(
      id: json['id'] as String,
      domain: AccessProfileDomain.values.firstWhere((item) => item.databaseValue == json['domain']),
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      status: AccessProfileStatus.fromDatabase(json['status'] as String),
      maxScopeKind: json['max_scope_kind'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      isSystem: json['is_system'] as bool? ?? false,
      capabilities: rows
          .map(
            (row) => AccessProfileModelCapability.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false),
      applicationCode: json['application_code'] as String?,
    );
  }

  final String id;
  final AccessProfileDomain domain;
  final String code;
  final String name;
  final String description;
  final AccessProfileStatus status;
  final String maxScopeKind;
  final int version;
  final bool isSystem;
  final List<AccessProfileModelCapability> capabilities;
  final String? applicationCode;
}

final class AccessProfileModelDraft {
  const AccessProfileModelDraft({
    required this.domain,
    required this.name,
    required this.description,
    required this.maxScopeKind,
    required this.status,
    required this.capabilities,
    this.id,
    this.expectedVersion,
    this.reason,
    this.sourceModelId,
  });

  final String? id;
  final AccessProfileDomain domain;
  final String name;
  final String description;
  final String maxScopeKind;
  final AccessProfileStatus status;
  final List<AccessProfileModelCapability> capabilities;
  final int? expectedVersion;
  final String? reason;
  final String? sourceModelId;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'domain': domain.databaseValue,
    'name': name.trim(),
    'description': description.trim(),
    'max_scope_kind': maxScopeKind,
    'status': status.databaseValue,
    'capabilities': capabilities.map((item) => item.toJson()).toList(growable: false),
    if (expectedVersion != null) 'expected_version': expectedVersion,
    if (reason != null) 'reason': reason!.trim(),
    if (sourceModelId != null) 'source_model_id': sourceModelId,
  };
}

final class AccessProfileModelQuery {
  const AccessProfileModelQuery({
    required this.domain,
    this.search = '',
    this.status,
    this.scope,
    this.limit = 25,
    this.afterName,
    this.afterId,
  });

  final AccessProfileDomain domain;
  final String search;
  final AccessProfileStatus? status;
  final String? scope;
  final int limit;
  final String? afterName;
  final String? afterId;
}

final class AccessProfileModelPage {
  const AccessProfileModelPage({required this.items, this.nextName, this.nextId});

  factory AccessProfileModelPage.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List<dynamic>? ?? const [];
    final cursor = json['next_cursor'] is Map
        ? Map<String, dynamic>.from(json['next_cursor'] as Map)
        : null;
    return AccessProfileModelPage(
      items: rows
          .map((row) => AccessProfileModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
      nextName: cursor?['name'] as String?,
      nextId: cursor?['id'] as String?,
    );
  }

  final List<AccessProfileModel> items;
  final String? nextName;
  final String? nextId;
}

final class AccessPermissionCatalogItem {
  const AccessPermissionCatalogItem({
    required this.applicationCode,
    required this.moduleCode,
    required this.moduleLabel,
    required this.screenCode,
    required this.screenLabel,
    required this.actionCode,
    required this.actionLabel,
    required this.code,
    required this.description,
    required this.riskLevel,
    required this.requiresMfa,
  });

  factory AccessPermissionCatalogItem.fromJson(Map<String, dynamic> json) =>
      AccessPermissionCatalogItem(
        applicationCode: json['application_code'] as String,
        moduleCode: json['module_code'] as String,
        moduleLabel: json['module_label'] as String,
        screenCode: json['screen_code'] as String,
        screenLabel: json['screen_label'] as String,
        actionCode: json['action_code'] as String,
        actionLabel: json['action_label'] as String,
        code: json['code'] as String,
        description: json['description'] as String? ?? '',
        riskLevel: json['risk_level'] as String,
        requiresMfa: json['requires_mfa'] as bool? ?? false,
      );

  final String applicationCode;
  final String moduleCode;
  final String moduleLabel;
  final String screenCode;
  final String screenLabel;
  final String actionCode;
  final String actionLabel;
  final String code;
  final String description;
  final String riskLevel;
  final bool requiresMfa;
}

final class AccessProfileModelExport {
  const AccessProfileModelExport({
    required this.formatVersion,
    required this.mimeType,
    required this.csv,
  });

  factory AccessProfileModelExport.fromJson(Map<String, dynamic> json) => AccessProfileModelExport(
    formatVersion: json['format_version'] as String,
    mimeType: json['mime_type'] as String,
    csv: json['csv'] as String,
  );

  final String formatVersion;
  final String mimeType;
  final String csv;
}

final class AccessProfileModelImportPreview {
  const AccessProfileModelImportPreview({
    required this.validCount,
    required this.errorCount,
    required this.rows,
  });

  factory AccessProfileModelImportPreview.fromJson(Map<String, dynamic> json) =>
      AccessProfileModelImportPreview(
        validCount: (json['valid_count'] as num).toInt(),
        errorCount: (json['error_count'] as num).toInt(),
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
      );

  final int validCount;
  final int errorCount;
  final List<Map<String, dynamic>> rows;
}

abstract interface class AccessProfileModelRepository {
  Future<AccessProfileModelPage> fetchModels(AccessProfileModelQuery query);
  Future<AccessProfileModel> fetchModel(String modelId);
  Future<AccessProfileModel> createModel(String requestId, AccessProfileModelDraft draft);
  Future<AccessProfileModel> updateModel(String requestId, AccessProfileModelDraft draft);
  Future<void> deleteModel({
    required String requestId,
    required String modelId,
    required int expectedVersion,
    required String reason,
  });
  Future<AccessProfileModel> duplicateModel(String requestId, AccessProfileModelDraft draft);
  Future<AccessProfileModelExport> exportModels(AccessProfileDomain domain);
  Future<AccessProfileModelImportPreview> previewModelImport(
    AccessProfileDomain domain,
    List<Map<String, dynamic>> rows,
  );
  Future<List<AccessProfileModel>> confirmModelImport({
    required String requestId,
    required AccessProfileDomain domain,
    required List<Map<String, dynamic>> rows,
    required String reason,
  });
  Future<List<AccessPermissionCatalogItem>> fetchPermissionCatalog();
}
