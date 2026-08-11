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
  essential('essential', 'Essencial'),
  professional('professional', 'Profissional'),
  complete('complete', 'Completo'),
  custom('custom', 'Personalizado');

  const InstitutionPlan(this.id, this.label);
  final String id;
  final String label;

  static InstitutionPlan fromCode(String? value) => switch (value) {
    'essential' => essential,
    'professional' => professional,
    'complete' => complete,
    'custom' => custom,
    _ => custom,
  };
}

InstitutionSubscriptionStatus _subscriptionStatusFromCode(String? value) => switch (value) {
  'active' => InstitutionSubscriptionStatus.active,
  'trial' => InstitutionSubscriptionStatus.trial,
  'paused' => InstitutionSubscriptionStatus.paused,
  'suspended' => InstitutionSubscriptionStatus.suspended,
  'canceled' || 'cancelled' => InstitutionSubscriptionStatus.canceled,
  'draft' => InstitutionSubscriptionStatus.draft,
  _ => InstitutionSubscriptionStatus.draft,
};

InstitutionStatus _institutionStatusFromCode(String? value) => switch (value) {
  'active' => InstitutionStatus.active,
  'onboarding' => InstitutionStatus.onboarding,
  'inactive' => InstitutionStatus.inactive,
  'suspended' => InstitutionStatus.suspended,
  'archived' => InstitutionStatus.archived,
  'draft' => InstitutionStatus.draft,
  _ => InstitutionStatus.draft,
};
int _toInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

