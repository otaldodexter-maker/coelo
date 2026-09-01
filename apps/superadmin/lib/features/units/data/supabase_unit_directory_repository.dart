import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../institutions/domain/institution_directory_item.dart';
import '../../institutions/domain/institution_record.dart';
import '../domain/unit_directory.dart';
import 'unavailable_unit_composition.dart';

final class SupabaseUnitDirectoryRepository implements UnitDirectoryRepository {
  SupabaseUnitDirectoryRepository(this._client);

  final SupabaseClient _client;
  final Map<String, UnitRecord> _cache = {};
  final Map<String, String> _planIdsByCode = {};

  @override
  List<UnitRecord> get records => List.unmodifiable(_cache.values);

  @override
  UnitRecord? findById(String id) => _cache[id];

  @override
  String createId(String institutionId, String slug) => _uuidV4();

  @override
  Future<void> upsert(UnitRecord record) async {
    final payload = _payload(record, _planIdsByCode);
    try {
      final response = record.managementVersion == 0
          ? await _client.rpc<Object?>(
              'create_unit_for_superadmin',
              params: {'p_request_id': _uuidV4(), 'p_payload': payload},
            )
          : await _client.rpc<Object?>(
              'update_unit_for_superadmin',
              params: {
                'p_request_id': _uuidV4(),
                'p_payload': payload,
                'p_unit_id': record.id,
                'p_expected_version': record.managementVersion,
              },
            );
      final saved = _record(_map(response), fallbackInstitution: record.institution);
      _cache[saved.id] = saved;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const UnavailableUnitDirectoryException();
    }
  }

  @override
  Future<UnitFormData> loadForm({String? unitId}) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>('get_unit_form_for_superadmin', params: {'p_unit_id': unitId}),
      );
      if (payload['not_found'] == true) {
        throw const UnavailableUnitDirectoryException();
      }
      final institutions = _rows(payload['institutions']).map(_institution).toList(growable: false);
      final unitTypes = _options(payload['unit_types']);
      for (final plan in _rows(payload['plans'])) {
        final code = plan['code'] as String?;
        final id = plan['id'] as String?;
        if (code != null && id != null) _planIdsByCode[code] = id;
      }
      final unitPayload = payload['unit'];
      UnitRecord? record;
      if (unitPayload is Map) {
        final row = Map<String, dynamic>.from(unitPayload);
        final institutionId = row['institution_id'] as String?;
        final parent = institutions.where((item) => item.id == institutionId).firstOrNull;
        record = _record(row, fallbackInstitution: parent);
        _cache[record.id] = record;
      }
      return UnitFormData(institutions: institutions, unitTypes: unitTypes, record: record);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const UnavailableUnitDirectoryException();
    }
  }

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'list_units_for_superadmin',
          params: {
            'p_search': query.search.trim(),
            'p_institution_ids': query.institutionIds.toList(growable: false),
            'p_institution_type_ids': query.institutionTypeIds.toList(growable: false),
            'p_unit_type_ids': query.unitTypeIds.toList(growable: false),
            'p_unit_statuses': query.statuses.map((item) => item.databaseValue).toList(),
            'p_plan_ids': query.planIds.toList(growable: false),
            'p_states': query.states.toList(growable: false),
            'p_cities': query.cities.toList(growable: false),
            'p_districts': query.districts.toList(growable: false),
            'p_sort': _sort(query.sortColumn),
            'p_ascending': query.sortAscending,
            'p_offset': query.offset,
            'p_limit': query.pageSize,
          },
        ),
      );
      final items = <UnitDirectoryItem>[];
      for (final row in _rows(payload['items'])) {
        final record = _record(row);
        _cache[record.id] = record;
        items.add(UnitDirectoryItem(record));
      }
      return UnitDirectoryPage(
        items: items,
        totalCount: _int(payload['total_count']),
        page: query.page,
        pageSize: query.pageSize,
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const UnavailableUnitDirectoryException();
    }
  }

  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    try {
      final payload = _map(
        await _client.rpc<Object?>(
          'unit_directory_filter_options',
          params: {
            'p_states': states.toList(growable: false),
            'p_cities': cities.toList(growable: false),
          },
        ),
      );
      return UnitDirectoryFilterOptions(
        institutions: _options(payload['institutions']),
        types: _options(payload['unit_types']),
        plans: _options(payload['plans']),
        states: _options(payload['states']),
        cities: _options(payload['cities']),
        districts: _options(payload['districts']),
      );
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on ClientException {
      throw const UnavailableUnitDirectoryException();
    }
  }
}

