import 'package:coelo_superadmin/features/forms/data/development_forms_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development directory exposes local lifecycle actions', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(api: DevelopmentFormsApi.seeded(), canManage: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa anual das famílias'));
    await tester.pumpAndSettle();

    for (final action in const [
      'Duplicar',
      'Copiar para instituição',
      'Mover para instituição',
      'Arquivar',
      'Excluir',
    ]) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });
}
