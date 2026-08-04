import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders completed current and pending steps with canonical semantics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Identidade, completa'), findsOneWidget);
    expect(find.bySemanticsLabel('Perfil, selecionada'), findsOneWidget);
    expect(find.bySemanticsLabel('Revisão, incompleta'), findsOneWidget);

    final current = tester.widget<TextButton>(find.byKey(const Key('step-perfil')));
    expect(
      current.style?.backgroundColor?.resolve({}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );
  });

  testWidgets('uses a compact progress summary without raw dropdown controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());

    expect(find.text('Etapa 2 de 3'), findsOneWidget);
    expect(find.text('Perfil'), findsWidgets);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
}

Widget _app() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: SuperadminFormStepNavigation(
      currentIndex: 1,
      steps: const [
        SuperadminFormStep(label: 'Identidade', status: SuperadminFormStepStatus.complete),
        SuperadminFormStep(label: 'Perfil', status: SuperadminFormStepStatus.current),
        SuperadminFormStep(label: 'Revisão', status: SuperadminFormStepStatus.incomplete),
      ],
      onStepSelected: (_) {},
    ),
  ),
);
