import 'package:coelo_domain/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_map.dart';

/// Leitura e escrita dos marcadores do mapa (lote 96). O servidor resolve o
/// escopo por instituição e a visibilidade; aqui só se traduz o envelope.
final class SupabaseLocationMapGateway implements LocationMapReader, LocationMapWriter {
  SupabaseLocationMapGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<LocationMap> fetchMap(LocationScope scope) async {
    final data = await _call('superadmin_location_map_get_v1', _owner(scope));
    final owner = _map(data['owner']);
    final address = _map(owner['address']);
    final line = [
      address['street'],
      address['number'],
      address['district'],
      address['city'],
      address['state'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty).join(', ');
    return LocationMap(
      ownerName: owner['name']?.toString() ?? '',
      addressLine: line.isEmpty ? null : line,
      markers: [
        for (final item in (data['markers'] as List<dynamic>? ?? const []))
          LocationMapMarker.fromJson(_map(item)),
      ],
      locations: [
        for (final item in (data['locations'] as List<dynamic>? ?? const []))
          LocationMapLocationOption(
            id: _map(item)['id'].toString(),
            name: _map(item)['name']?.toString() ?? '',
            floor: _map(item)['floor']?.toString(),
          ),
      ],
    );
  }

  @override
  Future<LocationMapMarker> saveMarker(
    LocationScope scope,
    LocationMapMarkerDraft draft, {
    required String requestId,
    String? markerId,
    int? expectedVersion,
  }) async {
    final owner = _owner(scope);
    final data = await _call('superadmin_location_map_marker_save_v1', {
      'p_request_id': requestId,
      'p_marker_id': markerId,
      'p_expected_version': expectedVersion,
      'p_payload': {
        'owner_kind': owner['p_owner_kind'],
        'institution_id': owner['p_institution_id'],
        'unit_id': owner['p_unit_id'],
        'label': draft.label,
        'shape': draft.shape.name,
        'x': draft.x,
        'y': draft.y,
        'points': [
          for (final point in draft.points) [point.$1, point.$2],
        ],
        'visibility': draft.visibility.name,
        'location_id': draft.locationId,
      },
    });
    return LocationMapMarker.fromJson(data);
  }

  @override
  Future<void> removeMarker(
    String markerId, {
    required String requestId,
    required int expectedVersion,
  }) async {
    await _call('superadmin_location_map_marker_remove_v1', {
      'p_request_id': requestId,
      'p_marker_id': markerId,
      'p_expected_version': expectedVersion,
    });
  }

  Map<String, Object?> _owner(LocationScope scope) => switch (scope) {
    InstitutionLocationScope(:final institutionId) => {
      'p_owner_kind': 'institution',
      'p_institution_id': institutionId,
      'p_unit_id': null,
    },
    UnitLocationScope(:final institutionId, :final unitId) => {
      'p_owner_kind': 'unit',
      'p_institution_id': institutionId,
      'p_unit_id': unitId,
    },
  };

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> params) async {
    final Object? raw;
    try {
      raw = await _client.rpc<Object?>(name, params: params);
    } on Object {
      throw const LocationMapUnavailableException();
    }
    final envelope = _map(raw);
    if (envelope['ok'] == true) return _map(envelope['data']);
    final code = _map(envelope['error'])['code']?.toString();
    if (code == 'SAI_CONCURRENT_CHANGE') throw const LocationMapConflictException();
    throw const LocationMapUnavailableException();
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
