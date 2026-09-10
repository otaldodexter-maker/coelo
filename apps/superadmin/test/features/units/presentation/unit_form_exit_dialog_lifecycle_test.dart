import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixa o contrato do dialogo de saida de Unidades: uma confirmacao respondida
/// depois que o formulario saiu de cena nao pode acionar o callback da pagina.
///
/// Honestidade sobre o valor desta prova: este caso passa TAMBEM sem a guarda
/// de `mounted` adicionada em `_cancel`/`_selectDestination`, porque descartar a
/// pagina faz a rota do dialogo completar com `null` e o `confirmed` vira false
/// de qualquer forma. Ou seja, ele NAO e prova causal do defeito, ao contrario
/// dos dois casos de Instituicoes, que falham sem a correcao. Ele fixa o
/// comportamento para que uma futura rota de recarga em Unidades - que hoje nao
/// existe, veja `didUpdateWidget` - nao reintroduza o defeito em silencio.
void main() {
  testWidgets('exit confirmation answered after the form is disposed does not cancel (contrato, nao prova causal)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var cancelled = 0;
    await tester.pumpWidget(_app(onCancel: () => cancelled++));
    await _makeDirty(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-confirm-exit-dialog')), findsOneWidget);

    // The form leaves while the dialog is still open.
    await tester.pumpWidget(_dialogOnlyHost());
    await tester.pumpAndSettle();

    expect(cancelled, 0);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required VoidCallback onCancel}) => MaterialApp(
  theme: CoeloTheme.light,
  home: UnitFormPage(
    repository: FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
    logout: () async => const LogoutResult.success(),
    onCancel: onCancel,
    onSaved: (_) {},
  ),
);

Widget _dialogOnlyHost() =>
    MaterialApp(theme: CoeloTheme.light, home: const Scaffold(body: SizedBox.shrink()));

Future<void> _makeDirty(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('unit-form-continue')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('unit-name-field')), 'Unidade rascunho');
  await tester.pumpAndSettle();
}
