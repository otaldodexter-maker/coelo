---
title: "Delta das skills a partir da Rodada 4 — grupo principal-chat-sistema"
source: "principal-chat-sistema.json rev 9 a 18; handoff da R04; coordenacao.json rev 20 a 30; rastreadores em origin/dev 0376a0446"
status: "proposta do grupo; o coordenador integra em dev"
generated_at: "2026-09-11"
---

# Delta das skills — R04, principal-chat-sistema

Validação de entrega feita às 08:30 de 11/09 sobre `origin/dev 0376a0446`:
a branch `work/etapa2-r04-principal-chat-sistema` (HEAD 889e289a8) está
inteira em `dev`; os oito pacotes do grupo (`20260910190300` a `191000`) estão
em `packages/coelo_database/migrations/` (aplicados nos lotes 9, 11 e 22); o
JSON do grupo (rev 17) e o handoff estão integrados; os três rastreadores
refletem os deltas aceitos (chat.list/open/send/edit/receipts/revoke
`verified-e2e`, auth.login/logout `verified-e2e`, shell.load/navigate/reload/
unauthorized `verified`, imports.list/catalog.list/meal-plans.list `verified`,
chat.create-group FE `verified` e BE `done`). As perguntas ao Owner estão em
`R04-perguntas-ao-owner-20260911.md` (P23, P26, P27, P28, P35, P37). Nenhum
WIP ficou fora do Git.

## O que muda nas skills (aplicado nesta branch, commit próprio)

**`coelo-backend`** (`.agents/skills/coelo-supabase/SKILL.md`)

- Pendência 1 (token R2): registrar o efeito como feito — `happens-media` e
  `now-media` implantadas em 10/09 22:24 (lote 9).
- Padrão de mídia nova (modelo de Circulares, repetido em Agora e Acontece):
  default `r2`, bucket por MIME, chave opaca, `NOT VALID` condicionado ao
  legado, `finalize` sem `storage.objects` no R2, descritor com
  `storage_provider`, sem bucket novo no Storage; órfão na substituição.
- Agora em produção (190300..190600) e a expiração sem agendador.
- Causa raiz do `anon` (privilégio padrão), o que `190900` revogou e as 12
  funções invoker que ficam para a revisão profunda.
- Presença do nome não prova o corpo (`pg_get_functiondef` decide).
- pgTAP: aspas duplas viram identificador; asserções por substring de
  `pg_get_functiondef` quebram a cada hardening; helper `pg_temp` security
  definer para ler ids antes de trocar de papel.

**`coelo-frontend`** (`.agents/skills/coelo-flutter-review/SKILL.md`)

- D3 sem "prévia" em produção; Catálogo não é preview.
- Estender interface de repositório exige completar os fakes de teste no
  mesmo commit (`flutter analyze test` lista todos).
- Momentos por largura (tela cheia até 768, moldura a partir de 840, aside a
  partir de 1200, mídia `contain` sobre preto); goldens 1024/1440 são R.
- Diálogo com altura dependente de dados de produção não se dirige por
  coordenadas na rota real.

**`coelo-frontend-backend`** (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

- `localhost` x `127.0.0.1` na mesma porta (duas pilhas, dois apps).
- Negativa cross-tenant pela própria RPC de produção vale como prova.
- E2E que depende de fixture sintética de outro grupo: combinar pelo JSON,
  registrar o que criou e entrar na limpeza (P37).

Sugestão fora das três skills: a composição de Momentos por largura e o
véu do chip Destaque (orange950 a 16%) pertencem também à `coelo-ui`.

## O que evoluiu na Etapa 2 por causa desta frente

- Agora existe em produção pela primeira vez (fundação, audiência, expiração,
  R2); Acontece tem retirada com `can_withdraw` no feed direto e misto e mídia
  em R2; as duas funções de mídia estão implantadas.
- Chat interno v2 provado ponta a ponta pela tela real com sessão de produção:
  inbox, abrir, enviar, editar (com janela de 15 min negando), revogar,
  recibo, Criar grupo pela RPC (replay idempotente, `CHAT_MEMBER_INVALID`,
  `CHAT_NOT_FOUND`) e diálogo de Criar grupo carregando instituição e pessoas
  de produção. Primeiros `verified-e2e` da Etapa 2.
- Superfície de `anon` fechada nas funções security definer de `public` e no
  privilégio padrão.
- Shell: launcher "Mensagens" da referência aprovada, com a flag da tela
  chegando ao hospedeiro (Decisão 7); ARQUIVO nos cards de Cardápios e
  Planos; véu do Destaque; D3 em 14 textos; Cardápios abre na rota real com a
  ponte de ator; Momentos na composição larga aprovada.
- 43 goldens regravados após observação (launcher, Cardápios, Planos, Para
  você, Chat, Momentos, Importações); imagens candidatas do erro 409.

## Pendências que ficam para depois (com o primeiro gate)

| Pendência | Gate | Quando |
| --- | --- | --- |
| Principal (Acontece, Momentos, Agora, Para você, Perfil) na rota real | membership institucional para a pessoa de serviço de qa-r03 (P35) | próxima rodada |
| Criar grupo pela UI até o grupo aparecer | dirigir por semântica/Key, não por coordenadas; `DropdownButtonFormField` do diálogo com `ValueKey(_institutionId)` para refletir a seleção automática | próxima rodada |
| CRUD de Cardápios pela UI (create/edit/model/publish) | ambiente pronto; sem prova nesta rodada | próxima rodada |
| Perfil: Acompanhar/Seguidores/Seguindo (R) e FOTO | D1 backfill já em produção (lote 16); UI não consome; P28 sobre a foto | próxima rodada |
| Galeria mobile do Acontece "mais Instagram" | direção do Owner | decisão |
| Curtir/comentar no Acontece | não existem no banco; pacote próprio | pós-MVP |
| Agendador da expiração do Agora | pg_cron ou worker (coordenador) | pós-MVP ou quando o Agora publicar |
| Coletor de órfãos no R2 para Agora/Acontece | modelo do de Momentos | pós-MVP |
| 12 funções invoker de `public` executáveis por `anon` | revisão profunda de segurança | pós-MVP |
| Erro 409 como golden oficial; Duplicar em Cardápios (ícone e menu) | P26, P27 | decisão do Owner |
| `pumpAndSettle` não assenta no hospedeiro desktop | animação a investigar | pós-MVP |
| `development_dataset_contract_test` já falha em dev (5 x 8..14 instituições) | dataset de desenvolvimento | fora do recorte |
| Dados sintéticos do chat em produção (conversa `355a3403-26bf-4f0c-9f76-9c0ba0bb04f6` na instituição `9f04…0010`, com mensagens) | limpeza P37 | fim da rodada |
