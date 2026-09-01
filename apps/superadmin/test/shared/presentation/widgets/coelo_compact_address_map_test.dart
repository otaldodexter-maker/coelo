import 'package:coelo_superadmin/shared/presentation/widgets/coelo_compact_address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact map exposes marker and OpenStreetMap attribution', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CoeloCompactAddressMap(latitude: -23.5505, longitude: -46.6333)),
      ),
    );

    expect(find.byKey(const Key('coelo-address-map-marker')), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
  });

  testWidgets('compact map rejects invalid coordinates without requesting tiles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CoeloCompactAddressMap(latitude: 91, longitude: 181))),
    );

    expect(find.text('Localização ainda não encontrada'), findsOneWidget);
    expect(find.byKey(const Key('coelo-address-map-marker')), findsNothing);
  });
}
