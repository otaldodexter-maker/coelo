import 'institution_directory_item.dart';
import 'institution_people.dart';
import '../../units/domain/unit_status.dart';

enum InstitutionSubscriptionStatus {
  draft('Rascunho'),
  trial('Período de teste'),
  active('Ativo'),
  paused('Pausado'),
  suspended('Suspenso'),
  canceled('Cancelado');

  const InstitutionSubscriptionStatus(this.label);
  final String label;
}

enum InstitutionPlan {
  essential('demo-plan-essential', 'Essencial'),
  professional('demo-plan-professional', 'Profissional'),
  complete('demo-plan-complete', 'Completo'),
  custom('demo-plan-custom', 'Personalizado');

  const InstitutionPlan(this.id, this.label);
  final String id;
  final String label;
}

final class InstitutionGroup {
  const InstitutionGroup({required this.id, required this.name});

  final String id;
  final String name;
}

final class InstitutionUnit {
  const InstitutionUnit({
    required this.id,
    required this.name,
    required this.groups,
    this.slug = '',
    this.status = UnitStatus.active,
    this.typeId = '',
    this.typeName = '',
    this.postalCode = '',
    this.country = 'Brasil',
    this.state = '',
    this.city = '',
    this.district = '',
    this.street = '',
    this.addressNumber = '',
    this.complement = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.contactMobilePhone = '',
    this.planOverride,
    this.inheritInstitutionBranding = true,
    this.brandDisplayName = '',
    this.hasSimulatedLogo = false,
    this.hasSimulatedCover = false,
    this.accentColor = '#D63C00',
    this.secondaryColor = '#3F4549',
    this.textColor = '#3F4549',
    this.surfaceColor = '#FFFFFF',
    this.activitiesCount = 0,
  });

  final String id;
  final String name;
  final List<InstitutionGroup> groups;
  final String slug;
  final UnitStatus status;
  final String typeId;
  final String typeName;
  final String postalCode;
  final String country;
  final String state;
  final String city;
  final String district;
  final String street;
  final String addressNumber;
  final String complement;
  final String contactEmail;
  final String contactPhone;
  final String contactMobilePhone;
  final InstitutionPlan? planOverride;
  final bool inheritInstitutionBranding;
  final String brandDisplayName;
  final bool hasSimulatedLogo;
  final bool hasSimulatedCover;
  final String accentColor;
  final String secondaryColor;
  final String textColor;
  final String surfaceColor;
  final int activitiesCount;

  InstitutionUnit copyWith({
    String? id,
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
    bool? hasSimulatedCover,
    String? accentColor,
    String? secondaryColor,
    String? textColor,
    String? surfaceColor,
    int? activitiesCount,
  }) {
    return InstitutionUnit(
      id: id ?? this.id,
      name: name ?? this.name,
      groups: groups,
      slug: slug ?? this.slug,
      status: status ?? this.status,
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      district: district ?? this.district,
      street: street ?? this.street,
      addressNumber: addressNumber ?? this.addressNumber,
      complement: complement ?? this.complement,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      contactMobilePhone: contactMobilePhone ?? this.contactMobilePhone,
      planOverride: clearPlanOverride ? null : planOverride ?? this.planOverride,
      inheritInstitutionBranding: inheritInstitutionBranding ?? this.inheritInstitutionBranding,
      brandDisplayName: brandDisplayName ?? this.brandDisplayName,
      hasSimulatedLogo: hasSimulatedLogo ?? this.hasSimulatedLogo,
      hasSimulatedCover: hasSimulatedCover ?? this.hasSimulatedCover,
      accentColor: accentColor ?? this.accentColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      textColor: textColor ?? this.textColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      activitiesCount: activitiesCount ?? this.activitiesCount,
    );
  }
}

final class InstitutionProfileLink {
  const InstitutionProfileLink({required this.label, required this.url});

  final String label;
  final String url;
}

