import '../../institutions/domain/institution_record.dart';
import 'unit_status.dart';

export 'unit_status.dart';

final class UnitRecord {
  const UnitRecord({required this.institution, required this.unit});

  final InstitutionRecord institution;
  final InstitutionUnit unit;

  String get id => unit.id;
  String get institutionId => institution.id;
  String get institutionName => institution.publicName;
  String get name => unit.name;
  String get slug => unit.slug;
  UnitStatus get status => unit.status;
  String get typeId => unit.typeId;
  String get typeName => unit.typeName;
  String get postalCode => unit.postalCode;
  String get country => unit.country;
  String get state => unit.state;
  String get city => unit.city;
  String get district => unit.district;
  String get street => unit.street;
  String get addressNumber => unit.addressNumber;
  String get complement => unit.complement;
  String get contactEmail => unit.contactEmail;
  String get contactPhone => unit.contactPhone;
  String get contactMobilePhone => unit.contactMobilePhone;
  InstitutionPlan? get planOverride => unit.planOverride;
  InstitutionPlan get effectivePlan => planOverride ?? institution.plan;
  bool get inheritInstitutionBranding => unit.inheritInstitutionBranding;
  String get brandDisplayName => unit.brandDisplayName;
  bool get hasSimulatedLogo => unit.hasSimulatedLogo;
  String get accentColor => unit.accentColor;
  String get secondaryColor => unit.secondaryColor;
  int get groupsCount => unit.groups.length;
  int get activitiesCount => unit.activitiesCount;

  UnitRecord copyWith({
    String? id,
    String? institutionId,
    String? name,
    String? slug,
    UnitStatus? status,
    String? typeId,
    String? typeName,
    String? postalCode,
    String? country,
    String? state,
    String? city,
    String? district,
    String? street,
    String? addressNumber,
    String? complement,
    String? contactEmail,
    String? contactPhone,
    String? contactMobilePhone,
    InstitutionPlan? planOverride,
    bool clearPlanOverride = false,
    bool? inheritInstitutionBranding,
    String? brandDisplayName,
    bool? hasSimulatedLogo,
    String? accentColor,
    String? secondaryColor,
    int? activitiesCount,
  }) {
    final targetInstitution = institutionId == null || institutionId == institution.id
        ? institution
        : throw ArgumentError.value(
            institutionId,
            'institutionId',
            'Changing an existing unit institution is not supported.',
          );
    return UnitRecord(
      institution: targetInstitution,
      unit: unit.copyWith(
        id: id,
        name: name,
        slug: slug,
        status: status,
        typeId: typeId,
        typeName: typeName,
        postalCode: postalCode,
        country: country,
        state: state,
        city: city,
        district: district,
        street: street,
        addressNumber: addressNumber,
        complement: complement,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        contactMobilePhone: contactMobilePhone,
        planOverride: planOverride,
        clearPlanOverride: clearPlanOverride,
        inheritInstitutionBranding: inheritInstitutionBranding,
        brandDisplayName: brandDisplayName,
        hasSimulatedLogo: hasSimulatedLogo,
        accentColor: accentColor,
        secondaryColor: secondaryColor,
        activitiesCount: activitiesCount,
      ),
    );
  }
}

final class UnitDirectoryItem {
  const UnitDirectoryItem(this.record);

  final UnitRecord record;

  String get id => record.id;
  String get institutionId => record.institutionId;
  String get institutionName => record.institutionName;
  String get name => record.name;
  UnitStatus get status => record.status;
  String get typeId => record.typeId;
  String get typeName => record.typeName;
  String get state => record.state;
  String get city => record.city;
  String get district => record.district;
  String get street => record.street;
  String get addressNumber => record.addressNumber;
  String get complement => record.complement;
  String get postalCode => record.postalCode;
  String get contactEmail => record.contactEmail;
  String get contactPhone => record.contactPhone;
  String get contactMobilePhone => record.contactMobilePhone;
  InstitutionPlan get effectivePlan => record.effectivePlan;
  int get groupsCount => record.groupsCount;
  int get activitiesCount => record.activitiesCount;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    final value = words.length > 1 ? '${words.first[0]}${words.last[0]}' : words.first;
    return value.substring(0, value.length.clamp(0, 2)).toUpperCase();
  }
}

final class UnitDirectoryQuery {
  UnitDirectoryQuery({
    this.search = '',
    Set<String> institutionIds = const {},
    Set<String> typeIds = const {},
    Set<UnitStatus> statuses = const {},
    Set<String> planIds = const {},
    Set<String> states = const {},
    Set<String> cities = const {},
    Set<String> districts = const {},
    this.page = 0,
  }) : assert(page >= 0),
       institutionIds = Set.unmodifiable(institutionIds),
       typeIds = Set.unmodifiable(typeIds),
       statuses = Set.unmodifiable(statuses),
       planIds = Set.unmodifiable(planIds),
       states = Set.unmodifiable(states),
       cities = Set.unmodifiable(cities),
       districts = Set.unmodifiable(districts);

  static const pageSize = 20;

  final String search;
  final Set<String> institutionIds;
  final Set<String> typeIds;
  final Set<UnitStatus> statuses;
  final Set<String> planIds;
  final Set<String> states;
  final Set<String> cities;
  final Set<String> districts;
  final int page;

  int get offset => page * pageSize;
  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      institutionIds.isNotEmpty ||
      typeIds.isNotEmpty ||
      statuses.isNotEmpty ||
      planIds.isNotEmpty ||
      states.isNotEmpty ||
      cities.isNotEmpty ||
      districts.isNotEmpty;
}

final class UnitDirectoryPage {
  const UnitDirectoryPage({required this.items, required this.totalCount, required this.page});

  final List<UnitDirectoryItem> items;
  final int totalCount;
  final int page;
}

final class UnitFilterOption {
  const UnitFilterOption(this.id, this.label);

  final String id;
  final String label;
}

final class UnitDirectoryFilterOptions {
  const UnitDirectoryFilterOptions({
    this.institutions = const [],
    this.types = const [],
    this.plans = const [],
    this.states = const [],
    this.cities = const [],
    this.districts = const [],
  });

  final List<UnitFilterOption> institutions;
  final List<UnitFilterOption> types;
  final List<UnitFilterOption> plans;
  final List<UnitFilterOption> states;
  final List<UnitFilterOption> cities;
  final List<UnitFilterOption> districts;
}

final class UnitDirectoryUnauthorizedException implements Exception {
  const UnitDirectoryUnauthorizedException();
}

abstract interface class UnitDirectoryRepository {
  List<UnitRecord> get records;
  UnitRecord? findById(String id);
  String createId(String institutionId, String slug);
  Future<void> upsert(UnitRecord record);
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query);
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  });
}