InstitutionRecord _institution(Map<String, dynamic> row) {
  final type = _mapOrEmpty(row['institution_type']);
  final plan = _mapOrEmpty(row['effective_plan']);
  return InstitutionRecord.fromDirectoryItem(
    InstitutionDirectoryItem(
      id: _string(row, 'institution_id'),
      publicName: _string(row, 'institution_name'),
      tradeName: null,
      legalName: null,
      primaryDomain: null,
      status: InstitutionStatus.active,
      typeId: type['id'] as String?,
      typeName: (type['label'] ?? type['name']) as String?,
      city: null,
      state: null,
      planId: (plan['code'] ?? plan['id']) as String?,
      planName: plan['label'] as String?,
      unitsCount: 0,
      groupsCount: 0,
    ),
  ).copyWith(units: const []);
}

UnitRecord _record(Map<String, dynamic> row, {InstitutionRecord? fallbackInstitution}) {
  final institutionId = _string(row, 'institution_id');
  final effectivePlan = _mapOrEmpty(row['effective_plan']);
  final parent =
      fallbackInstitution ??
      InstitutionRecord.fromDirectoryItem(
        InstitutionDirectoryItem(
          id: institutionId,
          publicName: _string(row, 'institution_name'),
          tradeName: null,
          legalName: null,
          primaryDomain: null,
          status: InstitutionStatus.active,
          typeId: _mapOrEmpty(row['institution_type'])['id'] as String?,
          typeName: _mapOrEmpty(row['institution_type'])['label'] as String?,
          city: null,
          state: null,
          planId: (effectivePlan['code'] ?? effectivePlan['id']) as String?,
          planName: effectivePlan['label'] as String?,
          unitsCount: 0,
          groupsCount: 0,
        ),
      ).copyWith(units: const []);
  final address = _mapOrEmpty(row['address']);
  final contact = _mapOrEmpty(row['contact']);
  final branding = _mapOrEmpty(row['branding']);
  final unitType = _mapOrEmpty(row['unit_type']);
  final inheritedPlan = effectivePlan['inherited'] != false;
  return UnitRecord(
    institution: parent,
    managementVersion: _int(row['management_version']),
    unit: InstitutionUnit(
      id: _string(row, 'id'),
      name: _string(row, 'name'),
      slug: row['slug'] as String? ?? '',
      status: UnitStatus.values.firstWhere(
        (item) => item.databaseValue == row['unit_status'],
        orElse: () => UnitStatus.draft,
      ),
      typeId: unitType['id'] as String? ?? '',
      typeName: unitType['label'] as String? ?? '',
      postalCode: address['postal_code'] as String? ?? '',
      country: address['country'] as String? ?? 'BR',
      state: address['state'] as String? ?? '',
      city: address['city'] as String? ?? '',
      district: address['district'] as String? ?? '',
      street: address['street'] as String? ?? '',
      addressNumber: address['number'] as String? ?? '',
      complement: address['complement'] as String? ?? '',
      contactEmail: contact['email'] as String? ?? '',
      contactPhone: contact['phone'] as String? ?? '',
      contactMobilePhone: contact['mobile_phone'] as String? ?? '',
      planOverride: inheritedPlan
          ? null
          : InstitutionPlan.fromCode(effectivePlan['code'] as String?),
      inheritInstitutionBranding: branding['inherit_institution_branding'] != false,
      brandDisplayName: branding['display_name'] as String? ?? row['name'] as String? ?? '',
      hasSimulatedLogo: branding['logo_media_asset_id'] != null,
      hasSimulatedCover: branding['cover_media_asset_id'] != null,
      accentColor: branding['accent_color'] as String? ?? '#D63C00',
      secondaryColor: branding['secondary_color'] as String? ?? '#3F4549',
      textColor: branding['text_color'] as String? ?? '#3F4549',
      surfaceColor: branding['surface_color'] as String? ?? '#FFFFFF',
      activitiesCount: _int(row['activities_count']),
      groups: [
        for (var index = 0; index < _int(row['groups_count']); index++)
          InstitutionGroup(id: '${row['id']}-group-$index', name: ''),
      ],
    ),
  );
}

