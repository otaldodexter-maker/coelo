import '../domain/institution_directory_item.dart';
import '../domain/institution_directory_page.dart';
import '../domain/institution_directory_query.dart';
import '../domain/institution_directory_repository.dart';
import '../domain/institution_record.dart';

final class FakeInstitutionDirectoryRepository implements InstitutionDirectoryRepository {
  FakeInstitutionDirectoryRepository({
    List<InstitutionDirectoryItem>? items,
    List<InstitutionRecord>? records,
  }) : _records = [
         ...?records,
         if (records == null)
           ...?items?.map(InstitutionRecord.fromDirectoryItem)
         else
           ...const <InstitutionRecord>[],
         if (records == null && items == null) ...demoInstitutionRecords,
       ];

  final List<InstitutionRecord> _records;

  List<InstitutionRecord> get records => List.unmodifiable(_records);

  Set<String> reservedHandles({String? excludingInstitutionId}) => {
    for (final record in _records)
      if (record.id != excludingInstitutionId) ...{
        '@${record.slug.toLowerCase()}',
        for (final administrator in record.administrators) administrator.handle.toLowerCase(),
      },
  };

  InstitutionRecord? findById(String id) {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  Future<void> upsert(InstitutionRecord record) async {
    final index = _records.indexWhere((candidate) => candidate.id == record.id);
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }

  String createId(String slug) {
    final base = 'local-institution-${slug.isEmpty ? 'nova' : slug}';
    var candidate = base;
    var suffix = 2;
    while (findById(candidate) != null) {
      candidate = '$base-${suffix++}';
    }
    return candidate;
  }

  @override
  Future<InstitutionRecord> fetchById(String institutionId) async {
    final record = findById(institutionId);
    if (record == null) {
      throw const InstitutionDirectoryNotFoundException();
    }
    return record;
  }

  @override
  Future<InstitutionRecord> create(InstitutionRecord draft) async {
    final created = draft.copyWith(
      id: draft.id.isNotEmpty ? draft.id : createId(draft.slug),
      version: draft.version + 1,
    );
    await upsert(created);
    return created;
  }

  @override
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion}) async {
    final index = _records.indexWhere((candidate) => candidate.id == draft.id);
    if (index == -1) {
      throw const InstitutionDirectoryNotFoundException();
    }

    final current = _records[index];
    if (current.version != expectedVersion) {
      throw const InstitutionDirectoryConflictException();
    }

    final updated = draft.copyWith(version: expectedVersion + 1);
    _records[index] = updated;
    return updated;
  }

  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    final search = query.search.trim().toLowerCase();
    final filtered =
        _records.map((record) => record.directoryItem).where((item) {
          final matchesSearch =
              search.isEmpty ||
              [
                item.publicName,
                item.tradeName,
                item.legalName,
              ].whereType<String>().any((name) => name.toLowerCase().contains(search));
          return matchesSearch &&
              (query.statuses.isEmpty || query.statuses.contains(item.status)) &&
              (query.planId == null || item.planId == query.planId) &&
              (query.states.isEmpty || query.states.contains(item.state)) &&
              (query.cities.isEmpty || query.cities.contains(item.city)) &&
              (query.districts.isEmpty || query.districts.contains(item.district)) &&
              (query.typeIds.isEmpty || query.typeIds.contains(item.typeId));
        }).toList()..sort((first, second) {
          final comparison = _compareItems(first, second, query.sortColumn);
          if (comparison != 0) {
            return query.sortAscending ? comparison : -comparison;
          }
          return first.id.compareTo(second.id);
        });

    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return InstitutionDirectoryPage(
      items: List.unmodifiable(filtered.sublist(start, end)),
      totalCount: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    final plans = <String, String>{};
    final types = <String, String>{};
    final stateOptions = <String, String>{};
    final cityOptions = <String, String>{};
    final districtOptions = <String, String>{};
    for (final item in _records.map((record) => record.directoryItem)) {
      if (item.planId case final id? when item.planName != null) {
        plans[id] = item.planName!;
      }
      if (item.typeId case final id? when item.typeName != null) {
        types[id] = item.typeName!;
      }
      if (item.state case final state? when state.trim().isNotEmpty) {
        stateOptions[state] = state;
      }
      if (states.contains(item.state) && item.city != null) {
        cityOptions[item.city!] = item.city!;
      }
      if (states.contains(item.state) && cities.contains(item.city) && item.district != null) {
        districtOptions[item.district!] = item.district!;
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
      states: options(stateOptions),
      cities: options(cityOptions),
      districts: options(districtOptions),
    );
  }
}

