import 'package:coelo_domain/locations.dart';

/// Marcador sobre a planta (spec 067): ponto ou área em coordenadas relativas
/// (0..1) à imagem; opcionalmente vinculado a um local do catálogo.
final class LocationMapMarker {
  const LocationMapMarker({
    required this.id,
    required this.label,
    required this.shape,
    required this.x,
    required this.y,
    required this.visibility,
    required this.managementVersion,
    this.points = const [],
    this.locationId,
    this.locationName,
  });

  final String id;
  final String label;
  final LocationMapShape shape;
  final double x;
  final double y;

  /// Vértices da área (relativos), vazio para ponto.
  final List<(double, double)> points;
  final LocationMapVisibility visibility;
  final int managementVersion;
  final String? locationId;
  final String? locationName;

  factory LocationMapMarker.fromJson(Map<String, dynamic> json) => LocationMapMarker(
    id: json['id'].toString(),
    label: json['label']?.toString() ?? '',
    shape: json['shape'] == 'area' ? LocationMapShape.area : LocationMapShape.point,
    x: _double(json['x']),
    y: _double(json['y']),
    points: [
      for (final point in (json['points'] as List<dynamic>? ?? const []))
        if (point is List && point.length == 2) (_double(point[0]), _double(point[1])),
    ],
    visibility: LocationMapVisibility.values.firstWhere(
      (item) => item.name == json['visibility'],
      orElse: () => LocationMapVisibility.all,
    ),
    managementVersion: (json['management_version'] as num?)?.toInt() ?? 1,
    locationId: json['location_id']?.toString(),
    locationName: json['location_name']?.toString(),
  );
}

enum LocationMapShape { point, area }

enum LocationMapVisibility {
  all('Todos'),
  staff('Funcionários'),
  guardians('Responsáveis'),
  admin('Administração'),
  none('Ninguém');

  const LocationMapVisibility(this.label);
  final String label;
}

/// Local do catálogo oferecido para vincular a um marcador.
final class LocationMapLocationOption {
  const LocationMapLocationOption({required this.id, required this.name, this.floor});
  final String id;
  final String name;
  final String? floor;
}

final class LocationMap {
  const LocationMap({
    required this.ownerName,
    required this.markers,
    required this.locations,
    this.addressLine,
  });

  final String ownerName;

  /// Endereço puxado do cadastro (spec 067 §1); nulo quando não há.
  final String? addressLine;
  final List<LocationMapMarker> markers;
  final List<LocationMapLocationOption> locations;
}

/// Rascunho enviado ao servidor; `id` nulo cria.
final class LocationMapMarkerDraft {
  const LocationMapMarkerDraft({
    required this.label,
    required this.shape,
    required this.x,
    required this.y,
    required this.visibility,
    this.points = const [],
    this.locationId,
  });

  final String label;
  final LocationMapShape shape;
  final double x;
  final double y;
  final List<(double, double)> points;
  final LocationMapVisibility visibility;
  final String? locationId;
}

abstract interface class LocationMapReader {
  Future<LocationMap> fetchMap(LocationScope scope);
}

abstract interface class LocationMapWriter {
  Future<LocationMapMarker> saveMarker(
    LocationScope scope,
    LocationMapMarkerDraft draft, {
    required String requestId,
    String? markerId,
    int? expectedVersion,
  });

  Future<void> removeMarker(
    String markerId, {
    required String requestId,
    required int expectedVersion,
  });
}

final class LocationMapConflictException implements Exception {
  const LocationMapConflictException();
}

final class LocationMapUnavailableException implements Exception {
  const LocationMapUnavailableException();
}

double _double(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.tryParse(s) ?? 0,
  _ => 0,
};
