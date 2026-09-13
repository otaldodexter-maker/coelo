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
