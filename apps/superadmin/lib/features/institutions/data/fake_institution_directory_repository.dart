import '../domain/institution_directory_item.dart';
import '../domain/institution_directory_page.dart';
import '../domain/institution_directory_query.dart';
import '../domain/institution_directory_repository.dart';

final class FakeInstitutionDirectoryRepository implements InstitutionDirectoryRepository {
  const FakeInstitutionDirectoryRepository({this.items = demoInstitutionDirectoryItems});

  final List<InstitutionDirectoryItem> items;

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesSearch =
          search.isEmpty ||
          [
            item.publicName,
            item.tradeName,
            item.legalName,
          ].whereType<String>().any((name) => name.toLowerCase().contains(search));
      return matchesSearch &&
          (query.status == null || item.status == query.status) &&
          (query.planId == null || item.planId == query.planId) &&
          (query.state == null || item.state == query.state) &&
          (query.city == null || item.city == query.city) &&
          (query.district == null || item.district == query.district) &&
          (query.typeId == null || item.typeId == query.typeId);
    }).toList()..sort((first, second) => first.publicName.compareTo(second.publicName));

    final start = query.offset.clamp(0, filtered.length);
    final end = (start + InstitutionDirectoryQuery.pageSize).clamp(start, filtered.length);
    return InstitutionDirectoryPage(
      items: List.unmodifiable(filtered.sublist(start, end)),
      totalCount: filtered.length,
      page: query.page,
    );
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    String? state,
    String? city,
  }) async {
    final plans = <String, String>{};
    final types = <String, String>{};
    final cities = <String, String>{};
    final districts = <String, String>{};
    for (final item in items) {
      final planId = item.planId;
      final planName = item.planName;
      if (planId != null && planName != null) {
        plans[planId] = planName;
      }
      final typeId = item.typeId;
      final typeName = item.typeName;
      if (typeId != null && typeName != null) {
        types[typeId] = typeName;
      }
      if (state != null && item.state == state && item.city != null) {
        cities[item.city!] = item.city!;
      }
      if (state != null && city != null && item.state == state && item.city == city) {
        final district = item.district;
        if (district != null) {
          districts[district] = district;
        }
      }
    }

    List<InstitutionDirectoryFilterOption> options(Map<String, String> entries) {
      return entries.entries
          .map((entry) => InstitutionDirectoryFilterOption(id: entry.key, label: entry.value))
          .toList()
        ..sort((first, second) => first.label.compareTo(second.label));
    }

    return InstitutionDirectoryFilterOptions(
      plans: options(plans),
      types: options(types),
      cities: options(cities),
      districts: options(districts),
    );
  }
}

const demoInstitutionDirectoryItems = <InstitutionDirectoryItem>[
  InstitutionDirectoryItem(
    id: 'demo-institution-aurora',
    publicName: 'Instituto Aurora',
    tradeName: 'Aurora',
    legalName: 'Instituto Aurora Educação LTDA',
    primaryDomain: 'aurora.coelo.me',
    status: InstitutionStatus.active,
    typeId: 'demo-type-school',
    typeName: 'Escola',
    district: 'Jardins',
    street: 'Alameda Santos',
    addressNumber: '1200',
    complement: 'Conjunto 42',
    city: 'São Paulo',
    state: 'SP',
    contactEmail: 'contato@aurora.coelo.me',
    contactPhone: '+55 11 3333-4444',
    contactMobilePhone: '+55 11 99999-8888',
    planId: 'demo-plan-essential',
    planName: 'Essencial',
    unitsCount: 3,
    groupsCount: 18,
  ),
  InstitutionDirectoryItem(
    id: 'demo-institution-horizonte',
    publicName: 'Centro Horizonte',
    tradeName: 'Horizonte',
    legalName: 'Centro Horizonte Terapia Ocupacional LTDA',
    primaryDomain: 'aurora-no-dominio.coelo.me',
    status: InstitutionStatus.onboarding,
    typeId: 'demo-type-occupational-therapy',
    typeName: 'Terapia Ocupacional',
    district: 'Cambuí',
    street: 'Rua Coronel Quirino',
    addressNumber: '850',
    complement: 'Sala 12',
    city: 'Campinas',
    state: 'SP',
    contactEmail: 'contato@centrohorizonte.coelo.me',
    contactPhone: '+55 19 3232-1212',
    contactMobilePhone: '+55 19 98888-1212',
    planId: 'demo-plan-professional',
    planName: 'Profissional',
    unitsCount: 1,
    groupsCount: 6,
  ),
  InstitutionDirectoryItem(
    id: 'demo-institution-pontes',
    publicName: 'Instituição Pontes',
    tradeName: 'Pontes',
    legalName: 'Pontes Desenvolvimento Infantil LTDA',
    primaryDomain: 'pontes.coelo.me',
    status: InstitutionStatus.suspended,
    typeId: 'demo-type-clinic',
    typeName: 'Clínica multidisciplinar',
    district: 'Batel',
    street: 'Avenida do Batel',
    addressNumber: '1440',
    complement: 'Térreo',
    city: 'Curitiba',
    state: 'PR',
    contactEmail: 'contato@pontes.coelo.me',
    contactPhone: '+55 41 3333-2020',
    contactMobilePhone: '+55 41 99999-2020',
    planId: 'demo-plan-essential',
    planName: 'Essencial',
    unitsCount: 2,
    groupsCount: 9,
  ),
];
