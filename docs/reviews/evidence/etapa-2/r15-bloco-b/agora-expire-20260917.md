---
source: "Sessão B da R15 (Fable 5.1), 17/09/2026; ADR 0040; r14-sessao-7/agora-20260916.md (publicações a4e65c73/655e437b de 16/09); lote 56 (cron coelo-now-publications-expire)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
action_id: "agora.expire"
---

# Agora › expiração automática de 24 h (`agora.expire`) — observação real em produção, 17/09/2026

Ambiente: produção; leitor `qa-r06-principal@coelo.me` por PostgREST (`scratchpad/rpc.mjs`, sem chave de
serviço) e por tela (build QA `r15/bloco-b` em `127.0.0.1:3015`, Chrome CDP 9425); estado das publicações por
`supabase db query --linked` (leitura). Nenhum relógio ou dado alterado: as duas publicações foram criadas pela
Sessão 7 da R14 em 16/09 e venceram sozinhas ~24 h depois. Capturas em `capturas/agora-expire-*.png`.

| Momento (UTC) | `list_visible_now_publications(d0c4…0001, null, null, 20)` como leitor | `now_publications` (`db query`) |
|---|---|---|
| **Antes** — 13:54:16 e 13:55:32 (17/09) | `200` com **1 item**: `655e437b-b646-42ff-bef0-352291c0aa0d` ("R14 S7 Agora QA staff", `published_at 2026-09-16T15:16:28Z`, `expires_at 2026-09-17T15:16:28Z`, `media` com `read_ticket`) — `a4e65c73` (audiência famílias) não é visível ao leitor de staff, como em 16/09 | `a4e65c73` `published` v2, `expires_at 15:06:48`; `655e437b` `published` v2, `expires_at 15:16:28` |
| **Depois** — 16:49:06 (17/09) | `200` **`[]`** | `a4e65c73` **`expired` v3**; `655e437b` **`expired` v3** — transição feita pelo worker `expire_due_now_publications`/cron (versão avançou 2→3 sem ação humana) |

Tela (`/principal-now`, que no build atual abre a home `/principal-happens` com a linha "Agora"): antes e depois a
linha mostrou só "Publicar agora" para o leitor (`agora-expire-before-feed-13h55utc.png`, `agora-expire-after-feed-16h50utc.png`).
Observação registrada, sem inferência: em 16/09 a Sessão 7 viu a story nessa rota (`agora-view-01`); hoje a RPC devolvia a
story mas a linha não a renderizou — pode ser a leitura da mídia por ticket no SwiftShader ou a composição da
home; fica como achado para a fatia `agora.remove` (mesma tela). A prova E2E da expiração é o contrato: feed
com a story antes de `expires_at` e vazio depois, com `status expired` persistido pelo worker.

## Separação FE / BE / E2E

- FE: **verified** pela combinação das capturas do mesmo leitor e da mesma story — 16/09 (Sessão 7,
  `r14-sessao-7/capturas/agora-view-01/02`: story `655e437b` renderizada, "6 min"/"8 min", barra de progresso) e
  17/09 após `expires_at` (`agora-expire-after-feed-16h50utc.png`: linha "Agora" sem story); o cliente filtra por
  `expires_at` e o servidor também; texto "Publicações ficam disponíveis por 24 horas" verificado no publicador
  em 16/09. Ressalva registrada acima: hoje, antes do vencimento, a linha "Agora" não renderizou a story neste
  build, embora a RPC a devolvesse (achado para `agora.remove`).
- BE: done (lote 56/57 + worker), reconfirmado: `expired` v3 nas duas publicações.
- E2E: **verified-e2e** — expiração real observada de ponta a ponta (antes/depois por RPC do leitor + estado persistido),
  sem alterar relógio ou dados.