int _compareItems(
  InstitutionDirectoryItem first,
  InstitutionDirectoryItem second,
  InstitutionDirectorySortColumn column,
) {
  final comparison = switch (column) {
    InstitutionDirectorySortColumn.publicName => first.publicName.compareTo(second.publicName),
    InstitutionDirectorySortColumn.typeName => _compareNullable(first.typeName, second.typeName),
    InstitutionDirectorySortColumn.unitsCount => first.unitsCount.compareTo(second.unitsCount),
    InstitutionDirectorySortColumn.groupsCount => first.groupsCount.compareTo(second.groupsCount),
    InstitutionDirectorySortColumn.planName => _compareNullable(first.planName, second.planName),
    InstitutionDirectorySortColumn.status => first.status.databaseValue.compareTo(
      second.status.databaseValue,
    ),
    InstitutionDirectorySortColumn.contactEmail => _compareNullable(
      first.contactEmail,
      second.contactEmail,
    ),
    InstitutionDirectorySortColumn.contactPhone => _compareNullable(
      first.contactPhone,
      second.contactPhone,
    ),
    InstitutionDirectorySortColumn.contactMobilePhone => _compareNullable(
      first.contactMobilePhone,
      second.contactMobilePhone,
    ),
    InstitutionDirectorySortColumn.primaryDomain => _compareNullable(
      first.primaryDomain,
      second.primaryDomain,
    ),
    InstitutionDirectorySortColumn.street => _compareNullable(first.street, second.street),
    InstitutionDirectorySortColumn.postalCode => _compareNullable(
      first.postalCode,
      second.postalCode,
    ),
    InstitutionDirectorySortColumn.addressNumber => _compareNullable(
      first.addressNumber,
      second.addressNumber,
    ),
    InstitutionDirectorySortColumn.complement => _compareNullable(
      first.complement,
      second.complement,
    ),
    InstitutionDirectorySortColumn.district => _compareNullable(first.district, second.district),
    InstitutionDirectorySortColumn.city => _compareNullable(first.city, second.city),
    InstitutionDirectorySortColumn.state => _compareNullable(first.state, second.state),
  };
  return comparison;
}

int _compareNullable<T extends Comparable<T>>(T? first, T? second) {
  return switch ((first, second)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    (final first?, final second?) => first.compareTo(second),
  };
}

