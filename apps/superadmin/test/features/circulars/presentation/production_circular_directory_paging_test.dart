import 'dart:async';

import 'package:coelo_superadmin/features/circulars/domain/superadmin_circular_repository.dart';
import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_superadmin/features/circulars/presentation/production_circular_hosts.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paginacao do diretorio produtivo de Circulares.
///
/// O diretorio busca, filtra por aba e pagina na propria pagina, sobre a lista
/// que recebe do hospedeiro. O hospedeiro lia UMA pagina e ignorava o cursor
/// devolvido pelo servidor, entao tudo o que estivesse alem dela sumia em
/// silencio: procurar uma Circular antiga simplesmente nao encontrava nada.
void main() {
  testWidgets('segue o cursor do servidor ate acabar', (tester) async {
    final repository = _PagedRepository(pages: 3);
    await _pumpHost(tester, repository);

    expect(repository.calls, hasLength(3));
    expect(repository.calls.first.cursorId, isNull);
    expect(repository.calls[1].cursorId, 'item-0-19');
    expect(repository.calls[2].cursorId, 'item-1-19');
    expect(
      tester.widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage)).items,
      hasLength(60),
    );
    expect(find.byKey(const Key('circular-directory-truncated')), findsNothing);
  });

  testWidgets('uma unica pagina nao dispara leitura extra', (tester) async {
    final repository = _PagedRepository(pages: 1);
    await _pumpHost(tester, repository);

    expect(repository.calls, hasLength(1));
    expect(
      tester.widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage)).items,
      hasLength(20),
    );
  });

  testWidgets('mostra a primeira pagina antes de terminar de seguir o cursor', (tester) async {
    final gate = Completer<void>();
    final repository = _PagedRepository(pages: 3, holdFrom: 1, gate: gate);
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ProductionCircularDirectoryHost(
            repository: repository,
            onOpen: (_) {},
            onCreate: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // A segunda leitura esta retida de proposito: a tela ja precisa mostrar a
    // primeira pagina em vez de esperar todas.
    final page = tester.widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage));
    expect(page.viewState, CircularDirectoryViewState.content);
    expect(page.items, hasLength(20));

    gate.complete();
    await tester.pumpAndSettle();

    expect(
      tester.widget<CircularDirectoryPage>(find.byType(CircularDirectoryPage)).items,
      hasLength(60),
    );
  });

  testWidgets('ao atingir o teto diz a verdade em vez de truncar em silencio', (tester) async {
    final repository = _PagedRepository(pages: 50);
    await _pumpHost(tester, repository);

    expect(repository.calls, hasLength(10), reason: 'o teto de paginas protege a tela');
    expect(find.byKey(const Key('circular-directory-truncated')), findsOneWidget);
    expect(find.textContaining('mais recentes'), findsOneWidget);
  });
}

Future<void> _pumpHost(WidgetTester tester, _PagedRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: ProductionCircularDirectoryHost(
          repository: repository,
          onOpen: (_) {},
          onCreate: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _PagedRepository implements SuperadminCircularRepository {
  _PagedRepository({required this.pages, this.holdFrom, this.gate});

  final int pages;

  /// Retem as leituras a partir deste indice ate [gate] completar, para provar
  /// que a tela nao espera todas as paginas.
  final int? holdFrom;
  final Completer<void>? gate;
  final calls = <SuperadminCircularDirectoryQuery>[];

  @override
  Future<SuperadminCircularDirectoryPage> fetchDirectory(
    SuperadminCircularDirectoryQuery query,
  ) async {
    calls.add(query);
    final index = calls.length - 1;
    if (holdFrom != null && index >= holdFrom! && gate != null) await gate!.future;
    final last = index >= pages - 1;
    return SuperadminCircularDirectoryPage(
      items: [
        for (var i = 0; i < 20; i++)
          SuperadminCircularDirectoryItem(
            id: 'item-$index-$i',
            institutionId: 'institution-1',
            title: 'Circular $index-$i',
            excerpt: 'Resumo',
            authorName: 'Equipe Coelo',
            contextLabel: 'Colegio Horizonte',
            status: CircularStatus.published,
            effectiveAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
            attachmentCount: 0,
            questionCount: 0,
            responseCount: 0,
            managementVersion: 1,
          ),
      ],
      nextCursorUpdatedAt: last ? null : DateTime.utc(2026, 9, 1),
      nextCursorId: last ? null : 'item-$index-19',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
