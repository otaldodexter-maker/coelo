enum UnitDetailFailure { invalidId, denied, unavailable }

final class UnitDetailException implements Exception {
  const UnitDetailException(this.failure);
  final UnitDetailFailure failure;
  @override
  String toString() => 'UnitDetailException(${failure.name})';
}

abstract interface class UnitDetailRepository {
  Future<UnitDetail> fetchById(String unitId);
}

final class UnavailableUnitDetailRepository implements UnitDetailRepository {
  const UnavailableUnitDetailRepository();
  @override
  Future<UnitDetail> fetchById(String unitId) async =>
      throw const UnitDetailException(UnitDetailFailure.unavailable);
}

final class UnitDetailType {
  const UnitDetailType({required this.id, required this.name});
  final String id;
  final String name;
  factory UnitDetailType.fromJson(Object? value) {
    final data = _map(value, const {'id', 'name'});
    return UnitDetailType(id: _uuid(data['id']), name: _string(data['name']));
  }
}

final class UnitDetailPlan {
  const UnitDetailPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.inherited,
  });
  final String id;
  final String code;
  final String name;
  final bool inherited;
  factory UnitDetailPlan.fromJson(Object? value) {
    final data = _map(value, const {'id', 'code', 'name', 'inherited'});
    final inherited = data['inherited'];
    if (inherited is! bool) throw const FormatException('Invalid unit detail');
    return UnitDetailPlan(
      id: _uuid(data['id']),
      code: _string(data['code']),
      name: _string(data['name']),
      inherited: inherited,
    );
  }
}

/// Read-only spec 043 payload. Absence is preserved, never replaced with a plan
/// default, branding, counters or guessed relationship data.
final class UnitDetail {
  UnitDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.institutionId,
    required this.institutionName,
    required this.institutionType,
    required this.unitType,
    required Map<String, String?>? address,
    required Map<String, String?>? contact,
    required this.effectivePlan,
  }) : address = address == null ? null : Map.unmodifiable(address),
       contact = contact == null ? null : Map.unmodifiable(contact);

  final String id;
  final String name;
  final String slug;
  final String status;
  final String institutionId;
  final String institutionName;
  final UnitDetailType? institutionType;
  final UnitDetailType unitType;
  final Map<String, String?>? address;
  final Map<String, String?>? contact;
  final UnitDetailPlan? effectivePlan;

  factory UnitDetail.fromJson(Object? value) {
    final data = _map(value, const {
      'id',
      'name',
      'slug',
      'status',
      'institution',
      'unit_type',
      'address',
      'contact',
      'effective_plan',
    });
    final institution = _map(data['institution'], const {'id', 'name', 'type'});
    final status = _string(data['status']);
    if (!const {'draft', 'active', 'inactive', 'suspended', 'archived'}.contains(status)) {
      throw const FormatException('Invalid unit detail');
    }
    final address = _nullableTextMap(data['address'], const {
      'country',
      'state',
      'city',
      'district',
      'street',
      'number',
      'complement',
      'postal_code',
    });
    if (address != null && address['country'] == null) {
      throw const FormatException('Invalid unit detail');
    }
    return UnitDetail(
      id: _uuid(data['id']),
      name: _string(data['name']),
      slug: _string(data['slug']),
      status: status,
      institutionId: _uuid(institution['id']),
      institutionName: _string(institution['name']),
      institutionType: institution['type'] == null
          ? null
          : UnitDetailType.fromJson(institution['type']),
      unitType: UnitDetailType.fromJson(data['unit_type']),
      address: address,
      contact: _nullableTextMap(data['contact'], const {'email', 'phone', 'mobile_phone'}),
      effectivePlan: data['effective_plan'] == null
          ? null
          : UnitDetailPlan.fromJson(data['effective_plan']),
    );
  }
}

bool isUnitDetailId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

Map<String, Object?> _map(Object? value, Set<String> keys) {
  if (value is! Map || value.length != keys.length || !keys.every(value.containsKey)) {
    throw const FormatException('Invalid unit detail');
  }
  return Map<String, Object?>.from(value);
}

Map<String, String?>? _nullableTextMap(Object? value, Set<String> keys) {
  if (value == null) return null;
  final data = _map(value, keys);
  return data.map((key, value) => MapEntry(key, value == null ? null : _string(value)));
}

String _string(Object? value) =>
    value is String ? value : throw const FormatException('Invalid unit detail');
String _uuid(Object? value) {
  final id = _string(value);
  if (!isUnitDetailId(id)) throw const FormatException('Invalid unit detail');
  return id;
}
