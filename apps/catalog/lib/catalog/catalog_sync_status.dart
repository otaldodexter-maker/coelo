enum CatalogSyncStatus { synchronized, catalogStale }

extension CatalogSyncStatusValue on CatalogSyncStatus {
  String get value => switch (this) {
    CatalogSyncStatus.synchronized => 'synchronized',
    CatalogSyncStatus.catalogStale => 'catalogStale',
  };

  static CatalogSyncStatus fromValue(String value) {
    return switch (value) {
      'synchronized' => CatalogSyncStatus.synchronized,
      'catalogStale' => CatalogSyncStatus.catalogStale,
      _ => throw FormatException('Status de sincronização desconhecido: $value'),
    };
  }
}

final class CatalogSyncDiagnostic {
  const CatalogSyncDiagnostic({required this.code, required this.message, this.id, this.path});

  factory CatalogSyncDiagnostic.fromJson(Map<String, Object?> json) {
    return CatalogSyncDiagnostic(
      code: json['code'] as String,
      message: json['message'] as String,
      id: json['id'] as String?,
      path: json['path'] as String?,
    );
  }

  final String code;
  final String message;
  final String? id;
  final String? path;

  Map<String, Object?> toJson() {
    return {
      'code': code,
      'message': message,
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    };
  }
}

final class CatalogSyncFingerprint {
  const CatalogSyncFingerprint({required this.source, required this.example});

  factory CatalogSyncFingerprint.fromJson(Map<String, Object?> json) {
    return CatalogSyncFingerprint(
      source: json['source'] as String,
      example: json['example'] as String,
    );
  }

  final String source;
  final String example;

  Map<String, Object?> toJson() => {'source': source, 'example': example};
}

final class CatalogSyncReport {
  const CatalogSyncReport({
    required this.status,
    required this.diagnostics,
    required this.fingerprints,
  });

  const CatalogSyncReport.synchronized()
    : status = CatalogSyncStatus.synchronized,
      diagnostics = const [],
      fingerprints = const {};

  factory CatalogSyncReport.fromJson(Map<String, Object?> json) {
    final rawDiagnostics = json['diagnostics'];
    final rawFingerprints = json['fingerprints'];
    if (rawDiagnostics is! List<Object?> || rawFingerprints is! Map<String, Object?>) {
      throw const FormatException('Relatório de sincronização inválido.');
    }
    return CatalogSyncReport(
      status: CatalogSyncStatusValue.fromValue(json['status'] as String),
      diagnostics: List.unmodifiable(
        rawDiagnostics.map((item) => CatalogSyncDiagnostic.fromJson(item as Map<String, Object?>)),
      ),
      fingerprints: Map.unmodifiable(
        rawFingerprints.map(
          (id, value) =>
              MapEntry(id, CatalogSyncFingerprint.fromJson(value as Map<String, Object?>)),
        ),
      ),
    );
  }

  factory CatalogSyncReport.unavailable() {
    return const CatalogSyncReport(
      status: CatalogSyncStatus.catalogStale,
      diagnostics: [
        CatalogSyncDiagnostic(
          code: 'sync-report-unavailable',
          message: 'O relatório de sincronização não pôde ser carregado.',
        ),
      ],
      fingerprints: {},
    );
  }

  final CatalogSyncStatus status;
  final List<CatalogSyncDiagnostic> diagnostics;
  final Map<String, CatalogSyncFingerprint> fingerprints;

  bool get isStale => status == CatalogSyncStatus.catalogStale || diagnostics.isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'status': status.value,
      'diagnostics': diagnostics.map((diagnostic) => diagnostic.toJson()).toList(),
      'fingerprints': fingerprints.map((id, fingerprint) => MapEntry(id, fingerprint.toJson())),
    };
  }
}