Map<String, Object?> _payload(UnitRecord record, Map<String, String> planIdsByCode) => {
  'institution_id': record.institutionId,
  'name': record.name.trim(),
  'slug': record.slug.trim().toLowerCase(),
  'unit_status': record.status.databaseValue,
  'unit_type_id': record.typeId,
  'plan_override_id': record.planOverride == null ? null : planIdsByCode[record.planOverride!.id],
  'address': {
    'postal_code': record.postalCode,
    'country': record.country,
    'state': record.state,
    'city': record.city,
    'district': record.district,
    'street': record.street,
    'number': record.addressNumber,
    'complement': record.complement,
  },
  'contact': {
    'email': record.contactEmail,
    'phone': record.contactPhone,
    'mobile_phone': record.contactMobilePhone,
  },
  'branding': {
    'display_name': record.brandDisplayName,
    'accent_color': record.accentColor,
    'secondary_color': record.secondaryColor,
    'text_color': record.textColor,
    'surface_color': record.surfaceColor,
    'inherit_institution_branding': record.inheritInstitutionBranding,
  },
  'inheritance': {
    'address': false,
    'contact': false,
    'branding': record.inheritInstitutionBranding,
    'logo': record.inheritInstitutionBranding,
    'cover': record.inheritInstitutionBranding,
    'surface_colors': record.inheritInstitutionBranding,
    'brand_colors': record.inheritInstitutionBranding,
    'text_colors': record.inheritInstitutionBranding,
    'representatives': true,
    'administrators': true,
  },
};

String _sort(UnitDirectorySortColumn column) => switch (column) {
  UnitDirectorySortColumn.name => 'name',
  UnitDirectorySortColumn.institutionName => 'institution_name',
  UnitDirectorySortColumn.institutionTypeName => 'institution_type_name',
  UnitDirectorySortColumn.typeName => 'unit_type_name',
  UnitDirectorySortColumn.groupsCount => 'groups_count',
  UnitDirectorySortColumn.activitiesCount => 'activities_count',
  UnitDirectorySortColumn.planName => 'plan_name',
  UnitDirectorySortColumn.status => 'unit_status',
  UnitDirectorySortColumn.contactEmail => 'contact_email',
  UnitDirectorySortColumn.contactPhone => 'contact_phone',
  UnitDirectorySortColumn.contactMobilePhone => 'contact_mobile_phone',
  UnitDirectorySortColumn.street => 'street',
  UnitDirectorySortColumn.addressNumber => 'address_number',
  UnitDirectorySortColumn.complement => 'complement',
  UnitDirectorySortColumn.district => 'district',
  UnitDirectorySortColumn.postalCode => 'postal_code',
  UnitDirectorySortColumn.city => 'city',
  UnitDirectorySortColumn.state => 'state',
};

List<UnitFilterOption> _options(Object? value) => _rows(
  value,
).map((row) => UnitFilterOption(_string(row, 'id'), _string(row, 'label'))).toList(growable: false);

Map<String, dynamic> _map(Object? value) {
  if (value is Map<Object?, Object?>) return Map<String, dynamic>.from(value);
  if (value is String) return Map<String, dynamic>.from(jsonDecode(value) as Map);
  throw const UnavailableUnitDirectoryException();
}

Map<String, dynamic> _mapOrEmpty(Object? value) =>
    value is Map<Object?, Object?> ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().map((row) => Map<String, dynamic>.from(row)).toList()
    : const [];

String _string(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is String && value.isNotEmpty) return value;
  throw const UnavailableUnitDirectoryException();
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

Exception _mapError(PostgrestException error) => switch (error.code) {
  '42501' || 'PGRST301' => const UnitDirectoryUnauthorizedException(),
  _ => const UnavailableUnitDirectoryException(),
};

String _uuidV4() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
