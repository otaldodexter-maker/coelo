import 'catalog_entry.dart';

enum CatalogFilter {
  all('Todos'),
  shared('Compartilhados'),
  adminAndSuperadmin('Admin + Superadmin'),
  superadminOnly('Somente Superadmin'),
  adminOnly('Somente Admin'),
  principalOnly('Somente Principal'),
  auth('Auth'),
  astroPlanned('Astro planejado');

  const CatalogFilter(this.label);

  final String label;

  List<CatalogEntry> apply(
    Iterable<CatalogEntry> entries, {
    CatalogStatus? status,
    String query = '',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return entries
        .where((entry) {
          return _matchesContext(entry) &&
              (status == null || entry.status == status) &&
              (normalizedQuery.isEmpty ||
                  entry.name.toLowerCase().contains(normalizedQuery) ||
                  entry.id.toLowerCase().contains(normalizedQuery));
        })
        .toList(growable: false);
  }

  bool _matchesContext(CatalogEntry entry) {
    final consumers = entry.consumers;
    return switch (this) {
      CatalogFilter.all => true,
      CatalogFilter.shared => consumers.contains('shared'),
      CatalogFilter.adminAndSuperadmin =>
        consumers.contains('admin') && consumers.contains('superadmin'),
      CatalogFilter.superadminOnly => consumers.length == 1 && consumers.single == 'superadmin',
      CatalogFilter.adminOnly => consumers.length == 1 && consumers.single == 'admin',
      CatalogFilter.principalOnly => consumers.length == 1 && consumers.single == 'principal',
      CatalogFilter.auth => consumers.contains('auth'),
      CatalogFilter.astroPlanned => consumers.contains('astro-planned'),
    };
  }
}
