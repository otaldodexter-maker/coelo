import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/data/demo_health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_detail_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile detail shows one navigable care section at a time', (tester) async {
    await _setViewport(tester, const Size(1440, 1000));
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);
    var edited = false;
    var plansOpened = false;

    await _pump(
      tester,
      HealthCareProfileDetailPage(
        controller: controller,
        childId: 'child-demo-a',
        logout: unavailableSuperadminLogout,
        onEditCareProfile: () => edited = true,
        onMedicationPlans: () => plansOpened = true,
      ),
    );

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.text('Resumo'), findsWidgets);
    expect(find.text('Alergias e restrições'), findsOneWidget);
    expect(find.text('Orientações de cuidado'), findsOneWidget);
    expect(find.text('Planos de medicação'), findsWidgets);
    expect(find.text('Criança Demo A'), findsOneWidget);
    expect(find.textContaining('Instituição Demo A'), findsOneWidget);
    expect(find.text('Alergia Medicamentosa Demo'), findsNothing);
    expect(find.text('Autismo'), findsNothing);
    expect(find.text('Ver planos da criança'), findsNothing);

    await tester.tap(find.text('Alergias e restrições'));
    await tester.pumpAndSettle();
    expect(find.text('Alergia Medicamentosa Demo'), findsOneWidget);
    expect(find.textContaining('Instituição Demo A'), findsNothing);

    await tester.tap(find.text('Orientações de cuidado'));
    await tester.pumpAndSettle();
    expect(find.text('Autismo'), findsOneWidget);
    expect(find.text('Alergia Medicamentosa Demo'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Planos de medicação'));
    await tester.pumpAndSettle();
    expect(find.text('Ver planos da criança'), findsOneWidget);

    await tester.tap(find.text('Ver planos da criança'));
    await tester.pump();
    expect(plansOpened, isTrue);

    await tester.tap(find.text('Editar perfil'));
    await tester.pump();
    expect(edited, isTrue);
  });

  testWidgets('profile detail keeps back and edit actions visible across sections', (tester) async {
    await _setViewport(tester, const Size(1440, 1000));
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-health-care-detail'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HealthCareProfileDetailPage(
                    controller: controller,
                    childId: 'child-demo-a',
                    logout: unavailableSuperadminLogout,
                    onEditCareProfile: () {},
                    onMedicationPlans: () {},
                  ),
                ),
              ),
              child: const Text('Abrir detalhe'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-health-care-detail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-care-profile-back')), findsOneWidget);
    expect(find.byKey(const Key('health-care-profile-edit')), findsOneWidget);

    await tester.tap(find.text('Alergias e restri\u00e7\u00f5es'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('health-care-profile-back')), findsOneWidget);
    expect(find.byKey(const Key('health-care-profile-edit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('health-care-profile-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-health-care-detail')), findsOneWidget);
  });

  testWidgets('compact detail keeps previous and next section actions accessible at 200%', (
    tester,
  ) async {
    await _setViewport(tester, const Size(375, 1000));
    final controller = HealthCareController(DemoHealthCareRepository());
    addTearDown(controller.dispose);

    await _pump(
      tester,
      HealthCareProfileDetailPage(
        controller: controller,
        childId: 'child-demo-a',
        logout: unavailableSuperadminLogout,
        onEditCareProfile: () {},
        onMedicationPlans: () {},
      ),
      textScale: 2,
    );

    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    expect(find.byKey(const Key('health-care-detail-previous-section')), findsOneWidget);
    expect(find.byKey(const Key('health-care-detail-next-section')), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
    expect(find.text('Próxima'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final next = find.byKey(const Key('health-care-detail-next-section'));
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Alergia Medicamentosa Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Autismo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: appChild!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
