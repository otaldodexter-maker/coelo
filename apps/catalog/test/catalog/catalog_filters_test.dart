import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entries = [
    _entry('core.search-field', 'CoeloSearchField', ['shared', 'auth']),
    _entry('admin.toolbar', 'CoeloAdminListingToolbar', ['admin', 'superadmin']),
    _entry('superadmin.audit', 'SuperadminAuditTrail', ['superadmin']),
    _entry('admin.directory', 'AdminDirectory', ['admin']),
    _entry('principal.moment', 'PrincipalMoment', ['principal']),
    _entry('auth.login', 'CatalogLogin', ['auth']),
    _entry('astro.planned', 'AstroCatalog', ['astro-planned'], status: CatalogStatus.approved),
  ];

  test('parses index records and filters every catalog context', () {
    final parsed = CatalogEntry.fromJson({
      'id': 'core.search-field',
      'name': 'CoeloSearchField',
      'category': 'component',
      'status': 'implemented',
      'ownerPackage': 'coelo_ui_core',
      'consumers': ['shared', 'auth'],
      'purpose': 'Busca textual.',
      'useWhen': 'Busca por texto.',
      'doNotUseWhen': 'Selecao de opcoes.',
      'variants': <String>[],
      'states': ['enabled'],
      'tokens': ['color.primary'],
      'accessibility': 'Rotulo obrigatorio.',
      'publicFile': 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      'tests': ['packages/coelo_ui_core/test/input/coelo_search_field_test.dart'],
      'example': 'CoeloSearchField()',
      'replacement': null,
    });

    expect(parsed.status, CatalogStatus.implemented);
    expect(CatalogStatusLabel.fromIndexValue('catalog-stale'), CatalogStatus.catalogStale);
    expect(CatalogFilter.all.apply(entries), hasLength(7));
    expect(CatalogFilter.shared.apply(entries).single.id, 'core.search-field');
    expect(CatalogFilter.adminAndSuperadmin.apply(entries).single.id, 'admin.toolbar');
    expect(CatalogFilter.superadminOnly.apply(entries).single.id, 'superadmin.audit');
    expect(CatalogFilter.adminOnly.apply(entries).single.id, 'admin.directory');
    expect(CatalogFilter.principalOnly.apply(entries).single.id, 'principal.moment');
    expect(
      CatalogFilter.auth.apply(entries).map((entry) => entry.id),
      containsAll(['core.search-field', 'auth.login']),
    );
    expect(CatalogFilter.astroPlanned.apply(entries).single.id, 'astro.planned');
  });

  test('filters entries by status and name or id search', () {
    expect(CatalogFilter.all.apply(entries, status: CatalogStatus.approved), [entries.last]);
    expect(CatalogFilter.all.apply(entries, query: 'toolbar'), [entries[1]]);
    expect(CatalogFilter.all.apply(entries, query: 'CORE.SEARCH'), [entries.first]);
  });

  test('filters catalog-stale entries by their explicit index status', () {
    final stale = _entry('core.stale', 'StaleComponent', [
      'shared',
    ], status: CatalogStatus.catalogStale);

    expect(CatalogFilter.all.apply([stale], status: CatalogStatus.catalogStale), [stale]);
  });
}

CatalogEntry _entry(
  String id,
  String name,
  List<String> consumers, {
  CatalogStatus status = CatalogStatus.implemented,
}) {
  return CatalogEntry(
    id: id,
    name: name,
    category: 'component',
    status: status,
    ownerPackage: 'coelo_ui_core',
    consumers: consumers,
    purpose: 'Purpose',
    useWhen: 'Use',
    doNotUseWhen: 'Do not use',
    variants: const [],
    states: const ['enabled'],
    tokens: const ['color.primary'],
    accessibility: 'Acessivel',
    publicFile: 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
    tests: const [],
    example: 'Example()',
  );
}
