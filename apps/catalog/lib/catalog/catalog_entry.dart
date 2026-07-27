enum CatalogStatus { proposed, approved, implemented, catalogStale, deprecated }

extension CatalogStatusLabel on CatalogStatus {
  String get label => switch (this) {
    CatalogStatus.proposed => 'Proposto',
    CatalogStatus.approved => 'Aprovado',
    CatalogStatus.implemented => 'Implementado',
    CatalogStatus.catalogStale => 'Catálogo desatualizado',
    CatalogStatus.deprecated => 'Descontinuado',
  };

  static CatalogStatus fromIndexValue(String value) {
    return switch (value) {
      'catalog-stale' => CatalogStatus.catalogStale,
      _ => CatalogStatus.values.byName(value),
    };
  }
}

final class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.ownerPackage,
    required this.consumers,
    required this.purpose,
    required this.useWhen,
    required this.doNotUseWhen,
    required this.variants,
    required this.states,
    required this.tokens,
    required this.accessibility,
    required this.publicFile,
    required this.tests,
    required this.example,
    this.replacement,
  });

  factory CatalogEntry.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => List<String>.from(json[key] as List<dynamic>);

    return CatalogEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      status: CatalogStatusLabel.fromIndexValue(json['status'] as String),
      ownerPackage: json['ownerPackage'] as String,
      consumers: strings('consumers'),
      purpose: json['purpose'] as String,
      useWhen: json['useWhen'] as String,
      doNotUseWhen: json['doNotUseWhen'] as String,
      variants: strings('variants'),
      states: strings('states'),
      tokens: strings('tokens'),
      accessibility: json['accessibility'] as String,
      publicFile: json['publicFile'] as String,
      tests: strings('tests'),
      example: json['example'] as String,
      replacement: json['replacement'] as String?,
    );
  }

  final String id;
  final String name;
  final String category;
  final CatalogStatus status;
  final String ownerPackage;
  final List<String> consumers;
  final String purpose;
  final String useWhen;
  final String doNotUseWhen;
  final List<String> variants;
  final List<String> states;
  final List<String> tokens;
  final String accessibility;
  final String publicFile;
  final List<String> tests;
  final String example;
  final String? replacement;
}
