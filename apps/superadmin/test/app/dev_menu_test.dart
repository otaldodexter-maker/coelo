import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'offers the floating dev menu on the login screen and opens fake institution preview',
    (tester) async {
      await tester.pumpWidget(const SuperadminApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Abrir menu de desenvolvimento'));
      await tester.pumpAndSettle();

      expect(find.text('Pré-visualizações'), findsOneWidget);
      await tester.tap(find.text('Instituições'));
      await tester.pumpAndSettle();

      final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devInstitutions);
      expect(find.text('Instituto Aurora'), findsOneWidget);
    },
  );
}