String _toString(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

DateTime _toDateTime(Object? value, {DateTime? fallback}) {
  if (value is String) {
    return DateTime.parse(value);
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _toNullableDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}

Map<String, dynamic> _aggregate(Map<String, dynamic>? payload) {
  if (payload == null) return const {};
  return Map<String, dynamic>.from(payload);
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

List<InstitutionProfileLink> _profileLinksFromRpc(Object? value) {
  if (value is! List) {
    return const [];
  }

  return [
    for (final item in value)
      if (item is Map)
        InstitutionProfileLink(label: _toString(item['label']), url: _toString(item['url'])),
  ];
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
    this.trialEnd,
    this.subscriptionPausedAt,
    this.subscriptionCancelledAt,
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
    this.version = 0,
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

  factory InstitutionRecord.fromRpcPayload(Map<String, dynamic> payload) {
    final root = _aggregate(payload);
    final institutions = root.isNotEmpty && root['institutions'] is Map<String, dynamic>
        ? _aggregate(root['institutions'] as Map<String, dynamic>?)
        : const <String, dynamic>{};
    final source = institutions.isNotEmpty ? institutions : root;

    final institutionType = _aggregate(root['institution_type'] as Map<String, dynamic>?);
    final address = _aggregate(root['address'] as Map<String, dynamic>?);
    final contact = _aggregate(root['contact'] as Map<String, dynamic>?);
    final branding = _aggregate(root['branding'] as Map<String, dynamic>?);
    final subscription = _aggregate(root['subscription'] as Map<String, dynamic>?);
    final latestSubscription = _aggregate(root['latest_subscription'] as Map<String, dynamic>?);

    return InstitutionRecord(
      id: _toString(source['id']),
      publicName: _toString(source['public_name']),
      tradeName: _toString(source['trade_name'], fallback: _toString(source['public_name'])),
      legalName: _toString(source['legal_name']),
      typeId: _toString(institutionType['id'], fallback: _toString(source['institution_type_id'])),
      typeName: _toString(
        institutionType['name'],
        fallback: _toString(source['institution_type_name']),
      ),
      documentType: _toString(source['document_type']),
      document: _toString(source['document_ref'], fallback: _toString(source['document'])),
      slug: _toString(source['slug']),
      primaryDomain: _toString(source['primary_domain']),
      status: _institutionStatusFromCode(_toString(source['status'], fallback: 'draft')),
      locale: _toString(source['locale'], fallback: 'pt-BR'),
      timezone: _toString(source['timezone'], fallback: 'America/Sao_Paulo'),
      postalCode: _toString(address['postal_code']),
      country: _toString(address['country'], fallback: 'Brasil'),
      state: _toString(address['state']),
      city: _toString(address['city']),
      district: _toString(address['district']),
      street: _toString(address['street']),
      addressNumber: _toString(address['number'], fallback: _toString(address['address_number'])),
      complement: _toString(address['complement']),
      contactEmail: _toString(contact['email']),
      contactPhone: _toString(contact['phone']),
      contactMobilePhone: _toString(contact['mobile_phone']),
      ownerFirstName: _toString(source['owner_first_name']),
      ownerLastName: _toString(source['owner_last_name']),
      ownerDisplayName: _toString(source['owner_display_name']),
      ownerEmail: _toString(source['owner_email']),
      ownerMobilePhone: _toString(source['owner_mobile_phone']),
      plan: InstitutionPlan.fromCode(
        _toString(
          subscription['plan_code'],
          fallback: _toString(latestSubscription['plan_code'], fallback: 'custom'),
        ),
      ),
      subscriptionStatus: _subscriptionStatusFromCode(
        _toString(
          subscription['status'],
          fallback: _toString(
            subscription['subscription_status'],
            fallback: _toString(source['subscription_status']),
          ),
        ),
      ),
      subscriptionStart: _toDateTime(
        subscription['starts_at'] ??
            latestSubscription['subscription_start'] ??
            source['subscription_start'],
        fallback: DateTime(1970, 1, 1),
      ),
      trialEnd: _toNullableDateTime(
        subscription['trial_ends_at'] ?? latestSubscription['trial_end'],
      ),
      subscriptionPausedAt: _toNullableDateTime(subscription['paused_at']),
      subscriptionCancelledAt: _toNullableDateTime(subscription['cancelled_at']),
      subscriptionJustification: _toString(
        subscription['justification'],
        fallback: _toString(
          subscription['manual_reason'],
          fallback: _toString(latestSubscription['subscription_justification']),
        ),
      ),
      brandDisplayName: _toString(
        branding['display_name'],
        fallback: _toString(source['public_name']),
      ),
      hasSimulatedLogo: branding['logo_media_asset_id'] != null,
      hasSimulatedCover: branding['cover_media_asset_id'] != null,
      accentColor: _toString(branding['accent_color'], fallback: '#D63C00'),
      secondaryColor: _toString(branding['secondary_color'], fallback: '#3F4549'),
      units: const [],
      textColor: _toString(branding['text_color'], fallback: '#3F4549'),
      secondaryTextColor: _toString(branding['secondary_text_color'], fallback: '#3F4549'),
      tertiaryTextColor: _toString(branding['tertiary_text_color'], fallback: '#3F4549'),
      surfaceColor: _toString(branding['surface_color'], fallback: '#FFFFFF'),
      secondarySurfaceColor: '#F4F5F5',
      tertiaryColor: _toString(branding['tertiary_color'], fallback: '#D63C00'),
      profileBio: _toString(branding['profile_bio']),
      profileLinks: _profileLinksFromRpc(branding['profile_links']),
      websiteUrl: _toString(contact['website_url']),
      whatsappNumber: _toString(contact['whatsapp_number']),
      legalRepresentatives: const [],
      administrators: const [],
      version: _toInt(
        source['management_version'],
        fallback: _toInt(
          source['version'],
          fallback: _toInt(latestSubscription['management_version']),
        ),
      ),
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
  final DateTime? subscriptionPausedAt;
  final DateTime? subscriptionCancelledAt;
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
  final int version;

  bool get hasUnsupportedRelations => legalRepresentatives.isNotEmpty || administrators.isNotEmpty;

  bool get hasUnsupportedRemoteData =>
      hasUnsupportedRelations || secondarySurfaceColor != '#F4F5F5';

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

  Map<String, dynamic> toRpcPayload() {
    return {
      'public_name': publicName,
      'trade_name': tradeName,
      'legal_name': legalName,
      'slug': slug,
      'primary_domain': primaryDomain,
      'document_ref': document,
      'document_type': documentType,
      'status': status.databaseValue,
      'timezone': timezone,
      'locale': locale,
      'institution_type_name': typeName,
      'address': {
        'postal_code': postalCode,
        'country': country,
        'state': state,
        'city': city,
        'district': district,
        'street': street,
        'number': addressNumber,
        'complement': complement,
      },
      'contact': {
        'email': contactEmail,
        'phone': contactPhone,
        'mobile_phone': contactMobilePhone,
        'website_url': websiteUrl,
        'whatsapp_number': whatsappNumber,
      },
      'branding': {
        'display_name': brandDisplayName,
        'accent_color': accentColor,
        'secondary_color': secondaryColor,
        'tertiary_color': tertiaryColor,
        'text_color': textColor,
        'secondary_text_color': secondaryTextColor,
        'tertiary_text_color': tertiaryTextColor,
        'surface_color': surfaceColor,

        'profile_bio': profileBio,
        'profile_links': [
          for (final link in profileLinks) {'label': link.label, 'url': link.url},
        ],
      },
      'subscription': {
        'plan_code': plan.id,
        'status': subscriptionStatus == InstitutionSubscriptionStatus.canceled
            ? 'cancelled'
            : subscriptionStatus.name,
        'starts_at': subscriptionStart.toIso8601String(),
        'trial_ends_at': trialEnd?.toIso8601String(),
        'manual_reason': subscriptionJustification,
        'paused_at': subscriptionPausedAt?.toIso8601String(),
        'cancelled_at': subscriptionCancelledAt?.toIso8601String(),
      },
    };
  }

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
    DateTime? subscriptionPausedAt,
    DateTime? subscriptionCancelledAt,
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
    int? version,
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
      subscriptionPausedAt: subscriptionPausedAt ?? this.subscriptionPausedAt,
      subscriptionCancelledAt: subscriptionCancelledAt ?? this.subscriptionCancelledAt,
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
      version: version ?? this.version,
    );
  }
}
