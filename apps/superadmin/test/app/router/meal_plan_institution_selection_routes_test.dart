import 'dart:convert';

import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_wizard_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scenario in ['unselected', 'selected', 'denied', 'unavailable']) {
    testWidgets('model route resolves institution from repository: $scenario', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saves = <Map<String, dynamic>>[];
      final reads = <String>[];
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://meal-plans.invalid',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final rpc = request.url.pathSegments.last;
            if (rpc == 'meal_plan_template_save') {
              saves.add(jsonDecode(request.body) as Map<String, dynamic>);
              return http.Response(
                jsonEncode({'code': '42501', 'message': 'synthetic permission denied'}),
                403,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            reads.add(rpc);
            if (rpc == 'meal_plan_audience_options') {
              if (scenario == 'unavailable') {
                throw http.ClientException('synthetic unavailable');
              }
              if (scenario == 'denied') {
                return http.Response(
                  jsonEncode({'code': '42501', 'message': 'synthetic permission denied'}),
                  403,
                  headers: {'content-type': 'application/json'},
                  request: request,
                );
              }
              return http.Response(
                jsonEncode({
                  'institutions': [
                    {'id': 'institution-a', 'label': 'Instituição sintética A'},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (rpc == 'meal_plan_template_list') {
              return http.Response(
                jsonEncode({'items': <Object?>[], 'total': 0}),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            throw StateError('Unexpected RPC: $rpc');
          }),
        ),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      final session = SuperadminSession()..signInForTesting();
      final router = createSuperadminRouter(
        session: session,
        login: unavailableSuperadminLogin,
        logout: unavailableSuperadminLogout,
        requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
        mealPlanRepository: SupabaseMealPlanRepository(client),
        onThemeModeChanged: (_) {},
      );
      addTearDown(router.dispose);
      addTearDown(session.dispose);
      router.go('/meal-plans/models/new');
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();

      expect(tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage)).tenantId, '');
      expect(reads, containsAll(['meal_plan_audience_options', 'meal_plan_template_list']));
      expect(saves, isEmpty);
      if (scenario == 'denied') {
        expect(find.text('Voce nao tem acesso aos cardapios.'), findsOneWidget);
      }
      if (scenario == 'unavailable') {
        expect(find.text('Cardapios indisponiveis no momento.'), findsOneWidget);
      }
      await tester.enterText(find.byType(TextFormField).first, 'Modelo sintético');
      if (scenario == 'selected') {
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is CoeloAdminMultiSelectField<String> &&
              widget.label == 'Instituição do modelo',
        );
        await tester.tap(find.descendant(of: field, matching: find.text('Selecionar')));
        await tester.pumpAndSettle();
        expect(find.text('Instituição sintética B'), findsNothing);
        await tester.tap(find.text('Instituição sintética A').last);
        await tester.pumpAndSettle();
        await _tap(tester, find.widgetWithText(FilledButton, 'Aplicar'));
      }
      await _tap(tester, find.widgetWithText(FilledButton, 'Continuar'));
      await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
      await _tap(tester, find.widgetWithText(FilledButton, 'Continuar'));
      await _tap(tester, find.widgetWithText(OutlinedButton, 'Salvar rascunho'));

      if (scenario == 'selected') {
        expect(saves, hasLength(1));
        expect(saves.single['p_payload']['tenantId'], 'institution-a');
        expect(saves.single['p_payload']['institutionId'], 'institution-a');
        expect(saves.single['p_publish'], isFalse);
        expect(find.text('Voce nao tem acesso aos cardapios.'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/meal-plans/models/new');
      } else {
        expect(saves, isEmpty);
        expect(find.text('Selecione a instituição autorizada do modelo.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
