enum InstitutionStatus {
  draft('draft', 'Rascunho'),
  onboarding('onboarding', 'Em implantação'),
  active('active', 'Ativa'),
  inactive('inactive', 'Inativa'),
  suspended('suspended', 'Suspensa'),
  archived('archived', 'Arquivada');

  const InstitutionStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static InstitutionStatus fromDatabase(String value) {
    for (final status in values) {
      if (status.databaseValue == value) {
        return status;
      }
    }
    throw FormatException('Unknown institution status: $value');
  }
}

final class InstitutionDirectoryItem {
  const InstitutionDirectoryItem({
    required this.id,
    required this.publicName,
    required this.tradeName,
    required this.legalName,
    required this.primaryDomain,
    required this.status,
    required this.typeId,
    required this.typeName,
    required this.city,
    required this.state,
    required this.planId,
    required this.planName,
    required this.unitsCount,
    required this.groupsCount,
    this.district,
    this.street,
    this.addressNumber,
    this.complement,
    this.contactEmail,
    this.contactPhone,
    this.contactMobilePhone,
  });

  factory InstitutionDirectoryItem.fromJson(Map<String, dynamic> json) {
    return InstitutionDirectoryItem(
      id: _requiredString(json, 'id'),
      publicName: _requiredString(json, 'public_name'),
      tradeName: _optionalString(json['trade_name']),
      legalName: _optionalString(json['legal_name']),
      primaryDomain: _optionalString(json['primary_domain']),
      status: InstitutionStatus.fromDatabase(_requiredString(json, 'status')),
      typeId: _optionalString(json['institution_type_id']),
      typeName: _optionalString(json['type_name']),
      district: _optionalString(json['district']),
      street: _optionalString(json['street']),
      addressNumber: _optionalString(json['number']),
      complement: _optionalString(json['complement']),
      city: _optionalString(json['city']),
      state: _optionalString(json['state']),
      contactEmail: _optionalString(json['contact_email']),
      contactPhone: _optionalString(json['contact_phone']),
      contactMobilePhone: _optionalString(json['contact_mobile_phone']),
      planId: _optionalString(json['plan_id']),
      planName: _optionalString(json['plan_name']),
      unitsCount: _integer(json['units_count']),
      groupsCount: _integer(json['groups_count']),
    );
  }

  final String id;
  final String publicName;
  final String? tradeName;
  final String? legalName;
  final String? primaryDomain;
  final InstitutionStatus status;
  final String? typeId;
  final String? typeName;
  final String? district;
  final String? street;
  final String? addressNumber;
  final String? complement;
  final String? city;
  final String? state;
  final String? contactEmail;
  final String? contactPhone;
  final String? contactMobilePhone;
  final String? planId;
  final String? planName;
  final int unitsCount;
  final int groupsCount;

  String get initials {
    final words = publicName.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    final name = words.firstOrNull ?? '';
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.toUpperCase();
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) {
    throw FormatException('Expected a non-empty string for $key');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value;
}

int _integer(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected an integer count, got ${value.runtimeType}');
}
