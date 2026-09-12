---
title: "Varredura R01–R06 para a Rodada 7"
source: "R01-C01..C07-prompt.md; R02-20260909; R03-plano; R03-fase0-handoff; R04/R05/R06 prompts, fechamentos, perguntas; comunicacao/*.json; tres rastreadores; skills Coelo"
status: "em andamento"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Varredura R01–R06

## Método e base

Varredura iniciada na worktree `e2-r07-coordenacao`, sobre `origin/dev` após
`git fetch`. Foram conferidos os prompts e fechamentos disponíveis em
`next-round/`, a reconciliação R01–R02, handoffs/fase 0, perguntas R03–R06,
os canais históricos de `comunicacao/`, o inventário e as seções de pendências
das três skills Coelo. O estado medido foi cruzado pelos `action_id` nos três
rastreadores; não foi promovido nenhum estado apenas por texto histórico.

## Itens que permanecem executáveis na R07

| Item | Origem | Fonte | Estado atual medido | Dono R07 / primeiro gate |
| --- | --- | --- | --- | --- |
| `internal-users.create` | R06 / P52 | `R06-fechamento.md`, `coordenacao.json`, `coelo-supabase-pendencias.md` | Edge Function implantada pela coordenação R07; a prova pela rota normal ainda não foi feita | Acessos e Pessoas; login pela rota normal, create, reload e negativa RLS |
| `internal-users.create` e definição de senha | R06 / P51 | `R06-perguntas-ao-owner-20260911.md` | Owner escolheu B; SMTP próprio permanece fora do MVP | Acessos e Pessoas; manter fluxo honesto e registrar geração/entrega alternativa sem SMTP |
| `activities.assessment` | R06 / lote 54 | R06 e inventário | backend disponível; mutação e reload ainda `pending-verification` | Estrutura; rota real de configuração, período, entrada, nota, fechar/reabrir |
| `groups.members` | R01–R06 | três rastreadores e handoff de Estrutura | leitura/estado vazio provado; cadastro/busca da própria instituição não certificado | Estrutura; gate de pessoa sintética na instituição da turma |
| `groups.location` | R03–R06 | rastreadores e evidência de Estrutura | backend existe; seção de local no assistente e composição `available:true` não provadas | Estrutura; ligar seção e verificar reload |
| `invites.resend` | R01–R06 | inventário, R02 reconciliação, R06 | caminho expirado existe; não há convite expirado sintético provado na rota | Acessos e Pessoas; seed simples, resend, erro/persistência e reload |
| `chat.create-group` | R01–R06 | rastreador integrado, `realm-interno` | RPC e diálogo carregado; prova UI/reload continua não certificada | Principal, Chat e Sistema; repetir por semântica/Key, sem coordenadas após relayout |
| `chat.attach` | R01–R06 | rastreadores, handoffs de mídia | cliente preserva placeholder; gateway/catalogo/Edge Function comum ainda são gate | Realm interno + Principal/Chat; contrato de mídia, sem inventar bucket/URL |
| Publicadores com mídia | R05–R06 | R06 fechamento e evidência G4 | composição reconstruída; create/publish com mídia ainda local-green | Principal, Chat e Sistema; rota real via Media Gateway/R2 privado |
| Lançar chamada / Publicação | R05–R06 | R06 e referência aprovada | `attendance.create` funcional; composição visual da família Publicação ainda deve ser conferida | Formulários, Cuidado e Rotina; prova visual/rota/reload |
| `V-1` Perfil → Agora | R05–R06 / P54 | perguntas, rastreador | Owner adiou depois do MVP; não executar na R07 | Pergunta ao Owner, fora da fila executável |
| 9 goldens de Atividades | R05–R06 / P53 | perguntas, skill FE | pré-existentes; Owner escolheu manter; não regravar | Pergunta registrada, fora da fila executável |

Os itens acima já existem no inventário ou nos três rastreadores; esta tabela
não cria ação duplicada. O deploy de P52 foi removido do primeiro gate e deu
lugar à prova de `internal-users.create`.

## Pendências históricas sem item novo

P51, P53, P54 e a lista de @ reservados já estão em
`R06-perguntas-ao-owner-20260911.md`. `180060` está registrado como decisão de
produto e não como pacote novo. As suítes pré-existentes de `test/app` e
`test/core/config` permanecem documentadas na matriz, sem atribuição artificial
à R07.

## Branches fora de `dev`

As branches `work/etapa2-r03-*`, `work/etapa2-r04-*`, `work/etapa2-r05-*`,
`work/etapa2-r06-*`, `codex/e2-r02-*` e `work/etapa2-noturna-*` foram listadas
com seus commits fora de `origin/dev`. A decisão é integrar por conteúdo apenas
quando houver handoff/delta da rodada vigente; não copiar branches em bloco.
O conteúdo R01–R06 já consolidado em `dev` não será reaberto. O WIP
`wip/fase0-arquivo-chat` fica retido para o grupo Principal/Chat, que deve
comparar o conteúdo com a base antes de integrar. As sete branches R07
remotas com commits de abertura são frentes vivas, não órfãs, e aguardam o
primeiro ciclo de cobrança.

## Resultado da primeira varredura

Não foi encontrado item aberto fora do inventário, dos três rastreadores ou das
perguntas R06 que exija nova pergunta nesta abertura. O único deslocamento de
estado observado foi P52: deploy executado e registrado; a prova funcional
continua atribuída à frente de Acessos e Pessoas. A varredura permanece aberta
para os handoffs que chegarem durante a R07. A oitava frente G8 (Suítes
pré-existentes) foi incorporada depois da abertura e permanece coberta pelo
recibo da coordenação.

## Reconciliação R07 — item novo medido

- Item: `attendance.entry/complete` publicado pelo FCR em
  `deltas-r07-fcr.json`; a coordenação tentou o aplicador e ele rejeitou o ID
  como desconhecido.
- Rodada de origem: R07, frente Formulários, Cuidado e Rotina.
- Fonte: `comunicacao/formularios-cuidado-rotina.json` checkpoints R07 e
  `docs/reviews/evidence/etapa-2/r07-formularios-cuidado-rotina/deltas-r07-fcr.json`.
- Estado atual medido: código integrado, analyzer limpo, 140 testes da família
  verdes; sem rota real; os IDs canônicos de Assiduidade (`attendance.mark`,
  `attendance.finish`) já estão terminais no inventário; nenhum tracker foi
  rebaixado.
- Dono: frente FCR para a prova real; coordenação para reconciliar o
  identificador antes de novo delta.

### Reconciliação de delta R07 — Acessos e Pessoas

- `people.create` foi aplicado em `frontendStatus=local-green` com handoff
  local; `people.handle` não existe no inventário e foi retido.
- `access-profiles.edit` já era `verified`, então a prova local não o
  rebaixou; `people.edit`, `access-models.edit` e `internal-users.edit` não
  receberam promoção nova.
- O delta original permanece preservado em
  `docs/reviews/evidence/etapa-2/r07-acessos-pessoas/deltas-r07.json`; a
  entrada aplicável foi normalizada em
  `deltas-r07-coordenacao-aplicaveis.json`.
