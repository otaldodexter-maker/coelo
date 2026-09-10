import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transbordamento vertical do diretorio de Importacoes, medido em 2026-09-10.
///
/// A leitura obvia do vermelho de import_development_routes_test — "o teste nao
/// fixa viewport e cai no 800x600" — esta errada, e a correcao obvia de fixar
/// 1440x900 esconderia o defeito dentro de uma correcao de teste. O que a
/// medicao mostra:
///
/// - o limiar e a ALTURA disponivel e o numero de linhas, nao a largura. Medido
///   linha por linha: 800x600 aguenta quatro trabalhos e transborda com cinco;
///   390x844 aguenta cinco e transborda com seis; 1440x900 aguenta oito e
///   transborda com dez. A tela estreita aguenta MAIS que a de 800x600 porque a
///   barra de ferramentas empilha de forma diferente, o que confirma que largura
///   sozinha nao explica nada aqui;
/// - a 1440x900 o transbordamento e de 70 pixels com dez trabalhos e 720 com
///   vinte, ou seja cerca de 65 pixels por linha, que e a altura de uma linha;
/// - a rota /dev/imports transborda em TODOS os viewports porque o repositorio de
///   desenvolvimento entrega muitas linhas, e o numero e identico com zero ou tres
///   trabalhos injetados por teste, o que confirma que a origem e a lista do
///   repositorio de desenvolvimento e nao a moldura da rota.
///
/// A causa esta no componente compartilhado, nao nesta tela:
/// `CoeloAdminResizableTable._tableBody` envolve as linhas num
/// `SingleChildScrollView` com `scrollDirection: Axis.horizontal` e monta as
/// linhas num `Column(mainAxisSize: min)`. Nao existe rolagem vertical, entao
/// passar da altura disponivel transborda e o conteudo fica inalcancavel.
///
/// Por isso aqui NAO ha correcao: o componente e usado por todos os diretorios
/// administrativos e a mudanca e decisao do Owner, registrada em
/// docs/reviews/etapa-2-operacao/reports/E2-noturna-tabela-admin-overflow-20260909.md.
/// O que este arquivo faz e preservar o sinal nos dois sentidos — garantir que o
/// que funciona hoje nao regrida, e deixar o defeito nomeado com o numero medido
/// em vez de escondido atras de um viewport generoso.
void main() {
  testWidgets('o diretorio nao transborda com oito trabalhos a 1440x900', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Oito e o ultimo valor medido como seguro nesta altura; nove nao foi medido.
    await _pump(tester, jobs: 8);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('import-table')), findsOneWidget);
  });

  testWidgets('o diretorio nao transborda em tela estreita com cinco trabalhos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, jobs: 5);

    expect(tester.takeException(), isNull);
  });

  testWidgets('o diretorio nao transborda na superficie padrao com quatro trabalhos', (
    tester,
  ) async {
    // 800x600 e a superficie que os testes de rota usam por omissao, e e a menos
    // tolerante das tres: quatro linhas passam, cinco transbordam.
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, jobs: 4);

    expect(tester.takeException(), isNull);
  });

  // O motivo vive no NOME porque testWidgets aceita somente bool em skip: quem
  // roda a suite ve a razao sem abrir o arquivo.
  testWidgets(
    'SKIP decisao do Owner: cinco trabalhos a 800x600, seis a 390x844 e dez a '
    '1440x900 transbordam, porque CoeloAdminResizableTable rola somente na horizontal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, jobs: 10);

      expect(tester.takeException(), isNull);
    },
    // Componente compartilhado por todos os diretorios administrativos; a
    // correcao e decisao do Owner e nao cabe numa frente isolada. Remover este
    // skip e o teste de aceite quando a decisao sair.
    skip: true,
  );
}

Future<void> _pump(WidgetTester tester, {required int jobs}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: ImportDirectoryPage(repository: _Repository(jobs), onNewImport: (_) {}),
      ),
    ),
  );
  for (var pump = 0; pump < 10; pump++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final class _Repository implements ImportRepository {
  _Repository(this.count);
  final int count;

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async =>
      ImportJobPage(items: List.generate(count, (index) => _job('job-$index')));
  @override
  Future<List<ImportJob>> fetchJobs() async => <ImportJob>[];
  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) => throw UnimplementedError();
  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) =>
      throw UnimplementedError();
  @override
  Future<ImportJob> update(ImportJob job) => throw UnimplementedError();
}

ImportJob _job(String id) => ImportJob(
  id: id,
  entity: ImportEntity.units,
  context: 'Unidades',
  file: ImportFileFixture.csv,
  strategy: ImportStrategy.createOnly,
  mapping: const {},
  previewRows: const [],
  conflicts: const [],
  result: const ImportResult(),
  status: ImportJobStatus.completed,
  progress: 100,
  actor: '—',
  createdAt: DateTime.utc(2026),
);