final class InstitutionRecord {
  const InstitutionRecord({
    required this.id,
    required this.publicName,
    required this.tradeName,
    required this.legalName,
    required this.typeId,
    required this.typeName,
    required this.documentType,
    required this.document,
    required this.slug,
    required this.primaryDomain,
    required this.status,
    required this.locale,
    required this.timezone,
    required this.postalCode,
    required this.country,
    required this.state,
    required this.city,
    required this.district,
    required this.street,
    required this.addressNumber,
    required this.complement,
    required this.contactEmail,
    required this.contactPhone,
    required this.contactMobilePhone,
    required this.ownerFirstName,
    required this.ownerLastName,
    required this.ownerDisplayName,
    required this.ownerEmail,
    required this.ownerMobilePhone,
    required this.plan,
    required this.subscriptionStatus,
    required this.subscriptionStart,
    required this.trialEnd,
    required this.subscriptionJustification,
    required this.brandDisplayName,
    required this.hasSimulatedLogo,
    required this.hasSimulatedCover,
    required this.accentColor,
    required this.secondaryColor,
    required this.units,
    this.tertiaryColor = '#D63C00',
    this.textColor = '#3F4549',
    this.secondaryTextColor = '#3F4549',
    this.tertiaryTextColor = '#3F4549',
    this.surfaceColor = '#FFFFFF',
    this.secondarySurfaceColor = '#F4F5F5',
    this.profileBio = '',
    this.profileLinks = const [],
    this.websiteUrl = '',
    this.whatsappNumber = '',
    this.legalRepresentatives = const [],
    this.administrators = const [],
  });

  factory InstitutionRecord.fromDirectoryItem(InstitutionDirectoryItem item) {
    final unit = InstitutionUnit(
      id: '${item.id}-unit-01',
      name: 'Unidade principal',
      groups: [
        for (var index = 0; index < item.groupsCount.clamp(1, 40); index++)
          InstitutionGroup(
            id: '${item.id}-unit-01-group-${(index + 1).toString().padLeft(2, '0')}',
            name: 'Turma ${(index + 1).toString().padLeft(2, '0')}',
          ),
      ],
    );
    return InstitutionRecord(
      id: item.id,
      publicName: item.publicName,
      tradeName: item.tradeName ?? '',
      legalName: item.legalName ?? '',
      typeId: item.typeId ?? '',
      typeName: item.typeName ?? '',
      documentType: 'CNPJ',
      document: '',
      slug: item.publicName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      primaryDomain: item.primaryDomain ?? '',
      status: item.status,
      locale: 'pt-BR',
      timezone: 'America/Sao_Paulo',
      postalCode: item.postalCode ?? '',
      country: 'Brasil',
      state: item.state ?? '',
      city: item.city ?? '',
      district: item.district ?? '',
      street: item.street ?? '',
      addressNumber: item.addressNumber ?? '',
      complement: item.complement ?? '',
      contactEmail: item.contactEmail ?? '',
      contactPhone: item.contactPhone ?? '',
      contactMobilePhone: item.contactMobilePhone ?? '',
      ownerFirstName: '',
      ownerLastName: '',
      ownerDisplayName: '',
      ownerEmail: '',
      ownerMobilePhone: '',
      plan: InstitutionPlan.values.firstWhere(
        (plan) => plan.id == item.planId,
        orElse: () => InstitutionPlan.essential,
      ),
      subscriptionStatus: InstitutionSubscriptionStatus.active,
      subscriptionStart: DateTime(2026, 1, 1),
      trialEnd: null,
      subscriptionJustification: '',
      brandDisplayName: item.publicName,
      hasSimulatedLogo: true,
      hasSimulatedCover: false,
      accentColor: '#D63C00',
      secondaryColor: '#3F4549',
      units: [unit],
    );
  }

  final String id;
  final String publicName;
  final String tradeName;
  final String legalName;
  final String typeId;
  final String typeName;
  final String documentType;
  final String document;
  final String slug;
  final String primaryDomain;
  final InstitutionStatus status;
  final String locale;
  final String timezone;
  final String postalCode;
  final String country;
  final String state;
  final String city;
  final String district;
  final String street;
  final String addressNumber;
  final String complement;
  final String contactEmail;
  final String contactPhone;
  final String contactMobilePhone;
  final String ownerFirstName;
  final String ownerLastName;
  final String ownerDisplayName;
  final String ownerEmail;
  final String ownerMobilePhone;
  final InstitutionPlan plan;
  final InstitutionSubscriptionStatus subscriptionStatus;
  final DateTime subscriptionStart;
  final DateTime? trialEnd;
  final String subscriptionJustification;
  final String brandDisplayName;
  final bool hasSimulatedLogo;
  final bool hasSimulatedCover;
  final String accentColor;
  final String secondaryColor;
  final List<InstitutionUnit> units;
  final String tertiaryColor;
  final String textColor;
  final String secondaryTextColor;
  final String tertiaryTextColor;
  final String surfaceColor;
  final String secondarySurfaceColor;
  final String profileBio;
  final List<InstitutionProfileLink> profileLinks;
  final String websiteUrl;
  final String whatsappNumber;
  final List<InstitutionLegalRepresentative> legalRepresentatives;
  final List<InstitutionAdministratorDraft> administrators;

