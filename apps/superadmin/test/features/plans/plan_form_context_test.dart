import 'dart:async';

import 'package:coelo_superadmin/features/plans/domain/plan_catalog.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/presentation/plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('same state reloads B and ignores a late A read', (tester) async {
    await _size(tester);
    final repository = _Repository();
    await tester.pumpWidget(_app(repository, 'a'));
    await tester.pump();
    await tester.pumpWidget(_app(repository, 'b'));
    await tester.pump();
    expect(repository.reads.keys, contains('b'));
    repository.reads['b']!.complete(_details('b'));
    await tester.pumpAndSettle();
    repository.reads['a']!.complete(_details('a'));
    await tester.pumpAndSettle();
    expect(find.text('Plano b'), findsOneWidget);
    expect(find.text('Plano a'), findsNothing);
    await _save(tester);
    expect(repository.commands.single.draft.id, 'b');
    expect(repository.commands.single.expectedRevision, 7);
    repository.saveResult.complete(_details('b'));
    await tester.pumpAndSettle();
  });

  testWidgets('repository swap clears loaded data even for the same ID', (tester) async {
    await _size(tester);
    final first = _Repository();
    final second = _Repository();
    await tester.pumpWidget(_app(first, 'a'));
    first.reads['a']!.complete(_details('a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(second, 'a'));
    await tester.pump();
    expect(find.text('Plano a'), findsNothing);
    expect(second.reads.keys, contains('a'));
    second.reads['a']!.completeError(
      const PlanRepositoryException(PlanRepositoryFailureKind.unauthorized, 'Negado'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  for (final failure in [false, true]) {
    testWidgets('late save cannot affect replacement B, failure=$failure', (tester) async {
      await _size(tester);
      final repository = _Repository();
      var saved = 0;
      await tester.pumpWidget(_app(repository, 'a', onSaved: () => saved++));
      repository.reads['a']!.complete(_details('a'));
      await tester.pumpAndSettle();
      await _save(tester);
      await tester.pumpWidget(_app(repository, 'b', onSaved: () => saved++));
      repository.reads['b']!.complete(_details('b'));
      await tester.pumpAndSettle();
      if (failure) {
        repository.saveResult.completeError(
          const PlanRepositoryException(PlanRepositoryFailureKind.conflict, 'Conflito antigo'),
        );
      } else {
        repository.saveResult.complete(_details('a'));
      }
      await tester.pumpAndSettle();
      expect(saved, 0);
      expect(find.text('Plano b'), findsOneWidget);
      expect(find.text('Plano a'), findsNothing);
      expect(
        find.text('O plano mudou desde que esta edição começou. Seu draft foi preservado.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('late save after dispose has no effect, failure=$failure', (tester) async {
      await _size(tester);
      final repository = _Repository();
      var saved = 0;
      await tester.pumpWidget(_app(repository, 'a', onSaved: () => saved++));
      repository.reads['a']!.complete(_details('a'));
      await tester.pumpAndSettle();
      await _save(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      if (failure) {
        repository.saveResult.completeError(
          const PlanRepositoryException(PlanRepositoryFailureKind.conflict, 'Conflito antigo'),
        );
      } else {
        repository.saveResult.complete(_details('a'));
      }
      await tester.pump();
      expect(saved, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('edit to create clears identity and step state', (tester) async {
    await _size(tester);
    final repository = _Repository();
    await tester.pumpWidget(_app(repository, 'a'));
    repository.reads['a']!.complete(_details('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(repository, null));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-name-field')), findsOneWidget);
    expect(find.text('Plano a'), findsNothing);
    expect(find.text('Instituições vinculadas'), findsNothing);
    final code = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('plan-code-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(code.enabled, isTrue);
    expect(code.controller!.text, isEmpty);
  });
}

Future<void> _size(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _app(_Repository repository, String? id, {VoidCallback? onSaved}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: PlanFormPage(repository: repository, planId: id, onSaved: onSaved),
  ),
);

Future<void> _save(WidgetTester tester) async {
  for (var step = 0; step < 4; step++) {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('plan-audit-reason-field')), 'Revisão autorizada.');
  await tester.tap(find.text('Salvar plano'));
  await tester.pump();
}

PlanDetails _details(String id) => PlanDetails(
  plan: PlanCatalog(
    id: id,
    name: 'Plano $id',
    code: id,
    description: 'Descrição $id',
    status: PlanStatus.active,
    features: const {PlanFeature.agenda},
    limits: const PlanLimits(units: 1, memberships: 100, storageGb: 10, mediaGb: 2),
    revision: 7,
  ),
);

final class _Repository implements PlanCatalogRepository {
  final reads = <String, Completer<PlanDetails>>{};
  final commands = <PlanSaveCommand>[];
  final saveResult = Completer<PlanDetails>();
  @override
  Future<PlanDetails> get(String planId) => (reads[planId] = Completer<PlanDetails>()).future;
  @override
  Future<PlanDetails> save(PlanSaveCommand command) {
    commands.add(command);
    return saveResult.future;
  }

  @override
  Future<PlanPage> list(PlanQuery query) => throw UnimplementedError();
}