final demoInstitutionRecords = List<InstitutionRecord>.unmodifiable(
  <InstitutionRecord>[
    _record(
      id: 'demo-institution-aurora',
      name: 'Instituto Aurora',
      type: 'Escola',
      city: 'São Paulo',
      state: 'SP',
      district: 'Jardins',
      street: 'Alameda Santos',
      number: '1200',
      tradeName: 'Aurora',
      legalName: 'Instituto Aurora Educação LTDA',
      domain: 'aurora.coelo.me',
      complement: 'Conjunto 42',
      postalCode: '01310-100',
      contactEmail: 'contato@aurora.coelo.me',
      contactPhone: '+55 11 3333-4444',
      contactMobilePhone: '+55 11 99999-8888',
      status: InstitutionStatus.active,
      plan: InstitutionPlan.essential,
      unitGroupCounts: const [6, 7, 5],
    ),
    _record(
      id: 'demo-institution-horizonte',
      name: 'Centro Horizonte',
      type: 'Terapia Ocupacional',
      city: 'Campinas',
      state: 'SP',
      district: 'Cambuí',
      street: 'Rua Coronel Quirino',
      number: '850',
      tradeName: 'Horizonte',
      legalName: 'Centro Horizonte Terapia Ocupacional LTDA',
      domain: 'aurora-no-dominio.coelo.me',
      complement: 'Sala 12',
      postalCode: '13025-100',
      contactEmail: 'contato@centrohorizonte.coelo.me',
      contactPhone: '+55 19 3232-1212',
      contactMobilePhone: '+55 19 98888-1212',
      status: InstitutionStatus.onboarding,
      plan: InstitutionPlan.professional,
      unitGroupCounts: const [6],
      firstUnitName: 'Unidade Cambuí',
      firstGroupName: 'Turma Girassol',
    ),
    _record(
      id: 'demo-institution-pontes',
      name: 'Instituição Pontes',
      type: 'Clínica multidisciplinar',
      city: 'Curitiba',
      state: 'PR',
      district: 'Batel',
      street: 'Avenida do Batel',
      number: '1440',
      tradeName: 'Pontes',
      legalName: 'Pontes Desenvolvimento Infantil LTDA',
      domain: 'pontes.coelo.me',
      complement: 'Térreo',
      postalCode: '80420-090',
      contactEmail: 'contato@pontes.coelo.me',
      contactPhone: '+55 41 3333-2020',
      contactMobilePhone: '+55 41 99999-2020',
      status: InstitutionStatus.suspended,
      plan: InstitutionPlan.essential,
      unitGroupCounts: const [4, 5],
    ),
    _record(
      id: 'demo-institution-sementes',
      name: 'Sementes do Vale',
      type: 'Escola',
      city: 'Belo Horizonte',
      state: 'MG',
      status: InstitutionStatus.draft,
      plan: InstitutionPlan.essential,
      unitGroupCounts: const [8, 4],
    ),
    _record(
      id: 'demo-institution-mare-alta',
      name: 'Colégio Maré Alta',
      type: 'Colégio',
      city: 'Recife',
      state: 'PE',
      status: InstitutionStatus.active,
      plan: InstitutionPlan.complete,
      unitGroupCounts: const [28, 10, 8, 6],
    ),
    _record(
      id: 'demo-institution-ipe',
      name: 'Núcleo Ipê',
      type: 'Centro terapêutico',
      city: 'Goiânia',
      state: 'GO',
      status: InstitutionStatus.onboarding,
      plan: InstitutionPlan.professional,
      unitGroupCounts: const [9, 7],
    ),
    _record(
      id: 'demo-institution-caminhos',
      name: 'Escola Caminhos',
      type: 'Escola',
      city: 'Florianópolis',
      state: 'SC',
      status: InstitutionStatus.active,
      plan: InstitutionPlan.professional,
      unitGroupCounts: const [14, 11],
    ),
    _record(
      id: 'demo-institution-casa-nuvem',
      name: 'Casa Nuvem',
      type: 'Educação infantil',
      city: 'Salvador',
      state: 'BA',
      status: InstitutionStatus.inactive,
      plan: InstitutionPlan.essential,
      unitGroupCounts: const [5],
    ),
    _record(
      id: 'demo-institution-viver',
      name: 'Instituto Viver',
      type: 'Instituto',
      city: 'Rio de Janeiro',
      state: 'RJ',
      status: InstitutionStatus.active,
      plan: InstitutionPlan.custom,
      unitGroupCounts: const [18, 16, 12],
    ),
    _record(
      id: 'demo-institution-raizes',
      name: 'Colégio Raízes',
      type: 'Colégio',
      city: 'Porto Alegre',
      state: 'RS',
      status: InstitutionStatus.archived,
      plan: InstitutionPlan.complete,
      unitGroupCounts: const [20, 15],
    ),
    _record(
      id: 'demo-institution-bem-te-vi',
      name: 'Centro Bem-Te-Vi',
      type: 'Centro multidisciplinar',
      city: 'Fortaleza',
      state: 'CE',
      status: InstitutionStatus.active,
      plan: InstitutionPlan.professional,
      unitGroupCounts: const [10, 8, 6],
    ),
    _record(
      id: 'demo-institution-estacao',
      name: 'Escola Estação',
      type: 'Escola',
      city: 'Brasília',
      state: 'DF',
      status: InstitutionStatus.onboarding,
      plan: InstitutionPlan.complete,
      unitGroupCounts: const [20, 18, 14, 10],
    ),
  ].take(5),
);

final demoInstitutionDirectoryItems = List<InstitutionDirectoryItem>.unmodifiable(
  demoInstitutionRecords.map((record) => record.directoryItem),
);

