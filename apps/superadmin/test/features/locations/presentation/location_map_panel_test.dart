import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_map.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_map_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// spec 067: toque no mapa cria um ponto (coordenadas relativas), área junta
// três toques, marcador existente edita/remove; sem writer é só leitura.
void main() {
  testWidgets('tap creates a point marker with relative coordinates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeGateway();
    await tester.pumpWidget(_app(gateway, writer: gateway));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-map-empty')), findsOneWidget);

    final canvas = find.byKey(const Key('location-map-canvas'));
    final rect = tester.getRect(canvas);
    await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.top + rect.height * 0.5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-map-marker-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('location-map-marker-label')), 'Quadra');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-map-marker-save')));
    await tester.pumpAndSettle();

    expect(gateway.saved, hasLength(1));
    expect(gateway.saved.single.$1.shape, LocationMapShape.point);
    expect(gateway.saved.single.$1.x, closeTo(0.25, 0.02));
    expect(gateway.saved.single.$1.y, closeTo(0.5, 0.02));
    expect(find.text('Quadra'), findsWidgets);
  });

  testWidgets('area needs three taps and remove goes through the writer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeGateway();
    await tester.pumpWidget(_app(gateway, writer: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('location-map-draw-area')));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const Key('location-map-canvas')));
    for (final point in const [(0.1, 0.1), (0.9, 0.1), (0.5, 0.9)]) {
      await tester.tapAt(
        Offset(rect.left + rect.width * point.$1, rect.top + rect.height * point.$2),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('location-map-finish-area')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location-map-marker-label')), 'Pátio');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-map-marker-save')));
    await tester.pumpAndSettle();
    expect(gateway.saved.single.$1.shape, LocationMapShape.area);
    expect(gateway.saved.single.$1.points, hasLength(3));

    final id = gateway.markers.single.id;
    await tester.tap(find.byKey(Key('location-map-row-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-map-marker-remove')));
    await tester.pumpAndSettle();
    expect(gateway.removed, [id]);
    expect(find.byKey(const Key('location-map-empty')), findsOneWidget);
  });

  testWidgets('without writer the map is read-only', (tester) async {
    final gateway = _FakeGateway()
      ..markers.add(
        const LocationMapMarker(
          id: 'm1',
          label: 'Secretaria',
          shape: LocationMapShape.point,
          x: 0.5,
          y: 0.5,
          visibility: LocationMapVisibility.all,
          managementVersion: 1,
        ),
      );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    expect(find.text('Secretaria'), findsWidgets);
    expect(find.byKey(const Key('location-map-draw-area')), findsNothing);
    await tester.tap(find.byKey(const Key('location-map-row-m1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-map-marker-dialog')), findsNothing);
  });
}

Widget _app(LocationMapReader reader, {LocationMapWriter? writer}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      child: LocationMapPanel(
        scope: const LocationScope.unit(institutionId: 'inst-1', unitId: 'unit-1'),
        reader: reader,
        writer: writer,
        sessionAvailable: true,
      ),
    ),
  ),
);

final class _FakeGateway implements LocationMapReader, LocationMapWriter {
  final markers = <LocationMapMarker>[];
  final saved = <(LocationMapMarkerDraft, String?)>[];
  final removed = <String>[];
  var _next = 0;

  @override
  Future<LocationMap> fetchMap(LocationScope scope) async => LocationMap(
    ownerName: 'Unidade A1',
    addressLine: 'Rua A, 10',
    markers: List.of(markers),
    locations: const [LocationMapLocationOption(id: 'loc-1', name: 'Quadra')],
  );

  @override
  Future<LocationMapMarker> saveMarker(
    LocationScope scope,
    LocationMapMarkerDraft draft, {
    required String requestId,
    String? markerId,
    int? expectedVersion,
  }) async {
    saved.add((draft, markerId));
    final marker = LocationMapMarker(
      id: markerId ?? 'm${++_next}',
      label: draft.label,
      shape: draft.shape,
      x: draft.x,
      y: draft.y,
      points: draft.points,
      visibility: draft.visibility,
      managementVersion: (expectedVersion ?? 0) + 1,
      locationId: draft.locationId,
    );
    markers
      ..removeWhere((item) => item.id == marker.id)
      ..add(marker);
    return marker;
  }

  @override
  Future<void> removeMarker(
    String markerId, {
    required String requestId,
    required int expectedVersion,
  }) async {
    removed.add(markerId);
    markers.removeWhere((item) => item.id == markerId);
  }
}
