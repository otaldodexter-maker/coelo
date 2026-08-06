---
source: "Solicitacao do Owner Coelo em 2026-08-04; docs/design/design-system.md; apps/superadmin/lib/app/router/superadmin_router.dart"
status: "approved"
generated_at: "2026-08-04"
---

# Navegacao persistente das pre-visualizacoes do Superadmin

## Objetivo e problema

Corrigir a navegacao lateral das rotas locais `/dev`: todos os destinos devem
funcionar fora de sequencia e a troca deve substituir somente o conteudo
principal, sem remontar perceptivelmente o menu e o shell.

## Escopo

- Reutilizar nas rotas de produto `/dev` o shell persistente ja aplicado nas
  rotas autenticadas.
- Centralizar os cliques do menu no dispatcher completo de desenvolvimento.
- Manter intacta a composicao visual aprovada de Menu/Flyouts.
- Exibir no menu `Pre-visualizacoes` todas as rotas-mae aprovadas, com rolagem
  limitada a viewport.

Ficam fora do escopo regras de negocio, repositorios, autorizacao, conteudo das
telas, rotas de criar/editar/detalhe e paginas de erro.

## Superficies, dados e permissoes

A mudanca afeta somente `apps/superadmin`: shell, roteador e menu local de
desenvolvimento. Nao cria entidades, dados persistidos, eventos, logs,
notificacoes ou permissoes. Rotas reais continuam protegidas pela sessao; rotas
`/dev` preservam a disponibilidade local existente.

## Estados de UX e responsividade

- Sidebar expandida ou recolhida preserva instancia, geometria e secoes abertas.
- O conteudo troca de forma instantanea por `KeyedSubtree`, sem fade ou slide.
- Reduced motion permanece instantaneo.
- O menu de pre-visualizacoes preserva trigger, cabecalho e itens atuais; sua
  lista rola em 375, 768, 1024 e 1440 px, com alvos minimos e teclado.
- O trigger permanece disponivel em `/dev/conversations`.

## Criterios de aceite e testes

- Instituicoes -> Pessoas -> Rotina diaria -> Atividades funciona por clique.
- A instancia e o estado recolhido do shell sobrevivem as trocas `/dev`.
- O destino atual e derivado corretamente de todas as rotas-mae `/dev`.
- `Pre-visualizacoes` contem somente as rotas-mae aprovadas e exclui criar,
  editar, detalhe, chamadas, preview docente e erros.
- Testes de widget cobrem navegacao nao linear, troca sem animacao, rolagem,
  teclado, reduced motion e os breakpoints exigidos; um golden registra o menu
  aberto sem substituir baselines existentes.

## Riscos e perguntas abertas

O worktree possui erros de compilacao preexistentes em Auditoria, Importacoes e
Avisos. Eles nao pertencem a esta entrega e podem bloquear a execucao integral
dos testes. Nao ha pergunta de produto aberta para esta correcao.
