import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_directory_page.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/health_care_fixture_repository.dart';

/// As diretrizes nativas de toque, rotulo e contraste nao eram verificadas em
/// Saude e Cuidado nem em Medicacao. Mesmo padrao ja usado no shell, em Auth,
/// em Locais, no Perfil do Principal e agora em Formularios.
void main() {
  Future<void> check(
    WidgetTester tester,
    Widget Function(HealthCareController) build, {
    bool tapSize = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: Scaffold(body: build(controller))),
    );
    await tester.pumpAndSettle();
    if (tapSize) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }

  // R08: alvo do menu do usuario corrigido de 44 para 48 sob posse C0.
  // Os dois casos foram reativados depois de RED atual e GREEN, com
  // goldens preservados. Evidencia: 14-care-accessibility.md.
  testWidgets('the care profile directory meets tap size', (tester) async {
    await check(
      tester,
      (controller) => HealthCareProfileDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
      ),
    );
  });

  testWidgets('the medication plan directory meets tap size', (tester) async {
    await check(
      tester,
      (controller) => HealthMedicationPlanDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
      ),
    );
  });

  testWidgets('the care profile directory meets labelling and contrast', (tester) async {
    await check(
      tapSize: false,
      tester,
      (controller) => HealthCareProfileDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
      ),
    );
  });

  // Este caso preserva o recorte de rotulo/contraste do formulario.
  // Tamanho de toque dos diretorios e verificado nos casos acima.
  testWidgets('the care profile form meets labelling and contrast', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: HealthCareProfileFormPage(
            logout: unavailableSuperadminLogout,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the medication plan directory meets labelling and contrast', (tester) async {
    await check(
      tapSize: false,
      tester,
      (controller) => HealthMedicationPlanDirectoryPage(
        controller: controller,
        logout: unavailableSuperadminLogout,
        onCreate: () {},
      ),
    );
  });
}
