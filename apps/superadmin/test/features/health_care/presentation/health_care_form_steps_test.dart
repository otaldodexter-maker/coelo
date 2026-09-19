import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileChildren = [
  HealthCareProfileChildOption(id: 'child-demo-a', label: 'Criança Demo A'),
];

void main() {
  testWidgets('profile form navigates four steps and retains entered values', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          onCancel: () {},
          onSaved: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    for (final label in const [
      'Criança',
      'Alimentos',
      'Restrições',
      'Orientações de cuidado',
      'Revisão',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Adicionar alimento'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Anterior'), findsNothing);
    expect(find.text('Criar perfil'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar alimento'), findsOneWidget);
    // Sem catálogo injetado só "Outro" é oferecido, com texto obrigatório.
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-care-catalog-item-other')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('health-care-catalog-other-text')), 'Pitanga');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('health-care-catalog-confirm-other')));
    await tester.pumpAndSettle();
    expect(find.text('Pitanga'), findsOneWidget);
    expect(find.text('O que fazer se consumido?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('health-care-food-reaction-0')), 'Urticária leve');

    await tester.tap(find.text('Restrições').last);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar restrição'), findsOneWidget);

    await tester.tap(find.text('Orientações de cuidado').last);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar orientação'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);

    await tester.tap(find.text('Alimentos').last);
    await tester.pumpAndSettle();
    expect(find.text('Urticária leve'), findsOneWidget);

    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    expect(find.text('Criar perfil'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('1. Pitanga'), findsOneWidget);
  });

  testWidgets('medication form navigates five steps and saves only on review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const [
      'Criança e medicamento',
      'Vigência',
      'Horários e responsáveis',
      'Documento',
      'Revisão',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Data inicial'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Vigência').last);
    await tester.pumpAndSettle();
    expect(find.text('Data de início'), findsOneWidget);

    await tester.tap(find.text('Documento').last);
    await tester.pumpAndSettle();
    expect(find.text('Prescrição'), findsOneWidget);

    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    expect(find.text('Criar plano'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('stepped forms avoid overflow at $width with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final page in <Widget>[
        HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          onCancel: () {},
          onSaved: (_) async {},
        ),
        HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
