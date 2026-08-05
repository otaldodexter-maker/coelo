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
    await tester.pumpWidget(_app(width: 1440));

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

  testWidgets('uses an accessible summary on compact layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(width: 375));

    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    expect(find.text('Etapa 2 de 3'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Identidade'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(MenuAnchor), findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('keeps the navigation vertical on medium layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(width: 768));

    final identity = tester.getRect(find.byKey(const Key('step-identidade')));
    final profile = tester.getRect(find.byKey(const Key('step-perfil')));
    expect(profile.left, identity.left);
    expect(profile.top, greaterThan(identity.bottom));
  });
}

Widget _app({required double width}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: SuperadminFormStepNavigation(
          currentIndex: 1,
          steps: const [
            SuperadminFormStep(label: 'Identidade', status: SuperadminFormStepStatus.complete),
            SuperadminFormStep(label: 'Perfil', status: SuperadminFormStepStatus.current),
            SuperadminFormStep(label: 'Revisão', status: SuperadminFormStepStatus.incomplete),
          ],
          onStepSelected: (_) {},
        ),
      ),
    ),
  ),
);
