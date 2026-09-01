import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

typedef CoeloAddressCoordinates = ({double latitude, double longitude});

/// Municipality-center fallback used only as an explicitly approximate preview.
CoeloAddressCoordinates? coeloApproximateAddressCoordinates({
  required String city,
  required String state,
}) {
  final key = '${city.trim().toLowerCase()}|${state.trim().toUpperCase()}';
  return _municipalityCenters[key];
}

const _municipalityCenters = <String, CoeloAddressCoordinates>{
  'são paulo|SP': (latitude: -23.5505, longitude: -46.6333),
  'campinas|SP': (latitude: -22.9056, longitude: -47.0608),
  'curitiba|PR': (latitude: -25.4284, longitude: -49.2733),
  'belo horizonte|MG': (latitude: -19.9167, longitude: -43.9345),
  'recife|PE': (latitude: -8.0476, longitude: -34.8770),
  'goiânia|GO': (latitude: -16.6869, longitude: -49.2648),
  'florianópolis|SC': (latitude: -27.5949, longitude: -48.5482),
  'salvador|BA': (latitude: -12.9777, longitude: -38.5016),
  'rio de janeiro|RJ': (latitude: -22.9068, longitude: -43.1729),
  'porto alegre|RS': (latitude: -30.0346, longitude: -51.2177),
  'fortaleza|CE': (latitude: -3.7319, longitude: -38.5267),
  'brasília|DF': (latitude: -15.7939, longitude: -47.8828),
};

/// Compact, read-only address preview shared by administrative forms.
final class CoeloCompactAddressMap extends StatelessWidget {
  const CoeloCompactAddressMap({required this.latitude, required this.longitude, super.key});

  final double latitude;
  final double longitude;

  bool get _valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  @override
  Widget build(BuildContext context) {
    if (!_valid) {
      return Container(
        key: const Key('coelo-address-map-unavailable'),
        constraints: const BoxConstraints(minHeight: 112),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined),
            SizedBox(width: CoeloSpacing.space2),
            Flexible(child: Text('Localização ainda não encontrada')),
          ],
        ),
      );
    }

    final point = LatLng(latitude, longitude);
    return Semantics(
      label: 'Mapa compacto do endereço informado',
      image: true,
      child: SizedBox(
        height: 184,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'me.coelo.superadmin',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: CoeloSize.touchMin,
                    height: CoeloSize.touchMin,
                    child: Icon(
                      Icons.location_pin,
                      key: const Key('coelo-address-map-marker'),
                      color: Theme.of(context).colorScheme.primary,
                      size: CoeloSize.iconLg,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