  InstitutionDirectoryItem get directoryItem => InstitutionDirectoryItem(
    id: id,
    publicName: publicName,
    tradeName: tradeName,
    legalName: legalName,
    primaryDomain: primaryDomain,
    status: status,
    typeId: typeId,
    typeName: typeName,
    district: district,
    street: street,
    addressNumber: addressNumber,
    complement: complement,
    postalCode: postalCode,
    city: city,
    state: state,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    contactMobilePhone: contactMobilePhone,
    planId: plan.id,
    planName: plan.label,
    unitsCount: units.length,
    groupsCount: units.fold(0, (total, unit) => total + unit.groups.length),
  );

  InstitutionRecord copyWith({
    String? id,
    String? publicName,
    String? tradeName,
    String? legalName,
    String? typeId,
    String? typeName,
    String? documentType,
    String? document,
    String? slug,
    String? primaryDomain,
    InstitutionStatus? status,
    String? locale,
    String? timezone,
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
    String? ownerFirstName,
    String? ownerLastName,
    String? ownerDisplayName,
    String? ownerEmail,
    String? ownerMobilePhone,
    InstitutionPlan? plan,
    InstitutionSubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionStart,
    DateTime? trialEnd,
    bool clearTrialEnd = false,
    String? subscriptionJustification,
    String? brandDisplayName,
    bool? hasSimulatedLogo,
    bool? hasSimulatedCover,
    String? accentColor,
    String? secondaryColor,
    List<InstitutionUnit>? units,
    String? tertiaryColor,
    String? textColor,
    String? secondaryTextColor,
    String? tertiaryTextColor,
    String? surfaceColor,
    String? secondarySurfaceColor,
    String? profileBio,
    List<InstitutionProfileLink>? profileLinks,
    String? websiteUrl,
    String? whatsappNumber,
    List<InstitutionLegalRepresentative>? legalRepresentatives,
    List<InstitutionAdministratorDraft>? administrators,
  }) {
    return InstitutionRecord(
      id: id ?? this.id,
      publicName: publicName ?? this.publicName,
      tradeName: tradeName ?? this.tradeName,
      legalName: legalName ?? this.legalName,
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      documentType: documentType ?? this.documentType,
      document: document ?? this.document,
      slug: slug ?? this.slug,
      primaryDomain: primaryDomain ?? this.primaryDomain,
      status: status ?? this.status,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      district: district ?? this.district,
      street: street ?? this.street,
      addressNumber: addressNumber ?? this.addressNumber,
      complement: complement ?? this.complement,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      contactMobilePhone: contactMobilePhone ?? this.contactMobilePhone,
      ownerFirstName: ownerFirstName ?? this.ownerFirstName,
      ownerLastName: ownerLastName ?? this.ownerLastName,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerMobilePhone: ownerMobilePhone ?? this.ownerMobilePhone,
      plan: plan ?? this.plan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      trialEnd: clearTrialEnd ? null : trialEnd ?? this.trialEnd,
      subscriptionJustification: subscriptionJustification ?? this.subscriptionJustification,
      brandDisplayName: brandDisplayName ?? this.brandDisplayName,
      hasSimulatedLogo: hasSimulatedLogo ?? this.hasSimulatedLogo,
      hasSimulatedCover: hasSimulatedCover ?? this.hasSimulatedCover,
      accentColor: accentColor ?? this.accentColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      units: units ?? this.units,
      tertiaryColor: tertiaryColor ?? this.tertiaryColor,
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      tertiaryTextColor: tertiaryTextColor ?? this.tertiaryTextColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      secondarySurfaceColor: secondarySurfaceColor ?? this.secondarySurfaceColor,
      profileBio: profileBio ?? this.profileBio,
      profileLinks: profileLinks ?? this.profileLinks,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      legalRepresentatives: legalRepresentatives ?? this.legalRepresentatives,
      administrators: administrators ?? this.administrators,
    );
  }
}
