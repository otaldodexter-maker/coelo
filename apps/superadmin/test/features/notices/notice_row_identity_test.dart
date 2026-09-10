import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

/// A listagem de comunicacoes troca de tabela para cartoes abaixo do breakpoint
/// medio. A tabela sempre identificou cada linha por `communication-row-<id>`;
/// os cartoes nao carregavam identificador nenhum, e no estreito nenhuma
/// comunicacao era alcancavel pelo proprio id.
///
/// O que se mede aqui nao e a existencia da chave, e o EFEITO: em qualquer
/// largura, cada comunicacao VISIVEL pode ser encontrada e acionada pelo seu
/// identificador, e o identificador e o mesmo nas duas apresentacoes.
void main() {
  for (final caso in const [
    (size: Size(1440, 900), nome: 'tabela'),
    (size: Size(375, 812), nome: 'cartoes'),
  ]) {
    testWidgets('cada comunicacao visivel e alcancavel pelo id em ${caso.nome}', (tester) async {
      final repository = _repository();
      final criadas = [
        repository.create(_draft(1)),
        repository.create(_draft(2)),
        repository.create(_draft(3)),
      ];

      final editados = <String>[];
      await _pump(tester, repository, caso.size, editados.add);

      // Quais comunicacoes esta largura mostra na primeira pagina e decisao da
      // tela, e no estreito cabem menos. O que nao pode variar e: toda
      // comunicacao MOSTRADA tem de ser alcancavel por id.
      final visiveis = criadas.where((n) => find.text(n.title).evaluate().isNotEmpty).toList();
      expect(visiveis, isNotEmpty, reason: 'nenhuma comunicacao apareceu em ${caso.nome}');

      for (final notice in visiveis) {
        expect(
          _porId(notice.id),
          findsWidgets,
          reason: '${notice.id} aparece em ${caso.nome} mas nao e alcancavel por id',
        );
      }

      // Alcancavel nao basta: tem de acionar a comunicacao CERTA. Sem isto,
      // uma chave posta no widget errado passaria na verificacao acima.
      final alvo = visiveis.first;
      // No estreito o composto mostra toggle, abas e o card Criar antes do
      // primeiro item; rolar ate o alvo antes de tocar.
      await tester.ensureVisible(_porId(alvo.id).first);
      await tester.pumpAndSettle();
      await tester.tap(_porId(alvo.id).first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(editados, [alvo.id], reason: 'o toque em ${caso.nome} abriu outra comunicacao');
    });
  }

  testWidgets('o identificador nao muda quando a apresentacao muda', (tester) async {
    final repository = _repository();
    final primeira = repository.create(_draft(1));

    // Uma lista que muda de forma nao deveria mudar de identidade: quem
    // escreve teste, automacao ou suporte nao precisa saber a largura da tela
    // para falar da mesma comunicacao.
    await _pump(tester, repository, const Size(1440, 900), (_) {});
    expect(_porId(primeira.id), findsWidgets);

    await _pump(tester, repository, const Size(375, 812), (_) {});
    expect(_porId(primeira.id), findsWidgets);
  });
}

/// Aceita a chave crua e as chaves derivadas que a tabela administrativa gera
/// em volta dela (fundo de linha, celulas). O contrato e o identificador estar
/// presente, nao o widget exato que o carrega.
Finder _porId(String id) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.contains('communication-row-$id');
});

Future<void> _pump(
  WidgetTester tester,
  FakeNoticeRepository repository,
  Size size,
  ValueChanged<String> onEdit,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: NoticeDirectoryPage(repository: repository, canManageLifecycle: true, onEdit: onEdit),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

FakeNoticeRepository _repository() {
  final now = DateTime.utc(2026, 8, 3, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  return FakeNoticeRepository(store: store, now: () => now);
}

NoticeDraft _draft(int index) => NoticeDraft(
  type: CommunicationType.notice,
  title: 'Aviso $index',
  message: 'Mensagem $index',
  priority: NoticePriority.routine,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.dismissible,
);
