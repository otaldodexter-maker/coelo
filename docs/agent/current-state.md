---
title: "Estado atual do trabalho do Coelo"
source: "Owner em 2026-09-14 e 2026-09-15; docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md; R14-pendencias.md; RODADAS.md; decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md; decisions/0040-agora-immediate-removal.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
audience: "team"
---

# Estado atual

## Agora

- A Etapa 2 está na R14, aberta em 14/09/2026 por decisão do Owner como **fila única
  consolidada** (R12/R13 congeladas como histórico; IDs preservados; itens `done`
  não retornam).
- A fila vive em um só lugar: `docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md`
  (Owner items, resíduos H, itens da ADR 0038 e ações não terminais por família).
- Último corte publicado: 15/09/2026, após a reconciliação das Sessões C, D e E
  — FE 186/232, BE 168/225, E2E 159/193 ativo. O Bloco A está 10/10 certificado;
  o Bloco B aplicou a reclassificação autorizada de sete ações; Cardápios tem
  prova FE/BE/E2E publicada, mas os quatro Owner items aguardam aceite central.
  Owner: 15/53 concluídos e 38 abertos/parciais.
- Entregas recentes ainda não alteram os quatro números certificados acima,
  exceto o delta oficial de Avaliações: `assessments.close/reopen` agora está
  certificado. Perfis de acesso não foi confirmado; Segurança infantil continua
  bloqueada por 504/sessão/CORS/massa; e Expirar/Excluir de Formulários tem
  somente avanço local e foi liberado para R15. A Sessão D foi
  integrada seletivamente ao `dev` (`0ab6abd8f`, `7797a8cad`, `2cd0da7c2`,
  `b135c8f20`, com dump produtivo preservado fora do Git). A Sessão E foi
  integrada no pacote coordenado `b023b4ccb`/`382c3b975`; `agora.remove` teve o
  contrato local reforçado em `2707086cf`, mas a negativa produtiva permanece
  bloqueada. Os números certificados permanecem inalterados fora do delta
  oficial de Avaliações.
- Bloqueios conhecidos durante a execução: o `504` de
  `child_safety_change_lifecycle` continua sem solução certificada. A entrega
  D não deve ser promovida por contador enquanto seus artefatos não estiverem
  reconciliados no corte central; o dump produtivo permanece fora do Git.
  O browser visível não é pré-requisito para o avanço automatizado.
- 15/09: a R14 executa em **paralelo** com a Sessão 1 encerrada (Blocos A–B),
  Sessões C/D/E entregues e reconciliadas no checkout coordenador; a coordenadora Codex atualiza
  os MDs na pasta principal. Papéis, portas, fluxo git e handoffs estão em
  `docs/reviews/etapa-2-operacao/next-round/R14-execucao-paralela.md`.
  As worktrees R14 existentes permanecem protegidas até o fechamento da rodada.
  Não reabrir decisões já registradas nas ADRs atuais.
- Decisão adicional do Owner em 15/09
  (`decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md`): Planos comerciais
  não entram no MVP; o reader de Planos fica para V1/V2, o reader self da Conta
  permanece no MVP/R14 e `auth.recover`/`auth.reset` ficam reservados à Etapa 3.
  Planos de medicação não são afetados.
- Decisão adicional do Owner em 15/09 (`decisions/0040-agora-immediate-removal.md`):
  a expiração automática do Agora continua em 24 horas, mas a remoção explícita
  passa a ser imediata. O `action_id` oficial `agora.remove` já tem pacote
  migration/Edge e prova produtiva integrado; a negativa cross-tenant específica
  foi tentada e bloqueada por fixture/helper ausente no schema remoto, com
  identidades temporárias removidas. O inventário permanece sem promoção.
- Decisão operacional do Owner em 15/09: Perfis de cuidado aceitam vários
  registros independentes de alergias e orientações. A validação da rota real
  deve cobrir adicionar/remover/reload sem reduzir o caso a dois registros; o
  backend deve aplicar limite defensivo de 100 registros por coleção/entidade,
  rejeitando o excesso sem deixar a proteção apenas no cliente.
- Fechamento de coordenação de 15/09: Forms `expire-file/delete-file` passou
  as suítes direcionadas, sem E2E remoto, e foi liberado para R15; o contexto
  Atividade de `attendance.create` foi isolado como bloqueio de RPC/massa em
  `14f6facab`. R16 permanece preparada, não aberta, para os resíduos da Sessão
  E e contratos sem action_id.

## Fonte da fila atual

Use, nesta ordem:

1. [Fila única R14](../reviews/etapa-2-operacao/next-round/R14-pendencias.md) — Owner
   items (fonte do sync), H, itens da ADR 0038 e ações não terminais;
2. [Estado atual da Etapa 2](../reviews/etapa-2-operacao/ETAPA-2-estado-atual.md) —
   percentuais canônicos;
3. [Inventário por action_id](../reviews/inventario-etapa-2.json) — detalhe e
   certificação por ação (estados só mudam por `apply-tracker-delta.cjs`);
4. [Checkpoint corrente da R14](../reviews/etapa-2-operacao/next-round/R14-checkpoint-20260915.md)
   — apenas para o delta do corte atual; checkpoints anteriores são históricos.

Os três rastreadores grandes são projeções do inventário para auditoria; não são a
entrada inicial. `R12-pendencias.md`, `R13-pendencias.md`, `R14-catalogo.md`,
`R13-projecao-atual.md` e `R13-owner-items-atual.json` são históricos/derivados.

## Regra de passagem entre rodadas (aplicada em 14/09 na R13 → R14)

A cada fechamento de rodada:

- itens `done` ou aceitos não são transferidos nem reabertos;
- itens `open`, `partial`, bloqueados ou sem prova são levados para a R14 com o
  mesmo `action_id`/Owner ID e nova referência de rodada;
- não criar cópia concorrente em R12, R13 ou R14;
- atualizar este arquivo, `RODADAS.md`, o catálogo corrente, o inventário e os
  rastreadores no mesmo ciclo;
- somente depois registrar que a R14 está aberta.

## Fora do trabalho corrente

Etapa 3, V1, V2, pós-MVP, históricos R01–R13 e artefatos de execução não são
trabalho corrente. Consulte [backlog.md](backlog.md) apenas quando a tarefa
explicitamente tratar desses horizontes.

Para uma tarefa explícita de limpeza, use o
[backlog de artefatos](artifact-cleanup-backlog-20260914.md), não a fila R14.
