import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/principal_shared/presentation/principal_runtime_context_route.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avatar keeps header visible and applies multiple contexts only on confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: PrincipalRuntimeContextRoute(
            repository: _Contexts(),
            avatarInitials: 'QA',
            multipleBuilder: (_, selected) => Text('Selected: ${selected.length}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vendo como'), findsNothing);
    expect(find.text('QA'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('principal-context-b')));
    await tester.pump();
    expect(find.text('Selected: 1'), findsOneWidget);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 2'), findsOneWidget);
    expect(find.byTooltip('Abrir menu do perfil'), findsOneWidget);
  });

  testWidgets('ver como only swaps the header avatar and name (ADR 0041 B9), without a fixed bar', (
    tester,
  ) async {
    resetPrincipalContextSelectionForTests();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: PrincipalRuntimeContextRoute(
            repository: _Contexts(),
            avatarInitials: 'QA',
            builder: (_, selected) => Text('Ativo: ${selected.institutionName}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Sem escolha explícita o cabeçalho segue a conta autenticada.
    expect(find.text('QA'), findsOneWidget);
    expect(find.byKey(const ValueKey('principal-context-header-context-label')), findsNothing);
    expect(find.text('Vendo como'), findsNothing);
    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    // Seletor de superfície branca no tema claro (ADR 0037).
    final sheet = tester.widget<Material>(
      find.ancestor(of: find.text('Ver como').last, matching: find.byType(Material)).first,
    );
    expect(sheet.color, CoeloPalette.neutral0);
    await tester.tap(find.byKey(const ValueKey('principal-context-b')));
    await tester.pumpAndSettle();
    expect(find.text('Ativo: QA b'), findsOneWidget);
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('principal-context-header-context-label')),
    );
    expect(label.data, 'QA b');
    expect(find.text('QB'), findsOneWidget);
    expect(find.text('QA'), findsNothing);
    expect(find.text('Vendo como'), findsNothing);
  });
}

class _Contexts implements PrincipalRuntimeContextRepository {
  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => [
    for (final id in ['a', 'b'])
      PrincipalRuntimeContext(
        membershipId: id,
        personId: 'qa',
        institutionId: id,
        institutionName: 'QA $id',
        roleCode: 'owner',
        scopeKind: 'institution',
      ),
  ];
}