InstitutionRecord _record({
  required String id,
  required String name,
  required String type,
  required String city,
  required String state,
  required InstitutionStatus status,
  required InstitutionPlan plan,
  required List<int> unitGroupCounts,
  String district = 'Centro',
  String street = 'Rua Principal',
  String number = '100',
  String? tradeName,
  String? legalName,
  String? domain,
  String? complement,
  String? postalCode,
  String? contactEmail,
  String? contactPhone,
  String? contactMobilePhone,
  String? firstUnitName,
  String? firstGroupName,
}) {
  final slug = id.replaceFirst('demo-institution-', '');
  final units = [
    for (var unitIndex = 0; unitIndex < unitGroupCounts.length; unitIndex++)
      InstitutionUnit(
        id: '$id-unit-${(unitIndex + 1).toString().padLeft(2, '0')}',
        name: unitIndex == 0 && firstUnitName != null
            ? firstUnitName
            : 'Unidade ${(unitIndex + 1).toString().padLeft(2, '0')}',
        slug: '$slug-unidade-${unitIndex + 1}',
        typeId: 'demo-type-${type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
        typeName: type,
        postalCode: postalCode ?? '${(slug.length * 137).toString().padLeft(5, '0')}-000',
        state: state,
        city: city,
        district: district,
        street: street,
        addressNumber: number,
        complement: complement ?? '',
        contactEmail: 'unidade${unitIndex + 1}@$slug.coelo.me',
        contactPhone: contactPhone ?? '+55 11 3333-0000',
        contactMobilePhone: contactMobilePhone ?? '+55 11 99999-0000',
        brandDisplayName: unitIndex == 0 && firstUnitName != null
            ? firstUnitName
            : 'Unidade ${(unitIndex + 1).toString().padLeft(2, '0')}',
        activitiesCount: (unitGroupCounts[unitIndex] / 3).ceil(),
        groups: [
          for (var groupIndex = 0; groupIndex < unitGroupCounts[unitIndex]; groupIndex++)
            InstitutionGroup(
              id: '$id-unit-${(unitIndex + 1).toString().padLeft(2, '0')}-group-${(groupIndex + 1).toString().padLeft(2, '0')}',
              name: unitIndex == 0 && groupIndex == 0 && firstGroupName != null
                  ? firstGroupName
                  : 'Turma ${(groupIndex + 1).toString().padLeft(2, '0')}',
            ),
        ],
      ),
  ];
  final ownerFirstName = switch (slug.codeUnitAt(0) % 4) {
    0 => 'Marina',
    1 => 'Rafael',
    2 => 'Camila',
    _ => 'Bruno',
  };
  return InstitutionRecord(
    id: id,
    publicName: name,
    tradeName: tradeName ?? name,
    legalName: legalName ?? '$name Educação LTDA',
    typeId: 'demo-type-${type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
    typeName: type,
    documentType: 'CNPJ',
    document: '12.345.678/0001-${(slug.length * 7).toString().padLeft(2, '0')}',
    slug: slug,
    primaryDomain: domain ?? '$slug.coelo.me',
    status: status,
    locale: 'pt-BR',
    timezone: 'America/Sao_Paulo',
    postalCode: postalCode ?? '${(slug.length * 137).toString().padLeft(5, '0')}-000',
    country: 'Brasil',
    state: state,
    city: city,
    district: district,
    street: street,
    addressNumber: number,
    complement: complement ?? (unitGroupCounts.length > 2 ? 'Bloco A' : ''),
    contactEmail: contactEmail ?? 'contato@$slug.coelo.me',
    contactPhone: contactPhone ?? '+55 11 3333-0000',
    contactMobilePhone: contactMobilePhone ?? '+55 11 99999-0000',
    ownerFirstName: ownerFirstName,
    ownerLastName: 'Coelho',
    ownerDisplayName: '$ownerFirstName Coelho',
    ownerEmail: '${ownerFirstName.toLowerCase()}@$slug.coelo.me',
    ownerMobilePhone: '+55 11 98888-0000',
    plan: plan,
    subscriptionStatus: status == InstitutionStatus.suspended
        ? InstitutionSubscriptionStatus.suspended
        : InstitutionSubscriptionStatus.active,
    subscriptionStart: DateTime(2026, 1, 15),
    trialEnd: null,
    subscriptionJustification: status == InstitutionStatus.suspended
        ? 'Revisão operacional programada.'
        : '',
    brandDisplayName: name,
    hasSimulatedLogo: true,
    hasSimulatedCover: slug.length.isEven,
    accentColor: const ['#D63C00', '#2D8A4E', '#3F4549'][0],
    secondaryColor: slug.length.isEven ? '#2D8A4E' : '#3F4549',
    units: units,
  );
}
